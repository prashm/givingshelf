require "test_helper"

class Api::ItemsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_items_url, params: { type: Book.name }
    assert_response :success
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
end
