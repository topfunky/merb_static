
namespace :merb_static do

  desc "Compile static version of a website"
  task :build => :merb_env do
    Merb::Static::Archiver.new
  end

  desc "Delete output directory"
  task :clean do
    rm_rf Merb.root / "output"
  end

end
