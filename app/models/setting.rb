# app/models/setting.rb
class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  scope :by_key, ->(k) { where(key: k) }

  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end
end