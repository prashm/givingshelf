class Api::ToysController < ApplicationController
  before_action :require_authentication, except: [ :index, :show, :search, :track_view, :stats ]
  before_action :resume_session, only: [ :show, :track_view ]
  before_action :set_toy, only: [ :show, :update, :destroy, :track_view ]

  include ApiCursorPagination

  def index
    paginated_toys_response Toy.available.includes(:user).recent
  end

  def my_toys
    @toys = Current.user.toys.includes(:item_requests).recent
    render json: {
      statuses: ShareableItemStatus.data,
      toys: @toys.map { |toy| my_toy_json(toy) }
    }
  end

  def show
    render json: toy_service.toy_json(@toy, Current.user)
  end

  def create
    toy = toy_service.create_toy(Current.user, toy_params)
    if toy
      render json: toy_service.toy_json(toy, Current.user), status: :created
    else
      render json: { errors: toy_service.errors }, status: :unprocessable_entity
    end
  end

  def update
    if toy_service.update_toy(Current.user, toy_params)
      render json: toy_service.toy_json(@toy, Current.user), status: :ok
    else
      render json: { errors: toy_service.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if toy_service.remove_toy(Current.user)
      render json: { message: "Toy deleted successfully" }, status: :ok
    else
      render json: { errors: toy_service.errors }, status: :unprocessable_entity
    end
  end

  def search
    paginated_toys_response toy_service.search_toys(
      query_string: params[:query],
      zip_code: params[:zip_code],
      radius: params[:radius],
      community_group_id: params[:community_group_id],
      sub_group_id: params[:sub_group_id]
    )
  end

  def track_view
    render json: { view_count: toy_service.track_toy_view(Current.user) }
  end

  def user_request
    @toy = Toy.find(params[:id])

    unless Current.user
      render json: { has_requested: false }
      return
    end

    request = @toy.item_requests.find_by(requester: Current.user, status: [ ItemRequest::PENDING_STATUS, ItemRequest::ACCEPTED_STATUS ])

    if request
      render json: {
        has_requested: true,
        request: {
          id: request.id,
          status: request.status,
          created_at: request.created_at,
          message: request.message
        }
      }
    else
      render json: { has_requested: false }
    end
  end

  def stats
    if params[:community_group_id].present?
      if params[:community_group_id].to_i <= 0 || !CommunityGroup.exists?(params[:community_group_id].to_i)
        render json: { error: "Group not found" }, status: :not_found
        return
      end
      # TODO: Implement toy-specific stats if needed
      stats = {}
    else
      # TODO: Implement toy-specific stats if needed
      stats = {}
    end
    render json: stats
  end

  private

  def toy_service
    @toy_service ||= ToyService.new(@toy)
  end

  def set_toy
    @toy = Toy.find(params[:id])
  end

  def toy_params
    params.require(:toy).permit(:title, :brand, :age_range, :condition, :summary,
                                 :cover_image, :api_cover_image, :personal_note, :pickup_method, :pickup_address,
                                 community_group_ids: [], user_images: [], remove_user_image_indices: [])
  end

  def my_toy_json(toy)
    {
      id: toy.id,
      title: toy.title,
      brand: toy.brand,
      age_range: toy.age_range,
      condition: toy.condition,
      status: toy.status,
      status_display: ShareableItemStatus.display_status(toy.status),
      cover_image_url: toy.cover_image.attached? ? toy.cover_image.attachment.url : nil,
      created_at: toy.created_at
    }
  end

  def paginated_toys_response(toys)
    @errors = []
    # Validate and set pagination options from params
    validate_and_setup_page_params(params[:page])

    if @errors.blank?
      paginated_toys = paginate(toys.select("items.*, items.id as toy_id"), "items.id", "toy_id")
      # Build API response with pagination metadata
      response = {
        status: "Success",
        data: paginated_toys.map { |toy| my_toy_json(toy) }
      }.merge(page_links_and_meta_data(request.base_url + request.path, request.query_parameters))

      render json: response, status: :ok
    else
      render json: error_response, status: :unprocessable_entity
    end
  end

  def error_response
    {
      status: "Error",
      errors: @errors.map { |error| error.is_a?(Hash) ? error : { title: error } }
    }
  end
end
