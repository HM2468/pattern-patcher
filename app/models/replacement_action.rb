class ReplacementAction < ApplicationRecord
  belongs_to :occurrence
  belongs_to :repository_file
end
