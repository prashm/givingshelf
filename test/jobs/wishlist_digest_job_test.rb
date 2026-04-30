# frozen_string_literal: true

require "test_helper"

class WishlistDigestJobTest < ActiveJob::TestCase
  def setup
    @requester = users(:one)
    @recipient = users(:two)
    @group = community_groups(:one)
    @sg1 = sub_groups(:one)
    @sg2 = sub_groups(:two)
  end

  def build_wishlist_book(sub_group_id: nil)
    book = Book.create!(
      type: Book.name,
      user_id: nil,
      title: "Digest Test Wish",
      author: "Author",
      summary: "Long enough summary for the digest test book creation here and now.",
      published_year: 2020,
      genre: "Fiction",
      status: ShareableItemStatus::WISHLIST
    )
    GroupItemAvailability.create!(item: book, community_group: @group, sub_group_id: sub_group_id)
    CommunityGroupMembership.find_or_create_by!(user: @requester, community_group: @group) do |m|
      m.admin = false
      m.auto_joined = false
      m.sub_group_id = @sg1.id
    end
    CommunityGroupMembership.find_or_create_by!(user: @recipient, community_group: @group) do |m|
      m.admin = false
      m.auto_joined = false
      m.sub_group_id = @sg1.id
    end
    ItemRequest.create!(
      item: book,
      requester: @requester,
      owner: nil,
      message: "I would love this book if anyone in the community has a copy.",
      status: ItemRequest::PENDING_STATUS
    )
    book
  end

  test "enqueues digest mail and records user notification for a community member" do
    book = build_wishlist_book

    assert_enqueued_jobs(1, only: ActionMailer::MailDeliveryJob) do
      WishlistDigestJob.perform_now
    end

    n = UserNotification.find_by(
      user: @recipient,
      notifiable: book,
      kind: UserNotification::KIND_WISHLIST_DIGEST
    )
    assert n
  end

  test "is idempotent: second run does not enqueue mail when notification exists" do
    book = build_wishlist_book
    UserNotification.create!(
      user: @recipient,
      notifiable: book,
      kind: UserNotification::KIND_WISHLIST_DIGEST,
      sent_at: Time.current
    )

    assert_enqueued_jobs(0, only: ActionMailer::MailDeliveryJob) do
      WishlistDigestJob.perform_now
    end
  end

  test "targets only members of requested subgroup when sub_group_id is scoped" do
    CommunityGroupMembership.find_by!(user: @recipient, community_group: @group).update!(sub_group_id: @sg2.id)
    build_wishlist_book(sub_group_id: @sg1.id)

    assert_enqueued_jobs(0, only: ActionMailer::MailDeliveryJob) do
      WishlistDigestJob.perform_now
    end
  end
end
