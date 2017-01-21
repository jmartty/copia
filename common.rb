require 'yaml'
require 'zlib'
require 'socket'
require 'fileutils'

# Message ids
class MsgDB
  def initialize(entries)
    @entries = {}
    counter = 0
    entries.each do |e|
      @entries[e] = counter
      @entries[counter] = e
      counter += 1
    end
  end
  def handler(msg_id)
    @entries[msg_id] || (raise "No handler for msg_id: #{msg_id}")
  end
  def id(handler)
    @entries[handler] || (raise "No id for handler: #{handler}")
  end
end

MSG_DEFINITIONS = ['msg_info',
                   'msg_folder_info',
                   'msg_delete_files',
                   'msg_update_file',
                  ]

MSG_DB = MsgDB.new MSG_DEFINITIONS

# Helpers

def files_mtime(filter)
  res = {}
  rg_filter = Regexp.new filter
  Dir.glob("**/*") do |f|
    begin
        res[f] = File.mtime(f).to_i if f =~ rg_filter
    rescue => e
        puts "Error: #{e}"
    end
  end
  res
end

def zip(data)
  Zlib::Deflate.deflate(data)
end

def unzip(data)
  Zlib::Inflate.inflate(data)
end

def serialize(data)
  Marshal.dump data
end

def deserialize(data)
  Marshal.load data
end

def encode_data(handler, data)
  bytes = ""
  msg_id = MSG_DB.id(handler)
  bytes += [msg_id].pack("C")
  # puts "Data size: #{data.size}"
  bytes += [data.size].pack("Q")
  bytes += data
  # puts "Bytes: #{bytes.bytes.map{|c| c.to_i}}"
  bytes
end

def decode_message(sock)
  # puts "Decoding message"
  # Read message id
  id = sock.read(1).unpack("C").first
  # puts "ID: #{id} / handler: #{MSG_DB.handler(id)}"
  # Read data length
  data_length = sock.read(8).unpack("Q").first
  # puts "Data length: #{data_length}"
  # Return hash with payload
  {
    id: id,
    data: sock.read(data_length)
  }
end

def read_config
  raise 'Missing configuraton file argument' if ARGV.empty?
  YAML.load_file(ARGV.first)
end

def safe_read_setting(dict, key)
  val = dict[key]
  if val.nil?
    raise "Missing required setting `#{key}`"
  else
    val
  end
end