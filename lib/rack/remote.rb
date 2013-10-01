require 'rack/remote/version'
require 'rack/request'
require 'multi_json'

module Rack

  # Rack::Remote is a Rack middleware for intercepting calls
  # and invoking remote calls. It can be used to call remote
  # function for test instructions in distributed systems.
  #
  class Remote
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env['HTTP_X_RACK_REMOTE_CALL']

      request = ::Rack::Request.new(env)
      call    = env['HTTP_X_RACK_REMOTE_CALL'].to_s

      if (cb = self.class.calls[call])
        response = cb.call(request.params, env, request)
        if response.is_a?(Array) && response.size == 3
          return response
        else
          [200, {'Content-Type' => 'application/json'}, StringIO.new(MultiJson.dump response) ]
        end
      else
        [404, {'Content-Type' => 'application/json'}, StringIO.new('{"error":"remote call not defined"}') ]
      end
    end

    class << self
      # Register a new remote call. Used on server side to
      # define available remote calls.
      #
      # @example
      #   Rack::Remote.register :factory_girl do |env, request|
      #     FactoryGirl.create request.params[:factory]
      #   end
      #
      # @params name [String, #to_s] Remote call name
      #
      def register(name, &block)
        calls[name.to_s] = block
      end

      # Return hash with registered calls.
      #
      def calls
        @calls ||= {}
      end

      # Removes all registered calls.
      def clear
        calls.clear
        remotes.clear
      end

      # Add a new remote to be used in `invoke` by symbolic reference.
      #
      def add(name, options = {})
        raise ArgumentError unless options[:url]
        remotes[name.to_sym] = options
      end

      def remotes
        @remotes ||= {}
      end

      # Invoke remote call.
      #
      # @param remote [Symbol, String, #to_s] Symbolic remote name or remote URL.
      # @param call [String, #to_s] Remote call to invoke.
      # @param params [Hash] Key-Value pairs that will be converted to json and sent to remote call.
      # @param headers [Hash] Header added to request.
      #
      def invoke(remote, call, params = {}, headers = {})
        remote = remotes[remote][:url] if remote.is_a? Symbol
        uri = URI.parse remote.to_s
        uri.path = '/' if uri.path.empty?

        Net::HTTP.start uri.host, uri.port do |http|
          request = Net::HTTP::Post.new uri.path
          headers.each do |key, value|
            request[key] = value.to_s
          end

          request['X-Rack-Remote-Call'] = call.to_s
          request.form_data = params

          response = http.request request
          raise StandardError, "Rack Remote Error Response: #{response.code}: #{response.body}" if response.code.to_i != 200

          if response['Content-Type'] == 'application/json'
            MultiJson.load response.body
          else
            response.body
          end
        end
      end
    end
  end
end
