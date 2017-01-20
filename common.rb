require 'socket'
require 'fileutils'
require 'json'
require 'base64'
require 'yaml'

DEFAULT_PORT = 4321

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