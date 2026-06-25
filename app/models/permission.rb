class Permission < ActiveRecord::Base
  # Validations
  validates_presence_of   :user_id, :node_id, :granted
  validates_inclusion_of  :granted, :in => [true, false]
  
  # Associations
  belongs_to :user
  belongs_to :node
  
  # Named scopes
  scope :for_node, ->(node) { where('node_id = ?', (node.is_a?(Node) ? node.id : node)) }
  scope :for_user, ->(user) { where('user_id = ?', (user.is_a?(User) ? user.id : user)) }
end
