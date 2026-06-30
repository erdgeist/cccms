class Event < ApplicationRecord
  include RruleHumanizer

  belongs_to :node, optional: true
  has_many   :occurrences

  validates :title, presence: true, unless: -> { node_id.present? }
  validates :is_primary, uniqueness: { scope: :node_id,
    message: "only one primary event per node allowed" },
    if: -> { is_primary? && node_id.present? }

  after_save :generate_occurences

  def occurrences_in_range start_time, end_time
    self.occurrences.where(
      "start_time > ? AND end_time < ?",
      start_time, end_time
    )
  end

  def display_title
    title.presence || node&.head&.title || "Untitled event"
  end

  private
    def generate_occurences
      Occurrence.generate self
    end
end
