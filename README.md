# Vagrant Google Compute Engine (GCE) Provider

[![Gem Version](https://badge.fury.io/rb/vagrant-google.svg)](https://badge.fury.io/rb/vagrant-google)

[gem]: https://rubygems.org/gems/vagrant-google
[gemnasium]: https://gemnasium.com/mitchellh/vagrant-google

This is a [Vagrant](https://www.vagrantup.com) plugin that adds an
[Google Compute Engine](https://cloud.google.com/compute/) (GCE) provider to
Vagrant, allowing Vagrant to control and provision instances in GCE.

**NOTE:** The plugin is currently looking for maintainers, please contact @temikus.

# Features

* Boot Google Compute Engine instances.
* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Synced folder support via Vagrant's
[rsync action](https://www.vagrantup.com/docs/synced-folders/rsync.html).
* Define zone-specific configurations so Vagrant can manage machines in
  multiple zones.

# Requirements

* Google Cloud Platform (GCP) account,
* a GCP project with:
  * Google Compute Engine API enabled
  * Your public SSH key added as GCE metadata.
* Vagrant 2.0.3+

## Google Cloud Platform Setup

Do the following:

1. Log in with your Google Account and go to
   [Google Cloud Platform](https://cloud.google.com) and click on the
   `Try it free` button.
2. Create a new project and remember to record the `Project ID`
3. Enable the
   [Google Compute Engine API](https://console.cloud.google.com/apis/library/compute.googleapis.com)
   for your project in the API console. If prompted, review and agree to the
   terms of service.
4. Install the [Cloud SDK](https://cloud.google.com/sdk/docs/install)
5. Run `[gcloud auth appplication-default login](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login)
   to create your credentials. (Alternatively, you may use a service account, see **Using a Service Account** section).
6. Add the public SSH key you're going to use to GCE Metadata in `Compute` ->
   `Compute Engine` -> `Metadata` section of the console, `SSH Keys` tab. (Read
   the [SSH Support](https://github.com/mitchellh/vagrant-google#ssh-support)
   readme section for more information.)

### Using a Service Account

The `[appplication-default login](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login)
method is intended to be used for developing code on a local environment - this is typically Vagrant's use-case
as well. However, if this is not your use-case, you will want to use a credential not tied to your local environment:
a service account.

To use a service account:

1. While still in the API & Services, go to
   [Credentials subsection](https://console.cloud.google.com/apis/api/compute.googleapis.com/credentials),
   and click `Create credentials` -> `Service account`.
2. Create a Service Account with any name (f.e. `vagrant`) and grant it
   a `Compute Admin` role.
3. Open the new service account page and click on the `Keys` tab. 
   Click `Add key` -> `Create new key`, choose JSON. Download the JSON private key
   and save this file in a secure and reliable location.

Then include the private key in your Vagrantfile's `provider` block as a `google_json_key_location`
attribute:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :google do |google|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.google_json_key_location = "/path/to/your/private-key.json"
  end
end
```

## Vagrant Setup

Install as a Vagrant plugin:

```sh
vagrant plugin install vagrant-google
```

# Usage

Make a `Vagrantfile` that looks like the following, filling in
your information where necessary:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "google/gce"

  config.vm.provider :google do |google, override|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.image_family = 'ubuntu-2004-lts'

    override.ssh.username = "USERNAME"
    override.ssh.private_key_path = "~/.ssh/id_rsa"
  end

end
```

Run:
```sh
vagrant up --provider=google
```

This will start the latest version of Ubuntu 20.04 LTS instance in the
`us-central1-f` zone, with an `n1-standard-1` machine, and the `"default"`
network within your project. And assuming your SSH information (see below) was
filled in properly within your Vagrantfile, SSH and provisioning will work as
well.

Note that normally a lot of this boilerplate is encoded within the box file,
but the box file used for the quick start, the "google" box, has no
preconfigured defaults.

## SSH Support

In order for SSH to work properly to the GCE VM, you will first need to add
your public key to the GCE metadata service for the desired VM user account.
When a VM first boots, a Google-provided daemon is responsible for talking to
the internal GCE metadata service and creates local user accounts and their
respective `~/.ssh/authorized_keys` entries.  Most new GCE users will use the
[Cloud SDK](https://cloud.google.com/sdk/) `gcloud compute` utility when first
getting started with GCE. This utility has built in support for creating SSH
key pairs, and uploading the public key to the GCE metadata service.  By
default, `gcloud compute` creates a key pair named
`~/.ssh/google_compute_engine[.pub]`.

Note that you can use the more standard `~/.ssh/id_rsa[.pub]` files, but you
will need to manually add your public key to the GCE metadata service so your
VMs will pick up the key. Note that the public key is typically
prefixed with the username, so that the daemon on the VM adds the public key
to the correct user account.

Additionally, you will probably need to add the key and username to override
settings in your Vagrantfile like so:

```ruby
config.vm.provider :google do |google, override|

    #...google provider settings are skipped...

    override.ssh.username = "testuser"
    override.ssh.private_key_path = "~/.ssh/id_rsa"

    #...google provider settings are skipped...

end
```

See the links below for more help with SSH and GCE VMs.

  * https://cloud.google.com/compute/docs/instances#sshing
  * https://cloud.google.com/compute/docs/console#sshkeys

## Box Format

Every provider in Vagrant must introduce a custom box format. This provider
introduces `google` boxes. You can view an example box in
[example_boxes/](https://github.com/mitchellh/vagrant-google/tree/master/example_boxes).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file along with
a `Vagrantfile` that does default settings for the provider-specific
configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options:

* `google_json_key_location` - The location of the JSON private key file matching your
  Service Account.
  (Can also be configured with `GOOGLE_JSON_KEY_LOCATION` environment variable.)
* `google_project_id` - The Project ID for your Google Cloud Platform account.
  (Can also be configured with `GOOGLE_PROJECT_ID` environment variable.)
* `image` - The image name to use when booting your instance.
* `image_family` - Specify an "image family" to pull the latest image from. For example: `centos-7`
will pull the most recent CentOS 7 image. For more info, refer to
[Google Image documentation](https://cloud.google.com/compute/docs/images#image_families).
* `image_project_id` - The ID of the GCP project to search for the `image` or `image_family`.
  For example: `centos-cloud` for Centos 7/8/Stream image families.
* `instance_group` - Unmanaged instance group to add the machine to. If one
  doesn't exist it will be created.
* `instance_ready_timeout` - The number of seconds to wait for the instance
  to become "ready" in GCE. Defaults to 20 seconds.
* `machine_type` - The machine type to use.  The default is "n1-standard-1".
* `disk_size` - The disk size in GB.  The default is 10.
* `disk_name` - The disk name to use.  If the disk exists, it will be reused, otherwise created.
* `disk_type` - Whether to use Standard disk or SSD disk. Use either `pd-ssd` or `pd-standard`.
* `autodelete_disk` - Boolean whether to delete the disk when the instance is deleted or not. Default is true.
* `metadata` - Custom key/value pairs of metadata to add to the instance.
* `name` - The name of your instance.  The default is "i-yyyymmddhh-randomsd",
  e.g. 10/08/2015 13:15:15 is "i-2015081013-15637fda".
* `network` - The name of the network to use for the instance.  Default is
 "default".
* `network_project_id` - The ID of the GCP project for the network and subnetwork to use for the instance. Default is `google_project_id`.
* `subnetwork` - The name of the subnetwork to use for the instance.
* `tags` - An array of tags to apply to this instance.
* `labels` - Custom key/value pairs of labels to add to the instance.
* `zone` - The zone name where the instance will be created.
* `can_ip_forward` - Boolean whether to enable IP Forwarding.
* `external_ip` - The external IP address to use (supports names). Set to `false` to not assign an external address.
* `network_ip` - The internal IP address to use. Default is to use next available address.
* `use_private_ip` - Boolean whether to use private IP for SSH/provisioning. Default is false.
* `preemptible` - Boolean whether to enable preemptibility. Default is false.
* `auto_restart` - Boolean whether to enable auto_restart. Default is true.
* `on_host_maintenance` - What to do on host maintenance. Can be set to `MIGRATE` or `TERMINATE` Default is `MIGRATE`.
* `scopes` or `service_accounts` - An array of OAuth2 account scopes for
  services that the instance will have access to. Those can be both full API
  scopes, just endpoint aliases (the part after `...auth/`), and `gcloud`
  utility aliases, for example:
  `['storage-full', 'bigquery', 'https://www.googleapis.com/auth/compute']`.
* `service_account` - The IAM service account email to use for the instance.
* `additional_disks` - An array of additional disk configurations. `disk_size` is default to `10`GB;
  `disk_name` is default to `name` + "-additional-disk-#{index}"; `disk_type` is default to `pd-standard`;
  `autodelete_disk` is default to `true`. Here is an example of configuration.
  ```ruby
    [{
     :image_family => "google-image-family",
     :image => nil,
     :image_project_id => "google-project-id",
     :disk_size => 20,
     :disk_name => "google-additional-disk-0",
     :disk_type => "pd-standard",
     :autodelete_disk => true
    }]
  ```
* `accelerators` - An array of accelerator configurations. `type` is the
  accelerator type (e.g. `nvidia-tesla-k80`); `count` is the number of
  accelerators and defaults to 1. Note that only `TERMINATE` is supported for
  `on_host_maintenance`; this should be set explicitly, since the default is
  `MIGRATE`.
  ```ruby
  google.accelerators = [{
    :type => "nvidia-tesla-k80",
    :count => 2
  }]

  google.on_host_maintenance = "TERMINATE"
  ```
* `enable_secure_boot` - For [Shielded VM](https://cloud.google.com/security/shielded-cloud/shielded-vm), whether to enable Secure Boot.
* `enable_vtpm` - For [Shielded VM](https://cloud.google.com/security/shielded-cloud/shielded-vm), whether to enable vTPM.
* `enable_integrity_monitoring` - For [Shielded VM](https://cloud.google.com/security/shielded-cloud/shielded-vm), whether to enable Integrity monitoring.
* `resource_policies` - Adds [Resource Policies](https://cloud.google.com/compute/docs/reference/rest/v1/resourcePolicies) to given instance.
These can be set like typical provider-specific configuration:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :google do |google|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.google_json_key_location = "/path/to/your/private-key.json"
  end
end
```

In addition to the above top-level configs, you can use the `zone_config`
method to specify zone-specific overrides within your Vagrantfile. Note
that the top-level `zone` config must always be specified to choose which
zone you want to actually use, however. This looks like this:

```ruby
Vagrant.configure("2") do |config|

  config.vm.box = "google/gce"

  config.vm.provider :google do |google|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.google_json_key_location = "/path/to/your/private-key.json"

    # Make sure to set this to trigger the zone_config
    google.zone = "us-central1-f"

    google.zone_config "us-central1-f" do |zone1f|
        zone1f.name = "testing-vagrant"
        zone1f.image = "debian-9-stretch-v20211105"
        zone1f.machine_type = "n1-standard-4"
        zone1f.zone = "us-central1-f"
        zone1f.metadata = {'custom' => 'metadata', 'testing' => 'foobarbaz'}
        zone1f.scopes = ['bigquery', 'monitoring', 'https://www.googleapis.com/auth/compute']
        zone1f.tags = ['web', 'app1']
    end
  end
end
```

The zone-specific configurations will override the top-level configurations
when that zone is used. They otherwise inherit the top-level configurations,
as you would expect.

There are a few example Vagrantfiles located in the
[vagrantfile_examples/ directory](https://github.com/mitchellh/vagrant-google/tree/master/vagrantfile_examples/).

## Networks

Networking features in the form of `config.vm.network` are not supported
with `vagrant-google`, currently. If any of these are specified, Vagrant will
emit a warning, but will otherwise boot the GCE machine.

## Synced Folders

Since plugin version 2.0, this is implemented via built-in `SyncedFolders` action.
See Vagrant's [rsync action](https://www.vagrantup.com/docs/synced-folders/rsync.html)
documentation for more info.

## Automatic shutdown

To save money you may want to ensure you don't forget to shut down your instances
when you stop using them.

A very basic solution for this is to use Vagrant's provisioning feature to plan
automatic shutdown of the vm after given time after each `vagrant up`:

```ruby
# Plan automatic shutdown of machine to prevent unwanted costs
config.vm.provision "auto-shutdown", type: "shell", run: "always",
  inline: "shutdown -P +480" # = 60 minutes * 8 hours
```

## Print external IP

You may want to know your machine's external IP f.e. to put it in your Ansible inventory
or open the app you deploy in it in your browser.

To automate printing it IP you can also use the Vagrant's provisioning feature:

```ruby
# Print the external IP
config.vm.provision "print-ip", type: "shell", run: "always",
  inline: "echo External IP: $(curl -s icanhazip.com)"
```

# Development

To work on the `vagrant-google` plugin, clone this repository, and use
[Bundler](https://gembundler.com) to get the dependencies:

```sh
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```sh
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is ignored by
 git), and use bundler to execute Vagrant:

```sh
$ bundle exec vagrant up --provider=google
```

## Acceptance testing

**Work-in-progress:** Acceptance tests are based on vagrant-spec library which
is currently under active development so they may occasionally break.

Before you start acceptance tests, you'll need to set the authentication
shell variables accordingly:

```sh
export GOOGLE_PROJECT_ID="your-google-cloud-project-id"
export GOOGLE_JSON_KEY_LOCATION="/full/path/to/your/private-key.json"

export GOOGLE_SSH_USER="testuser"
export GOOGLE_SSH_KEY_LOCATION="/home/testuser/.ssh/id_rsa"
```

After, you can run acceptance tests by running the `full` task in `acceptance`
namespace:
```sh
$ bundle exec rake acceptance:full
```

**IMPORTANT NOTES**:

- Since acceptance tests spin up instances on GCE, the whole suite may take
 20+ minutes to run.
- Since those are live instances, **you will be billed** for running them.

# Changelog
See [CHANGELOG.md](CHANGELOG.md)

# License
Apache 2.0; see [LICENSE](LICENSE) for details.
