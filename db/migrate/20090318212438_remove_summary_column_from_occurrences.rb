class RemoveSummaryColumnFromOccurrences < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :occurrences, :summary
  end

  def self.down
    add_column :occurrences, :summary, :string
  end
end
