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
      # This starts a stopped instance.
      class StartInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::start_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          server = env[:google_compute].servers.get(env[:machine].id, env[:machine].provider_config.zone)

          env[:ui].info(I18n.t("vagrant_google.starting"))

          begin
            server.start

            # Wait for the instance to be ready first
            env[:metrics]["instance_ready_time"] = Util::Timer.time do

              tries = env[:machine].provider_config.instance_ready_timeout / 2

              env[:ui].info(I18n.t("vagrant_google.waiting_for_ready"))
              begin
                retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                  # If we're interrupted don't worry about waiting
                  next if env[:interrupted]

                  # Wait for the server to be ready
                  server.wait_for(2) { ready? }
                end
              rescue Fog::Errors::TimeoutError
                # Notify the user
                raise Errors::InstanceReadyTimeout,
                      timeout: env[:machine].provider_config.instance_ready_timeout
              end
            end
          rescue Fog::Compute::Google::Error => e
            raise Errors::FogError, :message => e.message
          end

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

          unless env[:interrupted]
            env[:metrics]["instance_comm_time"] = Util::Timer.time do
              # Wait for Comms to be ready.
              env[:ui].info(I18n.t("vagrant_google.waiting_for_comm"))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end
            end

            @logger.info("Time for Comms ready: #{env[:metrics]["instance_comm_time"]}")

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_google.ready"))
          end

          @app.call(env)
        end
      end
    end
  end
end
