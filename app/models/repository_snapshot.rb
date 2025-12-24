# app/models/repository_snapshot.rb
class RepositorySnapshot < ApplicationRecord
  belongs_to :repository
  belongs_to :scan_run
end