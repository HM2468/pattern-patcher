class Occurrence < ApplicationRecord
  belongs_to :scan_run
  belongs_to :lexeme
  belongs_to :lexical_pattern
  belongs_to :repository_file
end
