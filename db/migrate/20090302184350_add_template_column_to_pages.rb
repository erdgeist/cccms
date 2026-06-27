class AddTemplateColumnToPages < ActiveRecord::Migration[4.2]
  def self.up
    add_column :pages, :template, :string
  end

  def self.down
    remove_column :pages, :template
  end
end
