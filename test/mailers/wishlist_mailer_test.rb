# frozen_string_literal: true

require "test_helper"

class WishlistMailerTest < ActionMailer::TestCase
  test "digest uses group subdomain for fulfill links on named group items" do
    recipient = users(:two)
    requester = users(:one)
    group = community_groups(:one)
    book = Book.create!(
      type: Book.name,
      user_id: nil,
      title: "Digest Wish Book",
      author: "Author",
      summary: "Long enough summary for wishlist digest mailer test content here.",
      published_year: 2020,
      genre: "Fiction",
      status: ShareableItemStatus::WISHLIST
    )
    entries = [ { item: book, requester: requester, group: group } ]

    email = WishlistMailer.digest(recipient, entries)
    expected = CommunityGroupService.public_url_for(
      path: "/fulfill_wishlist/#{book.id}",
      group: group
    )

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [ recipient.email_address ], email.to
    assert_equal "Wishlist Items — can you help?", email.subject
    assert_includes email.body.encoded, book.title
    assert_includes email.body.encoded, requester.display_name
    assert_includes email.body.encoded, expected
  end

  test "digest uses apex host for fulfill links when group is zipcode" do
    recipient = users(:two)
    requester = users(:one)
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    book = Book.create!(
      type: Book.name,
      user_id: nil,
      title: "Zip Digest Wish Book",
      author: "Author",
      summary: "Long enough summary for zipcode wishlist digest mailer test content.",
      published_year: 2020,
      genre: "Fiction",
      status: ShareableItemStatus::WISHLIST
    )
    entries = [ { item: book, requester: requester, group: zip_group } ]

    email = WishlistMailer.digest(recipient, entries)
    expected = "#{ApplicationSite.base_url}/fulfill_wishlist/#{book.id}"

    assert_emails 1 do
      email.deliver_now
    end
    assert_includes email.body.encoded, expected
    assert_not_includes email.body.encoded, ApplicationSite.subdomain_host(zip_group.short_name)
  end

  test "wishlist_available uses group subdomain for named group items" do
    user = users(:one)
    group = community_groups(:one)
    book = Book.create!(
      type: Book.name,
      user: users(:two),
      title: "Available Wish Book",
      author: "Author",
      summary: "Long enough summary for wishlist available mailer test content.",
      published_year: 2020,
      genre: "Fiction",
      condition: "good",
      status: ShareableItemStatus::AVAILABLE
    )
    GroupItemAvailability.create!(item: book, community_group: group)
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: group) do |m|
      m.admin = false
      m.auto_joined = false
    end
    item_request = ItemRequest.create!(
      item: book,
      requester: user,
      owner: users(:two),
      message: "I would love this book if anyone in the community has a copy.",
      status: ItemRequest::IN_REVIEW_STATUS
    )

    email = WishlistMailer.wishlist_available(user, book, item_request)
    expected = CommunityGroupService.public_url_for(
      path: "/item_request_details?id=#{item_request.id}",
      group: group
    )

    assert_emails 1 do
      email.deliver_now
    end
    assert_includes email.body.encoded, expected
  end
end
