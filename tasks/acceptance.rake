namespace :acceptance do

  desc "shows components that can be tested separately"
  task :components do
    exec("bundle exec vagrant-spec components")
  end

  desc "runs acceptance tests using vagrant-spec"
  task :run do

    puts "NOTE: For acceptance tests to be functional, vagrant private key needs to be added to GCE metadata."

    if !ENV["GOOGLE_JSON_KEY_LOCATION"] && !ENV["GOOGLE_KEY_LOCATION"]
      puts `export | grep GOOGLE`
      abort ("Environment variables GOOGLE_JSON_KEY_LOCATION or GOOGLE_KEY_LOCATION are not set. Aborting.")
    end

    if !ENV["GOOGLE_PROJECT_ID"]
      abort ("Environment variable GOOGLE_PROJECT_ID is not set. Aborting.")
    end

    if !ENV["GOOGLE_CLIENT_EMAIL"]
      abort ("Environment variable GOOGLE_CLIENT_EMAIL is not set. Aborting.")
    end

    components = %w(
      provisioner/shell
    ).map{ |s| "provider/google/#{s}" }

    command = "bundle exec vagrant-spec test --components=#{components.join(" ")}"
    puts command
    puts
    exec(command)
  end
end
