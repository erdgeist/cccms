class AddPublishedAtToPages < ActiveRecord::Migration[4.2]
  def self.up
    add_column :pages, :published_at, :datetime
  end

  def self.down
    remove_column :pages, :published_at
  end
end
