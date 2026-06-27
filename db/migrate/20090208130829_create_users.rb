class CreateUsers < ActiveRecord::Migration[4.2]
  def self.up
    create_table :users do |t|
      t.string :login
      t.string :email
      t.string :crypted_password
      t.string :salt

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
