require "test_helper"

class OccurrencesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get occurrences_index_url
    assert_response :success
  end

  test "should get show" do
    get occurrences_show_url
    assert_response :success
  end
end
