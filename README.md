# anse
Automatic Network Share Ectype

Bash script used for cloning network shares between servers.
My usage of this is to clone the contents of shares on my primary server to my cold-storage server once per month.

This script will power on a cold storage server using IPMI and then (non-destructivly) sync shares, shutting down the cold storage server once complete.
This script will then email a list of changed files (the raw rsync output)