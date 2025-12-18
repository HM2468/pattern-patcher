require "test_helper"

class ReplacementTargetsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get replacement_targets_index_url
    assert_response :success
  end

  test "should get show" do
    get replacement_targets_show_url
    assert_response :success
  end

  test "should get edit" do
    get replacement_targets_edit_url
    assert_response :success
  end
end
