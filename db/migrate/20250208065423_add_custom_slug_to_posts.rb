class AddCustomSlugToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :custom_slug, :string
  end
end
