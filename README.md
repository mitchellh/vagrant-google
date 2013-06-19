# Vagrant Google Compute Engine Provider

This is a [Vagrant](http://www.vagrantup.com) 1.2+ plugin that adds an
[Google Compute Engine](http://cloud.google.com/compute/) (GCE) provider to
Vagrant, allowing Vagrant to control and provision instances in GCE.

**NOTE:** This plugin requires Vagrant 1.2+,

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
 * See [CHANGELOG.md](https://github.com/GoogleCloudPlatform/vagrant-google/blob/master/CHANGELOG.md)

## Contributing
 * See [CONTRIB.md](https://github.com/GoogleCloudPlatform/vagrant-google/blob/master/CONTRIB.md)

## Licensing
 * See [LICENSE](https://github.com/GoogleCloudPlatform/vagrant-google/blob/master/LICENSE)
