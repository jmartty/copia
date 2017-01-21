require_relative 'common'

class Client

  def initialize(settings)
    @host = settings['host']
    @folder = settings['folder']
    @refresh_interval = settings['refresh_interval']
    @port = settings['port']
    @filter = settings['filter']
    @file_chunk_size = settings['file_chunk_size']
    Dir.chdir(@folder)
  end

  def run
    connect
    loop do
      remote_files = send_request_folder_info
      send_to_delete remote_files
      send_to_update remote_files
      sleep @refresh_interval
    end
  end

  private

  def send_request_folder_info
    reply = send_msg 'msg_folder_info', serialize(@filter)
    deserialize reply[:data]
  end

  def send_to_update(remote_files)
    updated_files = to_update remote_files
    updated_files.each do |file|
      first = true
      File.open(file, 'rb') do |f|
        # Special case for empty files
        if f.size == 0
          puts "Updating #{file}: empty file"
          send_msg 'msg_update_file', serialize({file: file, first: first, contents: zip("")})
        else
          while chunk = f.read(@file_chunk_size)
            puts "Updating #{file}: chunk" + (first ? " (first) " : " ") + " - size: #{chunk.size} - zipped: #{zip(chunk).size}"
            send_msg 'msg_update_file', serialize({file: file, first: first, contents: zip(chunk)})
            first = false
          end
        end
      end
    end
  end

  def to_update(remote_files)
    to_update = []

    local_files = files_mtime @filter
    new_files =  local_files.keys - remote_files.keys
    to_update.concat new_files

    common_files = local_files.keys & remote_files.keys
    common_files.each do |file|
      to_update << file if local_files[file] > remote_files[file]
    end

    to_update.select{|f| File.file? f}
  end

  def send_to_delete(remote_files)
    erased_files = to_delete remote_files
    send_msg 'msg_delete_files', serialize(erased_files) unless erased_files.empty?
  end

  def to_delete(remote_files)
    local_files = files_mtime @filter
    erased_files = remote_files.keys - local_files.keys
  end

  def connect
    @remote = TCPSocket.open(@host, @port)
    puts "Connected to #{@host}:#{@port}"
  end

  def send_msg(msg, data)
    puts "Sending #{msg}"
    @remote.write encode_data(msg, data)
    # puts "Sent, reading reply"
    reply = decode_message @remote
    # puts "Got reply"
    # Intercept info messages and print them
    if reply[:id] == MSG_DB.id('msg_info')
      reply_str = deserialize reply[:data]
      if reply.size > 0
        puts "Reply to '#{msg}': '#{reply_str}'"
      end
      return nil
    # Else forward decoded message for handling
    else
      return reply
    end
  end

end

client = Client.new(Settings.new)
client.run