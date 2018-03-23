# Copyright 2016 Google Inc. All Rights Reserved.
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
module VagrantPlugins
  module Google
    module Action
      # Action to assign instance groups. Looks for the 'instance_group'
      # parameter in the zone config and adds the instance to it.
      # If the instance group does not exist in the specified zone, it tries to
      # create one first.
      #
      # This action manipulates unmanaged instance groups
      # https://cloud.google.com/compute/docs/instance-groups/unmanaged-groups
      class AssignInstanceGroups
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new(
            "vagrant_google::action::assign_instance_groups"
          )
        end

        def call(env)
          zone = env[:machine].provider_config.zone
          zone_config = env[:machine].provider_config.get_zone_config(zone)
          instance_name = zone_config.name
          instance_group_name = zone_config.instance_group
          network = zone_config.network
          subnetwork = zone_config.subnetwork

          if instance_group_name
            group = env[:google_compute].instance_groups.get(instance_group_name,
                                                             zone)
            if group.nil?
              # If instance group doesn't exist, attempt to create it
              env[:ui].info(I18n.t("vagrant_google.instance_group_create"))
              instance_group_config = {
                name: instance_group_name,
                zone: zone,
                description: "Created by Vagrant",
                network: network,
                subnetwork: subnetwork,
              }
              env[:google_compute].instance_groups.create(instance_group_config)
            end

            # Add the machine to instance group
            env[:ui].info(I18n.t("vagrant_google.instance_group_add"))

            # Fixup with add_instance_group_instance after adding to fog
            # See https://github.com/fog/fog-google/issues/308
            response = env[:google_compute].add_instance_group_instances(
              instance_group_name,
              zone,
              [instance_name]
            )
            unless response.status == "DONE"
              operation = env[:google_compute].operations.get(response.name, zone)
              env[:ui].info(I18n.t("vagrant_google.waiting_for_operation",
                                   name: operation.name))
              operation.wait_for { ready? }
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
