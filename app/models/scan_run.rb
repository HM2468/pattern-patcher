class ScanRun < ApplicationRecord
  belongs_to :repository_file
  belongs_to :lexical_pattern
end
