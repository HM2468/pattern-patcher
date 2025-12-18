require "test_helper"

class LexemeProcessingsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get lexeme_processings_index_url
    assert_response :success
  end

  test "should get show" do
    get lexeme_processings_show_url
    assert_response :success
  end
end
