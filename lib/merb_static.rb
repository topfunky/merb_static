# make sure we're running inside Merb
if defined?(Merb::Plugins)

  $LOAD_PATH << File.dirname(__FILE__)
  require 'hpricot'
  require 'caboose'
  require 'caboose/spider_integrator'
  %w(cookie cookie_jar simple_rsync archiver).each do |filename|
    require "merb_static/#{filename}"
  end
  
  # Merb gives you a Merb::Plugins.config hash...feel free to put your stuff in your piece of it
  Merb::Plugins.config[:merb_static] = {
    :urls   => ["/"],
    :domain => 'localhost',
    :remote => {
      :domain     => "localhost",
      :username   => "root",
      :passphrase => "",
      :path       => "/tmp"
    }
  }

  Merb::BootLoader.before_app_loads do
    # require code that must be loaded before the application
  end

  Merb::BootLoader.after_app_loads do
    # code that can be required after the application loads
  end

  Merb::Plugins.add_rakefiles "merb_static/merbtasks"
end
