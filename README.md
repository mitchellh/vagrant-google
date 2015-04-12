# Vagrant Google Compute Engine (GCE) Provider

This is a [Vagrant](http://www.vagrantup.com) 1.2+ plugin that adds an
[Google Compute Engine](http://cloud.google.com/compute/) (GCE) provider to
Vagrant, allowing Vagrant to control and provision instances in GCE.

**NOTE:** This plugin requires Vagrant 1.2+,

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
   select the `Service Account` radio button and the click the `Create Client ID`
   button.
1. Make sure to download the *P12 private key* and save this file in a secure
   and reliable location.  This key file will be used to authorize all API
   requests to Google Compute Engine.
1. Still on the same page, find the newly created `Service Account` text
   block on the API Access page.  Record the `Email address` (it should end
   with `@developer.gserviceaccount.com`) associated with the new Service
   Account you just created.  You will need this email address and the
   location of the private key file to properly configure this Vagrant plugin.

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
    google.google_key_location = "/PATH/TO/YOUR/PRIVATE_KEY.p12"

    override.ssh.username = "USERNAME"
    override.ssh.private_key_path = "~/.ssh/id_rsa"
    #override.ssh.private_key_path = "~/.ssh/google_compute_engine"
  end

end
```

And then run `vagrant up --provider=google`.

This will start an Debian 7 (Wheezy) instance in the us-central1-f zone,
with an n1-standard-1 machine, and the "default" network within your project.
And assuming your SSH information (see below) was filled in properly within
your Vagrantfile, SSH and provisioning will work as well.

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
default, `glcoud compute` creates a key pair named
`~/.ssh/google_compute_engine[.pub]`.

Note that you can use the more standard `~/.ssh/id_rsa[.pub]` files, but you
will need to manually add your public key to the GCE metadata service so your
VMs will pick up the the key. Note that they public key is typically
prefixed with the username, so that the daemon on the VM adds the public key
to the correct user account.  See the blow links for more help with SSH and
GCE VMs.

  * https://cloud.google.com/compute/docs/instances#sshing
  * https://cloud.google.com/compute/docs/console#sshkeys

## Box Format

Every provider in Vagrant must introduce a custom box format. This provider
introduces `google` boxes. You can view an example box in the
[example_box/](https://github.com/mitchellh/vagrant-google/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file along with
a `Vagrantfile` that does default settings for the provider-specific
configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options:

* `google_client_email` - The Client Email address for your Service Account.
* `google_key_location` - The location to the private key file matching your
  Service Account.
* `google_project_id` - The Project ID for your Google Cloud Platform account.
* `image` - The image name to use when booting your instance.
* `instance_ready_timeout` - The number of seconds to wait for the instance
  to become "ready" in GCE. Defaults to 20 seconds.
* `machine_type` - The machine type to use.  The default is "n1-standard-1".
* `disk_size` - The disk size in GB.  The default is 10.
* `disk_name` - The disk name to use.  If the disk exists, it will be reused, otherwise created.
* `metadata` - Custom key/value pairs of metadata to add to the instance.
* `name` - The name of your instance.  The default is "i-yyyyMMddHH". Example 2014/10/01 10:00:00 is "i-2014100101".
* `network` - The name of the network to use for the instance.  Default is
 "default".
* `tags` - An array of tags to apply to this instance.
* `zone` - The zone name where the instance will be created.
* `can_ip_forward` - Boolean wether to enable IP Forwarding.

These can be set like typical provider-specific configuration:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :google do |google|
    google.google_project_id = "my_project"
    google.google_client_email = "hashstring@example.com"
    google.google_key_location = "/tmp/private-key.p12"
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
    google.google_project_id = "my_project"
    google.google_client_email = "hashstring@example.com"
    google.google_key_location = "/tmp/private-key.p12"

    # Make sure to set this to trigger the zone_config
    google.zone = "us-central1-f"

    google.zone_config "us-central1-f" do |zone1f|
        zone1f.name = "testing-vagrant"
        zone1f.image = "debian-7-wheezy-v20150127"
        zone1f.machine_type = "n1-standard-4"
        zone1f.zone = "us-central1-f"
        zone1f.metadata = {'custom' => 'metadata', 'testing' => 'foobarbaz'}
        zone1f.tags = ['web', 'app1']
        zone1f.external_ip = "123.123.123.123"
    end
  end
end
```

The zone-specific configurations will override the top-level configurations
when that zone is used. They otherwise inherit the top-level configurations,
as you would probably expect.

There are a few example Vagrantfile's located in the
[vagrantfile_examples/ directory](https://github.com/mitchellh/vagrant-google/tree/master/vagrantfile_examples/)

## Networks

Networking features in the form of `config.vm.network` are not supported
with `vagrant-google`, currently. If any of these are specified, Vagrant will
emit a warning, but will otherwise boot the GCE machine.

## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the Google provider will use
`rsync` (if available) to uni-directionally sync the folder to the remote
machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell, chef, and
puppet) to work!

## Development

To work on the `vagrant-google` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```
$ bundle exec rake
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
that uses it, and uses bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=google
```

## Changelog
 * See [CHANGELOG.md](https://github.com/mitchellh/vagrant-google/blob/master/CHANGELOG.md)

## Contributing
 * See [CONTRIB.md](https://github.com/mitchellh/vagrant-google/blob/master/CONTRIB.md)

## Licensing
 * See [LICENSE](https://github.com/mitchellh/vagrant-google/blob/master/LICENSE)
