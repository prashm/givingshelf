require "test_helper"

class Api::ItemsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_items_url, params: { type: Book.name }
    assert_response :success
  end

  test "should get toy age ranges" do
    get toy_age_ranges_api_items_url
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal ToyAgeRange.data.map { |r| r.stringify_keys }, body["age_ranges"]

    accepted = body["accepted_inputs"]
    assert_equal ToyAgeRange.values, accepted["bucket_labels"]
    assert_includes accepted["examples"], "8+"
    assert accepted["patterns"].all? { |p| p.key?("label") && p.key?("regex") }
  end

  test "should get show" do
    get api_item_url(items(:one))
    assert_response :success
  end

  test "should create book item" do
    user = users(:one)
    sign_in_as(user)
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end

    post api_items_url, params: {
      item: {
        type: Book.name,
        title: "Test Book",
        author: "Test Author",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        genre: "Fiction",
        published_year: 2020,
        community_group_ids: [ zip_group.id ]
      }
    }
    assert_response :created

    book_id = JSON.parse(response.body)["id"]
    assert GroupItemAvailability.exists?(item_id: book_id, community_group_id: zip_group.id)
  end

  test "should update book item" do
    sign_in_as(users(:one))
    patch api_item_url(items(:one)), params: { item: { title: "Updated Title" } }
    assert_response :success
  end

  test "should destroy book item" do
    sign_in_as(users(:one))
    delete api_item_url(items(:one))
    assert_response :success
  end

  test "should search books" do
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: zip_group)

    get search_api_items_url, params: { type: Book.name, query: "Gatsby", zip_code: "12345" }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, items(:one).id
  end

  test "should search books by dashed ISBN" do
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: zip_group)
    items(:one).update!(isbn: "9780134093413")

    get search_api_items_url, params: { type: Book.name, query: "978-0-13-409341-3", zip_code: "12345" }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, items(:one).id
    assert_not_includes ids, items(:two).id
  end

  test "search with community_group_id only returns books available in that group" do
    group = community_groups(:one)

    GroupItemAvailability.create!(item: items(:one), community_group: group)
    GroupItemAvailability.where(item: items(:two), community_group: group).delete_all

    get search_api_items_url, params: { type: Book.name, query: "", zip_code: "12345", community_group_id: group.id }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, items(:one).id
    assert_not_includes ids, items(:two).id
  end

  test "search with sub_group_id filters by owners membership subgroup" do
    group = community_groups(:one)
    sg1 = sub_groups(:one)
    sg2 = sub_groups(:two)

    # Ensure availabilities exist in group
    GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: group)
    GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)

    # Assign membership subgroups for owners
    CommunityGroupMembership.find_by!(user: users(:one), community_group: group).update!(sub_group_id: sg1.id)
    CommunityGroupMembership.find_by!(user: users(:two), community_group: group).update!(sub_group_id: sg2.id)

    get search_api_items_url, params: { type: Book.name, query: "", community_group_id: group.id, sub_group_id: sg1.id }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, items(:one).id
    assert_not_includes ids, items(:two).id
  end

  test "stats uses community_group_stats when community_group_id is present" do
    group = community_groups(:one)
    called = { group: false, community: false }

    service_stub = Object.new
    service_stub.define_singleton_method(:community_group_stats) do |**_kwargs|
      called[:group] = true
      { books_shared: 1, books_donated: 0, books_requested: 2, members: 42 }
    end
    service_stub.define_singleton_method(:community_stats) do |**_kwargs|
      called[:community] = true
      { books_shared: 999, books_donated: 999, books_requested: 999, happy_users: 999 }
    end

    BookService.stub(:new, service_stub) do
      get stats_api_items_url, params: { type: Book.name, community_group_id: group.id }
      assert_response :success
    end

    assert called[:group], "Expected community_group_stats to be called"
    assert_not called[:community], "Expected community_stats not to be called"

    body = JSON.parse(response.body)
    assert_equal 1, body["books_shared"]
    assert_equal 0, body["books_donated"]
    assert_equal 2, body["books_requested"]
    assert body.key?("members"), "Expected members count to be included for group stats"
  end

  test "wishlist endpoint returns paginated wishlist items for a community group" do
    group = community_groups(:one)
    wishlist_item = create_wishlist_book_for_scope(group: group, title: "Group Wish")
    wishlist_item_two = create_wishlist_book_for_scope(group: group, title: "Group Wish Two")
    non_wishlist_item = Book.create!(
      user: users(:one),
      title: "Available Book",
      author: "Author",
      condition: "good",
      summary: "A long enough summary for an available book in this test.",
      genre: "Fiction",
      published_year: 2020,
      status: ShareableItemStatus::AVAILABLE
    )
    GroupItemAvailability.create!(item: non_wishlist_item, community_group: group)

    get "/api/items/wishlist", params: { type: Book.name, community_group_id: group.id, page: { size: 1 } }
    assert_response :success

    body = JSON.parse(response.body)
    data = body["data"] || []
    assert_equal 1, data.length
    ids = data.map { |item| item["id"] }
    assert_includes ids, wishlist_item.id
    assert_not_includes ids, wishlist_item_two.id
    assert_not_includes ids, non_wishlist_item.id
  end

  test "wishlist endpoint filters by subgroup using availability subgroup" do
    group = community_groups(:one)
    sg1 = sub_groups(:one)
    sg2 = sub_groups(:two)

    in_scope = create_wishlist_book_for_scope(group: group, title: "Scoped Wish 1", sub_group: sg1)
    out_of_scope = create_wishlist_book_for_scope(group: group, title: "Scoped Wish 2", sub_group: sg2)

    get "/api/items/wishlist", params: { type: Book.name, community_group_id: group.id, sub_group_id: sg1.id }
    assert_response :success

    ids = (JSON.parse(response.body)["data"] || []).map { |item| item["id"] }
    assert_includes ids, in_scope.id
    assert_not_includes ids, out_of_scope.id
  end

  test "wishlist endpoint filters by query" do
    group = community_groups(:one)
    matching = create_wishlist_book_for_scope(group: group, title: "Query Match Wish Book")
    non_matching = create_wishlist_book_for_scope(group: group, title: "Other Wish Book")

    get "/api/items/wishlist", params: { type: Book.name, community_group_id: group.id, query: "Query Match" }
    assert_response :success

    ids = (JSON.parse(response.body)["data"] || []).map { |item| item["id"] }
    assert_includes ids, matching.id
    assert_not_includes ids, non_matching.id
  end

  test "stats includes items_wishlisted count" do
    group = CommunityGroup.create!(
      name: "Stats Scope Group",
      domain: "stats-scope.test",
      short_name: "stats-scope-group",
      group_description: "Stats scoped group for wishlist count tests"
    )

    available_item = Book.create!(
      user: users(:one),
      title: "Scoped Available Book",
      author: "Author",
      condition: "good",
      summary: "A summary long enough for scoped available stats validation.",
      genre: "Fiction",
      published_year: 2020,
      status: ShareableItemStatus::AVAILABLE
    )
    wishlisted_item = create_wishlist_book_for_scope(group: group, title: "Scoped Wishlist Book")
    GroupItemAvailability.create!(item: available_item, community_group: group)

    get stats_api_items_url, params: { type: Book.name, community_group_id: group.id }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["items_wishlisted"]
  end

  test "create_wishlist creates wishlist book and item request" do
    user = users(:one)
    sign_in_as(user)
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    scoped_group = community_groups(:one)
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: scoped_group) do |m|
      m.admin = false
      m.auto_joined = false
    end

    assert_difference -> { Book.wishlist.count }, 1 do
      post wishlist_api_items_url,
        params: {
          type: Book.name,
          item: {
            title: "Community Wish Title",
            author: "Test Author",
            summary: "This summary is definitely long enough for validation and describes the wish.",
            published_year: 2020,
            community_group_id: scoped_group.id
          }
        },
        as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body["item_request_id"].present?
    req = ItemRequest.find(body["item_request_id"])
    assert_equal BookService::DEFAULT_WISHLIST_MESSAGE, req.message
    gia = req.item.group_item_availabilities.find_by(community_group_id: scoped_group.id)
    assert gia
    assert_nil gia.sub_group_id
  end

  test "create_wishlist accepts a custom message" do
    user = users(:one)
    sign_in_as(user)
    scoped_group = community_groups(:one)
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: scoped_group) do |m|
      m.admin = false
      m.auto_joined = false
    end
    custom = "Hoping someone in our group has a spare copy for my classroom."

    post wishlist_api_items_url,
      params: {
        type: Book.name,
        item: {
          title: "Custom Message Wish",
          author: "Test Author",
          summary: "This summary is definitely long enough for validation and describes the wish.",
          published_year: 2020,
          community_group_id: scoped_group.id,
          message: custom
        }
      },
      as: :json

    assert_response :created
    req = ItemRequest.find(JSON.parse(response.body)["item_request_id"])
    assert_equal custom, req.message
  end

  test "fulfill_wishlist assigns donor and sets available" do
    requester = users(:one)
    donor = users(:two)
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    group = community_groups(:one)
    CommunityGroupMembership.find_or_create_by!(user: donor, community_group: group)
    CommunityGroupMembership.find_or_create_by!(user: donor, community_group: zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end

    book = Book.create!(
      user_id: nil,
      type: Book.name,
      title: "Wishlist Book",
      author: "Author",
      summary: "Summary text long enough for validations on the book model here.",
      published_year: 2020,
      genre: "Fiction",
      status: ShareableItemStatus::WISHLIST
    )
    GroupItemAvailability.create!(item: book, community_group: group)
    ItemRequest.create!(
      item: book,
      requester: requester,
      owner: nil,
      message: "I would love this book if anyone in the community has a copy.",
      status: ItemRequest::PENDING_STATUS
    )

    sign_in_as(donor)
    post fulfill_wishlist_api_item_url(book),
      params: {
        item: {
          condition: "good",
          community_group_ids: [ group.id ]
        }
      },
      as: :json

    assert_response :success
    book.reload
    assert_equal donor.id, book.user_id
    assert_equal ShareableItemStatus::AVAILABLE, book.status
    ir = book.item_requests.find_by(requester: requester)
    assert ir.in_review?
    assert_equal donor.id, ir.owner_id
  end

  test "fulfill_wishlist rejects non wishlist item" do
    sign_in_as(users(:two))
    post fulfill_wishlist_api_item_url(items(:one)),
      params: { item: { condition: "good" } },
      as: :json
    assert_response :unprocessable_entity
  end

  test "fulfill_wishlist rejects requester fulfilling their own request" do
    requester = users(:one)
    group = community_groups(:one)
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    CommunityGroupMembership.find_or_create_by!(user: requester, community_group: group)
    CommunityGroupMembership.find_or_create_by!(user: requester, community_group: zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end

    book = Book.create!(
      user_id: nil,
      type: Book.name,
      title: "Wishlist Self Fulfill",
      author: "Author",
      summary: "Summary text long enough for validations on the book model here.",
      published_year: 2020,
      genre: "Fiction",
      status: ShareableItemStatus::WISHLIST
    )
    GroupItemAvailability.create!(item: book, community_group: group)
    ItemRequest.create!(
      item: book,
      requester: requester,
      owner: nil,
      message: "I would love this book if anyone in the community has a copy.",
      status: ItemRequest::PENDING_STATUS
    )

    sign_in_as(requester)
    post fulfill_wishlist_api_item_url(book),
      params: {
        item: {
          condition: "good",
          community_group_ids: [ group.id ]
        }
      },
      as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"], "You cannot fulfill your own wishlist request"
    book.reload
    assert_nil book.user_id
    assert_equal ShareableItemStatus::WISHLIST, book.status
  end

  test "wishlist endpoint filters by requester zipcode when no community_group_id" do
    zip_group = zip_group_with_members
    local_wish = create_wishlist_book_for_scope(group: zip_group, title: "Local Wishlist", requester: users(:one))
    remote_wish = create_wishlist_book_for_scope(group: zip_group, title: "Remote Wishlist", requester: users(:two))

    get "/api/items/wishlist", params: { type: Book.name, zip_code: "12345" }
    assert_response :success

    ids = (JSON.parse(response.body)["data"] || []).map { |item| item["id"] }
    assert_includes ids, local_wish.id
    assert_not_includes ids, remote_wish.id
  end

  test "wishlist endpoint returns all items in group when community_group_id is provided regardless of zipcode" do
    zip_group_with_members
    group = community_groups(:one)
    wish_a = create_wishlist_book_for_scope(group: group, title: "Group Wish A", requester: users(:one))
    wish_b = create_wishlist_book_for_scope(group: group, title: "Group Wish B", requester: users(:two))

    get "/api/items/wishlist", params: { type: Book.name, community_group_id: group.id, zip_code: "12345" }
    assert_response :success

    ids = (JSON.parse(response.body)["data"] || []).map { |item| item["id"] }
    assert_includes ids, wish_a.id
    assert_includes ids, wish_b.id
  end

  test "wishlist endpoint returns all items when no zipcode is provided" do
    zip_group = zip_group_with_members
    wish_a = create_wishlist_book_for_scope(group: zip_group, title: "No Zip Wish A", requester: users(:one))
    wish_b = create_wishlist_book_for_scope(group: zip_group, title: "No Zip Wish B", requester: users(:two))

    get "/api/items/wishlist", params: { type: Book.name }
    assert_response :success

    ids = (JSON.parse(response.body)["data"] || []).map { |item| item["id"] }
    assert_includes ids, wish_a.id
    assert_includes ids, wish_b.id
  end

  test "search endpoint filters available books by owner zipcode" do
    zip_group = zip_group_with_members
    book_local = Book.create!(
      user: users(:one), type: Book.name, title: "Search Local",
      author: "Author", condition: "good",
      summary: "A long enough summary for search zipcode filtering test.",
      genre: "Fiction", published_year: 2020, status: ShareableItemStatus::AVAILABLE
    )
    book_remote = Book.create!(
      user: users(:two), type: Book.name, title: "Search Remote",
      author: "Author", condition: "good",
      summary: "A long enough summary for search zipcode filtering test.",
      genre: "Fiction", published_year: 2020, status: ShareableItemStatus::AVAILABLE
    )
    GroupItemAvailability.create!(item: book_local, community_group: zip_group)
    GroupItemAvailability.create!(item: book_remote, community_group: zip_group)

    get search_api_items_url, params: { type: Book.name, zip_code: "12345" }
    assert_response :success

    ids = (JSON.parse(response.body)["data"] || []).map { |item| item["id"] }
    assert_includes ids, book_local.id
    assert_not_includes ids, book_remote.id
  end

  test "stats endpoint returns correct items_wishlisted count scoped by zipcode" do
    zip_group = zip_group_with_members
    create_wishlist_book_for_scope(group: zip_group, title: "Stats Wish Local", requester: users(:one))
    create_wishlist_book_for_scope(group: zip_group, title: "Stats Wish Remote", requester: users(:two))

    get stats_api_items_url, params: { type: Book.name, zip_code: "12345" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["items_wishlisted"]
  end

  test "stats endpoint returns correct counts when community_group_id is present" do
    zip_group_with_members
    group = CommunityGroup.create!(
      name: "Stats Test Group",
      domain: "stats-test.test",
      short_name: "stats-test-group",
      group_description: "Stats test group for wishlist zipcode tests"
    )

    available_book = Book.create!(
      user: users(:one), type: Book.name, title: "Stats Available",
      author: "Author", condition: "good",
      summary: "A long enough summary for stats test.",
      genre: "Fiction", published_year: 2020, status: ShareableItemStatus::AVAILABLE
    )
    GroupItemAvailability.create!(item: available_book, community_group: group)

    create_wishlist_book_for_scope(group: group, title: "Stats Wish A", requester: users(:one))
    create_wishlist_book_for_scope(group: group, title: "Stats Wish B", requester: users(:two))

    CommunityGroupMembership.find_or_create_by!(user: users(:one), community_group: group) do |m|
      m.admin = false
      m.auto_joined = false
    end

    get stats_api_items_url, params: { type: Book.name, community_group_id: group.id }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 2, body["items_wishlisted"]
    assert_equal 1, body["items_shared"]
  end

  test "stats endpoint with zipcode returns correct items_shared count" do
    zip_group = zip_group_with_members
    book_local = Book.create!(
      user: users(:one), type: Book.name, title: "Stats Shared Local",
      author: "Author", condition: "good",
      summary: "A long enough summary for stats shared test.",
      genre: "Fiction", published_year: 2020, status: ShareableItemStatus::AVAILABLE
    )
    book_remote = Book.create!(
      user: users(:two), type: Book.name, title: "Stats Shared Remote",
      author: "Author", condition: "good",
      summary: "A long enough summary for stats shared test.",
      genre: "Fiction", published_year: 2020, status: ShareableItemStatus::AVAILABLE
    )
    GroupItemAvailability.create!(item: book_local, community_group: zip_group)
    GroupItemAvailability.create!(item: book_remote, community_group: zip_group)

    get stats_api_items_url, params: { type: Book.name, zip_code: "12345" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["items_shared"]
  end

  private

  def create_wishlist_book_for_scope(group:, title:, sub_group: nil, requester: nil)
    item = Book.create!(
      user_id: nil,
      type: Book.name,
      title: title,
      author: "Wishlist Author",
      summary: "Summary text long enough for validations on scoped wishlist tests.",
      published_year: 2020,
      genre: "Fiction",
      status: ShareableItemStatus::WISHLIST
    )
    GroupItemAvailability.create!(
      item: item,
      community_group: group,
      sub_group: sub_group
    )
    if requester
      ItemRequest.create!(
        item: item,
        requester: requester,
        owner: nil,
        message: "I would love this book if anyone in the community has a copy.",
        status: ItemRequest::PENDING_STATUS
      )
    end
    item
  end

  # users(:one) is in zip 12345 and users(:two) in 54321; both auto-join the ZIP group.
  def zip_group_with_members
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    [ users(:one), users(:two) ].each do |user|
      CommunityGroupMembership.find_or_create_by!(user: user, community_group: zip_group) do |m|
        m.admin = false
        m.auto_joined = true
      end
    end
    zip_group
  end
end
