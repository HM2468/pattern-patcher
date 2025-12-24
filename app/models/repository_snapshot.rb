# app/models/repository_snapshot.rb
class RepositorySnapshot < ApplicationRecord
  belongs_to :repository
end