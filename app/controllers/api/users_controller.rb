class Api::UsersController < ApplicationController
  before_action :require_authentication
  before_action :set_user, only: [ :show, :update, :update_community_groups ]

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

  def update_community_groups
    if @user != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    group_ids = params[:group_ids] || []

    # Get current memberships (all memberships, not just non-auto-joined)
    current_memberships = Current.user.community_group_memberships
    current_group_ids = current_memberships.pluck(:community_group_id)

    # Find groups to add and remove
    groups_to_add = group_ids.map(&:to_i) - current_group_ids
    groups_to_remove = current_group_ids - group_ids.map(&:to_i)

    # Add new memberships (only if not already a member)
    groups_to_add.each do |group_id|
      group = CommunityGroup.find_by(id: group_id)
      next unless group

      # Only add if not already a member (avoid duplicate)
      unless Current.user.community_group_memberships.exists?(community_group: group)
        Current.user.community_group_memberships.create!(
          community_group: group,
          admin: false,
          auto_joined: false
        )
      end
    end

    # Remove memberships (all memberships can be removed)
    groups_to_remove.each do |group_id|
      membership = current_memberships.find_by(community_group_id: group_id)
      membership&.destroy
    end

    render json: {
      message: "Community groups updated successfully",
      group_ids: Current.user.community_group_memberships.pluck(:community_group_id)
    }
  rescue => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :zip_code, :phone, :profile_picture, :street_address, :city, :state, :address_verified)
  end

  def user_json(user)
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
      community_groups: user.community_group_memberships.includes(:community_group).map { |m|
        {
          id: m.community_group.id,
          name: m.community_group.name,
          short_name: m.community_group.short_name,
          admin: m.admin,
          auto_joined: m.auto_joined
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
