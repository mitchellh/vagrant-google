# Copyright 2015 Google Inc. All Rights Reserved.
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
#
# Changes:
# April 2019: Modified example found here:
# https://github.com/GoogleCloudPlatform/compute-image-windows/blob/master/examples/windows_auth_python_sample.py
# to enable WinRM with vagrant.

module VagrantPlugins
  module Google
    module Action
      # Sets up a temporary WinRM password using Google's method for
      # establishing a new password over encrypted channels.
      class SetupWinrmPassword
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_google::action::setup_winrm_password")
        end

        def setup_password(env, instance, zone, user)
          # Setup
          compute = env[:google_compute]
          server = compute.servers.get(instance, zone)
          password = server.reset_windows_password(user)

          env[:ui].info("Temp Password: #{password}")

          password
        end

        def call(env)
          # Get the configs
          zone = env[:machine].provider_config.zone
          zone_config = env[:machine].provider_config.get_zone_config(zone)

          instance = zone_config.name
          user = env[:machine].config.winrm.username
          pass = env[:machine].config.winrm.password

          # Get Temporary Password, set WinRM password
          temp_pass = setup_password(env, instance, zone, user)
          env[:machine].config.winrm.password = temp_pass

          # Wait for WinRM To be Ready
          env[:ui].info("Waiting for WinRM To be ready")
          env[:machine].communicate.wait_for_ready(60)

          # Use WinRM to Change Password to one in Vagrantfile
          env[:ui].info("Changing password from temporary to winrm password")
          winrmcomm = VagrantPlugins::CommunicatorWinRM::Communicator.new(env[:machine])
          cmd = "net user #{user} #{pass}"
          opts = { elevated: true }
          winrmcomm.test(cmd, opts)

          # Update WinRM password to reflect updated one
          env[:machine].config.winrm.password = pass
        end
      end
    end
  end
end
