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
require "vagrant"
require "securerandom"

module VagrantPlugins
  module Google
    class Config < Vagrant.plugin("2", :config) # rubocop:disable Metrics/ClassLength
      # The path to the Service Account json-formatted private key
      #
      # @return [String]
      attr_accessor :google_json_key_location

      # The Google Cloud Project ID (not name or number)
      #
      # @return [String]
      attr_accessor :google_project_id

      # The image name of the instance to use.
      #
      # @return [String]
      attr_accessor :image

      # The image family of the instance to use.
      #
      # @return [String]
      attr_accessor :image_family

      # The name of the image_project_id
      #
      # @return [String]
      attr_accessor :image_project_id

      # The instance group name to put the instance in.
      #
      # @return [String]
      attr_accessor :instance_group

      # The type of machine to launch, such as "n1-standard-1"
      #
      # @return [String]
      attr_accessor :machine_type

      # The size of disk in GB
      #
      # @return [Int]
      attr_accessor :disk_size

      # The name of the disk to be used, it it exists, it will be reused, otherwise created.
      #
      # @return [String]
      attr_accessor :disk_name

      # The type of the disk to be used, such as "pd-standard"
      #
      # @return [String]
      attr_accessor :disk_type

      # The user metadata string
      #
      # @return [Hash<String, String>]
      attr_accessor :metadata

      # The name of the instance
      #
      # @return [String]
      attr_accessor :name

      # The name of the network
      #
      # @return [String]
      attr_accessor :network

      # The name of the network_project_id
      #
      # @return [String]
      attr_accessor :network_project_id

      # The name of the subnetwork
      #
      # @return [String]
      attr_accessor :subnetwork

      # Tags to apply to the instance
      #
      # @return [Array]
      attr_accessor :tags

      # Labels to apply to the instance
      #
      # @return [Hash<String, String>]
      attr_accessor :labels

      # whether to enable ip forwarding
      #
      # @return Boolean
      attr_accessor :can_ip_forward

      # The external IP Address to use
      #
      # @return String
      attr_accessor :external_ip

      # The network IP Address to use
      #
      # @return String
      attr_accessor :network_ip

      # Use private ip address
      #
      # @return Boolean
      attr_accessor :use_private_ip

      # whether to autodelete disk on instance delete
      #
      # @return Boolean
      attr_accessor :autodelete_disk

      # Availability policy
      # whether to run instance as preemptible
      #
      # @return Boolean
      attr_accessor :preemptible

      # Availability policy
      # whether to have instance restart on failures
      #
      # @return Boolean
      attr_accessor :auto_restart

      # Availability policy
      # specify what to do when infrastructure maintenance events occur
      # Options: MIGRATE, TERMINATE
      # The default is MIGRATE.
      #
      # @return String
      attr_accessor :on_host_maintenance

      # The timeout value waiting for instance ready
      #
      # @return [Int]
      attr_accessor :instance_ready_timeout

      # The zone to launch the instance into.
      # If nil and the "default" network is set use the default us-central1-f.
      #
      # @return [String]
      attr_accessor :zone

      # The list of access scopes for instance.
      #
      # @return [Array]
      attr_accessor :scopes

      # Deprecated: the list of access scopes for instance.
      #
      # @return [Array]
      attr_accessor :service_accounts

      # IAM service account for instance.
      #
      # @return [String]
      attr_accessor :service_account

      # The configuration for additional disks.
      #
      # @return [Array<Hash>]
      attr_accessor :additional_disks

      # (Optional - Override default WinRM setup before for Public Windows images)
      #
      # @return [Boolean]
      attr_accessor :setup_winrm_password

      # Accelerators
      #
      # @return [Array<Hash>]
      attr_accessor :accelerators

      # whether the instance has Secure Boot enabled
      #
      # @return Boolean
      attr_accessor :enable_secure_boot

      # whether the instance has the vTPM enabled
      #
      # @return Boolean
      attr_accessor :enable_vtpm

      # whether the instance has integrity monitoring enabled
      #
      # @return Boolean
      attr_accessor :enable_integrity_monitoring

      def initialize(zone_specific=false)
        @google_json_key_location    = UNSET_VALUE
        @google_project_id           = UNSET_VALUE
        @image                       = UNSET_VALUE
        @image_family                = UNSET_VALUE
        @image_project_id            = UNSET_VALUE
        @instance_group              = UNSET_VALUE
        @machine_type                = UNSET_VALUE
        @disk_size                   = UNSET_VALUE
        @disk_name                   = UNSET_VALUE
        @disk_type                   = UNSET_VALUE
        @metadata                    = {}
        @name                        = UNSET_VALUE
        @network                     = UNSET_VALUE
        @network_project_id          = UNSET_VALUE
        @subnetwork                  = UNSET_VALUE
        @tags                        = []
        @labels                      = {}
        @can_ip_forward              = UNSET_VALUE
        @external_ip                 = UNSET_VALUE
        @network_ip                  = UNSET_VALUE
        @use_private_ip              = UNSET_VALUE
        @autodelete_disk             = UNSET_VALUE
        @preemptible                 = UNSET_VALUE
        @auto_restart                = UNSET_VALUE
        @on_host_maintenance         = UNSET_VALUE
        @instance_ready_timeout      = UNSET_VALUE
        @zone                        = UNSET_VALUE
        @scopes                      = UNSET_VALUE
        @service_accounts            = UNSET_VALUE
        @service_account             = UNSET_VALUE
        @additional_disks            = []
        @setup_winrm_password        = UNSET_VALUE
        @accelerators                = []
        @enable_secure_boot          = UNSET_VALUE
        @enable_vtpm                 = UNSET_VALUE
        @enable_integrity_monitoring = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_zone_configs = {}
        @__finalized = false
        @__zone_config = {}
        @__zone_specific = zone_specific
      end

      # Allows zone-specific overrides of any of the settings on this
      # configuration object. This allows the user to override things like
      # image and machine type name for zones. Example:
      #
      #     google.zone_config "us-central1-f" do |zone|
      #       zone.image = "ubuntu-1604-xenial-v20180306"
      #       zone.machine_type = "n1-standard-4"
      #     end
      #
      # @param [String] zone The zone name to configure.
      # @param [Hash] attributes Direct attributes to set on the configuration
      #   as a shortcut instead of specifying a full block.
      # @yield [config] Yields a new Google configuration.
      def zone_config(zone, attributes=nil, &block)
        # Append the block to the list of zone configs for that zone.
        # We'll evaluate these upon finalization.
        @__zone_config[zone] ||= []

        # Append a block that sets attributes if we got one
        if attributes
          attr_block = lambda do |config|
            config.set_options(attributes)
          end

          @__zone_config[zone] << attr_block
        end

        # Append a block if we got one
        @__zone_config[zone] << block if block_given?
      end

      #-------------------------------------------------------------------
      # Internal methods.
      #-------------------------------------------------------------------

      def merge(other)
        super.tap do |result|
          # Copy over the zone specific flag. "True" is retained if either
          # has it.
          new_zone_specific = other.instance_variable_get(:@__zone_specific)
          result.instance_variable_set(
            :@__zone_specific, new_zone_specific || @__zone_specific
          )

          # Go through all the zone configs and prepend ours onto
          # theirs.
          new_zone_config = other.instance_variable_get(:@__zone_config)
          @__zone_config.each do |key, value|
            new_zone_config[key] ||= []
            new_zone_config[key] = value + new_zone_config[key]
          end

          # Set it
          result.instance_variable_set(:@__zone_config, new_zone_config)

          # Merge in the metadata
          result.metadata = self.metadata.merge(other.metadata)

          # Merge in the labels
          result.labels = self.labels.merge(other.labels)

          # Merge in the tags
          result.tags |= self.tags
          result.tags |= other.tags

          # Merge in the additional disks
          result.additional_disks |= self.additional_disks
          result.additional_disks |= other.additional_disks
        end
      end

      def finalize! # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        # Try to get access keys from standard Google environment variables; they
        # will default to nil if the environment variables are not present.
        @google_json_key_location = ENV['GOOGLE_JSON_KEY_LOCATION'] if @google_json_key_location == UNSET_VALUE
        @google_project_id = ENV['GOOGLE_PROJECT_ID'] if @google_project_id == UNSET_VALUE

        # Default image is nil
        @image = nil if @image == UNSET_VALUE

        # Default image family is nil
        @image_family = nil if @image_family == UNSET_VALUE

        # Default image project is nil
        @image_project_id = nil if @image_project_id == UNSET_VALUE

        # Default instance group name is nil
        @instance_group = nil if @instance_group == UNSET_VALUE

        # Default instance type is an n1-standard-1
        @machine_type = "n1-standard-1" if @machine_type == UNSET_VALUE

        # Default disk size is 10 GB
        @disk_size = 10 if @disk_size == UNSET_VALUE

        # Default disk name is nil
        @disk_name = nil if @disk_name == UNSET_VALUE

        # Default disk type is pd-standard
        @disk_type = "pd-standard" if @disk_type == UNSET_VALUE

        # Instance name defaults to a new datetime value + random seed
        # e.g. i-2015081013-15637fdb
        if @name == UNSET_VALUE
          t = Time.now
          @name = "i-#{t.strftime("%Y%m%d%H")}-" + SecureRandom.hex(4)
        end

        # Network defaults to 'default'
        @network = "default" if @network == UNSET_VALUE

        # Network project id defaults to project_id
        @network_project_id = @google_project_id if @network_project_id == UNSET_VALUE

        # Subnetwork defaults to nil
        @subnetwork = nil if @subnetwork == UNSET_VALUE

        # Default zone is us-central1-f if using the default network
        if @zone == UNSET_VALUE
          @zone = nil
          if @network == "default"
            @zone = "us-central1-f"
          end
        end

        # autodelete_disk defaults to true
        @autodelete_disk = true if @autodelete_disk == UNSET_VALUE

        # can_ip_forward defaults to nil
        @can_ip_forward = nil if @can_ip_forward == UNSET_VALUE

        # external_ip defaults to nil
        @external_ip = nil if @external_ip == UNSET_VALUE

        # network_ip defaults to nil
        @network_ip = nil if @network_ip == UNSET_VALUE

        # use_private_ip defaults to false
        @use_private_ip = false if @use_private_ip == UNSET_VALUE

        # preemptible defaults to false
        @preemptible = false if @preemptible == UNSET_VALUE

        # auto_restart defaults to true
        @auto_restart = true if @auto_restart == UNSET_VALUE

        # on_host_maintenance defaults to MIGRATE
        @on_host_maintenance = "MIGRATE" if @on_host_maintenance == UNSET_VALUE

        # Default instance_ready_timeout
        @instance_ready_timeout = 20 if @instance_ready_timeout == UNSET_VALUE

        # Default access scopes
        @scopes = nil if @scopes == UNSET_VALUE

        # Default access scopes
        @service_accounts = nil if @service_accounts == UNSET_VALUE

        # Default IAM service account
        @service_account = nil if @service_account == UNSET_VALUE

        # Default Setup WinRM Password
        @setup_winrm_password = nil if @setup_winrm_password == UNSET_VALUE

        # Config option service_accounts is deprecated
        if @service_accounts
          @scopes = @service_accounts
        end

        # enable_secure_boot defaults to nil
        @enable_secure_boot = false if @enable_secure_boot == UNSET_VALUE

        # enable_vtpm defaults to nil
        @enable_vtpm = false if @enable_vtpm == UNSET_VALUE

        # enable_integrity_monitoring defaults to nil
        @enable_integrity_monitoring = false if @enable_integrity_monitoring == UNSET_VALUE

        # Compile our zone specific configurations only within
        # NON-zone-SPECIFIC configurations.
        unless @__zone_specific
          @__zone_config.each do |zone, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The zone name of the configuration always equals the
            # zone config name:
            config.zone = zone

            # Finalize the configuration
            config.finalize!

            # Store it for retrieval
            @__compiled_zone_configs[zone] = config
          end
        end

        # Mark that we finalized
        @__finalized = true
      end

      def validate(machine)
        errors = _detected_errors

        errors << I18n.t("vagrant_google.config.zone_required") if @zone.nil?

        if @zone
          config = get_zone_config(@zone)

          # TODO: Check why provider-level settings are validated in the zone config
          errors << I18n.t("vagrant_google.config.google_project_id_required") if \
            config.google_project_id.nil?

          if config.google_json_key_location
            errors << I18n.t("vagrant_google.config.private_key_missing") unless \
              File.exist?(File.expand_path(config.google_json_key_location.to_s)) or
              File.exist?(File.expand_path(config.google_json_key_location.to_s, machine.env.root_path))
          end

          if config.preemptible
            errors << I18n.t("vagrant_google.config.auto_restart_invalid_on_preemptible") if \
             config.auto_restart
            errors << I18n.t("vagrant_google.config.on_host_maintenance_invalid_on_preemptible") unless \
             config.on_host_maintenance == "TERMINATE"
          end

          if config.image_family
            errors << I18n.t("vagrant_google.config.image_and_image_family_set") if \
             config.image
          end

          errors << I18n.t("vagrant_google.config.image_required") if config.image.nil? && config.image_family.nil?
          errors << I18n.t("vagrant_google.config.name_required") if @name.nil?

          if !config.accelerators.empty?
            errors << I18n.t("vagrant_google.config.on_host_maintenance_invalid_with_accelerators") unless \
              config.on_host_maintenance == "TERMINATE"
          end
        end

        if @service_accounts
          machine.env.ui.warn(I18n.t("vagrant_google.config.service_accounts_deprecaated"))
        end

        { "Google Provider" => errors }
      end

      # This gets the configuration for a specific zone. It shouldn't
      # be called by the general public and is only used internally.
      def get_zone_config(name)
        unless @__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled zone config
        @__compiled_zone_configs[name] || self
      end
    end
  end
end
