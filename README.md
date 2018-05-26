# Description
File sync server/client writen in pure ruby, tested with Ruby 2.3.0.

# Configuration
Example configurations are included for both server and client.
#### Server configuration example YML
```ruby
# Interface and port to listen on
interface: '0.0.0.0'
port: 4321
# Folder to store files (must exist before running)
folder: 'tmp/server'
```
#### Client configuration example YML
```ruby
# Remote server address and port
host: 'localhost'
port: 4321
# Folder to read files from (must exist before running)
folder: 'tmp/client'
# Chunk sizes (in bytes) to avoid reading entire files in memory
# Should not exceed 2^32 = 4294967296
file_chunk_size: 67108864
# Seconds to wait between synchronization attemps
refresh_interval: 4
# Regex applied to file listings, files that do not match are excluded
# Example to include only .txt or .ini file extensions: '\\.(txt|ini)$'
# Empty will match anything
filter: ''
```

# Usage

Starting the server: `ruby server.rb server_config.yml`

Starting the client: `ruby client.rb server_config.yml`

After startup, just drop/delete files in the client's folder and they will be syncronized with the server's folder. **Only one client is allowed at a time.**
