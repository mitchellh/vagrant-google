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
          disk_size          = zone_config.disk_size
          disk_name          = zone_config.disk_name
          disk_type          = zone_config.disk_type
          network            = zone_config.network
          metadata           = zone_config.metadata
          tags               = zone_config.tags
          can_ip_forward     = zone_config.can_ip_forward
          external_ip        = zone_config.external_ip
          autodelete_disk    = zone_config.autodelete_disk

          # Launch!
          env[:ui].info(I18n.t("vagrant_google.launching_instance"))
          env[:ui].info(" -- Name:            #{name}")
          env[:ui].info(" -- Type:            #{machine_type}")
          env[:ui].info(" -- Disk size:       #{disk_size} GB")
          env[:ui].info(" -- Disk name:       #{disk_name}")
          env[:ui].info(" -- Image:           #{image}")
          env[:ui].info(" -- Zone:            #{zone}") if zone
          env[:ui].info(" -- Network:         #{network}") if network
          env[:ui].info(" -- Metadata:        '#{metadata}'")
          env[:ui].info(" -- Tags:            '#{tags}'")
          env[:ui].info(" -- IP Forward:      #{can_ip_forward}")
          env[:ui].info(" -- External IP:     #{external_ip}")
          env[:ui].info(" -- Autodelete Disk: #{autodelete_disk}")
          begin
            request_start_time = Time.now().to_i
            # TODO: check if external IP is available
            if !external_ip.nil?
              address = env[:google_compute].addresses.get_by_ip_address(external_ip)
              if !address.nil?
                if address.in_use?
                  env[:ui].error("Specified external_ip is already in use, cannot be used!")
                  raise Errors::VagrantGoogleError, "Specified external_ip is already in use, cannot be used!"
                end
              end
            end
            #Check if disk type is available in the zone
            if !disk_type.nil?
              disk_type_obj = env[:google_compute].list_disk_types(zone).body['items'].select { |dt| dt['name'] == disk_type } || []
              if !disk_type_obj.empty?
                disk_type = disk_type_obj[0]["selfLink"]
              else
                env[:ui].error("Specified disk type: #{disk_type} is not available in the region selected!")
                raise Errors::VagrantGoogleError, "Specified disk type is not available and cannot be used!"
              end
            end

            if disk_name.nil?
              # no disk_name... disk_name defaults to instance name
              disk = env[:google_compute].disks.create(
                  name: name,
                  size_gb: disk_size,
                  type: disk_type,
                  zone_name: zone,
                  source_image: image
              )
              disk.wait_for { disk.ready? }
            else
              disk = env[:google_compute].disks.get(disk_name, zone)
              if disk.nil?
                # disk not found... create it with name
                disk = env[:google_compute].disks.create(
                    name: disk_name,
                    size_gb: disk_size,
                    type: disk_type,
                    zone_name: zone,
                    source_image: image
                )
                disk.wait_for { disk.ready? }
              end
            end

            defaults = {
              :name               => name,
              :zone_name          => zone,
              :machine_type       => machine_type,
              :disk_size          => disk_size,
              :disk_type          => disk_type,
              :image              => image,
              :network            => network,
              :metadata           => metadata,
              :tags               => tags,
              :can_ip_forward     => can_ip_forward,
              :external_ip        => external_ip,
              :disks              => [disk.get_as_boot_disk(true, autodelete_disk)],
            }
            server = env[:google_compute].servers.create(defaults)
            @logger.info("Machine '#{zone}:#{name}' created.")
          rescue Fog::Compute::Google::NotFound => e
            raise
          rescue Fog::Compute::Google::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the name since the instance has been created
          env[:machine].id = server.name
          server.reload

          env[:ui].info(I18n.t("vagrant_google.waiting_for_ready"))
          begin
            server.wait_for { ready? }
            env[:metrics]["instance_ready_time"] = Time.now().to_i - request_start_time
            @logger.info("Time for instance ready: #{env[:metrics]["instance_ready_time"]}")
            env[:ui].info(I18n.t("vagrant_google.ready"))
          rescue
            env[:interrupted] = true
          end

          if !env[:terminated]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_google.waiting_for_ssh"))
              while true
                # If we're interrupted just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end
            end
            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")
            env[:ui].info(I18n.t("vagrant_google.ready_ssh"))
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
