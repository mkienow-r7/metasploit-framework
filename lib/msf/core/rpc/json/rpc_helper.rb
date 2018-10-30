require 'msf/core/rpc/json/error'

module Msf::RPC::JSON
  module RpcHelper
    BAD_REQUEST = 400
    INTERNAL_SERVER_ERROR = 500

    # Gets the HTTP status code mapping for the specified JSON-RPC error code.
    # @param error_code [Integer] the JSON-RPC error code
    # @returns [Integer] the HTTP status code.
    def json_rpc_error_as_http_status_code(error_code)
      case error_code
      when PARSE_ERROR, INVALID_REQUEST, METHOD_NOT_FOUND, INVALID_PARAMS
        # errors caused by the client
        BAD_REQUEST
      else
        # server failed to fulfill a request
        INTERNAL_SERVER_ERROR
      end
    end
  end
end