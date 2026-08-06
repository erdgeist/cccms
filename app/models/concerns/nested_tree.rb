# app/models/concerns/nested_tree.rb
#
# Minimal parent_id-based replacement for the tree-traversal subset of
# awesome_nested_set actually used by this app (descendants, ancestors,
# level, root, move_to_child_of)
module NestedTree
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: name, foreign_key: :parent_id, optional: true, inverse_of: :children
    has_many :children, -> { order(:id) }, class_name: name, foreign_key: :parent_id, inverse_of: :parent
  end

  class_methods do
    def root
      roots.first
    end

    def roots
      where(parent_id: nil)
    end

    def valid?
      # Every non-root row's parent_id must point at a real, existing row.
      where.not(parent_id: nil).where.missing(:parent).none?
    end
  end

  def root?
    parent_id.nil?
  end

  def ancestors
    result = []
    current = parent
    while current
      result << current
      current = current.parent
    end
    result
  end

  def level
    ancestors.size
  end

  def descendants
    ids = []
    queue = self.class.where(parent_id: id).pluck(:id)
    until queue.empty?
      ids.concat(queue)
      queue = self.class.where(parent_id: queue).pluck(:id)
    end
    self.class.where(id: ids)
  end

  def self_and_descendants
    self.class.where(id: [id] + descendants.pluck(:id))
  end

  def self_and_descendants_ordered_with_level
    nodes = [self] + descendants.to_a
    children_by_parent = nodes.group_by(&:parent_id)
    children_by_parent.each_value do |list|
      list.sort_by! { |n| [children_by_parent.key?(n.id) ? 0 : 1, n.slug.to_s] }
    end

    result = []
    visit = ->(node, level) do
      result << [node, level]
      (children_by_parent[node.id] || []).each { |child| visit.call(child, level + 1) }
    end
    visit.call(self, 0)
    result
  end

  def move_to_child_of(new_parent)
    update!(parent_id: new_parent.id)
  end
end
