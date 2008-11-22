namespace :merb_static do

  desc "Compile static version of a website"
  task :build => :merb_env do
    Merb::Static::Archiver.build
  end

  desc "Delete output directory"
  task :clean do
    rm_rf Merb.root / "output"
  end

  desc "Sync generated files to remote server"
  task :sync => :build do
    Merb::Static::Archiver.sync
  end

end
