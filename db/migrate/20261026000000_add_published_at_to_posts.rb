class AddPublishedAtToPosts < ActiveRecord::Migration[8.1]
  def up
    add_column :posts, :published_at, :datetime
    execute <<~SQL
      UPDATE posts SET published_at = created_at
      WHERE type = 'Thought' AND status = 'published'
    SQL
  end

  def down
    remove_column :posts, :published_at
  end
end
