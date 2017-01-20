require_relative 'common'

class Server

  def initialize(folder, port=DEFAULT_PORT)
    @folder = folder
    @port = port || DEFAULT_PORT
    Dir.chdir(@folder)
  end

  def start
    server = TCPServer.open('0.0.0.0', @port)
    puts "Starting server on port #{@port}, folder: #{@folder}"
    Thread.abort_on_exception = true
    loop do
      Thread.new(server.accept) do |client|
        puts "#{peer_str client}: new session"
        while !client.closed? && recv_msg(client)
          # Do stuff
        end
        puts "#{peer_str client}: session ended"
      end
    end
  end

  def recv_msg(sock)
    line = sock.gets
    if line.nil?
      return false
    else
      res = line.chomp.split(",")
      msg = res[0]
      puts "#{peer_str sock}: msg_#{msg}"
      data = JSON.parse Base64.strict_decode64(res[1])
      begin
        reply_with sock, send("msg_#{msg}", data)
      rescue => e
        reply_with sock, {error: e.to_s}
      end
      return true
    end
  end

  def reply_with(sock, data)
    sock.puts Base64.strict_encode64(data.to_json)
  end

  private

  # Messages

  def msg_folder_info(params)
    files_mtime params['filter']
  end

  def msg_update_file(params)
    file = validate_file_path params['file']
    FileUtils.mkpath File.dirname(file)
    File.open(file, 'wb') { |f| f.write Base64.strict_decode64(params['contents']) }
    puts "Updated #{file}"
    {}
  end

  def msg_delete_file(params)
    file = validate_file_path params['file']
    FileUtils.rm_rf file
    puts "Deleted #{params['file']}"
    {}
  end

  # Helpers

  def peer_str(socket)
    addr = socket.peeraddr(false)
    "#{addr[2]}:#{addr[1]}"
  end

  def validate_file_path(file)
    if file.include?("..") || file.include?("~") || file[0] == "/"
      raise "Invalid file path #{file}"
    end
    file
  end

end

server = Server.new('tmp/server')
server.start