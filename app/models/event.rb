class Event < ApplicationRecord
  include RruleHumanizer

  belongs_to :node, optional: true
  has_many   :occurrences, dependent: :destroy
  acts_as_taggable_on :tags

  validates :title, presence: true, unless: -> { node_id.present? }

  after_save :generate_occurrences

  def occurrences_in_range start_time, end_time
    self.occurrences.where(
      "start_time > ? AND end_time < ?",
      start_time, end_time
    )
  end

  def display_title
    title.presence || node&.head&.title || "Untitled event"
  end

  def save_witnessed(actor:)
    saved = false
    transaction do
      saved = save
      raise ActiveRecord::Rollback unless saved
      witness_event!("event_create", actor)
    end
    saved
  end

  def update_witnessed(attributes, actor:)
    updated = false
    transaction do
      updated = update(attributes)
      raise ActiveRecord::Rollback unless updated
      changes = event_changes
      witness_event!("event_update", actor, changes) if changes.any?
    end
    updated
  end

  def destroy_witnessed(actor:)
    destroyed = false
    transaction do
      witness_event!("event_destroy", actor)
      destroyed = destroy
      raise ActiveRecord::Rollback unless destroyed
    end
    destroyed
  end

  private
    def generate_occurrences
      Occurrence.generate self
    end

    def event_snapshot
      {
        :event_title => title.presence || node&.unique_name || "##{id}",
        :start_time  => start_time&.iso8601,
        :end_time    => end_time&.iso8601,
        :allday      => allday,
        :rrule       => rrule.presence,
        :location    => location.presence,
        :url         => url.presence,
        :event_tags  => tag_list.to_a.sort,
        :path        => node&.unique_name
      }.compact
    end

    def event_changes
      pairs = {}

      saved_changes.except("updated_at", "created_at", "description")
                   .each do |attribute, (before, after)|
        key, pair =
          case attribute
          when "node_id"
            ["node_path", { "from" => Node.find_by(:id => before)&.unique_name,
                            "to"   => Node.find_by(:id => after)&.unique_name }]
          when "start_time", "end_time"
            [attribute, { "from" => before&.iso8601, "to" => after&.iso8601 }]
          when "tag_list"
            ["tags", { "from" => Array(before).sort, "to" => Array(after).sort }]
          else
            [attribute, { "from" => before, "to" => after }]
          end
        pairs[key] = pair
      end

      extra = {}
      extra[:changes] = pairs if pairs.any?
      extra[:description_changed] = true if saved_changes.key?("description")
      extra
    end

    def witness_event!(verb, actor, extra = {})
      NodeAction.record!(:node => node, :participants => [node, self].compact,
                          :action => verb, :user => actor,
                          **event_snapshot, **extra)
    end
end
