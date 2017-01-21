require_relative 'common'

class Server

  def initialize(settings)
    @interface = safe_read_setting settings, 'interface'
    @port = safe_read_setting settings, 'port'
    @folder = safe_read_setting settings, 'folder'
    Dir.chdir(@folder)
  end

  def start
    server = TCPServer.open(@interface, @port)
    puts "Server listening @ '#{@interface}:#{@port}', folder: '#{@folder}'"
    
    Thread.abort_on_exception = true
    mutex = Mutex.new
    remote_client = nil
    
    loop do
      Thread.new(server.accept) do |client|
    
        # Allow only single client, reject others    
        can_access = mutex.synchronize do
            if remote_client.nil?
                remote_client = peer_str client
                true
            else
                false
            end
        end

        if can_access
            puts "#{peer_str client}: new session"
            while recv_msg(client)
              # Loop
            end
            puts "#{peer_str client}: session ended"
            mutex.synchronize{ remote_client = nil }
        else
            puts "#{peer_str client}: session rejected"
            reply_with client, 'msg_info', serialize("server busy with #{remote_client}")
            client.close
        end
      end
    end
  end

  def recv_msg(sock)
    return false if sock.closed?
    
    begin
      msg = decode_message(sock)
    rescue => e
      puts "#{peer_str sock}: fatal error: #{e.to_s}"
      return false
    end

    begin
      handler = MSG_DB.handler(msg[:id])
      reply_with sock, handler, serialize(send(handler, sock, msg[:data]))
    rescue => e
      reply_with sock, 'msg_info', serialize(e.to_s)
      puts "#{peer_str sock}: error: #{e.to_s}"
    end
    
    true
  end

  def reply_with(sock, handler, data)
    sock.write encode_data(handler, data)
  end

  private

  # Messages

  def msg_folder_info(sock, data)
    puts "#{peer_str sock}: msg_folder_info"
    filter = deserialize data
    files_mtime filter
  end

  def msg_update_file(sock, data)
    params = deserialize data
    file = validate_file_path params[:file]
    FileUtils.mkpath File.dirname(file)
    open_mode = params[:first] ? 'wb' : 'ab'
    File.open(file, open_mode) { |f| f.write unzip(params[:contents]) }
    puts "#{peer_str sock}: msg_update_file: '#{file}'"
    ""
  end

  def msg_delete_files(sock, data)
    files = deserialize data
    files.each do |file|
      file = validate_file_path file
      FileUtils.rm_rf file
    end
    puts "#{peer_str sock}: msg_delete_files: '#{files}'"
    ""
  end

  # Helpers

  def peer_str(socket)
    begin
      addr = socket.peeraddr(false)
      "#{addr[2]}:#{addr[1]}"
    rescue => e
      'undefined'
    end
  end

  def validate_file_path(file)
    if file.empty? || file.include?("..") || file.include?("~") || file[0] == "/"
      raise "Invalid file path `#{file}`"
    end
    file
  end

end

server = Server.new(read_config)
server.start