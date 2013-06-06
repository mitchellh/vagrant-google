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

require 'vagrant-gce/util/timer'

module VagrantPlugins
  module GCE
    module Action
      # This runs the configured instance.
      class RunInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_gce::action::run_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get the region we're going to booting up in
          region = env[:machine].provider_config.region

          # Get the configs
          region_config      = env[:machine].provider_config.get_region_config(region)
          image              = region_config.image
          zone               = region_config.zone
          machine_type       = region_config.machine_type
          keypair            = region_config.keypair_name
          private_ip_address = region_config.private_ip_address
          security_groups    = region_config.security_groups
          subnet_id          = region_config.subnet_id
          tags               = region_config.tags
          metadata           = region_config.metadata 

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t("vagrant_gce.launch_no_keypair"))
          end

          # If there is a subnet ID then warn the user
          if subnet_id
            env[:ui].warn(I18n.t("vagrant_gce.launch_vpc_warning"))
          end

          # Launch!
          env[:ui].info(I18n.t("vagrant_gce.launching_instance"))
          env[:ui].info(" -- Type: #{machine_type}")
          env[:ui].info(" -- Image: #{image}")
          env[:ui].info(" -- Region: #{region}")
          env[:ui].info(" -- Zone: #{zone}") if zone
          env[:ui].info(" -- Keypair: #{keypair}") if keypair
          env[:ui].info(" -- Subnet ID: #{subnet_id}") if subnet_id
          env[:ui].info(" -- Private IP: #{private_ip_address}") if private_ip_address
          env[:ui].info(" -- User Data: yes") if metadata 
          env[:ui].info(" -- Security Groups: #{security_groups.inspect}") if !security_groups.empty?
          env[:ui].info(" -- User Data: #{metadata }") if metadata 

          begin
            options = {
              :zone               => zone,
              :flavor_id          => machine_type,
              :image_id           => image,
              :key_name           => keypair,
              :private_ip_address => private_ip_address,
              :subnet_id          => subnet_id,
              :tags               => tags,
              :metadata           => metadata 
            }

            if !security_groups.empty?
              security_group_key = options[:subnet_id].nil? ? :groups : :security_group_ids
              options[security_group_key] = security_groups
            end

            server = env[:gce_compute].servers.create(options)
          rescue Fog::Compute::GCE::NotFound => e
            # Invalid subnet doesn't have its own error so we catch and
            # check the error message here.
            if e.message =~ /subnet ID/
              raise Errors::FogError,
                :message => "Subnet ID not found: #{subnet_id}"
            end

            raise
          rescue Fog::Compute::GCE::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id = server.id

          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            tries = region_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t("vagrant_gce.waiting_for_ready"))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                next if env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2) { ready? }
              end
            rescue Fog::Errors::TimeoutError
              # Delete the instance
              terminate(env)

              # Notify the user
              raise Errors::InstanceReadyTimeout,
                timeout: region_config.instance_ready_timeout
            end
          end

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

          if !env[:interrupted]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_gce.waiting_for_ssh"))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end
            end

            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_gce.ready"))
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
