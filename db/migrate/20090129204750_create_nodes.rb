class CreateNodes < ActiveRecord::Migration[4.2]
  def self.up
    create_table :nodes do |t|
      t.string :slug
      t.string :unique_name

      t.timestamps
    end
  end

  def self.down
    drop_table :nodes
  end
end
