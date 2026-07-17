require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "books-only group root renders without redirect" do
    group = community_groups(:one)
    group.update!(support_item_types: "B")
    host! ApplicationSite.subdomain_host(group.short_name)

    get "/"
    assert_response :success
  end

  test "toys-only group toys path renders without redirect" do
    group = community_groups(:one)
    group.update!(support_item_types: "T")
    host! ApplicationSite.subdomain_host(group.short_name)

    get "/toys"
    assert_response :success
  end

  test "books-only group toys path renders without redirect" do
    group = community_groups(:one)
    group.update!(support_item_types: "B")
    host! ApplicationSite.subdomain_host(group.short_name)

    get "/toys"
    assert_response :success
  end

  test "unrestricted group root does not redirect" do
    group = community_groups(:one)
    group.update!(support_item_types: nil)
    host! ApplicationSite.subdomain_host(group.short_name)

    get "/"
    assert_response :success
  end

  test "apex root does not redirect" do
    host! ApplicationSite.domain
    get "/"
    assert_response :success
  end
end
