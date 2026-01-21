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

  describe "#can_be_requested_by?" do
    it "returns false when user is nil" do
      assert_not @book.can_be_requested_by?(nil)
    end

    it "returns false when book is not available" do
      @book.update!(status: BookStatus::DONATED)
      assert_not @book.can_be_requested_by?(@requester)
    end

    it "returns false when user is the owner" do
      assert_not @book.can_be_requested_by?(@owner)
    end

    it "returns false when user has pending request" do
      BookRequest.create!(
        book: @book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: BookRequest::PENDING_STATUS
      )
      assert_not @book.can_be_requested_by?(@requester)
    end

    it "returns false when book has no groups" do
      GroupBookAvailability.where(book: @book).delete_all
      assert_not @book.can_be_requested_by?(@requester)
    end

    it "returns false when user is not in any of the book's groups" do
      GroupBookAvailability.where(book: @book).delete_all
      GroupBookAvailability.create!(book: @book, community_group: @other_group)
      CommunityGroupMembership.where(user: @requester, community_group: @other_group).delete_all

      assert_not @book.can_be_requested_by?(@requester)
    end

    it "returns true when user is in at least one of the book's groups" do
      # Ensure book is available
      @book.update!(status: BookStatus::AVAILABLE)

      GroupBookAvailability.where(book: @book).delete_all
      GroupBookAvailability.create!(book: @book, community_group: @other_group)
      CommunityGroupMembership.find_or_create_by!(user: @requester, community_group: @other_group) do |m|
        m.admin = false
        m.auto_joined = false
      end

      assert @book.can_be_requested_by?(@requester)
    end

    it "returns true when book is only in zipcode group and user is in zipcode group" do
      # Ensure book is available
      @book.update!(status: BookStatus::AVAILABLE)

      GroupBookAvailability.where(book: @book).delete_all
      GroupBookAvailability.create!(book: @book, community_group: @zip_group)
      CommunityGroupMembership.find_or_create_by!(user: @requester, community_group: @zip_group) do |m|
        m.admin = false
        m.auto_joined = true
      end

      assert @book.can_be_requested_by?(@requester)
    end
  end
end
