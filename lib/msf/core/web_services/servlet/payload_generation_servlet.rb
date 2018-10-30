require 'base64'
require 'digest'
require 'msf/core/rpc'

module Msf::WebServices
  module PayloadGenerationServlet

    def self.api_path
      '/api/v1/payload-generate'
    end

    def self.api_path_with_uuid
      "#{PayloadGenerationServlet.api_path}/?:uuid?"
    end

    def self.registered(app)
      app.get PayloadGenerationServlet.api_path_with_uuid, &get_payload
      app.apost PayloadGenerationServlet.api_path, &payload_generate
    end

    #######
    private
    #######

    # Process get payload request
    def self.get_payload
      lambda {
        warden.authenticate!
        begin
          # logger.info("PayloadGenerationServlet.get_payload(): framework.db.name=#{settings.framework.db.name}")
          # logger.info("PayloadGenerationServlet.get_payload(): framework.db.driver=#{settings.framework.db.driver}")

          sanitized_params = sanitize_params(params, env['rack.request.query_hash'])

          # TODO: update accordingly when payload DBManager and endpoint are available
          # The notes DBManager and endpoint are used here for demonstration.
          uuid = sanitized_params.delete(:uuid)
          sanitized_params[:search_term] = uuid
          data = framework.db.notes(sanitized_params)
          logger.info("PayloadGenerationServlet.get_payload(): data=#{data}")

          set_json_data_response(response: data)
        rescue => e
          print_error_and_create_response(error: e, message: 'There was an error retrieving the payload:', code: 500)
        end
      }
    end

    # Process payload generate request
    def self.payload_generate
      lambda {
        warden.authenticate!
        begin
          # logger.info("PayloadGenerationServlet.payload_generate(): helper method framework=#{framework}, settings.framework=#{settings.framework}, framework == settings.framework=#{framework == settings.framework}")
          # logger.info("PayloadGenerationServlet.payload_generate(): json_rpc_id=#{settings.json_rpc_id}, json_rpc_url=#{settings.json_rpc_url}, json_rpc_token=#{settings.json_rpc_token}, data_service_url=#{settings.data_service_url}, data_service_cert=#{settings.data_service_cert}, data_service_skip_verify=#{settings.data_service_skip_verify}, data_service_api_token=#{settings.data_service_api_token}")
          # logger.info("PayloadGenerationServlet.payload_generate(): framework.db.name=#{settings.framework.db.name}")
          # logger.info("PayloadGenerationServlet.payload_generate(): framework.db.driver=#{settings.framework.db.driver}")

          opts = parse_json_request(request, false)
          logger.info("PayloadGenerationServlet.payload_generate(): opts=#{opts}")
          tmp_params = sanitize_params(params)

          # use JSON-RPC service to generate the payload
          module_rpc_client = Msf::RPC::JSON::Client.new(settings.json_rpc_url, api_token: settings.json_rpc_token, namespace: 'module')
          module_execute = module_rpc_client.execute('payload', opts[:payload], opts)

          module_execute.callback do |result|
            logger.info("PayloadGenerationServlet.payload_generate(): *** module_execute.callback *** result.class=#{result.class}, result=#{result}")
            data = opts.merge(result)
            payload_base64 = result[:payload]
            if !payload_base64.nil?
              raw_payload = Base64.strict_decode64(payload_base64)
              raw_payload_sha256 = Digest::SHA256.hexdigest(raw_payload)
              data[:raw_payload_hash] = raw_payload_sha256
              logger.info("PayloadGenerationServlet.payload_generate(): raw_payload_sha256=#{raw_payload_sha256}")
            end

            data_response = { data: data }

            # TODO: lookup payload UUID and return since payload generation could take awhile

            # TODO: update accordingly when payload DBManager and endpoint are available
            # The notes DBManager and endpoint are used here for demonstration.
            payload_note = {
                type: 'payload.info',
                workspace: 'default',
                data: data,
                # update: :insert
                update: :unique_data
            }
            framework.db.report_note(payload_note)

            status(200)
            headers({'Content-Type': 'application/json'})
            body do
              data_response.to_json
            end
          end

          module_execute.errback do |error|
            logger.info("PayloadGenerationServlet.payload_generate(): *** module_execute.errback *** error.class=#{error.class}, error=#{error}")
            if error.is_a?(Hash)
              status_code = json_rpc_error_as_http_status_code(error[:code])
            else
              error = "Error processing payload generation request: #{error.to_s}"
              status_code = 500
            end

            error_response = { error: error }
            logger.info("PayloadGenerationServlet.payload_generate(): *** module_execute.errback *** status_code=#{status_code}, error_response=#{error_response}")
            status(status_code)
            headers({'Content-Type': 'application/json'})
            body do
              error_response.to_json
            end
          end

        rescue => e
          print_error_and_create_response(error: e, message: 'There was an error generating the payload:', code: 500)
        end
      }
    end
  end
end