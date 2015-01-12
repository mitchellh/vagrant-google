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

$:.unshift File.expand_path("../lib", __FILE__)
require "vagrant-google/version"

Gem::Specification.new do |s|
  s.name          = "vagrant-google"
  s.version       = VagrantPlugins::Google::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = "Eric Johnson"
  s.email         = "erjohnso@google.com"
  s.homepage      = "http://www.vagrantup.com"
  s.summary       = "Vagrant provider plugin for Google Compute Engine."
  s.description   = "Enables Vagrant to manage Google Compute Engine instances."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "vagrant-google"

  s.add_runtime_dependency "fog", "1.22"
  s.add_runtime_dependency "google-api-client"
  #s.add_runtime_dependency "pry"
  #s.add_runtime_dependency "pry-nav"
  #s.add_runtime_dependency "rb-readline"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec-core", "~> 2.12.2"
  s.add_development_dependency "rspec-expectations", "~> 2.12.1"
  s.add_development_dependency "rspec-mocks", "~> 2.12.1"

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
