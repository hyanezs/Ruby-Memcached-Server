# frozen_string_literal: true

require 'socket'
require_relative 'validate_protocol'

# Memcache server implementation
class MemcachedServer
  include ValidateProtocol

  # constants (commands)
  READ_COMMANDS = %w[get gets].freeze
  WRITE_COMMANDS = %w[set add replace append prepend cas].freeze

  def initialize
    # server socket -> 11211 memcache default port
    @server = TCPServer.open(11_211)
    # stored data
    @cache = {}
  end

  # command processing
  def protocol_valid?(tokens, no_reply, client)
    # TODO: only length implemented
    last_token = no_reply ? tokens.length - 2 : tokens.length - 1
    params = tokens.slice(1, last_token)
    is_cas = tokens[0] == 'cas'
    ValidateProtocol.validate_length(params, is_cas, client)
  end

  def no_reply?(tokens)
    tokens[tokens.length - 1] == 'noreply'
  end

  def command_read?(command)
    READ_COMMANDS.include?(command)
  end

  def command_write?(command)
    WRITE_COMMANDS.include?(command)
  end

  def process_read_command(key)
    get(key)
  end

  def process_write_command(command, to_store)
    # assert -> is write command

    key = to_store[:key]
    case command
    when 'set'
      store(to_store) # returns "STORED"

    # add & replace return "NOT_STORED" if key already exists (add) or doesnt exist (replace)
    when 'add'
      if exists?(key)
        "NOT_STORED\r\n" # "STORED"
      else store(to_store)
      end
    when 'replace'
      if exists?(key)
        store(to_store) # "STORED"
      else "NOT_STORED\r\n"
      end
      # TODO

      # when 'append'
      # when 'prepend'
      # when 'cas'
    end
  end

  # parameters processing
  def process_params(tokens, data_block)
    {
      key: tokens[1],
      flags: tokens[2],
      exptime: tokens[3],
      bytes: tokens[4],
      data_block: data_block
    }
  end

  # retrieval commands
  def get(key)
    [@cache[key][:flags], @cache[key][:bytes], @cache[key][:data_block]]
  end

  # storage commands
  def store(to_store)
    @cache[to_store[:key]] = to_store
    "STORED\r\n"
  end

  # utils
  def exists?(key)
    @cache.key?(key)
  end

  def start
    loop do
      puts('Server running! Listening on localhost:11211')
      Thread.start(@server.accept) do |client| # accept a connection - client
        while (input = client.gets.chop)
          tokens = input.split
          command = tokens[0]
          puts("Command received \r\n #{tokens}")

          if command_read?(command)
            keys = tokens.slice(1, tokens.length - 1)
            keys.each do |key|
              next unless exists?(key) # skip when !exists

              flags, bytes, data_block = process_read_command(key)
              client.puts("VALUE #{key} #{flags} #{bytes}\r\n")
              client.puts(data_block)
            end
            client.puts("END\r\n")

          elsif command_write?(command)
            no_reply = no_reply?(tokens)
            error_string, is_protocol_valid = protocol_valid?(tokens, no_reply, client)

            if is_protocol_valid
              data_block = client.gets
              puts("Data block received \r\n #{data_block}")
              to_store = process_params(tokens, data_block)
              client.puts(process_write_command(command, to_store)) unless no_reply
            else
              client.puts(error_string) unless no_reply
            end

          else
            # means the client sent a nonexistent command
            puts('Nonexistent command')
            client.puts("ERROR\r\n")
          end
        end
      end
    end
  end
end

test = MemcachedServer.new
test.start
