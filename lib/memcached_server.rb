# frozen_string_literal: true

require 'socket'
require_relative 'validate_protocol'

# Memcache server implementation
class MemcachedServer
  include ValidateProtocol

  # constants (commands)
  READ_COMMANDS = %w[get gets].freeze
  WRITE_COMMANDS = %w[set add replace append prepend cas].freeze

  def initialize(debug)
    @hostname = '127.0.0.1'
    @port = 11_211
    # stored data
    @cache = {}
    # cas counter
    @cas_unique = 0
    # server console logging
    @debug = debug
  end

  attr_reader :cache

  def listen_connections
    # server socket -> 11211 memcache default port
    @server = TCPServer.open(@hostname, @port)
    puts("Server is running! Listening for connections on #{@hostname}:#{@port}") if @debug
    true
  end

  # command processing
  def no_reply?(tokens)
    tokens[tokens.length - 1] == 'noreply'
  end

  def command_read?(command)
    READ_COMMANDS.include?(command)
  end

  def command_write?(command)
    WRITE_COMMANDS.include?(command)
  end

  def process_write_command(command, to_store, cas_unique)
    # assert -> is write command

    key = to_store[:key]
    case command
    when 'set'
      store(to_store, key) # returns "STORED"

    # add & replace return "NOT_STORED" if key already exists (add) or doesnt exist (replace)
    when 'add'
      if exists?(key) && !expired?(key)
        "NOT_STORED\r\n" # "STORED"
      else store(to_store, key)
      end
    when 'replace'
      if exists?(key) && !expired?(key)
        store(to_store, key) # "STORED"
      else "NOT_STORED\r\n"
      end

    # append & prepend only update bytes & data_block
    when 'append'
      if exists?(key) && !expired?(key)
        append(to_store, key) # "STORED"
      else "NOT_STORED\r\n"
      end

    when 'prepend'
      if exists?(key) && !expired?(key)
        prepend(to_store, key) # "STORED"
      else "NOT_STORED\r\n"
      end

    # cas stores if cas_unique == cas_unique from item in cache
    when 'cas'
      if exists?(key) && !expired?(key)
        cas(to_store, key, cas_unique) # "STORED" or "EXISTS"
      else "NOT_FOUND\r\n"
      end
    end
  end

  # arguments processing
  def protocol_valid?(tokens, no_reply)
    ValidateProtocol.validate(tokens, no_reply, @debug)
  end

  def process_args(tokens, data_block)
    # assert -> args validated
    {
      key: tokens[1],
      flags: Integer(tokens[2], 10),
      exptime: Integer(tokens[3]),
      stored_time: Time.now.to_i,
      bytes: Integer(tokens[4], 10),
      data_block: data_block,
      cas_unique: next_cas_unique
    }
  end

  # data processing
  def process_data_block(data_block, bytes)
    bytes = Integer(bytes, 10)
    if data_block.length > bytes
      data_block = data_block.slice(0, bytes)
      data_block.concat("\r\n")
    else
      data_block
    end
  end

  # retrieval commands
  def get(key)
    [@cache[key][:flags], @cache[key][:bytes], @cache[key][:data_block], @cache[key][:cas_unique]]
  end

  # storage commands
  def store(to_store, key)
    @cache[key] = to_store
    "STORED\r\n"
  end

  def append(to_store, key)
    new_bytes = to_store[:bytes] + @cache[key][:bytes]
    data_block = @cache[key][:data_block]
    data_block = data_block.slice(0, data_block.length - 2) # deletes "\r\n"
    data_block.concat(to_store[:data_block])

    @cache[key][:bytes] = new_bytes
    @cache[key][:data_block] = data_block
    @cache[key][:cas_unique] = to_store[:cas_unique]
    "STORED\r\n"
  end

  def prepend(to_store, key)
    new_bytes = to_store[:bytes] + @cache[key][:bytes]
    data_block = to_store[:data_block]
    data_block = data_block.slice(0, data_block.length - 2) # deletes "\r\n"
    data_block.concat(@cache[key][:data_block])

    @cache[key][:bytes] = new_bytes
    @cache[key][:data_block] = data_block
    @cache[key][:cas_unique] = to_store[:cas_unique]
    "STORED\r\n"
  end

  def cas(to_store, key, cas_unique)
    puts("cas_unique entered  #{cas_unique}") if @debug
    puts("cache item cas_unique:  #{@cache[key][:cas_unique]}") if @debug

    if @cache[key][:cas_unique] == cas_unique
      @cache[key] = to_store
      "STORED\r\n"
    else
      "EXISTS\r\n"
    end
  end

  # utils
  def exists?(key)
    puts("Exists?  #{@cache.key?(key)}") if @debug
    @cache.key?(key)
  end

  def expired?(key)
    exptime = @cache[key][:exptime]
    stored_time = @cache[key][:stored_time]
    return false if exptime.zero?

    if unix_time?(exptime)
      is_expired = Time.now.to_i > exptime
      remaining_time = exptime - Time.now.to_i
    else
      time_passed = Time.now.to_i - stored_time
      is_expired = time_passed > exptime
      remaining_time = exptime - time_passed
    end

    puts("Has expired?  #{is_expired}") if @debug
    if is_expired
      # lazy delete (delete when client tries to unsuccessfully access)
      @cache.delete(key)
    elsif @debug
      puts("Remaining time:  #{remaining_time}  seconds")
    end
    is_expired
  end

  def retrievable?(key)
    if exists?(key) && !expired?(key)
      puts('Sending value...') if @debug
      true
    else
      puts('Data could not be retrieved, value has expired or key is not valid') if @debug
      false
    end
  end

  def unix_time?(exptime)
    # exptime > 30 days then is Unix time (seconds from Jan 1 1970)
    exptime > 2_592_000
  end

  def next_cas_unique
    @cas_unique += 1
  end

  def gets?(command)
    command == 'gets'
  end

  # run
  def start
    listen_connections
    loop do
      Thread.start(@server.accept) do |client| # accept a connection - client
        begin
          puts("\r\nConnection", client) if @debug

          loop do
            if (input = client.gets)
              input = input.chop
              tokens = input.split
              command = tokens[0]
              puts("\r\n##########################################################\r\n") if @debug
              puts("Command received:  #{command}\r\n") if @debug
              puts("Parameters:  #{tokens.slice(1, tokens.length - 1)}\r\n") if @debug

              if command_read?(command)
                is_gets = gets?(command)
                keys = tokens.slice(1, tokens.length - 1)
                if keys.length.zero?
                  puts("No keys submitted.\r\n") if @debug
                  client.puts("ERROR\r\n")
                else
                  keys.each do |key|
                    puts("#############################\r\n") if @debug
                    puts("Retrieving key:  #{key}") if @debug

                    next unless retrievable?(key) # skip when !exists or is_expired

                    # if retrievable then get item
                    flags, bytes, data_block, cas_unique = get(key)
                    if is_gets
                      # gets
                      client.puts("VALUE #{key} #{flags} #{bytes} #{cas_unique}\r\n")
                    else
                      # get
                      client.puts("VALUE #{key} #{flags} #{bytes}\r\n")
                    end
                    client.puts(data_block)
                  end
                  client.puts("END\r\n")
                end

              elsif command_write?(command)
                # protocol processing
                no_reply = no_reply?(tokens)
                error_string, is_protocol_valid = protocol_valid?(tokens, no_reply)

                if is_protocol_valid
                  # get data_block until bytes
                  data_block_input = client.gets
                  data_block_input.concat(client.gets) while data_block_input.length <= Integer(tokens[4], 10)
                  # cut data_block if longer than bytes
                  data_block = process_data_block(data_block_input, tokens[4])
                  puts("Data block received \r\n #{data_block}") if @debug

                  # if cas then get cas_unique
                  cas_unique = nil
                  cas_unique = Integer(tokens[5], 10) if tokens.length > 5 && tokens[5] != 'noreply'

                  # try to store, sends STORED or <error> to client
                  to_store = process_args(tokens, data_block)
                  client.puts(process_write_command(command, to_store, cas_unique)) unless no_reply
                else
                  client.puts(error_string) unless no_reply
                end
              elsif command == 'close'
                puts('Connection closed by client', client) if @debug
                client.close
                break
              else
                # command is not read nor write, client sent a nonexistent command
                puts('Nonexistent command') if @debug
                client.puts("ERROR\r\n")
              end
            else
              # if input is nil then client interrupted connection, server raised error input.NoMethod
              puts("\r\n#############################\r\n") if @debug
              puts('Connection aborted by client') if @debug
              break
            end
          end
        rescue Errno::ECONNABORTED
          puts("\r\n#############################\r\n") if @debug
          puts('Connection aborted by client') if @debug
        end
      end
    end
  end
end
