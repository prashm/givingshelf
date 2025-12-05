# app/jobs/book_request_notification_job.rb
class BookRequestNotificationJob < ApplicationJob
    queue_as :default

    def perform(book_request)
      BookRequestMailer.new_request_notification(book_request).deliver_later
    end
end
