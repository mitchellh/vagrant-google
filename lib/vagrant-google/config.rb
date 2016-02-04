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
    class Config < Vagrant.plugin("2", :config)
      # The Service Account Client ID Email address
      #
      # @return [String]
      attr_accessor :google_client_email

      # The path to the Service Account private key
      #
      # @return [String]
      attr_accessor :google_key_location

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

      # Tags to apply to the instance
      #
      # @return [Array]
      attr_accessor :tags

      # whether to use private IP for SSH
      #
      # @return Boolean
      attr_accessor :use_private_ip

      # whether to enable ip forwarding
      #
      # @return Boolean
      attr_accessor :can_ip_forward

      # The external IP Address to use
      #
      # @return String
      attr_accessor :external_ip

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

      # The zone to launch the instance into. If nil, it will
      # use the default us-central1-f.
      #
      # @return [String]
      attr_accessor :zone

      # The list of access controls for service accounts.
      #
      # @return [Array]
      attr_accessor :service_accounts
      alias_method :scopes, :service_accounts
      alias_method :scopes=, :service_accounts=

      def initialize(zone_specific=false)
        @google_client_email = UNSET_VALUE
        @google_key_location = UNSET_VALUE
        @google_json_key_location = UNSET_VALUE
        @google_project_id   = UNSET_VALUE
        @image               = UNSET_VALUE
        @machine_type        = UNSET_VALUE
        @disk_size           = UNSET_VALUE
        @disk_name           = UNSET_VALUE
        @disk_type           = UNSET_VALUE
        @metadata            = {}
        @name                = UNSET_VALUE
        @network             = UNSET_VALUE
        @tags                = []
        @use_private_ip      = UNSET_VALUE
        @can_ip_forward      = UNSET_VALUE
        @external_ip         = UNSET_VALUE
        @autodelete_disk     = UNSET_VALUE
        @preemptible         = UNSET_VALUE
        @auto_restart        = UNSET_VALUE
        @on_host_maintenance = UNSET_VALUE
        @instance_ready_timeout = UNSET_VALUE
        @zone                = UNSET_VALUE
        @service_accounts    = UNSET_VALUE

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
      #       zone.image = "debian-7-wheezy-v20150127"
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
            :@__zone_specific, new_zone_specific || @__zone_specific)

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
          result.metadata.merge!(self.metadata)
          result.metadata.merge!(other.metadata)
        end
      end

      def finalize!
        # Try to get access keys from standard Google environment variables; they
        # will default to nil if the environment variables are not present.
        @google_client_email = ENV['GOOGLE_CLIENT_EMAIL'] if @google_client_email == UNSET_VALUE
        @google_key_location = ENV['GOOGLE_KEY_LOCATION'] if @google_key_location == UNSET_VALUE
        @google_json_key_location = ENV['GOOGLE_JSON_KEY_LOCATION'] if @google_json_key_location == UNSET_VALUE
        @google_project_id = ENV['GOOGLE_PROJECT_ID'] if @google_project_id == UNSET_VALUE

        # Image must be nil, since we can't default that
        @image = "debian-7-wheezy-v20150127" if @image == UNSET_VALUE

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

        # Default zone is us-central1-f.
        @zone = "us-central1-f" if @zone == UNSET_VALUE

        # autodelete_disk defaults to true
        @autodelete_disk = true if @autodelete_disk == UNSET_VALUE

        # use_private_ip defaults to false
        @use_private_ip = false if @use_private_ip == UNSET_VALUE

        # can_ip_forward defaults to nil
        @can_ip_forward = nil if @can_ip_forward == UNSET_VALUE

        # external_ip defaults to nil
        @external_ip = nil if @external_ip == UNSET_VALUE

        # preemptible defaults to false
        @preemptible = false if @preemptible == UNSET_VALUE

        # auto_restart defaults to true
        @auto_restart = true if @auto_restart == UNSET_VALUE

        # on_host_maintenance defaults to MIGRATE
        @on_host_maintenance = "MIGRATE" if @on_host_maintenance == UNSET_VALUE

        # Default instance_ready_timeout
        @instance_ready_timeout = 20 if @instance_ready_timeout == UNSET_VALUE

        # Default service_accounts
        @service_accounts = nil if @service_accounts == UNSET_VALUE

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

          errors << I18n.t("vagrant_google.config.google_project_id_required") if \
            config.google_project_id.nil?
          errors << I18n.t("vagrant_google.config.google_client_email_required") if \
            config.google_client_email.nil?
          errors << I18n.t("vagrant_google.config.google_duplicate_key_location") if \
            !config.google_key_location.nil? and !config.google_json_key_location.nil?
          errors << I18n.t("vagrant_google.config.google_key_location_required") if \
            config.google_key_location.nil? and config.google_json_key_location.nil?
          errors << I18n.t("vagrant_google.config.private_key_missing") unless \
            File.exist?(config.google_key_location.to_s) or \
            File.exist?(config.google_json_key_location.to_s)

          if config.preemptible
            errors << I18n.t("vagrant_google.config.auto_restart_invalid_on_preemptible") if \
             config.auto_restart
            errors << I18n.t("vagrant_google.config.on_host_maintenance_invalid_on_preemptible") unless \
             config.on_host_maintenance == "TERMINATE"
          end
        end

        errors << I18n.t("vagrant_google.config.image_required") if config.image.nil?
        errors << I18n.t("vagrant_google.config.name_required") if @name.nil?

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
