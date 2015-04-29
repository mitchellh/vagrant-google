require_relative "test/acceptance/base"

Vagrant::Spec::Acceptance.configure do |c|
  c.component_paths << File.expand_path("../test/acceptance", __FILE__)
  c.skeleton_paths << File.expand_path("../test/acceptance/skeletons", __FILE__)

  c.provider "google",
    box: "https://github.com/mitchellh/vagrant-google/raw/master/google-test.box",
    contexts: ["provider-context/google"]
end
