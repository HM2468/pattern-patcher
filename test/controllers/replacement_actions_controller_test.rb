require "test_helper"

class ReplacementActionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get replacement_actions_index_url
    assert_response :success
  end

  test "should get show" do
    get replacement_actions_show_url
    assert_response :success
  end
end
