class AddDefaultTemplateNameToNodes < ActiveRecord::Migration[8.1]
  def up
    add_column :nodes, :default_template_name, :string

    Node.find_each do |node|
      node.update_column(:default_template_name, "update") if node.update?
    end
  end

  def down
    remove_column :nodes, :default_template_name
  end
end
