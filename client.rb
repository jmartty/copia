require_relative 'common'

class Client

  def initialize(host, folder, filter='', refresh_interval=5, port=DEFAULT_PORT)
    @host = host
    @folder = folder
    @refresh_interval = refresh_interval
    @port = port || DEFAULT_PORT
    @filter = filter
    Dir.chdir(@folder)
  end

  def run
    connect
    loop do
      remote_files = send_request_folder_info
      send_to_update remote_files
      send_to_delete remote_files
      sleep @refresh_interval
    end
  end

  private

  def send_request_folder_info
    send_msg 'folder_info', {filter: @filter}
  end

  def send_to_update(remote_files)
    updated_files = to_update remote_files
    updated_files.each do |file|
      contents = File.open(file, 'rb') { |f| f.read }
      puts "Updating #{file}"
      send_msg 'update_file', {file: file, contents: Base64.strict_encode64(contents) }
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
    erased_files.each do |file|
      puts "Deleting #{file}"
      send_msg 'delete_file', {file: file}
    end
  end

  def to_delete(remote_files)
    local_files = files_mtime @filter
    erased_files = remote_files.keys - local_files.keys
  end

  def connect
    puts "Connecting to #{@host}:#{@port}"
    @remote = TCPSocket.open(@host, @port)
  end

  def send_msg(msg, data={})
    puts "Sending #{msg}"
    @remote.puts "#{msg},#{Base64.strict_encode64 data.to_json}"
    reply = JSON.parse Base64.strict_decode64(@remote.gets.chomp)
    if reply['error']
      puts "Error: #{reply['error']}" 
      return {}
    else
      return reply
    end
  end

end

client = Client.new('localhost', 'tmp/client', '')
client.run