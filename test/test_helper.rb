ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    # Helper method to set up authentication for API tests
    def sign_in_as(user)
      session = user.sessions.create!(
        user_agent: "Test Agent",
        ip_address: "127.0.0.1"
      )
      # In integration tests, cookies returns Rack::Test::CookieJar which doesn't have signed
      # We need to create a proper cookie jar with signed support
      # Create a mock request to get a proper cookie jar
      env = Rails.application.env_config.dup
      request = ActionDispatch::Request.new(env)
      cookie_jar = request.cookie_jar
      cookie_jar.signed[:session_id] = session.id
      # Copy the signed cookie value to the test cookies
      cookies[:session_id] = cookie_jar[:session_id]
      session
    end
  end
end
