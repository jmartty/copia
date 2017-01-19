require 'socket'
require 'fileutils'
require 'json'
require 'base64'

require_relative 'common'

class Server

  def initialize(folder='.', port=4321)
    @folder = folder
    @port = port
    Dir.chdir(@folder)
  end

  def start
    server = TCPServer.open(@port)
    puts "Starting server on port #{@port}, folder `#{@folder}`"
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
      reply_with sock, send("msg_#{msg}", data)
      return true
    end
  end

  def reply_with(sock, data)
    sock.puts Base64.strict_encode64(data.to_json)
  end

  private

  def peer_str(socket)
    addr = socket.peeraddr(false)
    "#{addr[2]}:#{addr[1]}"
  end

  def msg_folder_info(params)
    files_mtime
  end

  def msg_update_file(params)
    file = params['file']
    FileUtils.mkpath File.dirname(file)
    File.open(file, 'wb') { |f| f.write Base64.strict_decode64(params['contents']) }
    puts "Updated #{file}"
    {}
  end

  def msg_delete_file(params)
    FileUtils.rm_rf params['file']
    puts "Deleted #{params['file']}"
    {}
  end

end

server = Server.new('tmp/server')
server.start