class Event < ApplicationRecord
  include RruleHumanizer

  belongs_to :node, optional: true
  has_many   :occurrences
  acts_as_taggable_on :tags

  validates :title, presence: true, unless: -> { node_id.present? }

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
