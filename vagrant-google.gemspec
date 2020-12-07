# Copyright 2013 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "vagrant-google/version"

Gem::Specification.new do |s|
  s.name          = "vagrant-google"
  s.version       = VagrantPlugins::Google::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Eric Johnson", "Artem Yakimenko"]
  s.email         = "vagrant-google@google.com"
  s.homepage      = "http://www.vagrantup.com"
  s.summary       = "Vagrant provider plugin for Google Compute Engine."
  s.description   = "Enables Vagrant to manage Google Compute Engine instances."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "vagrant-google"

  s.add_runtime_dependency "fog-google", "~> 1.12.0"

  # This is a restriction to avoid errors on `failure_message_for_should`
  # TODO: revise after vagrant_spec goes past >0.0.1 (at master@e623a56)
  s.add_development_dependency "rspec-legacy_formatters"

  s.add_development_dependency "rake", ">= 13.0.1"
  s.add_development_dependency "rspec", ">= 3.5.0", "<= 3.6"
  s.add_development_dependency "rspec-its", "~> 1.2"
  s.add_development_dependency "rubocop", "~> 0.83"
  s.add_development_dependency "rubocop-performance", "~> 1.5.2"
  s.add_development_dependency "highline"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-byebug"

  # The following block of code determines the files that should be included
  # in the gem. It does this by reading all the files in the directory where
  # this gemspec is, and parsing out the ignored files from the gitignore.
  # Note that the entire gitignore(5) syntax is not supported, specifically
  # the "!" syntax, but it should mostly work correctly.
  root_path      = File.dirname(__FILE__)
  all_files      = Dir.chdir(root_path) { Dir.glob("**/{*,.*}") }
  all_files.reject! { |file| [".", ".."].include?(File.basename(file)) }
  gitignore_path = File.join(root_path, ".gitignore")
  gitignore      = File.readlines(gitignore_path)
  gitignore.map!    { |line| line.chomp.strip }
  gitignore.reject! { |line| line.empty? || line =~ /^(#|!)/ }

  unignored_files = all_files.reject do |file|
    # Ignore any directories, the gemspec only cares about files
    next true if File.directory?(file)
    # Ignore any paths that match anything in the gitignore. We do
    # two tests here:
    #
    #   - First, test to see if the entire path matches the gitignore.
    #   - Second, match if the basename does, this makes it so that things
    #     like '.DS_Store' will match sub-directories too (same behavior
    #     as git).
    #
    gitignore.any? do |ignore|
      File.fnmatch(ignore, file, File::FNM_PATHNAME) ||
        File.fnmatch(ignore, File.basename(file), File::FNM_PATHNAME)
    end
  end

  s.files         = unignored_files
  s.executables   = unignored_files.map { |f| f[/^bin\/(.*)/, 1] }.compact
  s.require_path  = 'lib'
end
