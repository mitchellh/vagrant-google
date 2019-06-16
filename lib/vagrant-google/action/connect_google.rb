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
require "fog/google"
require "log4r"

module VagrantPlugins
  module Google
    module Action
      # This action connects to Google, verifies credentials work, and
      # puts the Google connection object into the `:google_compute` key
      # in the environment.
      class ConnectGoogle
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::connect_google")
        end

        # Initialize Fog::Compute and add it to the environment
        def call(env)
          provider_config = env[:machine].provider_config

          # Build fog config
          fog_config = {
            :provider            => :google,
            :google_project      => provider_config.google_project_id,
          }

          unless provider_config.google_json_key_location.nil?
            fog_config[:google_json_key_location] = find_key(provider_config.google_json_key_location, env)
          end

          @logger.info("Creating Google API client and adding to Vagrant environment")
          env[:google_compute] = Fog::Compute.new(fog_config)
          @app.call(env)
        end

        # If the key is not found, try expanding from root location (see #159)
        def find_key(location, env)
           if File.file?(File.expand_path(location))
             return File.expand_path(location)
           else
             return File.expand_path(location, env[:root_path])
           end
        end
      end
    end
  end
end
