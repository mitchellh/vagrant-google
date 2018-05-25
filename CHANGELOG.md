# 2.1.0 (May 2018)

* Add new configuration option `image_project_id` to allow using GCE images from other projects. [seanmalloy]
* Add new configuration option `network_project_id` to allow using GCP Shared VPC networks. [seanmalloy]
* Add new configuration option `service_account` to allow setting the IAM service account on instances. [seanmalloy]
* Deprecate configuration option `service_accounts`. Use `scopes` configuration option instead. [seanmalloy]

# 2.0.0 (March 2018)

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

# 1.0.0 (July 2017)
# 0.2.5 (October 2016)
# 0.2.4 (April 2016)
# 0.2.3 (January 2016)

# 0.2.2 (October 2015)

* Cleanup instance and disks on backend failures [p0deje]
* Refactoring ssh warnings into separate action [temikus]
* Refactoring disk type detection logic [temikus]
* Miscellaneous doc updates and minor fixes [mbrukman, temikus]

# 0.2.1 (July 2015)

* Temporarily reverted the old SyncedFolders behaviour. (See #94)

# 0.2.0 (July 2015)

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

# 0.1.5 (May 2015)

* Added support for JSON private keys [temikus]
* Added disk_type parameter support [temikus]
* Added acceptance tests [temikus]
* Added can_ip_forward, external_ip, autodelete_disk and disk_name parameters support [phueper]
* Added support for user specified rsync excludes [patkar]
* Miscellaneous bugfixes [mbrukman, beauzeaux, iceydee, mklbtz, temikus]

# 0.1.4 (October 2014)

* Add option for disk size [franzs]
* Add tags [ptone]
* Updated default for latest Debian image

# 0.1.3 (July 2014)

* Updated all image references
* Fixed fog deprecation warning
* Updated example box `google.box`
* Got spec tests passing again

# 0.1.1 (October 11, 2013)

* Fixed bug with instance ready/SSH

# 0.1.0 (August 14, 2013)

* Initial release.
