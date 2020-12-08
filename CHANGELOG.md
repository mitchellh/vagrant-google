# Changelog
All notable changes to this project will be documented in this file.
The format is loosely based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Next


## 2.6.0 (December 2020)

### User-facing

#### Added

- \#248 Add support for modifying the configuration of Shielded VM [lcy0321]
- \#244 Add accelerator (GPU) configuration [johanvdhaegen]
- \#216 Add support for Windows hosts through WinRM [dvanbrug]

#### Fixed

- \#246 Fix config override during metadata merge [mavin]
- \#249 Fix shielded API failures on non-shielded VM's [temikus]
- \#227 Fix additional disks being auto-deleted unless a disk type is specified [chrisgavin]

### Development

#### Fixed

- \#247 chore: Update Gemfile with new `vagrant-spec` branch name [mavin]
- \#241 Fix unfortunate CI `on:` trigger typo [temikus]
- \#240 Update development environment, add CI functionality [Temikus]
- \#239 Remove old fixup in Gemfile [Temikus]
- \#237 Bump image size for test skeleton [Temikus]


## 2.5.0 (September 2019)

### User-facing

#### Added
- \#222 Added internal IP support [andrewh1978]

#### Deprecated

- \#220 Deprecated google_client_email parameter, as it's no longer needed or
  supported by fog-google [temikus]

### Development

#### Added

- \#223 Set up unit test GitHub Action worflow [temikus]

#### Fixed

- \#225 Locked the vagrant dep to 2.2.4 due to bundler issues on 2.2.5 [temikus]

## 2.4.0 (April 2019)

### User-facing

#### Added
- \#213 Implemented Application Default Credentials authentication [mavin]

#### Fixed
- \#214 Set a default zone only if `default` network is used [mavin]
- \#215 Allow tags,labels and additional_disks to be merged with multiple
  configs [mavin]

### Development

- \#213 Bumped dependencies [mavin]
   - fog-google version to 1.9.0

## 2.3.0 (February 2019)

### User-facing

- \#210 Allow adding additional disks to the instances. [whynick1]

### Development

- \#211 Rspec-its is now explicitly required for unit tests. [temikus]

## 2.2.1 (October 2018)

### User-facing

- \#206 Fix image selection logic - Plugin no longer traces back with
  `image_family` config option. [temikus]

### Development

- \#206 Bumped dependencies. [temikus]
  - fog-google version to 1.8.1
  - vagrant & vagrant-spec are now pointing to new upstream Hashicorp org repos

## 2.2.0 (June 2018)

#### Fixed
* Bumped fog-google to v1.4.
This is a necessary upstream update to work properly with Ruby 2.4+ on some
platforms.

## 2.1.0 (May 2018)

* Add new configuration option `image_project_id` to allow using GCE images from other projects. [seanmalloy]
* Add new configuration option `network_project_id` to allow using GCP Shared VPC networks. [seanmalloy]
* Add new configuration option `service_account` to allow setting the IAM service account on instances. [seanmalloy]
* Deprecate configuration option `service_accounts`. Use `scopes` configuration option instead. [seanmalloy]

## 2.0.0 (March 2018)

* Update to use fog-google gem v1
* Add new configuration option `labels` for setting [labels](https://cloud.google.com/compute/docs/labeling-resources)
  on GCE instances
* Fix disk cleanup issue causing the disk to be marked as created before insertion
* Test environment fixups to avoid 'Encoded files can't be read outside of the Vagrant installer.'
* Breaking changes:
  * Drop support for configuration option `google_key_location`(GCP P12 key)
  * `image` parameter no longer defaults to an arbitrary image and must be
    specified at runtime
  * Rsync behavior now consistent with Vagrant's default, removed old rsync code

## 1.0.0 (July 2017)
## 0.2.5 (October 2016)
## 0.2.4 (April 2016)
## 0.2.3 (January 2016)

## 0.2.2 (October 2015)

* Cleanup instance and disks on backend failures [p0deje]
* Refactoring ssh warnings into separate action [temikus]
* Refactoring disk type detection logic [temikus]
* Miscellaneous doc updates and minor fixes [mbrukman, temikus]

## 0.2.1 (July 2015)

* Temporarily reverted the old SyncedFolders behaviour. (See #94)

## 0.2.0 (July 2015)

* Added support for service account definitions [tcr]
* Added support for preemptible instances [jcdang]
* Implemented auto_restart and on_host_maintenance options [jcdang]
* Implemented vagrant halt and reload actions [temikus]
* Added support for IP address specification by name [temikus]
* Instance name now defaults to time + uuid [temikus]
* Removed legacy rsync code, switched to Vagrant built-in SyncedFolders [temikus]
* Switched to fog-google metagem [temikus]
* Added a linter and custom acceptance tests [temikus]
* Updated documentation and examples [mbrukman, temikus]
* Miscellaneous UI/UX updates and bugfixes [temikus]

## 0.1.5 (May 2015)

* Added support for JSON private keys [temikus]
* Added disk_type parameter support [temikus]
* Added acceptance tests [temikus]
* Added can_ip_forward, external_ip, autodelete_disk and disk_name parameters support [phueper]
* Added support for user specified rsync excludes [patkar]
* Miscellaneous bugfixes [mbrukman, beauzeaux, iceydee, mklbtz, temikus]

## 0.1.4 (October 2014)

* Add option for disk size [franzs]
* Add tags [ptone]
* Updated default for latest Debian image

## 0.1.3 (July 2014)

* Updated all image references
* Fixed fog deprecation warning
* Updated example box `google.box`
* Got spec tests passing again

## 0.1.1 (October 11, 2013)

* Fixed bug with instance ready/SSH

## 0.1.0 (August 14, 2013)

* Initial release.
