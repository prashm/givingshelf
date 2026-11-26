# frozen_string_literal: true

require "test_helper"
require "minitest/spec"

class ItemTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  describe "status enum" do
    it "keeps the stored values" do
      assert_equal({ "available" => 0, "requested" => 1, "donated" => 2, "wishlist" => 3 }, Item.statuses)
    end

    it "labels statuses by name" do
      assert_equal "Wishlist", Item.status_label("wishlist")
      assert_equal "Unknown", Item.status_label(nil)
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
        status: :wishlist
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
        status: :available
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
        status: :wishlist,
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
        status: :available
      )
      assert_not b.valid?
      assert_includes b.errors[:user_id], "can't be blank"
    end
  end

  describe "wishlist_item" do
    it "is set on a wish when created and never changes after" do
      wish = Book.create!(
        user_id: nil, title: "A wish", author: "Author", published_year: 2020, genre: "Fiction",
        summary: "Summary is definitely long enough for this validation test case.",
        status: :wishlist
      )
      assert wish.wishlist_item?

      wish.update!(user: users(:one), status: :available, condition: "good")
      assert wish.reload.wishlist_item?
      assert_raises(ActiveRecord::ReadonlyAttributeError) { wish.wishlist_item = false }
    end

    it "is false for an item listed by its owner" do
      assert_not items(:one).wishlist_item?
    end
  end

  describe "#open_to_requests?" do
    it "takes requests on a requested item only when it started as a wish" do
      wish = Book.create!(
        user_id: nil, title: "A wish", author: "Author", published_year: 2020, genre: "Fiction",
        summary: "Summary is definitely long enough for this validation test case.",
        status: :wishlist
      )
      assert wish.open_to_requests?
      wish.update!(user: users(:one), status: :requested, condition: "good")
      assert wish.open_to_requests?

      listed = items(:one)
      listed.update_columns(status: :requested)
      assert_not listed.open_to_requests?
      listed.update_columns(status: :donated)
      assert_not listed.open_to_requests?
    end
  end

  describe "requesters and original_requester" do
    def wish_with_requests(*specs)
      wish = Book.create!(
        user_id: nil, title: "Requester Wish", author: "Author", published_year: 2020, genre: "Fiction",
        summary: "Summary is definitely long enough here for validation pass.",
        status: :wishlist
      )
      specs.each_with_index do |(user, status), i|
        ItemRequest.create!(item: wish, requester: user, status: status,
          created_at: (specs.size - i).days.ago)
      end
      wish
    end

    def extra_user
      User.create!(email_address: "item_test_#{SecureRandom.hex(4)}@example.com",
        password_digest: BCrypt::Password.create("password123!"), verified: true)
    end

    it "lists non-cancelled requesters, oldest request first" do
      third = extra_user
      wish = wish_with_requests(
        [ users(:two), :pending ],
        [ third, :cancelled ],
        [ users(:one), :in_review ]
      )

      assert_equal [ users(:two), users(:one) ], wish.requesters.to_a
    end

    it "returns the earliest requester even after they cancel" do
      wish = wish_with_requests(
        [ users(:two), :cancelled ],
        [ users(:one), :pending ]
      )

      assert_equal users(:two), wish.original_requester
    end

    it "memoizes original_requester, including nil, until reload" do
      wish = wish_with_requests
      assert_nil wish.original_requester

      ItemRequest.create!(item: wish, requester: users(:two))
      assert_nil wish.original_requester, "memoized nil should not re-query"

      assert_equal users(:two), wish.reload.original_requester
    end
  end
end
