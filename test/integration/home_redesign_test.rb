require "test_helper"

class HomeRedesignTest < ActionDispatch::IntegrationTest
  test "shows publication dates and counts only published thoughts in the current month" do
    published_at = Time.zone.local(2026, 10, 20, 9, 30)
    Thought.create!(content: "October thought", published_at: published_at, user: users(:one))
    Thought.create!(content: "Private draft thought", status: "draft", user: users(:one))
    Post.create!(title: "Article", content: "Article body", status: "published", user: users(:one))

    travel_to Time.zone.local(2026, 10, 26, 12) do
      get root_path
      assert_response :success
      assert_select ".home-projects a", 4
      assert_select ".home-thought-meta time[datetime='#{published_at.iso8601}']", 1
      assert_select ".home-rhythm-day.has-posts", 1
      assert_select ".home-rhythm-day.is-future", 5
      assert_select ".home-rhythm-days[aria-label*='20日1条']", 1
      assert_select ".home-thought-content", text: /October thought/
      assert_select ".home-thought-content", text: /Private draft thought/, count: 0

      get thoughts_path(month: "2026-10", date: "2026-10-20")
      assert_select "main", text: /October thought/
      get thoughts_path(month: "2026-10", date: "2026-10-26")
      assert_select "main", text: /October thought/, count: 0

      get posts_path
      assert_response :success
      assert_select ".home-thoughts", 0
      assert_select "h1", text: "文章"
    end

    travel_to Time.zone.local(2026, 11, 1, 12) do
      get root_path
      assert_select "#rhythm-title", text: "本月发布节奏"
      assert_select ".home-rhythm-heading", text: /2026年11月/
      assert_select ".home-rhythm-day.has-posts", 0
      assert_select ".home-rhythm-day.is-future", 29
    end
  end

  test "home previews six articles while the article index keeps the full list" do
    7.times do |index|
      Post.create!(title: "Recent article #{index}", custom_slug: "recent-article-#{index}", content: "Body", status: "published", user: users(:one))
    end

    get root_path
    assert_select ".home-articles .article-preview", 6
    assert_select ".home-pagination", 0

    get posts_path
    assert_select ".article-preview", Post.only_posts.status_published.count
  end
end
