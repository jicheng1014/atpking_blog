class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'draft'

      t.timestamps
    end

    add_index :posts, :status
  end
end
