class AddTypeToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :type, :string
    add_index :posts, :type
    change_column_null :posts, :title, true
  end
end
