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
    module Action
      # Include the built-in modules so we can use them as top-level things.
      include Vagrant::Action::Builtin

      # This action is called to terminate the remote machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, DestroyConfirm do |env, b2|
            if env[:result]
              b2.use ConfigValidate
              b2.use ConnectGoogle
              b2.use TerminateInstance
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
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Provision
            b2.use SyncFolders
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
            if !env[:result]
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
            if !env[:result]
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
          b.use ConnectGoogle
          b.use Call, IsCreated do |env, b2|
            if env[:result]
              b2.use MessageAlreadyCreated
              next
            end

            b2.use Provision
            b2.use SyncFolders
            b2.use WarnNetworks
            b2.use RunInstance
          end
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :ConnectGoogle, action_root.join("connect_google")
      autoload :IsCreated, action_root.join("is_created")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :ReadState, action_root.join("read_state")
      autoload :RunInstance, action_root.join("run_instance")
      autoload :SyncFolders, action_root.join("sync_folders")
      autoload :TimedProvision, action_root.join("timed_provision")
      autoload :WarnNetworks, action_root.join("warn_networks")
      autoload :TerminateInstance, action_root.join("terminate_instance")
    end
  end
end
