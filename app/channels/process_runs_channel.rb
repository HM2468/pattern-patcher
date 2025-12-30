# app/channels/process_runs_channel.rb
class ProcessRunsChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "process_runs"
  end
end