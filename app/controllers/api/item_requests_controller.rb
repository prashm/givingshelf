class Api::ItemRequestsController < ApplicationController
  before_action :require_authentication
  before_action :set_item_request, only: [ :show, :update, :destroy, :messages ]

  def index
    item_requests = item_request_service.requests_for_user(Current.user, params[:type])
    render json: item_requests.map { |req| item_request_service.request_json(req) }
  end

  def show
    unless @item_request.requester == Current.user || @item_request.item.owner?(Current.user)
      render json: { error: "Not authorized" }, status: :forbidden
    else
      render json: item_request_service.request_json(@item_request)
    end
  end

  def create
    item_request = item_request_service.create_request(Current.user, params[:item_id], params[:message])
    if item_request
      render json: item_request_service.request_json(item_request), status: :created
    else
      Rails.logger.error "Item request creation failed: #{item_request_service.errors.join(', ')}"
      render json: { errors: item_request_service.errors }, status: :unprocessable_entity
    end
  end

  def update
    if item_request_service.update_request(Current.user, params[:action_type])
      render json: item_request_service.request_json(item_request_service.item_request)
    else
      render json: { errors: item_request_service.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if item_request_service.cancel_request(Current.user)
      render json: { message: "Request cancelled successfully" }
    else
      render json: { errors: item_request_service.errors }, status: :unprocessable_entity
    end
  end

  def messages
    unless @item_request.requester == Current.user || @item_request.owner == Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    # Fetch most recent 50 messages, ordered by created_at desc (newest first)
    # Then reverse for display (oldest first)
    messages = @item_request.messages
      .includes(:user)
      .recent
      .limit(50)
      .to_a
      .reverse

    render json: {
      messages: messages.map { |msg|
        {
          id: msg.id,
          content: msg.content,
          user_id: msg.user.id,
          user_name: msg.user.display_name,
          created_at: msg.created_at.iso8601
        }
      }
    }
  end

  private

  def item_request_service
    @item_request_service ||= ItemRequestService.new(@item_request)
  end

  def set_item_request
    @item_request = ItemRequest.find(params[:id])
  end
end
