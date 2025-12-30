# app/channels/import_files_channel.rb
class ImportFilesChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "import_files"
  end
end