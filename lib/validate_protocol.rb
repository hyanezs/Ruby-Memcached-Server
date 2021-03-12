# frozen_string_literal: true

# validates write commands protocol
module ValidateProtocol
  # key validation -> matches alphanumeric and underscore
  KEY_REGEX = /^[a-zA-Z0-9_]*$/.freeze
  # number validation -> matches positive numbers
  UNSIGNED_INTEGER_REGEX = /\A\d+\Z/.freeze

  def self.validate(tokens, no_reply, debug)
    # returns [error_string, is_valid]
    @debug = debug

    # get arguments and slice noreply (already validated)
    last_token = no_reply ? tokens.length - 2 : tokens.length - 1
    args = tokens.slice(1, last_token)
    is_cas = tokens[0] == 'cas'

    if !length_valid?(args, is_cas)
      [err(0), false]
    elsif !key_valid?(tokens[1])
      [err(1), false]
    elsif !flags_valid?(tokens[2])
      [err(2), false]
    elsif !exptime_valid?(tokens[3])
      [err(3), false]
    elsif !bytes_valid?(tokens[4])
      [err(4), false]
    elsif !cas_unique_valid?(tokens, is_cas)
      [err(5), false]
    else
      ['', true]
    end
  end

  def self.err(err)
    case err
    when 0
      "CLIENT_ERROR Incorrect protocol input: Incorrect number of arguments\r\n"
    when 1
      "CLIENT_ERROR Incorrect protocol input: Key is too long or contains control characters\r\n"
    when 2
      "CLIENT_ERROR Incorrect protocol input: Flags must be a number (16-bit unsigned integer)\r\n"
    when 3
      "CLIENT_ERROR Incorrect protocol input: Expiration time must be a number\r\n"
    when 4
      "CLIENT_ERROR Incorrect protocol input: bytes must be a positive number\r\n"

    when 5
      "CLIENT_ERROR Incorrect protocol input: cas_unique must be a positive number\r\n"
    end
  end

  # validations
  def self.length_valid?(args, is_cas)
    # args: <key> <flags> <exptime> <bytes> [cas_unique]

    # cas command adds <cas_unique> arg, normalize args to 4-length
    args_length = args.length
    args_length -= 1 if is_cas

    # all storage commands should be 4 length (regardless of <cas> or [noreply])
    if args_length == 4
      true
    else
      puts("Incorrect arguments length: #{args_length}") if @debug
      false
    end
  end

  def self.key_valid?(key)
    # should be shorter than 250 characters && should not have control characters or whitespace

    key.length < 250 && !!key.match(KEY_REGEX)
  end

  def self.flags_valid?(flags)
    # should be a 16 bit unsigned integer in decimal -> 0 ... 65535

    if flags.match(UNSIGNED_INTEGER_REGEX).nil? # is negative number
      false
    else
      Integer(flags, 10) < 65_535
    end
  end

  def self.exptime_valid?(exptime)
    # should be a number (can be negative)

    exptime = exptime.delete('-')
    !!exptime.match(UNSIGNED_INTEGER_REGEX)
  end

  def self.bytes_valid?(bytes)
    # should be a positive number

    !!bytes.match(UNSIGNED_INTEGER_REGEX)
  end

  def self.cas_unique_valid?(tokens, is_cas)
    # should be a positive number

    if is_cas
      !tokens[5].match(UNSIGNED_INTEGER_REGEX).nil?
    else
      true
    end
  end
end
