module Merb
  module Static

    ##
    # TODO Refactor
    # * Try with fresh destination. Are the directories created as needed?
    # * It may be better to sync a separate directory, then symlink it to the live directory.

    module SimpleRsync

      def self.sync(options={})
        require 'net/ssh'
        require 'net/sftp'

        file_perm = 0644

        local_path  = Merb.root / "output"
        remote_path = options[:path]

        extra_net_ssh_options              = {}
        extra_net_ssh_options[:password]   = options[:password]   if options[:password]
        extra_net_ssh_options[:passphrase] = options[:passphrase] if options[:passphrase]

        puts "Connecting to #{options[:domain]}"
        Net::SSH.start(options[:domain], options[:username], extra_net_ssh_options) do |ssh|
          ssh.sftp.connect do |sftp|
            puts 'Checking for files which need updating'

            puts "Making initial remote directory: #{remote_path}"
            puts ssh.exec!("mkdir -p #{remote_path}")

            filenames_with_assets_first = Dir[local_path + '/**/*'].sort { |a,b|
              a_is_asset = (a =~ /\.(jpg|png|css|js|gif)$/)
              b_is_asset = (b =~ /\.(jpg|png|css|js|gif)$/)
              if (a_is_asset && b_is_asset)
                0
              elsif (a_is_asset)
                -1
              else
                1
              end
            }

            filenames_with_assets_first.each do |file|
              remote_file = remote_path + file.sub(/^#{local_path}/, '')

              if File.stat(file).directory?
                begin
                  sftp.stat!(remote_file)
                rescue Net::SFTP::StatusException => e
                  raise unless e.code == 2
                  puts "Making remote directory: #{remote_file}"
                  puts ssh.exec!("mkdir -p #{remote_file}")
                end
                next
              end

              begin
                rstat = sftp.stat!(remote_file)
              rescue Net::SFTP::StatusException => e
                raise unless e.code == 2
                puts "Uploading: #{file}"
                sftp.upload!(file, remote_file)
                sftp.setstat(remote_file, :permissions => file_perm)
                next
              end

              if File.stat(file).mtime > Time.at(rstat.mtime)
                puts "Copying #{file} to #{remote_file}"
                sftp.upload!(file, remote_file)
              end
            end
          end

          puts 'Disconnecting from remote server'
        end

        puts 'File transfer complete'
      end

    end
  end
end
