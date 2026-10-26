require "test_helper"

class ThoughtTest < ActiveSupport::TestCase
  test "records first publication when a draft becomes visible and keeps it on edits" do
    thought = Thought.create!(content: "Draft thought", status: "draft", user: users(:one), created_at: Time.zone.local(2026, 10, 20))
    assert_nil thought.published_at

    travel_to Time.zone.local(2026, 10, 26, 10) do
      thought.update!(status: "published")
      assert_equal Time.current, thought.reload.published_at
      thought.update!(content: "Edited thought")
      thought.update!(status: "draft")
      thought.update!(status: "published")
      assert_equal Time.current, thought.reload.published_at
    end
  end
end
