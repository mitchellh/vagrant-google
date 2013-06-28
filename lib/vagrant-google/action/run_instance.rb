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

          # Get the zone we're going to booting up in
          zone = env[:machine].provider_config.zone

          # Get the configs
          zone_config        = env[:machine].provider_config.get_zone_config(zone)
          image              = zone_config.image
          name               = zone_config.name
          machine_type       = zone_config.machine_type
          keypair            = zone_config.keypair_name
          network            = zone_config.network
          metadata           = zone_config.metadata 

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t("vagrant_google.launch_no_keypair"))
          end

          # Launch!
          has_metadata = metadata.empty? ? "No" : "Yes"
          env[:ui].info(I18n.t("vagrant_google.launching_instance"))
          env[:ui].info(" -- Name: #{name}")
          env[:ui].info(" -- Type: #{machine_type}")
          env[:ui].info(" -- Image: #{image}")
          env[:ui].info(" -- Zone: #{zone}") if zone
          env[:ui].info(" -- Keypair: #{keypair}") if keypair
          env[:ui].info(" -- Network: #{network}") if network
          env[:ui].info(" -- User Data: #{has_metadata}")
          begin
            defaults = {
              :name               => name,
              :zone_name          => zone,
              :machine_type       => machine_type,
              :image_name         => image,
              :private_key_path   => File.expand_path("~/.ssh/id_rsa"),
              :public_key_path    => File.expand_path("~/.ssh/id_rsa.pub"),
#              :username           => $(whoami),
            }

            server = env[:google_compute].servers.create(defaults)
            @logger.info("Machine '#{zone}:#{name}' created.")
          rescue Fog::Compute::Google::NotFound => e
            raise
          rescue Fog::Compute::Google::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the name since it is created at this point.
          env[:machine].id = server.name

          # TODO(erjohnso): servers.get() populates instance variables
          # such as 'public_ip_adress' where the above servers.create()
          # only seems to return a partial object (e.g. missing critical
          # instance variables such as 'public_ip_address'
          sleep 2 # w/o this delay, we seem to get env[:interrupted] set
          server = env[:google_compute].servers.get(name, zone)

          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            tries = zone_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t("vagrant_google.waiting_for_ready"))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                sleep 2
                next if env[:interrupted]
                break if env[:machine].communicate.ready?
              end
            end

            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_google.ready"))
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
