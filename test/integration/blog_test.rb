require "test_helper"

class BlogTest < ActionDispatch::IntegrationTest
  test "public pages render published articles and hide drafts" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", post_path(posts(:one))
    assert_select "a[href=?]", post_path(posts(:two)), count: 0

    get post_url(posts(:one))
    assert_response :success
    assert_select "h2", "Ruby and Rails"

    get post_url(posts(:two))
    assert_response :not_found

    get tag_posts_url(tag: tags(:one).slug)
    assert_response :success
    assert_select "a[href=?]", post_path(posts(:one))

    get feed_posts_url(format: :rss)
    assert_response :success
    assert_select "item title", "Published article"

    get thoughts_url
    assert_response :success
  end

  test "admin requires login and can create an article after login" do
    get admin_posts_url
    assert_redirected_to new_session_url

    post session_url, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to admin_posts_url

    get admin_posts_url
    assert_response :success

    assert_difference "Post.count", 1 do
      post admin_posts_url, params: { post: { title: "升级检查", custom_slug: "upgrade-check", content: "**Ready**", status: "published", tag_list: "Ruby" } }
    end
    assert_redirected_to admin_posts_url

    article = Post.find_by!(slug: "upgrade-check")
    assert_equal users(:one), article.user
    assert_equal [ tags(:one) ], article.tags.to_a
    get post_url(article)
    assert_response :success
    assert_select "strong", "Ready"

    delete session_url
    assert_redirected_to new_session_url
    get admin_posts_url
    assert_redirected_to new_session_url
  end
end
