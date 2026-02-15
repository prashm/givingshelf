# app/jobs/item_request_notification_job.rb
class ItemRequestNotificationJob < ApplicationJob
  queue_as :default

  def perform(item_request)
    ItemRequestMailer.new_request_notification(item_request).deliver_later
  end
end
