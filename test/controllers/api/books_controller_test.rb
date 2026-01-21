require "test_helper"

class Api::BooksControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_books_url
    assert_response :success
  end

  test "should get show" do
    get api_book_url(books(:one))
    assert_response :success
  end

  test "should create book" do
    user = users(:one)
    sign_in_as(user)
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end

    post api_books_url, params: {
      book: {
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
    assert GroupBookAvailability.exists?(book_id: book_id, community_group_id: zip_group.id)
  end

  test "should update book" do
    sign_in_as(users(:one))
    patch api_book_url(books(:one)), params: { book: { title: "Updated Title" } }
    assert_response :success
  end

  test "should destroy book" do
    sign_in_as(users(:one))
    delete api_book_url(books(:one))
    assert_response :success
  end

  test "should search books" do
    zip_group = CommunityGroup.find_or_create_zipcode_group!
    GroupBookAvailability.find_or_create_by!(book: books(:one), community_group: zip_group)

    get search_api_books_url, params: { query: "Gatsby", zip_code: "12345" }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, books(:one).id
  end

  test "search with community_group_id only returns books available in that group" do
    group = community_groups(:one)

    GroupBookAvailability.create!(book: books(:one), community_group: group)
    GroupBookAvailability.where(book: books(:two), community_group: group).delete_all

    get search_api_books_url, params: { query: "", zip_code: "12345", community_group_id: group.id }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, books(:one).id
    assert_not_includes ids, books(:two).id
  end

  test "search with sub_group_id filters by owners membership subgroup" do
    group = community_groups(:one)
    sg1 = sub_groups(:one)
    sg2 = sub_groups(:two)

    # Ensure availabilities exist in group
    GroupBookAvailability.find_or_create_by!(book: books(:one), community_group: group)
    GroupBookAvailability.find_or_create_by!(book: books(:two), community_group: group)

    # Assign membership subgroups for owners
    CommunityGroupMembership.find_by!(user: users(:one), community_group: group).update!(sub_group_id: sg1.id)
    CommunityGroupMembership.find_by!(user: users(:two), community_group: group).update!(sub_group_id: sg2.id)

    get search_api_books_url, params: { query: "", community_group_id: group.id, sub_group_id: sg1.id }
    assert_response :success

    data = JSON.parse(response.body)["data"] || []
    ids = data.map { |b| b["id"] }
    assert_includes ids, books(:one).id
    assert_not_includes ids, books(:two).id
  end
end
