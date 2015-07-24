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
