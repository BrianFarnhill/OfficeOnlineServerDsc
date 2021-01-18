# Change log for OfficeOnlineServerDsc

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- OfficeOnlineServerFarm
  - Added hierarchy and LDAP:// support for FarmOU

## [1.5.0] - 2020-04-03

## Added

- OfficeOnlineServerDsc
  - Implemented the new DSC Community CD/CI system
  - Optin to the following Dsc Resource metatests:
    - Common Tests - Validate Module Files
    - Common Tests - Validate Script Files
    - Common Tests - Relative Path Length
    - Common Tests - Validate Markdown Links
- OfficeOnlineServerFarm
  - Added logic to make sure this resource does not interfere with
    a patch installation after a reboot
- OfficeOnlineServerInstall
  - Added check for CDROM to prevent issues with block file check
- OfficeOnlineServerInstallLanguagePack
  - Added Contextual Help information
  - Added check for CDROM to prevent issues with block file check
- OfficeOnlineServerMachine
  - Added logic to make sure this resource does not interfere with
    a patch installation after a reboot
- OfficeOnlineServerProductUpdate
  - New resource

## Changed

- OfficeOnlineServerInstall
  - Updated error code checks to force reboot
- OfficeOnlineServerMachine
  - Removed check for MachineToJoin. The resource only needs to check
    for farm join, especially with the new ProductUpdate resource.

For older change log history see the [historic changelog](HISTORIC_CHANGELOG.md).
