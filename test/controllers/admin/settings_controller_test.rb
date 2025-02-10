require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    get admin_settings_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_settings_update_url
    assert_response :success
  end
end
