# app/models/replacement_target.rb
class ReplacementTarget < ApplicationRecord
  belongs_to :lexeme
  belongs_to :repository_file

  TARGET_TYPES = %w[i18n_key constant method_call comment].freeze

  validates :target_type, presence: true, inclusion: { in: TARGET_TYPES }
  validates :target_value, presence: true
  validates :rendered_code, presence: true

  validates :lexeme_id, uniqueness: { scope: %i[file_id target_type] }

  scope :for_file, ->(file_id) { where(file_id: file_id) }

  def full_key
    return target_value if key_prefix.blank?
    "#{key_prefix}.#{target_value}"
  end
end