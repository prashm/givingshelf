require "test_helper"
require "minitest/spec"

class BookTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  def setup
    @owner = users(:one)
    @requester = users(:two)
    @book = items(:one)
    @zip_group = CommunityGroup.find_or_create_zipcode_group!
    @other_group = community_groups(:one)

    # Clean up any existing requests for the test book to avoid conflicts
    ItemRequest.where(item: @book, requester: @requester).destroy_all
    # Ensure book is available
    @book.update!(status: ShareableItemStatus::AVAILABLE)
  end

  describe ".to_isbn13" do
    it "converts a known ISBN-10 to ISBN-13" do
      assert_equal "9780134093413", Book.to_isbn13("0134093413")
    end

    it "accepts dashed ISBN-10 input" do
      assert_equal "9780134093413", Book.to_isbn13("0-13-409341-3")
    end

    it "passes through an already-canonical ISBN-13" do
      assert_equal "9780134093413", Book.to_isbn13("9780134093413")
    end

    it "accepts dashed ISBN-13 input" do
      assert_equal "9780134093413", Book.to_isbn13("978-0-13-409341-3")
    end

    it "converts ISBN-10 with trailing X check digit" do
      assert_equal "9780804429573", Book.to_isbn13("080442957X")
    end

    it "returns nil for blank or unrecognized values" do
      assert_nil Book.to_isbn13(nil)
      assert_nil Book.to_isbn13("")
      assert_nil Book.to_isbn13("12345")
    end
  end

  describe "isbn normalization" do
    it "stores ISBN-10 as ISBN-13 on assignment" do
      @book.isbn = "0134093413"
      @book.save!
      assert_equal "9780134093413", @book.reload.isbn
    end

    it "strips dashes before storing" do
      @book.isbn = "978-0-13-409341-3"
      @book.save!
      assert_equal "9780134093413", @book.reload.isbn
    end

    it "clears blank isbn to nil" do
      @book.isbn = ""
      @book.save!
      assert_nil @book.reload.isbn
    end
  end
end
