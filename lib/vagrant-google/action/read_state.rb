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
require "log4r"

module VagrantPlugins
  module Google
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::read_state")
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:google_compute], env[:machine])

          @app.call(env)
        end

        def read_state(google, machine)
          return :not_created if machine.name.nil?

          # Find the machine
          zone = machine.provider_config.zone
          server = google.servers.get(machine.name, zone)
          if server.nil? || [:"shutting-down", :terminated].include?(server.state.to_sym)
            # The machine can't be found
            @logger.info("Machine '#{zone}:#{machine.name}' not found or terminated, assuming it got destroyed.")
            machine.id = nil
            return :not_created
          end

          # Return the state
          return server.state.to_sym
        end
      end
    end
  end
end
