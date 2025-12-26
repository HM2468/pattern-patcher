# app/channels/scan_runs_channel.rb
class ScanRunsChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "scan_runs"
  end
end