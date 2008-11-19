module Merb
  module Static
    class Archiver

      def initialize
        read_configuration
        copy_assets
        unleash_the_spiders
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
        @config[:urls].each do |relative_url|
          Merb.logger.info "Fetching #{relative_url}"
          absolute_url = [@config[:domain], relative_url].join

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
          else
            raise "Error while fetching page: #{response.inspect}"
          end
        end

      end



      class Cookie

        # :api: private
        attr_reader :name, :value

        # :api: private
        def initialize(raw, default_host)
          # separate the name / value pair from the cookie options
          @name_value_raw, options = raw.split(/[;,] */n, 2)

          @name, @value = Merb::Parse.query(@name_value_raw, ';').to_a.first
          @options = Merb::Parse.query(options, ';')

          @options.delete_if { |k, v| !v || v.empty? }

          @options["domain"] ||= default_host
        end

        # :api: private
        def raw
          @name_value_raw
        end

        # :api: private
        def empty?
          @value.nil? || @value.empty?
        end

        # :api: private
        def domain
          @options["domain"]
        end

        # :api: private
        def path
          @options["path"] || "/"
        end

        # :api: private
        def expires
          Time.parse(@options["expires"]) if @options["expires"]
        end

        # :api: private
        def expired?
          expires && expires < Time.now
        end

        # :api: private
        def valid?(uri)
          uri.host =~ Regexp.new("#{Regexp.escape(domain)}$") &&
          uri.path =~ Regexp.new("^#{Regexp.escape(path)}")
        end

        # :api: private
        def matches?(uri)
          ! expired? && valid?(uri)
        end

        # :api: private
        def <=>(other)
          # Orders the cookies from least specific to most
          [name, path, domain.reverse] <=> [other.name, other.path, other.domain.reverse]
        end

      end

      class CookieJar

        # :api: private
        def initialize
          @jars = {}
        end

        # :api: private
        def update(jar, uri, raw_cookies)
          return unless raw_cookies
          # Initialize all the the received cookies
          cookies = []
          raw_cookies.each do |raw|
            c = Cookie.new(raw, uri.host)
            cookies << c if c.valid?(uri)
          end

          @jars[jar] ||= []

          # Remove all the cookies that will be updated
          @jars[jar].delete_if do |existing|
            cookies.find { |c| [c.name, c.domain, c.path] == [existing.name, existing.domain, existing.path] }
          end

          @jars[jar].concat cookies

          @jars[jar].sort!
        end

        # :api: private
        def for(jar, uri)
          cookies = {}

          @jars[jar] ||= []
          # The cookies are sorted by most specific first. So, we loop through
          # all the cookies in order and add it to a hash by cookie name if
          # the cookie can be sent to the current URI. It's added to the hash
          # so that when we are done, the cookies will be unique by name and
          # we'll have grabbed the most specific to the URI.
          @jars[jar].each do |cookie|
            cookies[cookie.name] = cookie.raw if cookie.matches?(uri)
          end

          cookies.values.join
        end

      end


      def request(uri, env = {})
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
          @__cookie_jar__ ||= Merb::Static::Archiver::CookieJar.new
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
