module Merb
  module Static
    class Archiver
      
      include ::Caboose::SpiderIntegrator
      
      attr_accessor :config

      def initialize
        yield self
      end

      def self.build
        new do |a|
          a.read_configuration
#           a.copy_assets
          a.unleash_the_spiders
        end
      end

      def self.sync
        new do |a|
          a.read_configuration
          SimpleRsync.sync(a.config[:remote])
        end
      end

      def read_configuration
        @config = Merb::Plugins.config[:merb_static]
        # TODO Prepend http:// to domain
      end

      def copy_assets
        # TODO rake haml:compile_sass if using haml
        # Sync directories and preserve original file times
        system "rsync -ruvt public/ output"
      end

      def unleash_the_spiders
        Merb.logger.info "Unleashing spiders"
        domain = (@config[:domain] =~ /^https?:/) ? @config[:domain] : "http://#{@config[:domain]}"

        @config[:urls].each do |relative_url|
          Merb.logger.info "Fetching #{relative_url}"
          # TODO Do this in the request method
          absolute_url = [domain, relative_url].join

          Merb.logger.info "Absolute url: #{absolute_url}"
          response = request(absolute_url)
          
          if response.status == 200
            Merb.logger.info "Response is #{response.status}"
            # TODO Get file type and extension from headers or request.
            # TODO If response is text/html and url is not .html, append /index.html
            filename_on_disk = Merb.root / "output" / relative_url / "index.html"

            Merb.logger.info "Making directory #{filename_on_disk}"
            FileUtils.mkdir_p(File.dirname(filename_on_disk))
            File.open(filename_on_disk, 'w') do |f|
              f.write(response.body.to_s)
            end
            
            spider(response.body, "/", :verbose => true)  
          else
            raise "Error while fetching page: #{response.inspect}"
          end
        end

      end

      def request(uri, env = {})
        # TODO Combine with domain here to get absolute URL
        uri = url(uri) if uri.is_a?(Symbol)
        uri = URI(uri)
        uri.scheme ||= "http"
        uri.host   ||= "example.org"

        if (env[:method] == "POST" || env["REQUEST_METHOD"] == "POST")
          params = env.delete(:body_params) if env.key?(:body_params)
          params = env.delete(:params) if env.key?(:params) && !env.key?(:input)

          unless env.key?(:input)
            env[:input] = Merb::Parse.params_to_query_string(params)
            env["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
          end
        end

        if env[:params]
          uri.query = [
            uri.query, Merb::Parse.params_to_query_string(env.delete(:params))
          ].compact.join("&")
        end

        ignore_cookies = env.has_key?(:jar) && env[:jar].nil?

        unless ignore_cookies
          # Setup a default cookie jar container
          @__cookie_jar__ ||= Merb::Static::CookieJar.new
          # Grab the cookie group name
          jar = env.delete(:jar) || :default
          # Set the cookie header with the cookies
          env["HTTP_COOKIE"] = @__cookie_jar__.for(jar, uri)
        end

        app = Merb::Rack::Application.new
        rack = app.call(::Rack::MockRequest.env_for(uri.to_s, env))

        rack = Struct.new(:status, :headers, :body, :url, :original_env).
        new(rack[0], rack[1], rack[2], uri.to_s, env)

        @__cookie_jar__.update(jar, uri, rack.headers["Set-Cookie"]) unless ignore_cookies

        Merb::Dispatcher.work_queue.size.times do
          Merb::Dispatcher.work_queue.pop.call
        end

        rack
      end

    end
  end
end
