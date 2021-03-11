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
    last_token = no_reply ? tokens.length - 2 : tokens.length - 1
    params = tokens.slice(1, last_token)
    is_cas = tokens[0] == 'cas'

    if !validate_length(params, is_cas)
      [err(0), false]
    elsif !validate_key(tokens[1])
      [err(1), false]
    elsif !validate_flags(tokens[2])
      [err(2), false]
    elsif !validate_exptime(tokens[3])
      [err(3), false]
    elsif !validate_bytes(tokens[4])
      [err(4), false]
    else
      ['', true]
    end
  end

  def self.err(err)
    case err
    when 0
      "CLIENT_ERROR Incorrect protocol input: Wrong number of parameters\r\n"
    when 1
      "CLIENT_ERROR Incorrect protocol input: Key is too long or contains control characters\r\n"
    when 2
      "CLIENT_ERROR Incorrect protocol input: Flags must be a number (16-bit unsigned integer)\r\n"
    when 3
      "CLIENT_ERROR Incorrect protocol input: Expiration time must be a number\r\n"

    when 4
      "CLIENT_ERROR Incorrect protocol input: Bytes must be a number\r\n"
    end
  end

  # validations
  def self.validate_length(params, is_cas)
    # params: <key> <flags> <exptime> <bytes> [cas_unique]

    # cas command adds <cas_unique> param, normalize params to 4-length
    params_length = params.length
    params_length -= 1 if is_cas

    # all storage commands should be 4 length (regardless of <cas> or [noreply])
    if params_length == 4
      true
    else
      puts("Incorrect parameters length: #{params_length}") if @debug
      false
    end
  end

  def self.validate_key(key)
    # should be shorter than 250 characters && should not have control characters or whitespace

    key.length < 250 && !!key.match(KEY_REGEX)
  end

  def self.validate_flags(flags)
    # should be a 16 bit unsigned integer in decimal -> 0 ... 65535

    if flags.match(UNSIGNED_INTEGER_REGEX).nil? # is negative number
      false
    else
      Integer(flags, 10) < 65_535
    end
  end

  def self.validate_exptime(exptime)
    # should be a number (can be negative)

    exptime = exptime.delete('-')
    !!exptime.match(UNSIGNED_INTEGER_REGEX)
  end

  def self.validate_bytes(bytes)
    # should be a number
    !!bytes.match(UNSIGNED_INTEGER_REGEX)
  end
end
