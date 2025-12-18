class ReplacementTarget < ApplicationRecord
  belongs_to :lexeme
  belongs_to :repository_file
end
