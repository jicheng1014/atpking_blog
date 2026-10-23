require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }
    assert_response :redirect
  end

  test "should get edit when signed in" do
    get admin_settings_url
    assert_response :success
  end

  test "should update settings when signed in" do
    patch admin_settings_update_url, params: { site_name: "Updated blog", post_signature: "Signature", icp_number: "ICP" }
    assert_redirected_to admin_settings_url
    assert_equal "Updated blog", Setting.site_name
    assert_equal "Signature", Setting.post_signature
    assert_equal "ICP", Setting.icp_number
  end
end
