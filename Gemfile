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

source "https://rubygems.org"

gemspec

# This is a restriction to avoid an error "undefined method 'last_comment'" which is deprecated
# https://github.com/ruby/rake/issues/116
# Remove it after update rspec-core-2.99.2 to version greater than 3.4.4
gem 'rake', '< 11' 

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem 'vagrant', git: "https://github.com/mitchellh/vagrant.git"
  gem 'vagrant-spec', git: "https://github.com/mitchellh/vagrant-spec.git"
end

group :plugins do
  gem "vagrant-google" , path: "."
end
