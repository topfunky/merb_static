
require 'caboose'
require 'fileutils'
require 'uri'

##
# Looted from the Rails spider_test plugin.

module Caboose::SpiderIntegrator

  # Begin spidering your application.
  # +body+:: the HTML request.body from a page in your app
  # +uri+::  the URL which generated the request.body. This is used in stack traces (followed link <...> from <uri>)
  # +options+:: A list of options for ignoring URLs, URL patterns, forms and form patterns
  #
  # The possible option are
  #         :ignore_urls : An array of URL strings and Regexp patterns that the spide should ignore
  #         :ignore_forms : An array of URL strings and Regexp patterns of form POST actions that the spider will ignore
  #         :verbose : Set this to true if you want extreme verbosity.
  #   
  # You can override certain instance methods if necessary:
  #    @links_to_visit : array containing Caboose::SpiderIntegrator::Link.new( dest_url, source_url ) objects
  #    @forms_to_visit : array containing Caboose::SpiderIntegrator::Form.new( method, action, query, source ) objects
  #   
  # You may find it useful to have two spider tests, one logged in and one logged out.
  def spider( body, uri, options )
    @errors, @stacktraces = {}, {}
    setup_spider(options)
    begin
      do_spider(body.send(:to_s), uri)

    rescue Interrupt
      $stderr.puts "Caught CTRL-C"
    ensure
      finish
    end
  end
  
  protected
  # You probably don't want to be calling these from within your test.

  # Use HTML::Document to suck the links and forms out of the spidered page.
  # todo: use hpricot or something else more fun (we will need to validate 
  # the html in this case since HTML::Document does it by default)
  def consume_page( html, url )
    doc = Hpricot(html.send(:to_s))
    (doc / "a").each do |tag|
      queue_link( tag, url )
    end
    (doc / "link").each do |tag|
      # Strip appended browser-caching numbers from asset paths like ?12341234
      queue_link( tag, url )
    end
    (doc / "img").each do |tag|
      queue_link(tag, url)
    end
  end
  
  def console(str)
    return unless @verbosity
    puts str
  end
  
  def setup_spider(options = {})
    options.reverse_merge!({ :ignore_urls => ['/logout'], :ignore_forms => ['/login'] })

    @ignore = {}
    @ignore[:urls] = Hash.new(false)
    @ignore[:url_patterns] = Hash.new(false)
    @ignore[:forms] = Hash.new(false)
    @ignore[:form_patterns] = Hash.new(false)

    options[:ignore_urls].each do |option|
      @ignore[:url_patterns][option] = true if option.is_a? Regexp
      @ignore[:urls][option] = true if option.is_a? String
    end
    
    options[:ignore_forms].each do |option|
      @ignore[:form_patterns][option] = true if option.is_a? Regexp
      @ignore[:forms][option] = true if option.is_a? String
    end

    @verbosity = options[:verbose]
    
    console "Spidering will ignore the following URLs #{@ignore[:urls].keys.inspect}"
    console "Spidering will ignore the following URL patterns #{@ignore[:url_patterns].keys.inspect}"
    console "Spidering will ignore the following form URLs #{@ignore[:forms].keys.inspect}"
    console "Spidering will ignore the following form URL patterns #{@ignore[:form_patterns].keys.inspect}"
    
    @links_to_visit ||= []
    @forms_to_visit ||= []
    @visited_urls = Hash.new(false)
    @visited_forms = Hash.new(false)
    
    @visited_urls.merge! @ignore[:urls]
    @visited_forms.merge! @ignore[:forms] 
    
  end
  
  def spider_should_ignore_url?(uri)
     if @visited_urls[uri] then
       return true
     end
    
    @ignore[:url_patterns].keys.each do |pattern|
      if pattern.match(uri)
        console  "- #{uri} ( Ignored by pattern #{pattern.inspect})"
        @visited_urls[uri] = true
        return true 
      end
    end
    return false
  end
  
  def spider_should_ignore_form?(uri)
    return true if @visited_forms[uri] == true
    
    @ignore[:form_patterns].keys.each do |pattern|
        if pattern.match(uri)
          console  "- #{uri} ( Ignored by pattern #{pattern.inspect})"
          @visited_forms[uri] = true
          return true 
        end
    end
    return false
  end
  
  # This is the actual worker method to grab the page.
  def do_spider( body, uri )
    @visited_urls[uri] = true
    consume_page( body, uri )
    until @links_to_visit.empty?
      next_link = @links_to_visit.shift
      next if spider_should_ignore_url?(next_link.uri)
      next if retrieve_cached_file(next_link.uri)
      
      @response = request(next_link.uri)
      
      if [200, 201, 302, 401].include?( @response.status )
        console "GET '#{next_link.uri}'"
        # Cache output to disk
        next_link_path         = URI.parse(next_link.uri).path
        local_output_file_path = Merb.root / 'output' / next_link_path
        
        # TODO Fix local_output_file_path to end in /index.html or add appropriate extension.
        local_output_file_path = local_output_file_path / "index.html" # HACK See comment on previous line.
        
        FileUtils.mkdir_p File.dirname(local_output_file_path)
        File.open(local_output_file_path, "wb") do |f|
          f.write(@response.body)
        end
      elsif @response.status == 404
        console  "? #{next_link.uri} ( 404 File not found from #{next_link.source} and File does not exist )"
        @errors[next_link.uri] = "File not found: #{next_link.uri} from #{next_link.source}"
      else
        console  "! #{ next_link.uri } ( Received response code #{ @response.status }  - from #{ next_link.source } )"
        @errors[next_link.uri] = "Received response code #{ @response.status } for URI #{ next_link.uri } from #{ next_link.source }"
          
        @stacktraces[next_link.uri] = @response.body
      end
      consume_page( @response.body, next_link.uri )
      @visited_urls[next_link.uri] = true
    end
  end

  def retrieve_cached_file(relative_file_path)
    absolute_cached_path = File.expand_path('public' / relative_file_path, Merb.root)
    if (exists = File.exist?(absolute_cached_path))
      if File.directory?(absolute_cached_path)
        # skip directories
      else
        console "STATIC: #{relative_file_path}"
        absolute_output_path = File.expand_path('output' / relative_file_path, Merb.root)
        FileUtils.mkdir_p File.dirname(absolute_output_path)
        # Copy if public copy is newer than output copy
        if (!File.exist?(absolute_output_path)) || (File.mtime(absolute_cached_path) > File.mtime(absolute_output_path))
          FileUtils.cp absolute_cached_path, absolute_output_path
        end
      end
      return true
    end
    false
  end
  
  # Finalize the test and display any errors.
  # TODO make this look much better; and optionally save to a file instead of dumping to the page."
  def finish
    console  "\nFinished with #{@errors.size} error(s)."
    # TODO dump this in a file instead.
    err_dump = ""
    @errors.each do |url, error|
      err_dump << "\n#{'='*120}\n"
      err_dump << "ERROR:\t #{error}\n"
      err_dump << "URL  :\t #{url}\n"
      if @stacktraces[url] then
        err_dump << "STACK TRACE:\n"
        raise @stacktraces[url].to_s
