require "test_helper"

class RepositoryFilesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get repository_files_index_url
    assert_response :success
  end

  test "should get show" do
    get repository_files_show_url
    assert_response :success
  end

  test "should get new" do
    get repository_files_new_url
    assert_response :success
  end

  test "should get edit" do
    get repository_files_edit_url
    assert_response :success
  end
end
