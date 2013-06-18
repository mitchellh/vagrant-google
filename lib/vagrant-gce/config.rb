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
  module GCE
    class Config < Vagrant.plugin("2", :config)
      # The GCE endpoint to connect to
      #
      # @return [String]
      attr_accessor :endpoint

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

      # The timeout to wait for an instance to become ready.
      #
      # @return [Fixnum]
      attr_accessor :instance_ready_timeout

      # The name of the keypair to use.
      #
      # @return [String]
      attr_accessor :keypair_name

      # The type of machine to launch, such as "n1-standard-1"
      #
      # @return [String]
      attr_accessor :machine_type

      # The user metadata string
      #
      # @return [Hash<String, String>]
      attr_accessor :metadata

      # The private IP address to give this machine (VPC).
      #
      # @return [String]
      attr_accessor :private_ip_address

      # The name of the GCE region in which to create the instance.
      #
      # @return [String]
      attr_accessor :region

      # The security groups to set on the instance. For VPC this must
      # be a list of IDs.
      #
      # @return [Array<String>]
      attr_accessor :security_groups

      # The subnet ID to launch the machine into (VPC).
      #
      # @return [String]
      attr_accessor :subnet_id

      # The tags for the machine.
      #
      # @return [Hash<String, String>]
      attr_accessor :tags

      # The version of the GCE api to use
      #
      # @return [String]
      attr_accessor :version

      # The zone to launch the instance into. If nil, it will
      # use the default us-central1-a.
      #
      # @return [String]
      attr_accessor :zone

      def initialize(region_specific=false)
        @google_client_email = UNSET_VALUE
        @google_key_location = UNSET_VALUE
        @google_project_id   = UNSET_VALUE
        @image               = UNSET_VALUE
        @zone                = UNSET_VALUE
        @instance_ready_timeout = UNSET_VALUE
        @machine_type        = UNSET_VALUE
        @keypair_name        = UNSET_VALUE
        @private_ip_address  = UNSET_VALUE
        @region              = UNSET_VALUE
        @endpoint            = UNSET_VALUE
        @version             = UNSET_VALUE
        @security_groups     = UNSET_VALUE
        @tags                = {}
        @metadata            = {}

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_region_configs = {}
        @__finalized = false
        @__region_config = {}
        @__region_specific = region_specific
      end

      # Allows region-specific overrides of any of the settings on this
      # configuration object. This allows the user to override things like
      # image and keypair name for regions. Example:
      #
      #     gce.region_config "us-central1" do |region|
      #       region.image = "centos-6"
      #       region.keypair_name = "company-east"
      #     end
      #
      # @param [String] region The region name to configure.
      # @param [Hash] attributes Direct attributes to set on the configuration
      #   as a shortcut instead of specifying a full block.
      # @yield [config] Yields a new GCE configuration.
      def region_config(region, attributes=nil, &block)
        # Append the block to the list of region configs for that region.
        # We'll evaluate these upon finalization.
        @__region_config[region] ||= []

        # Append a block that sets attributes if we got one
        if attributes
          attr_block = lambda do |config|
            config.set_options(attributes)
          end

          @__region_config[region] << attr_block
        end

        # Append a block if we got one
        @__region_config[region] << block if block_given?
      end

      #-------------------------------------------------------------------
      # Internal methods.
      #-------------------------------------------------------------------

      def merge(other)
        super.tap do |result|
          # Copy over the region specific flag. "True" is retained if either
          # has it.
          new_region_specific = other.instance_variable_get(:@__region_specific)
          result.instance_variable_set(
            :@__region_specific, new_region_specific || @__region_specific)

          # Go through all the region configs and prepend ours onto
          # theirs.
          new_region_config = other.instance_variable_get(:@__region_config)
          @__region_config.each do |key, value|
            new_region_config[key] ||= []
            new_region_config[key] = value + new_region_config[key]
          end

          # Set it
          result.instance_variable_set(:@__region_config, new_region_config)

          # Merge in the tags
          result.tags.merge!(self.tags)
          result.tags.merge!(other.tags)
        end
      end

      def finalize!
        # Try to get access keys from standard GCE environment variables; they
        # will default to nil if the environment variables are not present.
        @google_client_email = ENV['GOOGLE_CLIENT_EMAIL'] if @google_client_email == UNSET_VALUE
        @google_key_location = ENV['GOOGLE_KEY_LOCATION'] if @google_key_location == UNSET_VALUE
        @google_project_id   = ENV['GOOGLE_PROJECT_ID'] if @google_project_id == UNSET_VALUE

        # Image must be nil, since we can't default that
        @image = "debian-7" if @image == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 30 if @instance_ready_timeout == UNSET_VALUE

        # Default instance type is an n1-standard-1
        @machine_type = "n1-standard-1" if @machine_type == UNSET_VALUE

        # Keypair defaults to nil
        @keypair_name = nil if @keypair_name == UNSET_VALUE

        # Default the private IP to nil since VPC is not default
        @private_ip_address = nil if @private_ip_address == UNSET_VALUE

        # Default region is us-central1.
        @region = "us-central1" if @region == UNSET_VALUE
        @zone = "us-central1-a" if @zone == UNSET_VALUE
        @endpoint = nil if @endpoint == UNSET_VALUE
        @version = "v1beta15" if @version == UNSET_VALUE

        # The security groups are empty by default.
        @security_groups = [] if @security_groups == UNSET_VALUE

        # Compile our region specific configurations only within
        # NON-REGION-SPECIFIC configurations.
        if !@__region_specific
          @__region_config.each do |region, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The region name of the configuration always equals the
            # region config name:
            config.region = region

            # Finalize the configuration
            config.finalize!

            # Store it for retrieval
            @__compiled_region_configs[region] = config
          end
        end

        # Mark that we finalized
        @__finalized = true
      end

      def validate(machine)
        errors = _detected_errors

        errors << I18n.t("vagrant_gce.config.region_required") if @region.nil?

        if @region
          # Get the configuration for the region we're using and validate only
          # that region.
          config = get_region_config(@region)

          errors << I18n.t("vagrant_gce.config.google_project_id_required") if \
            config.google_project_id.nil?
          errors << I18n.t("vagrant_gce.config.google_client_email_required") if \
            config.google_client_email.nil?
          errors << I18n.t("vagrant_gce.config.google_key_location_required") if \
            config.google_key_location.nil?

          errors << I18n.t("vagrant_gce.config.image_required") if config.image.nil?
        end

        { "GCE Provider" => errors }
      end

      # This gets the configuration for a specific region. It shouldn't
      # be called by the general public and is only used internally.
      def get_region_config(name)
        if !@__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled region config
        @__compiled_region_configs[name] || self
      end
    end
  end
end
