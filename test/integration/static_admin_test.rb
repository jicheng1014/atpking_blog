require "test_helper"

class StaticAdminTest < ActionDispatch::IntegrationTest
  test "private image preview requires login while password reset URLs remain usable" do
    ActiveStorage::BaseController.include Authentication
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("private draft image"), filename: "draft.png", content_type: "image/png")
    path = rails_storage_proxy_path(blob)
    get path
    assert_redirected_to new_session_url

    post session_url, params: { email_address: users(:one).email_address, password: "password" }
    assert_response :redirect
    get path
    assert_response :success
    assert_equal "private draft image", response.body

    delete session_url
    get new_password_url
    assert_response :success
    get edit_password_url(users(:one).password_reset_token)
    assert_response :success
    get edit_password_url("invalid-token")
    assert_redirected_to new_password_url
  ensure
    blob&.purge
  end
end
