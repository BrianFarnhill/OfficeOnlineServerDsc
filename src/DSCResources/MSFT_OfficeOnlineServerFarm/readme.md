# Description

The OfficeOnlineServerFarm resource is used to create a new farm for either
Office Web Apps 2013 or Office Online Server 2016. It requries that the binaries
have already been installed, but when this is run it will establish a new farm. This
means that this resource only needs to be used on the first server in a deployment,
all other servers should use the OfficeOnlineServerMachine resource to join
the farm.

FarmOU can be specified using path or LDAP syntax. For example "Servers/OOS" or
"LDAP://OU=OOS,OU=Servers". ntds:// format is supported by the underlying
Office Online Server Management Shell but is not implemented in OfficeOnlineServerDSC.
