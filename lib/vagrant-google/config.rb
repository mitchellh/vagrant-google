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

      # The timeout value waiting for instance ready
      #
      # @return [Int]
      attr_accessor :instance_ready_timeout

      # The tags for the machine.
      # TODO(erjohnso): not supported in fog
      #
      # @return [Hash<String, String>]
      #attr_accessor :tags

      # The zone to launch the instance into. If nil, it will
      # use the default us-central1-f.
      #
      # @return [String]
      attr_accessor :zone

      def initialize(zone_specific=false)
        @google_client_email = UNSET_VALUE
        @google_key_location = UNSET_VALUE
        @google_project_id   = UNSET_VALUE
        @image               = UNSET_VALUE
        @machine_type        = UNSET_VALUE
        @disk_size           = UNSET_VALUE
        @metadata            = {}
        @name                = UNSET_VALUE
        @network             = UNSET_VALUE
        @tags                = []
        @instance_ready_timeout = UNSET_VALUE
        @zone                = UNSET_VALUE

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
      #       zone.image = "debian-7-wheezy-v20140926"
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
        @google_project_id   = ENV['GOOGLE_PROJECT_ID'] if @google_project_id == UNSET_VALUE

        # Image must be nil, since we can't default that
        @image = "debian-7-wheezy-v20140926" if @image == UNSET_VALUE

        # Default instance type is an n1-standard-1
        @machine_type = "n1-standard-1" if @machine_type == UNSET_VALUE

        # Default disk size is 10 GB
        @disk_size = 10 if @disk_size == UNSET_VALUE

        # Instance name defaults to a new datetime value (hour granularity)
        t = Time.now
        @name = "i-#{t.year}#{t.month.to_s.rjust(2,'0')}#{t.day.to_s.rjust(2,'0')}#{t.hour.to_s.rjust(2,'0')}" if @name == UNSET_VALUE

        # Network defaults to 'default'
        @network = "default" if @network == UNSET_VALUE

        # Default zone is us-central1-f.
        @zone = "us-central1-f" if @zone == UNSET_VALUE

        # Default instance_ready_timeout
        @instance_ready_timeout = 20 if @instance_ready_timeout == UNSET_VALUE

        # Compile our zone specific configurations only within
        # NON-zone-SPECIFIC configurations.
        if !@__zone_specific
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
          errors << I18n.t("vagrant_google.config.google_key_location_required") if \
            config.google_key_location.nil?
        end

        errors << I18n.t("vagrant_google.config.image_required") if config.image.nil?
        errors << I18n.t("vagrant_google.config.name_required") if @name.nil?

        { "Google Provider" => errors }
      end

      # This gets the configuration for a specific zone. It shouldn't
      # be called by the general public and is only used internally.
      def get_zone_config(name)
        if !@__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled zone config
        @__compiled_zone_configs[name] || self
      end
    end
  end
end
