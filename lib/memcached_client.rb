# frozen_string_literal: true

require 'socket'

# Memcache client implementation
class MemcachedClient
  def initialize
    @hostname = '127.0.0.1' # Default for memcache
    @port = 11_211
  end

  def next_line_readable?(_socket)
    select([@socket], nil, nil, 0.1)
  end

  def read
    puts(@socket.gets.chop) while next_line_readable?(@socket)
  end

  def write(line)
    @socket.puts(line)
  end

  def connect
    @socket = TCPSocket.open(@hostname, @port)
    puts('Connected to localhost:11211')
    true
  rescue Errno::ECONNREFUSED || Errno::ETIMEDOUT
    puts('Error: Connection timeout or refused')
    false
  end

  def close?(line)
    if line == 'close'
      disconnect
      true
    else
      false
    end
  end

  def disconnect
    @socket.close
  end

  def start
    return unless connect

    loop do
      input = gets.chop
      write(input)
      if close?(input)
        puts('Connection ended')
        return
      else
        read
      end
    end
  end
end
