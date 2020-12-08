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
require 'vagrant-google/action/setup_winrm_password'

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
          zone_config                 = env[:machine].provider_config.get_zone_config(zone)
          image                       = zone_config.image
          image_family                = zone_config.image_family
          image_project_id            = zone_config.image_project_id
          instance_group              = zone_config.instance_group
          name                        = zone_config.name
          machine_type                = zone_config.machine_type
          disk_size                   = zone_config.disk_size
          disk_name                   = zone_config.disk_name
          disk_type                   = zone_config.disk_type
          network                     = zone_config.network
          network_project_id          = zone_config.network_project_id
          subnetwork                  = zone_config.subnetwork
          metadata                    = zone_config.metadata
          labels                      = zone_config.labels
          tags                        = zone_config.tags
          can_ip_forward              = zone_config.can_ip_forward
          use_private_ip              = zone_config.use_private_ip
          external_ip                 = zone_config.external_ip
          network_ip                  = zone_config.network_ip
          preemptible                 = zone_config.preemptible
          auto_restart                = zone_config.auto_restart
          on_host_maintenance         = zone_config.on_host_maintenance
          autodelete_disk             = zone_config.autodelete_disk
          service_account_scopes      = zone_config.scopes
          service_account             = zone_config.service_account
          project_id                  = zone_config.google_project_id
          additional_disks            = zone_config.additional_disks
          accelerators                = zone_config.accelerators
          enable_secure_boot          = zone_config.enable_secure_boot
          enable_vtpm                 = zone_config.enable_vtpm
          enable_integrity_monitoring = zone_config.enable_integrity_monitoring

          # Launch!
          env[:ui].info(I18n.t("vagrant_google.launching_instance"))
          env[:ui].info(" -- Name:                 #{name}")
          env[:ui].info(" -- Project:              #{project_id}")
          env[:ui].info(" -- Type:                 #{machine_type}")
          env[:ui].info(" -- Disk type:            #{disk_type}")
          env[:ui].info(" -- Disk size:            #{disk_size} GB")
          env[:ui].info(" -- Disk name:            #{disk_name}")
          env[:ui].info(" -- Image:                #{image}")
          env[:ui].info(" -- Image family:         #{image_family}")
          env[:ui].info(" -- Image Project:        #{image_project_id}") if image_project_id
          env[:ui].info(" -- Instance Group:       #{instance_group}")
          env[:ui].info(" -- Zone:                 #{zone}") if zone
          env[:ui].info(" -- Network:              #{network}") if network
          env[:ui].info(" -- Network Project:      #{network_project_id}") if network_project_id
          env[:ui].info(" -- Subnetwork:           #{subnetwork}") if subnetwork
          env[:ui].info(" -- Metadata:             '#{metadata}'")
          env[:ui].info(" -- Labels:               '#{labels}'")
          env[:ui].info(" -- Network tags:         '#{tags}'")
          env[:ui].info(" -- IP Forward:           #{can_ip_forward}")
          env[:ui].info(" -- Use private IP:       #{use_private_ip}")
          env[:ui].info(" -- External IP:          #{external_ip}")
          env[:ui].info(" -- Network IP:           #{network_ip}")
          env[:ui].info(" -- Preemptible:          #{preemptible}")
          env[:ui].info(" -- Auto Restart:         #{auto_restart}")
          env[:ui].info(" -- On Maintenance:       #{on_host_maintenance}")
          env[:ui].info(" -- Autodelete Disk:      #{autodelete_disk}")
          env[:ui].info(" -- Scopes:               #{service_account_scopes}") if service_account_scopes
          env[:ui].info(" -- Service Account:      #{service_account}") if service_account
          env[:ui].info(" -- Additional Disks:     #{additional_disks}")
          env[:ui].info(" -- Accelerators:         #{accelerators}")
          env[:ui].info(" -- Secure Boot:          #{enable_secure_boot}") if enable_secure_boot
          env[:ui].info(" -- vTPM:                 #{enable_vtpm}") if enable_vtpm
          env[:ui].info(" -- Integrity Monitoring: #{enable_integrity_monitoring}") if enable_integrity_monitoring

          # Munge image config
          if image_family
            image = env[:google_compute].images.get_from_family(image_family, image_project_id).self_link
          else
            image = env[:google_compute].images.get(image, image_project_id).self_link
          end

          # Munge network configs
          if network != 'default'
            network = "projects/#{network_project_id}/global/networks/#{network}"
            subnetwork  = "projects/#{network_project_id}/regions/#{zone.split('-')[0..1].join('-')}/subnetworks/#{subnetwork}"
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
          service_accounts = [ { :email => service_account, :scopes => service_account_scopes } ]

          # Construct accelerator URLs
          accelerators_url = []
          accelerators.each do |accelerator|
            unless accelerator.key?(:type)
              next
            end
            accelerator_type = "https://compute.googleapis.com/compute/v1/projects/#{project_id}/zones/#{zone}/acceleratorTypes/#{accelerator[:type]}"
            accelerator_count = accelerator.fetch(:count, 1)
            accelerators_url.push({ :accelerator_type => accelerator_type,
                                    :accelerator_count => accelerator_count })
          end

          # Munge shieldedInstance config
          shielded_instance_config = { :enable_secure_boot => enable_secure_boot, :enable_vtpm => enable_vtpm, :enable_integrity_monitoring => enable_integrity_monitoring }

          begin
            request_start_time = Time.now.to_i
            disk = nil
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

            # Add boot disk to the instance
            disks = [disk.get_as_boot_disk(true, autodelete_disk)]

            # Configure additional disks
            additional_disks.each_with_index do |disk_config, index|
              additional_disk = nil

              # Get additional disk image
              # Create a blank disk if neither image nor additional_disk_image is provided
              additional_disk_image = nil
              if disk_config[:image_family]
                additional_disk_image = env[:google_compute].images.get_from_family(disk_config[:image_family], disk_config[:image_project_id]).self_link
              elsif disk_config[:image]
                additional_disk_image = env[:google_compute].images.get(disk_config[:image], disk_config[:image_project_id]).self_link
              end

              # Get additional disk size
              additional_disk_size = nil
              if disk_config[:disk_size].nil?
                # Default disk size is 10 GB
                additional_disk_size = 10
              else
                additional_disk_size = disk_config[:disk_size]
              end

              # Get additional disk type
              additional_disk_type = nil
              if disk_config[:disk_type].nil?
                # Default disk type is pd-standard
                additional_disk_type = get_disk_type(env, "pd-standard", zone)
              else
                additional_disk_type = get_disk_type(env, disk_config[:disk_type], zone)
              end

              # Get additional disk auto delete
              additional_disk_auto_delete = nil
              if disk_config[:autodelete_disk].nil?
                # Default auto delete to true
                additional_disk_auto_delete = true
              else
                additional_disk_auto_delete = disk_config[:autodelete_disk]
              end

              # Get additional disk name
              additional_disk_name = nil
              if disk_config[:disk_name].nil?
                # no disk_name... disk_name defaults to instance (name + "-additional-disk-#{index}"
                additional_disk_name = name + "-additional-disk-#{index}"
                additional_disk = env[:google_compute].disks.create(
                  name: additional_disk_name,
                  size_gb: additional_disk_size,
                  type: additional_disk_type,
                  zone_name: zone,
                  source_image: additional_disk_image
                )
              else
                # additional_disk_name set in disk_config
                additional_disk_name = disk_config[:disk_name]

                additional_disk = env[:google_compute].disks.get(additional_disk_name, zone)
                if additional_disk.nil?
                  # disk not found... create it with name
                  additional_disk = env[:google_compute].disks.create(
                    name: additional_disk_name,
                    size_gb: additional_disk_size,
                    type: additional_disk_type,
                    zone_name: zone,
                    source_image: additional_disk_image
                  )
                  additional_disk.wait_for { additional_disk.ready? }
                end
              end

              # Add additional disk to the instance
              disks.push(additional_disk.attached_disk_obj(boot:false, writable:true, auto_delete:additional_disk_auto_delete))
            end

            defaults = {
              :name               => name,
              :zone               => zone,
              :machine_type       => machine_type,
              :disk_size          => disk_size,
              :disk_type          => disk_type,
              :image              => image,
              :network_interfaces => network_interfaces,
              :metadata           => { :items => metadata.each.map { |k, v| { :key => k.to_s, :value => v.to_s } } },
              :labels             => labels,
              :tags               => { :items => tags },
              :can_ip_forward     => can_ip_forward,
              :use_private_ip     => use_private_ip,
              :external_ip        => external_ip,
              :network_ip         => network_ip,
              :disks              => disks,
              :scheduling         => scheduling,
              :service_accounts   => service_accounts,
              :guest_accelerators => accelerators_url
            }

            # XXX HACK - only add  of the parameters are set in :shielded_instance_config we need to drop the field from
            # the API call otherwise we'll error out with Google::Apis::ClientError
            # TODO(temikus): Remove if the API changes, see internal GOOG ref: b/175063371
            if shielded_instance_config.has_value?(true)
              defaults[:shielded_instance_config] = shielded_instance_config
            end

            server = env[:google_compute].servers.create(defaults)
            @logger.info("Machine '#{zone}:#{name}' created.")
          rescue *FOG_ERRORS => e
            # TODO: Cleanup the Fog catch-all once Fog implements better exceptions
            # There is a chance Google has failed to create an instance, so we need
            # to clean up the created disk.
            disks.each do |disk|
                cleanup_disk(disk.name, env) if disk && disk_created_by_vagrant
            end
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

          # Parse out the image project in case it was not set
          # and check if it is part of a public windows project
          img_project = image.split("/")[6]
          is_windows_image = img_project.eql?("windows-cloud") || img_project.eql?("windows-sql-cloud")

          # Reset the password if a windows image unless flag overrides
          setup_winrm_password = zone_config.setup_winrm_password
          if setup_winrm_password.nil? && is_windows_image
            setup_winrm_password = true
          end

          if setup_winrm_password
            env[:ui].info("Setting up WinRM Password")
            env[:action_runner].run(Action.action_setup_winrm_password, env)
          end

          unless env[:terminated]
            env[:metrics]["instance_comm_time"] = Util::Timer.time do
              # Wait for Comms to be ready.
              env[:ui].info(I18n.t("vagrant_google.waiting_for_comm"))
              while true
                # If we're interrupted just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end
            end
            @logger.info("Time for Comms ready: #{env[:metrics]["instance_comm_time"]}")
            env[:ui].info(I18n.t("vagrant_google.ready_comm")) unless env[:interrupted]
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
