# frozen_string_literal: true

require 'socket'

# Memcache client implementation
class MemcachedClient
  def initialize
    @hostname = 'localhost' # Default for memcache
    @port = 11_211
    @socket = TCPSocket.open(@hostname, @port)
  end

  def next_line_readable?(_socket)
    select([@socket], nil, nil, 0.1)
  end

  def start
    @socket.puts('set tutorialspoint 0 900 9')
    @socket.puts('memcached')
    puts(@socket.gets.chop)
    @socket.puts('get sss tutorialspoint')
    puts(@socket.gets.chop) while next_line_readable?(@socket)
  end
end

client = MemcachedClient.new
client.start