#         err_dump << @stacktraces[url]
      end
      err_dump << "\n#{'='*120}\n\n\n"
    end
    
    err_dump unless @errors.empty?

    # reset our history. If you want to get access to some of these variables,
    # such as a trace of what you tested, don't clear them here!
    @visited_forms, @visited_urls, @links_to_visit, @forms_to_visit = nil
  end

  # Adds all <a href=..> links to the list of links to be spidered.
  # Adds all <link href=..> references to the list of pages to be spidered.
  # If it finds an Ajax.Updater url, it'll call that too.
  # Potentially there are other ajax links here to follow (TODO!)
  #
  # Will automatically ignore the following: 
  # * external links (starting with http://). This means, if you call foo_url in your app it will be ignored.
  # * mailto: links
  # * hex-encoded links (&#109;&#97;) generally encoded email addresses
  # * empty or purely anchor links (<a href="#foo"></a>)
  # * links where there is an ajax action, e.g. <a href="/foo/bar" onclick="new Ajax.Updater(...)">
  #   only the ajax action will be followed in that case.  This behavior probably should be changed
  #
  def queue_link( tag, source )
    dest = if (tag.attributes['onclick'] =~ /^new Ajax.Updater\(['"].*?['"], ['"](.*?)['"]/i)
             $1
           elsif tag.attributes['href']
             tag.attributes['href']
           elsif tag.attributes['src']
             tag.attributes['src']
           end

    return if dest.nil?
    return if dest =~ /txmt:\/\//
    dest.gsub!(/([?]\d+)$/, '') # fix asset caching
    # TODO Ignore only URLs outside of @config['domain']
    unless dest =~ %r{^(http://|mailto:|#|&#)} 
      dest = dest.split('#')[0] if dest.index("#") # don't want page anchors
      @links_to_visit << Caboose::SpiderIntegrator::Link.new( dest, source ) if dest.any? # could be empty, make sure there's no empty links queueing
    end
  end

  # Parse the variables and elements from a form, including inputs and textareas,
  # and fill them with crap.
  def queue_form( form, source )
    form.action ||= source
    form.mutate_inputs!(false)
    
    @forms_to_visit << Caboose::SpiderIntegrator::Form.new( form.method, form.action, form.query_hash, source )
    # @forms_to_visit << Caboose::SpiderIntegrator::Form.new( form_method, form_action, mutate_inputs(form, true), source )
  end

  Caboose::SpiderIntegrator::Link = Struct.new( :uri, :source )
  Caboose::SpiderIntegrator::Form = Struct.new( :method, :action, :query, :source )
end 
