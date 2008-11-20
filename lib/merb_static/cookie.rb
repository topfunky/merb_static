module Merb
  module Static

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

  end
end
