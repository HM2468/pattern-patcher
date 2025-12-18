require "test_helper"

class RepositorysControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get repositorys_index_url
    assert_response :success
  end

  test "should get show" do
    get repositorys_show_url
    assert_response :success
  end

  test "should get new" do
    get repositorys_new_url
    assert_response :success
  end

  test "should get edit" do
    get repositorys_edit_url
    assert_response :success
  end
end
