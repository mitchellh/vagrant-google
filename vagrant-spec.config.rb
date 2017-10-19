require_relative "test/acceptance/base"

Vagrant::Spec::Acceptance.configure do |c|
  c.component_paths << File.expand_path("../test/acceptance", __FILE__)
  c.skeleton_paths << File.expand_path("../test/acceptance/skeletons", __FILE__)
  c.assert_retries = 1
  c.provider "google",
             box: File.expand_path("../google-test.box", __FILE__),
             contexts: ["provider-context/google"]
end
