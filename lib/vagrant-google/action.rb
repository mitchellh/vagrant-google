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
require "vagrant/action/builder"

module VagrantPlugins
  module Google
    module Action # rubocop:disable Metrics/ModuleLength
      # Include the built-in modules so we can use them as top-level things.
      include Vagrant::Action::Builtin

      # This action is called to halt the remote machine.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end
            b2.use ConnectGoogle
            b2.use StopInstance
          end
        end
      end

      # This action is called to terminate the remote machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, DestroyConfirm do |env, b2|
            if env[:result]
              b2.use ConfigValidate
              b2.use Call, IsCreated do |env2, b3|
                unless env2[:result]
                  b3.use MessageNotCreated
                  next
                end
                b3.use ConnectGoogle
                b3.use TerminateInstance
              end
            else
              b2.use MessageWillNotDestroy
            end
          end
        end
      end

      # This action is called when `vagrant provision` is called.
      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Provision
            b2.use SyncedFolders
          end
        end
      end

      # This action is called to read the SSH info of the machine. The
      # resulting state is expected to be put into the `:machine_ssh_info`
      # key.
      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectGoogle
          b.use ReadSSHInfo
        end
      end

      # This action is called to setup the Windows user/password on the machine.
      def self.action_setup_winrm_password
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectGoogle
          b.use SetupWinrmPassword
        end
      end

      # This action is called to read the state of the machine. The
      # resulting state is expected to be put into the `:machine_state_id`
      # key.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectGoogle
          b.use ReadState
        end
      end

      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHExec
          end
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHRun
          end
        end
      end

      # This action is called to bring the box up from nothing.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use HandleBox
          b.use ConfigValidate
          b.use BoxCheckOutdated
          b.use ConnectGoogle
          b.use Call, IsCreated do |env1, b1|
            if env1[:result]
              b1.use Call, IsTerminated do |env2, b2|
                if env2[:result]
                  b2.use Provision
                  b2.use SyncedFolders
                  b2.use WarnNetworks
                  b2.use WarnSshKeys
                  b2.use StartInstance
                else
                  # TODO: Impement better messages for different states
                  b2.use MessageAlreadyCreated
                end
              end
            else
              b1.use Provision
              b1.use SyncedFolders
              b1.use WarnNetworks
              b1.use WarnSshKeys
              b1.use RunInstance
              b1.use AssignInstanceGroups
            end
          end
        end
      end

      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectGoogle
          b.use Call, IsCreated do |env1, b1|
            unless env1[:result]
              b1.use MessageNotCreated
              next
            end

            # TODO: Think about implementing through server.reboot
            b1.use action_halt
            b1.use action_up
          end
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :AssignInstanceGroups, action_root.join("assign_instance_groups")
      autoload :ConnectGoogle, action_root.join("connect_google")
      autoload :IsCreated, action_root.join("is_created")
      autoload :IsTerminated, action_root.join("is_terminated")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :SetupWinrmPassword, action_root.join('setup_winrm_password')
      autoload :ReadState, action_root.join("read_state")
      autoload :RunInstance, action_root.join("run_instance")
      autoload :StartInstance, action_root.join("start_instance")
      autoload :StopInstance, action_root.join("stop_instance")
      autoload :TerminateInstance, action_root.join("terminate_instance")
      autoload :TimedProvision, action_root.join("timed_provision")
      autoload :WarnNetworks, action_root.join("warn_networks")
      autoload :WarnSshKeys, action_root.join("warn_ssh_keys")
    end
  end
end
