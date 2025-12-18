require "test_helper"

class LexicalPatternsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get lexical_patterns_index_url
    assert_response :success
  end

  test "should get show" do
    get lexical_patterns_show_url
    assert_response :success
  end

  test "should get new" do
    get lexical_patterns_new_url
    assert_response :success
  end

  test "should get edit" do
    get lexical_patterns_edit_url
    assert_response :success
  end

  test "should get test" do
    get lexical_patterns_test_url
    assert_response :success
  end
end
