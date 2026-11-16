# frozen_string_literal: true

require "test_helper"
require "minitest/spec"

class ItemTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL
  parallelize(workers: 1)

  describe "status enum and ShareableItemStatus" do
    it "maps enum statuses to expected database integers" do
      expected = {
        "available" => 0,
        "requested" => 1,
        "donated" => 2,
        "wishlist" => 3
      }
      assert_equal expected, Item.statuses
      assert_equal expected, Book.statuses
      assert_equal expected, Toy.statuses
    end

    it "removes numeric constants from ShareableItemStatus and exposes labels by status name" do
      %i[AVAILABLE REQUESTED DONATED WISHLIST].each do |const_name|
        assert_not ShareableItemStatus.const_defined?(const_name), "Expected ShareableItemStatus::#{const_name} to be removed"
      end

      assert_equal %w[available requested donated wishlist], ShareableItemStatus.values
      assert_equal "Available", ShareableItemStatus.display_status("available")
      assert_equal "Requested", ShareableItemStatus.display_status(:requested)
      assert_equal "Donated", ShareableItemStatus.display_status("donated")
      assert_equal "Wishlist", ShareableItemStatus.display_status("wishlist")
      assert_equal "Unknown", ShareableItemStatus.display_status("unknown")
    end

    it "supports scopes, predicates, transitions, and stores expected ints in db" do
      book = items(:one)
      book.available!
      assert book.available?
      assert_includes Item.available, book
      assert_includes Book.available, book
      assert_equal 0, book.reload.read_attribute_before_type_cast(:status)

      book.requested!
      assert book.requested?
      assert_includes Item.requested, book
      assert_equal 1, book.reload.read_attribute_before_type_cast(:status)

      book.donated!
      assert book.donated?
      assert_includes Item.donated, book
      assert_equal 2, book.reload.read_attribute_before_type_cast(:status)

      wish = Book.create!(
        type: Book.name,
        user_id: nil,
        title: "Wishlist Enum Check",
        author: "Author",
        summary: "Summary is definitely long enough here for validation pass.",
        published_year: 2020,
        genre: "Fiction",
        status: :wishlist
      )
      assert wish.wishlist?
      assert_includes Item.wishlist, wish
      assert_includes Book.wishlist, wish
      assert_equal 3, wish.reload.read_attribute_before_type_cast(:status)
    end

    it "rejects unrecognized status values via validation" do
      b = Book.new(
        type: Book.name,
        user: users(:one),
        title: "Invalid Status",
        author: "Author",
        condition: "good",
        summary: "Summary is definitely long enough here for validation pass.",
        published_year: 2020,
        status: "bogus"
      )
      assert_not b.valid?
      assert_not_empty b.errors[:status]
    end
  end

  describe "conditional condition validation" do
    it "does not require condition when there is no owner" do
      b = Book.new(
        type: Book.name,
        user_id: nil,
        title: "Wish",
        author: "Author",
        summary: "Summary is definitely long enough here for validation pass.",
        published_year: 2020,
        genre: "Fiction",
        status: "wishlist"
      )
      assert b.valid?
    end

    it "requires condition when an owner is present" do
      b = Book.new(
        type: Book.name,
        user: users(:one),
        title: "Owned",
        author: "Author",
        condition: nil,
        summary: "Summary is long enough to satisfy item validation rules we use.",
        published_year: 2020,
        genre: "Fiction",
        status: "available"
      )
      assert_not b.valid?
      assert_includes b.errors[:condition], "can't be blank"
    end
  end

  describe "user_id and wishlist status" do
    it "rejects wishlist items that have an owner" do
      b = Book.new(
        type: Book.name,
        user: users(:one),
        title: "Bad wish",
        author: "Author",
        summary: "Summary is definitely long enough for this validation test case.",
        published_year: 2020,
        genre: "Fiction",
        status: "wishlist",
        condition: "good"
      )
      assert_not b.valid?
      assert_includes b.errors[:user_id], "must be blank for wishlist items"
    end

    it "rejects non-wishlist items with no owner" do
      b = Book.new(
        type: Book.name,
        user_id: nil,
        title: "Orphan",
        author: "Author",
        summary: "Summary is definitely long enough for this validation test case.",
        published_year: 2020,
        genre: "Fiction",
        status: "available"
      )
      assert_not b.valid?
      assert_includes b.errors[:user_id], "can't be blank"
    end
  end
end
