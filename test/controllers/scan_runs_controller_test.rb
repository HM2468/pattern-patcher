require "test_helper"

class ScanRunsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get scan_runs_index_url
    assert_response :success
  end

  test "should get show" do
    get scan_runs_show_url
    assert_response :success
  end
end
