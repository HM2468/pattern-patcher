class CleanupScanRunJob < ApplicationJob
  queue_as :default

  def perform(scan_run_id:)
    ScanRunFile.where(scan_run_id: scan_run_id).delete_all
    occurrences = Occurrence.where(scan_run_id: scan_run_id)
    lexemes_ids = occurrences.pluck(:lexeme_id).uniq
    Lexeme.where(id: lexemes_ids).delete_all
    occurrences.delete_all
  end
end