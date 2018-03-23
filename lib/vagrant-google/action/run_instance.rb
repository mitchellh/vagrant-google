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
      class RunInstance # rubocop:disable Metrics/ClassLength
        include Vagrant::Util::Retryable

        FOG_ERRORS = [
          Fog::Compute::Google::NotFound,
          Fog::Compute::Google::Error,
          Fog::Errors::Error
        ].freeze

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::run_instance")
        end

        def call(env) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          # Initialize metrics if they haven't been
          env[:metrics] ||= {}

          # Get the zone we're going to booting up in
          zone = env[:machine].provider_config.zone

          # Get the configs
          zone_config         = env[:machine].provider_config.get_zone_config(zone)
          image               = zone_config.image
          image_family        = zone_config.image_family
          instance_group      = zone_config.instance_group
          name                = zone_config.name
          machine_type        = zone_config.machine_type
          disk_size           = zone_config.disk_size
          disk_name           = zone_config.disk_name
          disk_type           = zone_config.disk_type
          network             = zone_config.network
          subnetwork          = zone_config.subnetwork
          metadata            = zone_config.metadata
          labels              = zone_config.labels
          tags                = zone_config.tags
          can_ip_forward      = zone_config.can_ip_forward
          use_private_ip      = zone_config.use_private_ip
          external_ip         = zone_config.external_ip
          preemptible         = zone_config.preemptible
          auto_restart        = zone_config.auto_restart
          on_host_maintenance = zone_config.on_host_maintenance
          autodelete_disk     = zone_config.autodelete_disk
          service_accounts    = zone_config.service_accounts
          project_id          = zone_config.google_project_id

          # Launch!
          env[:ui].info(I18n.t("vagrant_google.launching_instance"))
          env[:ui].info(" -- Name:            #{name}")
          env[:ui].info(" -- Project:         #{project_id}")
          env[:ui].info(" -- Type:            #{machine_type}")
          env[:ui].info(" -- Disk type:       #{disk_type}")
          env[:ui].info(" -- Disk size:       #{disk_size} GB")
          env[:ui].info(" -- Disk name:       #{disk_name}")
          env[:ui].info(" -- Image:           #{image}")
          env[:ui].info(" -- Image family:    #{image_family}")
          env[:ui].info(" -- Instance Group:  #{instance_group}")
          env[:ui].info(" -- Zone:            #{zone}") if zone
          env[:ui].info(" -- Network:         #{network}") if network
          env[:ui].info(" -- Subnetwork:      #{subnetwork}") if subnetwork
          env[:ui].info(" -- Metadata:        '#{metadata}'")
          env[:ui].info(" -- Labels:          '#{labels}'")
          env[:ui].info(" -- Network tags:    '#{tags}'")
          env[:ui].info(" -- IP Forward:      #{can_ip_forward}")
          env[:ui].info(" -- Use private IP:  #{use_private_ip}")
          env[:ui].info(" -- External IP:     #{external_ip}")
          env[:ui].info(" -- Preemptible:     #{preemptible}")
          env[:ui].info(" -- Auto Restart:    #{auto_restart}")
          env[:ui].info(" -- On Maintenance:  #{on_host_maintenance}")
          env[:ui].info(" -- Autodelete Disk: #{autodelete_disk}")
          env[:ui].info(" -- Scopes:          #{service_accounts}")

          # Munge image configs
          image = env[:google_compute].images.get(image).self_link

          # If image_family is set, get the latest image image from the family.
          unless image_family.nil?
            image = env[:google_compute].images.get_from_family(image_family).self_link
          end

          # Munge network configs
          if network != 'default'
            network = "projects/#{project_id}/global/networks/#{network}"
            subnetwork  = "projects/#{project_id}/regions/#{zone.split('-')[0..1].join('-')}/subnetworks/#{subnetwork}"
          else
            network = "global/networks/default"
          end

          if external_ip == false
            # No external IP
            network_interfaces = [ { :network => network, :subnetwork => subnetwork } ]
          else
            network_interfaces = [ { :network => network, :subnetwork => subnetwork, :access_configs => [{:name => 'External NAT', :type => 'ONE_TO_ONE_NAT'}]} ]
          end

          # Munge scheduling configs
          scheduling = { :automatic_restart => auto_restart, :on_host_maintenance => on_host_maintenance, :preemptible => preemptible}

          # Munge service_accounts / scopes config
          service_accounts = [ { :scopes => service_accounts } ]

          begin
            request_start_time = Time.now.to_i

            # Check if specified external ip is available
            external_ip = get_external_ip(env, external_ip) if external_ip
            # Check if disk type is available in the zone and set the proper resource link
            disk_type = get_disk_type(env, disk_type, zone)

            disk_created_by_vagrant = false
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
              disk_created_by_vagrant = true
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
                disk_created_by_vagrant = true
              end
            end

            defaults = {
              :name                => name,
              :zone                => zone,
              :machine_type        => machine_type,
              :disk_size           => disk_size,
              :disk_type           => disk_type,
              :image               => image,
              :network_interfaces  => network_interfaces,
              :metadata            => { :items => metadata.each.map { |k, v| {:key => k.to_s, :value => v.to_s} } },
              :labels              => labels,
              :tags                => { :items => tags },
              :can_ip_forward      => can_ip_forward,
              :use_private_ip      => use_private_ip,
              :external_ip         => external_ip,
              :disks               => [disk.get_as_boot_disk(true, autodelete_disk)],
              :scheduling          => scheduling,
              :service_accounts    => service_accounts
            }
            server = env[:google_compute].servers.create(defaults)
            @logger.info("Machine '#{zone}:#{name}' created.")
          rescue *FOG_ERRORS => e
            # TODO: Cleanup the Fog catch-all once Fog implements better exceptions
            # There is a chance Google has failed to create an instance, so we need
            # to clean up the created disk.
            cleanup_disk(disk.name, env) if disk && disk_created_by_vagrant
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the name since the instance has been created
          env[:machine].id = server.name
          server.reload

          env[:ui].info(I18n.t("vagrant_google.waiting_for_ready"))
          begin
            server.wait_for { ready? }
            env[:metrics]["instance_ready_time"] = Time.now.to_i - request_start_time
            @logger.info("Time for instance ready: #{env[:metrics]["instance_ready_time"]}")
            env[:ui].info(I18n.t("vagrant_google.ready"))
          rescue
            env[:interrupted] = true
          end

          unless env[:terminated]
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
            env[:ui].info(I18n.t("vagrant_google.ready_ssh")) unless env[:interrupted]
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

        def get_disk_type(env, disk_type, zone)
          begin
            # TODO(temikus): Outsource parsing logic to fog-google
            disk_type = env[:google_compute].get_disk_type(disk_type, zone).self_link
          rescue Fog::Errors::NotFound
            raise Errors::DiskTypeError,
                  :disktype => disk_type
          end
          disk_type
        end

        def get_external_ip(env, external_ip)
          address = env[:google_compute].addresses.get_by_ip_address_or_name(external_ip)
          if address.nil?
            raise Errors::ExternalIpDoesNotExistError,
                  :externalip => external_ip
          end
          if address.in_use?
            raise Errors::ExternalIpInUseError,
                  :externalip => external_ip
          end
          # Resolve the name to IP address
          address.address
        end

        def cleanup_disk(disk_name, env)
          zone = env[:machine].provider_config.zone
          autodelete_disk = env[:machine].provider_config.get_zone_config(zone).autodelete_disk
          if autodelete_disk
            disk = env[:google_compute].disks.get(disk_name, zone)
            disk.destroy(false) if disk
          end
        end
      end
    end
  end
end
