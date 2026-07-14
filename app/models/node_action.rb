class NodeAction < ApplicationRecord
  belongs_to :node, optional: true
  belongs_to :page, optional: true
  belongs_to :user, optional: true

  validates :action, presence: true
  validates :occurred_at, presence: true

  def self.record!(node:, action:, user: nil, page: nil, locale: nil, **extra)
    create!(
      :node        => node,
      :page        => page,
      :user        => user,
      :action      => action,
      :locale      => locale,
      :occurred_at => Time.now,
      :metadata    => {
        "username"                 => user&.login,
        "human_readable_node_name" => Globalize.with_locale(I18n.default_locale) {
                                        node&.head&.title || node&.draft&.title
                                      },
      }.merge(extra.stringify_keys)
   )
  end

  def actor_name
    metadata["username"] || "unknown"
  end

  def subject_name
    metadata["human_readable_node_name"] || node&.unique_name || "deleted node"
  end
end
