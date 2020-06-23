# Changelog

## v1.17 [Unreleased]

* Added check 19: Check if content databases aren't larger than 175GB
* Updated documentation to reflect all recent changes
* Updated reporting template to include new checks

## v1.16

* Published script on GitHub
* Fixed bug with reading config file, introduced in v1.15
* Removed the dependency on MBSA for the Missing Patch scan
* Increased PowerShell version requirement to v5.0 (due to use of Copy-Item -ToSession)

## v1.15

* Removed obsolete parameter Search String in url.txt file
* Added folder and file checks to make sure required configuration files really exist
* Added Config parameter to enable the possibility to specify custom configuration file
* Improved "Failed Timer Jobs" check to make it more efficient
* Minor bugfixes

## v1.14

* Added Full parameter to enable the possiblity to force run all checks
* Updated Distributed Cache check (check 18) to first validate if the DC is actually running on the specified server
* Updated URLCheck (check 1) to allow authentication against an ADFS/Windows Claims environment

## v1.13

* Added possibility to configure CC and BCC addresses as report recipients

## v1.12

* Improved MBSA check logging to show reason of a failed scan
* Fixed script duration per server calculation issue
* Updated wait procedure to display how many servers have completed
* Updated MBSA check to leave the reports when Debug is set to True
* Added ".NET v4.0" and ".NET v4.0 Classic" application pools to default ignored application pools
* Added check to validate if the user has sufficient permissions to use PowerShell with SharePoint (Only for servers where Role=SP)
* Added check if SharePoint plugin exists (Only for servers where Role=SP)
* Added check if Distributed Cache module can be found

## v1.11

* Added possibility to use multiple email addresses, separated with comma
* Added check for valid email address
* Improved script relative path support. The script now ensures all files and folders are found in the script folder
* Added validation of server configuration
* Added exitcodes
* Added information about debug the script to the documentation
* Added Distributed Cache check

## v1.10

* Updated documentation (MBSA check and CredSSP prereqs), fixed naming issue in check 17

## v1.9

* Added new check (17, ServiceApp status)

## v1.8

* Added NULL check to check 21

## v1.7

* Added Policy Compliance check (Large Lists and Versioning limits)
* Added option to store report on disk (config.xml changes)
* Added XML validation

## v1.6

* Improved job logging (added job duration)

## v1.5

* Added Group membership test, updated checks 1 and W4

## v1.4

* Updated error logging and fixed issue in check W4

## v1.3

* Added errored server logging

## v1.2

* Added timeout to Wait-Job, so it won't wait indefinitely. Corrected some code styling issues (config.xml changes)

## v1.1

* Added ServersSQL parameter

## v1.0

* Initial release
