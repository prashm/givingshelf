# app/jobs/book_request_notification_job.rb
class BookRequestNotificationJob < ApplicationJob
  queue_as :default

  def perform(item_request)
    BookRequestMailer.new_request_notification(item_request).deliver_later
  end
end
