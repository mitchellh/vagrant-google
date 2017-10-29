# Copyright 2015 Google Inc. All Rights Reserved.
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
require 'log4r'
require 'vagrant/util/retryable'
require 'vagrant-google/util/timer'

module VagrantPlugins
  module Google
    module Action
      # This stops the running instance.
      class StopInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::stop_instance")
        end

        def call(env)
          server = env[:google_compute].servers.get(env[:machine].id, env[:machine].provider_config.zone)

          if env[:machine].state.id == :TERMINATED
            env[:ui].info(I18n.t("vagrant_google.already_status", :status => env[:machine].state.id))
          else
            env[:ui].info(I18n.t("vagrant_google.stopping"))
            operation = server.stop
            operation.wait_for { ready? }
          end

          @app.call(env)
        end
      end
    end
  end
end
