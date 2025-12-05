# app/jobs/message_notification_job.rb
class MessageNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id, recipient_user_id)
    message = Message.find(message_id)
    recipient = User.find(recipient_user_id)

    MessageMailer.new_message_notification(message, recipient).deliver_later
  end
end
