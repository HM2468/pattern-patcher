# app/channels/scan_runs_channel.rb
class ScanRunsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "scan_runs"
  end
end