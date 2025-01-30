class Permission < ActiveRecord::Base
  # Validations
  validates :user_id, presence: true
  validates :node_id, presence: true
  validates :granted, presence: true
  validates_inclusion_of  :granted, :in => [true, false]
  
  # Associations
  belongs_to :user
  belongs_to :node
  
  # Named scopes
  scope :for_node, lambda { |node| { :conditions => ['node_id = ?', (node.is_a? Node ? node.id : node)] } }
  scope :for_user, lambda { |user| { :conditions => ['user_id = ?', (user.is_a? User ? user.id : user)] } }
end
