require "test_helper"
require "minitest/spec"

class BookTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  def setup
    @owner = users(:one)
    @requester = users(:two)
    @book = books(:one)
    @zip_group = CommunityGroup.find_or_create_zipcode_group!
    @other_group = community_groups(:one)

    # Clean up any existing requests for the test book to avoid conflicts
    BookRequest.where(book: @book, requester: @requester).destroy_all
    # Ensure book is available
    @book.update!(status: BookStatus::AVAILABLE)
  end
end
