# app/models/repository.rb
class Repository < ApplicationRecord
  has_many :repository_files, dependent: :destroy

  validates :root_path, presence: true, uniqueness: true
  validates :repository_uid, presence: true, uniqueness: true

  STATUSES = %w[active archived error].freeze
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  before_validation :ensure_repository_uid, on: :create

  private

  def ensure_repository_uid
    self.repository_uid ||= SecureRandom.uuid
  end
end