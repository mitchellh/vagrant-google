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
      # This terminates the running instance.
      class TerminateInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::terminate_instance")
        end

        def call(env)
          server = env[:google_compute].servers.get(env[:machine].id, env[:machine].provider_config.zone)

          # Destroy the server and remove the tracking ID
          env[:ui].info(I18n.t("vagrant_google.terminating"))
          server.destroy if not server.nil?
          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
