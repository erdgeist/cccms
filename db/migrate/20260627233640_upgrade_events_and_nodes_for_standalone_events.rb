class UpgradeEventsAndNodesForStandaloneEvents < ActiveRecord::Migration[8.1]
  def up
    # Events: make node optional, add missing fields
    change_column_null :events, :node_id, true
    add_column :events, :title,       :string
    add_column :events, :description, :text

    # Occurrences: make node optional
    change_column_null :occurrences, :node_id, true

    # Nodes: add external URL
    add_column :nodes, :external_url, :string
  end

  def down
    remove_column :nodes,       :external_url
    change_column_null :occurrences, :node_id, false
    remove_column :events, :description
    remove_column :events, :title
    change_column_null :events, :node_id, false
  end
end
