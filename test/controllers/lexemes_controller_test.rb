require "test_helper"

class LexemesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get lexemes_index_url
    assert_response :success
  end

  test "should get show" do
    get lexemes_show_url
    assert_response :success
  end
end
