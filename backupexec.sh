
#define what servers to use, and what shares to mount
primaryserver=hostname #host name of your primary server to take the backup from
backupserver=hostname #hostname of cold-storage server to send the backup to
declare -a shares=("share" "to" "backup") #names of shares to backup- shares should have the same name on both servers
ipmi=192.168.0.9 #ipmi IP address to power on backup server
ipmiusr=ADMIN #set your IPMI login details here
ipmipsw=PASSWORD #and here
backupip=192.168.0.8 #IP address of backup server
email=backupexec@darkmage.org

#here we actually start doing stuff
declare -a servers=($primaryserver $backupserver)
cd /root
echo "start time: $(date)" >> /root/backuplog.txt
echo "" >> /root/backuplog.txt

##bring backup server online

ipmiutil power -u -N $ipmi -U $ipmiusr -P $ipmipsw >> /root/backuplog.txt

##wait for backup server to respond to ping

UNREACHEABLE=1
COUNTER=0
TURBOCOUNTER=0
while [ $UNREACHEABLE -ne "0" ]
	do ping -q -c 1 $backupip &> /dev/null; UNREACHEABLE=$?; sleep 10
	COUNTER=$[COUNTER + 1]
	if [ $COUNTER -eq 60 ]; then
		echo ssh root@$backupip 'reboot' >> /root/backuplog.txt
		COUNTER=0
		TURBOCOUNTER=$[TURBOCOUNTER + 1]
		if [ $TURBOCOUNTER -eq 10 ]; then
			ipmiutil power -c -N $ipmi -U ADMIN -P ADMIN >> /root/backuplog.txt
			echo "" >> /root/backuplog.txt
			TURBOCOUNTER=0
		fi
	fi
done
sleep 60

##create directories and mount shares to them

for i in "${servers[@]}"
do
	for s in "${shares[@]}"
	do
		mkdir -p /mnt/"$i"/"$s"
		mount -t nfs "$i":/mnt/user/"$s"/ /mnt/"$i"/"$s" >> /root/backuplog.txt
	done
done

##rsync

for s in "${shares[@]}"
do
	if mountpoint -q /mnt/$primaryserver/"$s"; then
		if mountpoint -q /mnt/$backupserver/"$s"; then
			echo "" >> /root/backuplog.txt
			echo "" >> /root/backuplog.txt
			echo "$s" >> /root/backuplog.txt
			rsync --archive --human-readable -v --itemize-changes /mnt/$primaryserver/"$s"/ /mnt/$backupserver/"$s" >> /root/backuplog.txt
		fi
	fi
done

##clean up mounts and remove folders

for i in "${servers[@]}"
do
	for s in "${shares[@]}"
	do
		umount /mnt/"$i"/"$s"
		rmdir /mnt/"$i"/"$s"
	done
done

##shut down crown

echo "" >> /root/backuplog.txt
echo "" >> /root/backuplog.txt
ssh root@$backupip 'shutdown -h now' >> /root/backuplog.txt

##email log file

echo "" >> /root/backuplog.txt
echo "" >> /rootbackuplog.txt
echo "finish time: $(date)" >> /root/backuplog.txt
mail -s "backup log" $email < /root/backuplog.txt
mv /root/backuplog.txt /root/backuplog/$(date +%F-%T)_backuplog.txt
