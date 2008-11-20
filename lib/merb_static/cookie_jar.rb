module Merb
  module Static
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
  end
end
