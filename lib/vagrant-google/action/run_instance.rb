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
require 'vagrant/util/retryable'
require 'vagrant-google/util/timer'

module VagrantPlugins
  module Google
    module Action
      # This runs the configured instance.
      class RunInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::run_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          ssh_info = env[:machine].ssh_info

          # Get the zone we're going to booting up in
          zone = env[:machine].provider_config.zone

          # Get the configs
          zone_config        = env[:machine].provider_config.get_zone_config(zone)
          image              = zone_config.image
          name               = zone_config.name
          machine_type       = zone_config.machine_type
          network            = zone_config.network
          metadata           = zone_config.metadata 

          # Launch!
          env[:ui].info(I18n.t("vagrant_google.launching_instance"))
          env[:ui].info(" -- Name: #{name}")
          env[:ui].info(" -- Type: #{machine_type}")
          env[:ui].info(" -- Image: #{image}")
          env[:ui].info(" -- Zone: #{zone}") if zone
          env[:ui].info(" -- Network: #{network}") if network
          env[:ui].info(" -- Metadata: '#{metadata}'")
          begin
            defaults = {
              :name               => name,
              :zone_name          => zone,
              :machine_type       => machine_type,
              :image_name         => image,
              :metadata           => metadata,
            }
            if !ssh_info.nil? and ssh_info[:public_key_path]
              defaults[:public_key] = ssh_info[:public_key_path]
              defaults[:public_key_path] = ssh_info[:public_key_path]
            else
              defaults[:public_key] = File.expand_path("~/.ssh/id_rsa.pub")
              defaults[:public_key_path] = File.expand_path("~/.ssh/id_rsa.pub")
            end
            if !ssh_info.nil? and ssh_info[:private_key_path]
              defaults[:private_key_path] = ssh_info[:private_key_path]
            else
              defaults[:private_key_path] = File.expand_path("~/.ssh/id_rsa")
            end

            request_start_time = Time.now().to_i
            server = env[:google_compute].servers.create(defaults)
            @logger.info("Machine '#{zone}:#{name}' created.")
          rescue Fog::Compute::Google::NotFound => e
            raise
          rescue Fog::Compute::Google::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the name since the instance has been created
          env[:machine].id = server.name

          env[:ui].info(I18n.t("vagrant_google.waiting_for_ready"))
          begin
            server.wait_for { sshable? }
            #server.wait_for { ready? }
            #sleep 10
            env[:metrics]["instance_ready_time"] = Time.now().to_i - request_start_time
            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")
            env[:ui].info(I18n.t("vagrant_google.ready"))
          rescue
            env[:interrupted] = true
          end

          # Terminate the instance if we were interrupted
          terminate(env) if env[:interrupted]

          @app.call(env)
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
          end
        end

        def terminate(env)
          destroy_env = env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate] = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Action.action_destroy, destroy_env)
        end
      end
    end
  end
end
