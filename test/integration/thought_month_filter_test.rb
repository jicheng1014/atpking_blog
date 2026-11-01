require "test_helper"

class ThoughtMonthFilterTest < ActionDispatch::IntegrationTest
  test "anonymous month and date filters keep their own pagination across month boundaries" do
    travel_to Time.zone.local(2026, 11, 1, 12) do
      21.times do |index|
        Thought.create!(content: "October #{index}", user: users(:one), published_at: Time.zone.local(2026, 10, 28, 12) - index.minutes)
      end
      [Time.zone.local(2026, 10, 1), Time.zone.local(2026, 10, 31, 23, 59)].each do |time|
        Thought.create!(content: "October boundary", user: users(:one), published_at: time)
      end
      Thought.create!(content: "November boundary", user: users(:one), published_at: Time.zone.local(2026, 11, 1))
      Thought.create!(content: "August thought", user: users(:one), published_at: Time.zone.local(2026, 8, 1))
      Thought.create!(content: "Private October", status: "draft", user: users(:one), published_at: Time.zone.local(2026, 10, 28))

      get thoughts_path(month: "2026-10")
      assert_response :success
      assert_select "time[datetime]", 20 do |times|
        assert times.all? { |node| Time.iso8601(node["datetime"]).in_time_zone.month == 10 }
      end
      assert_select "a[href='#{thoughts_path(month: '2026-10', page: 2)}']", text: "下一页 →"
      assert_select "main", text: /Private October/, count: 0

      get thoughts_path(month: "2026-10", page: 2)
      assert_select "time[datetime]", 3 do |times|
        assert times.all? { |node| Time.iso8601(node["datetime"]).in_time_zone.month == 10 }
      end

      get thoughts_path(month: "2026-11")
      assert_select "time[datetime]", 1
      assert_select "main", text: /November boundary/

      get thoughts_path(month: "2026-09")
      assert_response :success
      assert_select "time[datetime]", 0

      get thoughts_path
      assert_select "main", text: /November boundary/
      assert_select "a[href='#{thoughts_path(page: 2)}']", text: "下一页 →"
      get thoughts_path(page: 2)
      assert_select "main", text: /August thought/

      get thoughts_path(date: "2026-10-28")
      assert_select "time[datetime]", 20
      assert_select "a[href='#{thoughts_path(date: '2026-10-28', page: 2)}']", text: "下一页 →"
      get thoughts_path(date: "2026-10-28", page: 2)
      assert_select "time[datetime]", 1
      get thoughts_path(month: "2026-11", date: "2026-10-28", page: 2)
      assert_select "time[datetime]", 1
    end
  end
end
