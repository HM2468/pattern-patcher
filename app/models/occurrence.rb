# app/models/occurrence.rb
class Occurrence < ApplicationRecord
  belongs_to :scan_run
  belongs_to :lexeme
  belongs_to :lexical_pattern
  belongs_to :repository_file

  has_many :replacement_actions, dependent: :destroy
  has_one :occurrence_review, dependent: :destroy

  STATUSES = %w[unreviewed approved ignored replaced].freeze
  validates :status, presence: true, inclusion: { in: STATUSES }

  validates :line_at, numericality: { only_integer: true, greater_than: 0 }
  validates :line_char_start, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :line_char_end, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :unreviewed, -> { where(status: "unreviewed") }
  scope :by_location, -> { order(file_id: :asc, line_at: :asc, line_char_start: :asc) }

  before_validation :default_status, on: :create

  def match_range
    return nil if line_char_start.nil? || line_char_end.nil?
    line_char_start..line_char_end
  end

  def highlighted_origin_context
    highlighted = "<span class=\"ppmatchhi\">#{matched_text}</span>"
    context[0..(line_char_start - 1)] + highlighted + context[(line_char_end + 1)..]
  end

  private

  def default_status
    self.status ||= "unreviewed"
  end
end