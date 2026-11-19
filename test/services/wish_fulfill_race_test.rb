require "test_helper"

# Two donors fulfilling the same wish at once, each on its own database connection. This can't run
# inside the usual per-test transaction, because each thread must see the other's committed work.
class WishFulfillRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    @donors = Array.new(2) { |i| create_user("racer#{i}") }
    @wish = Book.create!(
      title: "Raced Wish", author: "Author", genre: "Fiction", published_year: 2020,
      summary: "Summary text long enough for validations on the book model here.",
      status: ShareableItemStatus::WISHLIST
    )
    ItemRequest.create!(item: @wish, requester: users(:two), message: "I would love this book please")
  end

  def teardown
    UserNotification.where(user: users(:two)).delete_all if defined?(UserNotification)
    @wish.item_requests.each { |request| request.messages.delete_all }
    @wish.item_requests.delete_all
    @wish.delete
    User.where(id: @donors.map(&:id)).delete_all
  end

  test "exactly one donor wins; the other is told the wish was just fulfilled" do
    start = Queue.new
    threads = @donors.map do |donor|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          service = ItemService.new(Item.find(@wish.id))
          [ donor, service.fulfill_wishlist_item(donor, { condition: "good" }), service.errors ]
        end
      end
    end
    2.times { start << true }
    results = threads.map(&:value)

    winners = results.select { |_, ok, _| ok }
    losers = results.reject { |_, ok, _| ok }
    assert_equal 1, winners.size, results.inspect
    assert_equal [ "Another donor just fulfilled this wish" ], losers.first[2]
    assert_equal winners.first[0].id, @wish.reload.user_id
    assert_equal [ winners.first[0].id ], @wish.item_requests.pluck(:owner_id)
  end

  private

  def create_user(name)
    user = User.create!(email_address: "#{name}_#{SecureRandom.hex(4)}@example.com", verified: true,
      password_digest: BCrypt::Password.create("password123!"))
    user.update_columns(first_name: name.capitalize, last_name: "Tester", zip_code: "12345")
    user
  end
end
