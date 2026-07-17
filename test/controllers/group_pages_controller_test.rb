require "test_helper"

class GroupPagesControllerTest < ActionDispatch::IntegrationTest
  test "show redirects to subdomain URL" do
    group = community_groups(:one)

    get "/g/#{group.short_name}"
    assert_response :moved_permanently
    assert_redirected_to ApplicationSite.subdomain_url(group.short_name)
  end

  test "show redirects books path to subdomain books" do
    group = community_groups(:one)

    get "/g/#{group.short_name}/books"
    assert_response :moved_permanently
    assert_redirected_to ApplicationSite.subdomain_url(group.short_name, "/books")
  end

  test "show returns 404 for unknown short_name" do
    get "/g/does-not-exist"
    assert_response :not_found
  end
end
