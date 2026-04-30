# frozen_string_literal: true

require "test_helper"
require "minitest/spec"

class ItemTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

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
        status: ShareableItemStatus::WISHLIST
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
        status: ShareableItemStatus::AVAILABLE
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
        status: ShareableItemStatus::WISHLIST,
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
        status: ShareableItemStatus::AVAILABLE
      )
      assert_not b.valid?
      assert_includes b.errors[:user_id], "can't be blank"
    end
  end
end
