class DropCustomRruleFromEvents < ActiveRecord::Migration[8.1]
  def change
    remove_column :events, :custom_rrule, :string
  end
end
