# Vagrant Google Compute Engine (GCE) Provider

<span class="badges">
[![Gem Version](https://badge.fury.io/rb/vagrant-google.png)][gem]
[![Dependency Status](https://gemnasium.com/mitchellh/vagrant-google.png)][gemnasium]
</span>

This is a [Vagrant](http://www.vagrantup.com) 1.2+ plugin that adds an
[Google Compute Engine](http://cloud.google.com/compute/) (GCE) provider to
Vagrant, allowing Vagrant to control and provision instances in GCE.

**NOTE:** This plugin requires Vagrant 1.2+.

## Features

* Boot Google Compute Engine instances.
* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.
* Define zone-specific configurations so Vagrant can manage machines in
  multiple zones.

## Usage

Install using standard Vagrant 1.1+ plugin installation methods.  After
installing, `vagrant up` and specify the `google` provider.  For example,

```sh
$ vagrant plugin install vagrant-google
...
$ vagrant up --provider=google
...
```

Of course, prior to this you'll need to obtain a GCE-compatible box file for
Vagrant. You may also need to ensure you have a ruby-dev and other utilities
such as GNU make installed prior to installing the plugin.

## Google Cloud Platform Setup

Prior to using this plugin, you will first need to make sure you have a
Google Cloud Platform account, enable Google Compute Engine, and create a
Service Account for API Access.

1. Log in with your Google Account and go to
   [Google Cloud Platform](https://cloud.google.com) and click on the
   `Try it now` button.
1. Create a new project and remember to record the `Project ID`
1. Next, visit the [Developers Console](https://console.developers.google.com)
   make sure to enable the `Google Compute Engine` service for your project
   If prompted, review and agree to the terms of service.
1. While still in the Developers Console, go to `API & AUTH`, `Credentials`
   section and click the `Create new Client ID` button.  In the pop-up dialog,
   select the `Service Account` radio button and the click the
   `Create Client ID` button.
1. Make sure to download the *P12 private key* and save this file in a secure
   and reliable location.  This key file will be used to authorize all API
   requests to Google Compute Engine.
1. Still on the same page, find the newly created `Service Account` text
   block on the API Access page.  Record the `Email address` (it should end
   with `@developer.gserviceaccount.com`) associated with the new Service
   Account you just created.  You will need this email address and the
   location of the private key file to properly configure this Vagrant plugin.
1. Add the SSH key you're going to use to GCE Metadata in `Compute` ->
   `Compute Engine` -> `Metadata` section of the console, `SSH Keys` tab. (Read
   the [SSH Support](https://github.com/mitchellh/vagrant-google#ssh-support)
   readme section for more information.)

## Quick Start

After installing the plugin (instructions above), the quickest way to get
started is to actually use a dummy Google box and specify all the details
manually within a `config.vm.provider` block. So first, add the Google box
using any name you want:

```sh
$ vagrant box add gce https://github.com/mitchellh/vagrant-google/raw/master/google.box
...
```

And then make a Vagrantfile that looks like the following, filling in
your information where necessary.

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "gce"

  config.vm.provider :google do |google, override|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.google_client_email = "YOUR_SERVICE_ACCOUNT_EMAIL_ADDRESS"
    google.google_json_key_location = "/path/to/your/private-key.json"

    override.ssh.username = "USERNAME"
    override.ssh.private_key_path = "~/.ssh/id_rsa"
    #override.ssh.private_key_path = "~/.ssh/google_compute_engine"
  end

end
```

And then run `vagrant up --provider=google`.

This will start a Debian 7 (Wheezy) instance in the `us-central1-f` zone,
with an `n1-standard-1` machine, and the `"default"` network within your
project. And assuming your SSH information (see below) was filled in properly
within your Vagrantfile, SSH and provisioning will work as well.

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
VMs will pick up the the key. Note that they public key is typically
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

* `google_client_email` - The Client Email address for your Service Account.
* `google_key_location` - The location of the P12 private key file matching your
  Service Account.
* `google_json_key_location` - The location of the JSON private key file matching your
  Service Account.
* `google_project_id` - The Project ID for your Google Cloud Platform account.
* `image` - The image name to use when booting your instance.
* `instance_ready_timeout` - The number of seconds to wait for the instance
  to become "ready" in GCE. Defaults to 20 seconds.
* `machine_type` - The machine type to use.  The default is "n1-standard-1".
* `disk_size` - The disk size in GB.  The default is 10.
* `disk_name` - The disk name to use.  If the disk exists, it will be reused, otherwise created.
* `metadata` - Custom key/value pairs of metadata to add to the instance.
* `name` - The name of your instance.  The default is "i-yyyymmddhh-randomsd",
  e.g. 10/08/2015 13:15:15 is "i-2015081013-15637fda".
* `network` - The name of the network to use for the instance.  Default is
 "default".
* `tags` - An array of tags to apply to this instance.
* `zone` - The zone name where the instance will be created.
* `can_ip_forward` - Boolean whether to enable IP Forwarding.
* `external_ip` - The external IP address to use (supports names).
* `preemptible` - Boolean whether to enable preemptibility. Default is false.
* `auto_restart` - Boolean whether to enable auto_restart. Default is true.
* `on_host_maintenance` - What to do on host maintenance. Default is "MIGRATE".
* `service_accounts` or `scopes` - An array of OAuth2 account scopes for
  services that the instance will have access to. Those can be both full API
  scopes, just endpoint aliases (the part after `...auth/`), and `gcloud`
  utility aliases, for example:
  `['storage-full', 'bigquery', 'https://www.googleapis.com/auth/compute']`.

These can be set like typical provider-specific configuration:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :google do |google|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.google_client_email = "YOUR_SERVICE_ACCOUNT_EMAIL_ADDRESS"
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

  config.vm.box = "gce"

  config.vm.provider :google do |google|
    google.google_project_id = "YOUR_GOOGLE_CLOUD_PROJECT_ID"
    google.google_client_email = "YOUR_SERVICE_ACCOUNT_EMAIL_ADDRESS"
    google.google_json_key_location = "/path/to/your/private-key.json"

    # Make sure to set this to trigger the zone_config
    google.zone = "us-central1-f"

    google.zone_config "us-central1-f" do |zone1f|
        zone1f.name = "testing-vagrant"
        zone1f.image = "debian-7-wheezy-v20150127"
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

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the Google provider will use
`rsync` (if available) to uni-directionally sync the folder to the remote
machine over SSH.

This is good enough for all built-in Vagrant provisioners (`shell`, `chef`, and
`puppet`) to work!

## Development

To work on the `vagrant-google` plugin, clone this repository, and use
[Bundler](http://gembundler.com) to get the dependencies:

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
export GOOGLE_CLIENT_EMAIL="your-google_service_account_email@developer.gserviceaccount.com"
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

## Changelog
See [CHANGELOG.md](CHANGELOG.md)

## License
Apache 2.0; see [LICENSE](LICENSE) for details.
