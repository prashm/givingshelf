class ItemRequestChatChannel < ApplicationCable::Channel
  def subscribed
    @item_request = ItemRequest.find(params[:item_request_id])

    unless can_access_chat?
      reject
      return
    end

    stream_from "item_request_#{params[:item_request_id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def receive(data)
    @item_request = ItemRequest.find(params[:item_request_id])

    unless can_access_chat?
      transmit({ type: "error", message: "Not authorized" })
      return
    end

    content = data["content"].to_s.strip
    if content.blank? || content.length > 1000
      transmit({ type: "error", message: "Invalid message content" })
      return
    end

    message = @item_request.messages.create!(
      user: current_user,
      content: content
    )

    # Broadcast to all subscribers
    ActionCable.server.broadcast(
      "item_request_#{params[:item_request_id]}",
      {
        type: "message",
        message: {
          id: message.id,
          content: message.content,
          user_id: message.user.id,
          user_name: message.user.display_name,
          created_at: message.created_at.iso8601
        }
      }
    )

    # Check if recipient is active and handle email notification
    handle_message_notification(message)
  end

  def typing(data)
    @item_request = ItemRequest.find(params[:item_request_id])

    unless can_access_chat?
      transmit({ type: "error", message: "Not authorized" })
      return
    end

    is_typing = data["is_typing"] != false # Default to true if not specified

    # Broadcast typing status to all subscribers
    ActionCable.server.broadcast(
      "item_request_#{params[:item_request_id]}",
      {
        type: "typing",
        user_id: current_user.id,
        user_name: current_user.display_name,
        is_typing: is_typing
      }
    )
  end

  private

  def can_access_chat?
    return false unless current_user
    @item_request.requester == current_user || @item_request.owner == current_user
  end

  def handle_message_notification(message)
    # Determine the recipient (the other user in the conversation)
    recipient = message.user == @item_request.requester ? @item_request.owner : @item_request.requester

    # Check if recipient is currently active using the presence channel class method
    begin
      recipient_active = ItemRequestPresenceChannel.is_user_active?(@item_request.id, recipient.id)
    rescue => e
      Rails.logger.warn "Failed to check user presence: #{e.message}. Assuming inactive."
      recipient_active = false
    end

    # Only send email if recipient is not active
    unless recipient_active
      MessageNotificationJob.perform_later(message.id, recipient.id)
    end
  end
end
