require "rubygems"
require "rspec/its"

# Set vagrant env to avoid "Encoded files can't be read" error.
ENV["VAGRANT_INSTALLER_EMBEDDED_DIR"] = File.expand_path("../../../", __FILE__)

# Require Vagrant itself so we can reference the proper
# classes to test.
require "vagrant"
require "vagrant-google"

# Add the test directory to the load path
$LOAD_PATH.unshift File.expand_path("../../", __FILE__)

# Do not buffer output
$stdout.sync = true
$stderr.sync = true

# Configure RSpec
RSpec.configure do |c|
  c.formatter = :progress
end
