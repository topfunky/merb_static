# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{merb_static}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Geoffrey Grosenbach"]
  s.date = %q{2008-11-21}
  s.description = %q{Merb plugin that builds a static site from a dynamic Merb application, like Webby.}
  s.email = %q{boss@topfunky.com}
  s.extra_rdoc_files = ["README", "LICENSE"]
  s.files = ["LICENSE", "README", "Rakefile", "lib/merb_static", "lib/merb_static/archiver.rb", "lib/merb_static/cookie.rb", "lib/merb_static/cookie_jar.rb", "lib/merb_static/merbtasks.rb", "lib/merb_static/simple_rsync.rb", "lib/merb_static.rb", "spec/merb_static_spec.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://topfunky.com/}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{merb_static}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Merb plugin that builds a static site from a dynamic Merb application, like Webby.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<merb>, [">= 1.0"])
    else
      s.add_dependency(%q<merb>, [">= 1.0"])
    end
  else
    s.add_dependency(%q<merb>, [">= 1.0"])
  end
end
