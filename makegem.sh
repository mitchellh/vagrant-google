#!/bin/sh -x

gem build vagrant-google.gemspec
gem install vagrant-google-0.1.0.gem
vagrant plugin install vagrant-google

