# frozen_string_literal: true

# validates write commands protocol
module ValidateProtocol
  def self.validate_length(params, is_cas, _client)
    # returns [error_string, is_valid]
    # params: <key> <flags> <exptime> <bytes> [cas_unique]

    # cas command adds <cas_unique> param, normalize params to 4-length
    params_length = params.length
    params_length -= 1 if is_cas

    # all storage commands should be 4 length (regardless of <cas> or [noreply])
    if params_length == 4
      ['', true]
    else
      puts("Incorrect parameters length: #{params_length}")
      ["CLIENT_ERROR Incorrect protocol input: Wrong number of parameters\r\n", false]
    end
  end
end
