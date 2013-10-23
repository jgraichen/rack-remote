require 'rack/remote/version'
require 'rack/request'
require 'multi_json'

module Rack
  # Rack::Remote is a Rack middleware for intercepting calls
  # and invoking remote calls. It can be used to call remote
  # function for test instructions in distributed systems.
  #
  class Remote
    require 'rack/remote/railtie' if defined?(Rails)

    class ChainedError < StandardError
      attr_reader :cause

      def initialize(*attrs)
        if attrs.last.is_a?(Hash) && attrs.last[:cause].is_a?(Exception)
          @cause = attrs.last.delete(:cause)
          attrs.pop if attrs.last.empty?
        end
        super *attrs
      end

      def set_backtrace(trace)
        trace.is_a?(Array) ? trace.map!(&:to_s) : trace = trace.to_s.split("\n")
        trace.map! { |line| "  #{line}" }
        if cause
          trace << "caused by #{cause.class.name}: #{cause.message}"
          trace += cause.backtrace.map! { |line| "  #{line}" }
        end
        super trace
      end
    end

    class RemoteError < StandardError
      def initialize(opts = {})
        super "#{opts[:class]}: #{opts[:error]}"
        set_backtrace opts[:backtrace]
      end
    end

    class RemoteCallFailed < ChainedError
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env['HTTP_X_RACK_REMOTE_CALL']

      request = ::Rack::Request.new(env)
      call    = env['HTTP_X_RACK_REMOTE_CALL'].to_s

      if (cb = self.class.calls[call])
        begin
          # First rewind request body before read
          request.body.rewind

          data = request.body.read
          json = data.empty? ? {} : MultiJson.load(data)

          response = cb.call(json, env, request)
          if response.is_a?(Array) && response.size == 3
            return response
          else
            [200, {'Content-Type' => 'application/json'}, StringIO.new(MultiJson.dump response) ]
          end
        rescue => err
          [500, {'Content-Type' => 'application/json'}, StringIO.new(MultiJson.dump error: err.message, backtrace: err.backtrace, class: err.class.name) ]
        end
      else
        [404, {'Content-Type' => 'application/json'}, StringIO.new(MultiJson.dump error: 'remote call not defined', calls: call, list: self.class.calls.keys) ]
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
          request['Content-Type'] = 'application/json'
          request.body = MultiJson.dump(params)

          response = http.request request
          if response.code.to_i == 500 and response['Content-Type'] == 'application/json'
            json = MultiJson.load(response.body)

            if json['error'] && json['backtrace'] && json['class']
              remote_error = RemoteError.new class: json['class'], error: json['error'], backtrace: json['backtrace']
              raise Rack::Remote::RemoteCallFailed.new("Remote call returned error code #{response.code}", cause: remote_error)
            end
          end

          raise StandardError, "Rack Remote Error Response: #{response.code}: #{response.body}" if response.code.to_i != 200

          if response['Content-Type'] == 'application/json'
            response.body.empty? ? {} : MultiJson.load(response.body)
          else
            response.body
          end
        end
      end
    end
  end
end
