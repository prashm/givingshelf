class Api::UsersController < ApplicationController
  before_action :require_authentication
  before_action :set_user, only: [ :show, :update ]

  def show
    if @user == Current.user || Current.user.verified?
      render json: user_json(@user)
    else
      render json: { error: "Not authorized" }, status: :forbidden
    end
  end

  def update
    if @user != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    user_service = UserService.new(Current.user)
    if user_service.update_user(user_params.to_h)
      render json: user_json(@user.reload)
    else
      render json: { errors: user_service.errors }, status: :unprocessable_entity
    end
  end

  def profile
    render json: user_json(Current.user)
  end

  def my_requests
    @requests = Current.user.book_requests.includes(:book, :requester).recent
    render json: @requests.map { |request| request_json(request) }
  end

  def received_requests
    @requests = BookRequest.for_book_owner(Current.user).includes(:book, :requester).recent
    render json: @requests.map { |request| request_json(request) }
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :zip_code, :phone, :profile_picture, :street_address, :city, :state, :address_verified)
  end

  def user_json(user)
    memberships = user.community_group_memberships.includes(:sub_group, :community_group)
    {
      id: user.id,
      email_address: user.email_address,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      display_name: user.display_name,
      zip_code: user.zip_code,
      phone: user.phone,
      street_address: user.street_address,
      city: user.city,
      state: user.state,
      address_verified: user.address_verified?,
      trust_score: user.trust_score || 0,
      verified: user.verified?,
      profile_complete: user.profile_complete?,
      profile_picture_url: user.profile_picture.attached? ? user.profile_picture.attachment.url : nil,
      community_groups: memberships.map { |m|
        sub_group = m.sub_group
        group = m.community_group
        grp_name = group.name
        if sub_group.present? && group.short_name == CommunityGroup::ZIPCODE_SHORT_NAME
          grp_name = "#{sub_group.name} Community"
        end
        {
          id: group.id,
          name: grp_name,
          short_name: group.short_name,
          public: group.public,
          auto_joined: m.auto_joined,
          sub_group: sub_group ? { id: sub_group.id, name: sub_group.name } : nil
        }
      },
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def request_json(request)
    {
      id: request.id,
      status: request.status,
      message: request.message,
      created_at: request.created_at,
      updated_at: request.updated_at,
      book: {
        id: request.book.id,
        title: request.book.title,
        author: request.book.author,
        cover_image_url: request.book.cover_image.attached? ? rails_blob_url(request.book.cover_image) : nil
      },
      requester: {
        id: request.requester.id,
        name: request.requester.display_name,
        location: request.requester.location,
        verified: request.requester.verified?
      }
    }
  end
end
