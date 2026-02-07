class Api::ItemsController < ApplicationController
  before_action :require_authentication, except: [ :index, :show, :search, :track_view, :stats ]
  before_action :resume_session, only: [ :show, :track_view ]
  before_action :set_item, only: [ :show, :update, :destroy, :track_view, :user_request ]

  include ApiCursorPagination

  def index
    paginated_items_response item_service.available_items
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def my_items
    @items = Current.user.items.includes(:item_requests).recent
    render json: {
      statuses: ShareableItemStatus.data,
      items: @items.map { |item| item_service.item_map(item) }
    }
  end

  def show
    render json: item_service.item_detail_map(@item, Current.user)
  end

  def create
    item = item_service.create_item(Current.user, item_params)
    if item
      render json: item_service.item_detail_map(item, Current.user), status: :created
    else
      render json: { errors: item_service.errors }, status: :unprocessable_entity
    end
  end

  def update
    if item_service.update_item(Current.user, item_params)
      render json: item_service.item_detail_map(@item, Current.user), status: :ok
    else
      render json: { errors: item_service.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if item_service.remove_item(Current.user)
      render json: { message: "Item deleted successfully" }, status: :ok
    else
      render json: { errors: item_service.errors }, status: :unprocessable_entity
    end
  end

  def search
    paginated_items_response item_service.search_items(
      query_string: params[:query],
      zip_code: params[:zip_code],
      radius: params[:radius],
      community_group_id: params[:community_group_id],
      sub_group_id: params[:sub_group_id]
    )
  end

  def track_view
    render json: { view_count: item_service.track_item_view(Current.user) }
  end

  def user_request
    unless Current.user
      render json: { has_requested: false }
      return
    end

    request = @item.item_requests.find_by(requester: Current.user, status: [ ItemRequest::PENDING_STATUS, ItemRequest::ACCEPTED_STATUS ])

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
      stats = item_service.community_group_stats(community_group_id: params[:community_group_id], sub_group_id: params[:sub_group_id])
    else
      stats = item_service.community_stats(zip_code: params[:zip_code], radius: params[:radius])
    end
    render json: stats
  end

  private

  def item_service
    @item_service ||= ItemService.get_service(params[:type], @item)
  end

  def set_item
    @item = Item.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:type, :title, :author, :condition, :summary, :isbn, :genre, :published_year,
    :cover_image, :api_cover_image, :personal_note, :pickup_method, :pickup_address,
    community_group_ids: [], user_images: [], remove_user_image_indices: [])
  end

  def paginated_items_response(items)
    @errors = []
    # Validate and set pagination options from params
    validate_and_setup_page_params(params[:page])

    if @errors.blank?
      paginated_items = paginate(items.select("items.*, items.id as item_id"), "items.id", "item_id")
      # Build API response with pagination metadata
      response = {
        status: "Success",
        data: paginated_items.map { |item| item_service.item_map(item) }
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
