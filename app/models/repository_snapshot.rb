# app/models/repository_snapshot.rb
class RepositorySnapshot < ApplicationRecord
  belongs_to :repository
  has_many :scan_runs
end