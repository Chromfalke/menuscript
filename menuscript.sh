#! /bin/sh

main () {
	# loop for the main menu made with case instead of select
	while [ 1 -eq 1 ]
	do
		echo "<---Main Menu--->"
		echo "1) Networking"
		echo "2) Drives"
		echo "3) Filesystem"
		echo "4) Users"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)	network ;;
		2)	drives ;;
		3)	filesystem ;;
		4)	user ;;
		q)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# change the current network settings
settings () {
	ostype=$1
	while [ 1 -eq 1 ]
	do
		echo "<---Network Settings--->"
		echo "1) Create interface"
		echo "2) Remove interface"
		echo "3) Change status"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)
			# add a new interface with ipadm or ifconfig
			read -p "Name of the interface: " name
			read -p "Address of the interface: " addr
			if [ $ostype = SunOS ]
			then
				ipadm create-ip $name
				ipadm create-addr -T static -a $addr $name
			else
				ifconfig $name create
				ifconfig $name $addr
			fi
			;;
		2)
			# remove an interface with ipadm or ifconfig
			read -p "Interface name: " name
			if [ $ostype = SunOS ]
			then
				ipadm delete-ip $name
			else
				ifconfig $name delete
			fi
			;;
		3)
			# change the status of a selected interface
			read -p "Interface name: " name
			read -p "New status (up/down): " status
			if [ $status = up -o $status = down ]
			then
				ifconfig $name $status
			else
				echo "Invalid status"
			fi
			;;
		q)	break ;;
		qq)	main ;;
		qqq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# change the persistent network configuration
# files are edited with the sed command
config () {
	ostype=$1
	while [1 -eq 1]
	do
		echo "<---Network Config--->"
		echo "1) Change hostname"
		echo "2) Change ip-address"
		echo "3) Show routing table"
		echo "4) Change default route"
		echo "5) Add route"
		echo "6) Remove route"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)
			read -p "New hostname: " name
			case "$ostype" in
			FreeBSD)
				hostname $name
				sed -i '' 's/hostname=".*"/hostname="'"$name"'"/g' /etc/rc.conf
				;;
			SunOS)
				svccfg -s system/identity:node setprop config/nodename=$name
				svccfg -s system/identity:node setprop config/loopback=$name
				svcadm refresh system/identity:node
				svcadm restart system/identity:node
				;;
			AIX)
				# not tested but it should work
				hostname $name
				chdev -l inet0 -a hostname=$name
				;;
			*)	echo "OS could ot be recognized" ;;
			esac
			;;
		2)
			ifconfig -a
			read -p "Select interface: " $name
			read -p "New ip-address: " $addr
			if [ $ostype = FreeBSD ]
			then
				ifconfig $name inet $addr
				sed -i '' 's/ifconfig_'"$name"'="inet .* netmask/ifconfig_'"$name"'="inet '"$addr"' netmask/g' /etc/rc.conf
				./etc/netstart
			else
				ipadm delete-ip $name
				ipadm create-ip $name
				ipadm create-addr -T static -a $addr $name
			fi
			;;
		3)	netstat -rn ;;
		4)
			read -p "New default route: " addr
			if [ $ostype = FreeBSD ]
			then
				route del default
				route add default $addr
				sed -i '' 's/defaultrouter=".*"/defaultrouter="'"$addr"'"/g' /etc/rc.conf
			else
				route delete default
				route add default $addr
			fi
			;;
		5)
			read -p "Destination: " dest
			read -p "Gateway: " gate
			if [ $ostype = FreeBSD ]
			then
				route add -net $dest $gate
				# check if there are already static routes defined
				cat /etc/rc.conf | grep "static_routes" > /dev/zero
				if [ $? = 0 ]
				then
					# if yes then add the new route
					sed -i '' 's/static_routes="/static_routes="net'"$dest"' /g' /etc/rc.conf
				else
					# if no create an entry for static routes
					echo "static_routes=\"net'"$dest"'\"" >> /etc/rc.conf
				fi
				echo "route_net${dest}=\"-net $addr $gate\"" >> /etc/rc.conf
			else
				route -p add -net $dest -gateway $gate
			fi
			;;
		6)
			read -p "Destination: " dest
			if [ $ostype = FreeBSD ]
			then
				route del $dest
				# remove the entry from static routes
				sed -i '' 's/static_routes=.*net'"$dest"'/static_routes=.&/g' /etc/rc.conf
				# overwrite the file with itself without the route
				cat /etc/rc.conf | grep -v "$dest" > /etc/rc.conf
			else
				route delete $dest
			fi
			;;
		q)	break ;;
		qq)	main ;;
		qqq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# networking menu
network () {
	ostype=`uname`
	while [ 1 -eq 1 ]
	do
		echo "<---Networking--->"
		echo "1) List interfaces"
		echo "2) Settings"
		echo "3) Config"
		echo "4) List physical interfaces"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)	ifconfig -a ;;
		2)	settings $ostype ;;
		3)	config $ostype ;;
		4)
			if [ $ostype = SunOS ]
			then
				dladm show-phys
			else
				echo `pciconf -lv | grep ethernet -B4 | grep class= | cut -d@ -f1`
			fi
			;;
		q)	break ;;
		qq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# replicated limited funtionality of format under freebsd with gpart
dformat () {
	name=$1
	while [ 1 -eq 1 ]
	do
		echo "<---$name--->"
		echo "1) List partitions"
		echo "2) Add partition"
		echo "3) Remove partition"
		echo "4) Edit partition"
		echo "5) Create new partitioning scheme"
		echo "6) Destroy partitioning scheme"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)	gpart show $name ;;
		2)
			read -p "Size: " size
			read -p "Type: " tpe
			gpart add -t $tpe -s $size $name
			;;
		3)
			read -p "Index of the partition: " index
			gpart delete -i $index $name
			;;
		4)
			read -p "Index of the partition: " index
			read -p "Do you want to change the label? (y/n): " check1
			if [ check1 = y ]
			then
				read -p "New label: " label
				gpart modify -i $index -l $label $name
			fi
			read -p "Do you want to change the type? (y/n): " check2
			if [ check2 = y ]
			then
				read -p "New type: " tpe
				gpart modify -i $index -t $tpe $name
			fi
			;;
		5)
			read -p "Scheme: " scheme
			gpart create -s $scheme $name
			;;
		6)
			read -p "Are you shure you want to destroy the partitioning scheme on $name? (y/n): " check
			if [ check = y ]
			then
				gpart -F destroy $name
			fi
			;;
		q)	break ;;
		qq)	main ;;
		qqq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# drives menu
drives () {
	ostype=`uname`
	while [ 1 -eq 1 ]
	do
		echo "<---Drives--->"
		echo "1) List drives"
		echo "2) Select drive"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)
			if [ $ostype = FreeBSD ]
			then
				geom disk list
			else
				echo " " | format | grep -v "Specify disk (enter its number):" | grep c
			fi
			;;
		2)
			if [ $ostype = FreeBSD ]
			then
				read -p "Name of the device (Geom name): " drive
				dformat $drive
			else
				read -p "Name of the device (cXtXdX): " drive
				format $drive
			fi
			;;
		q)	break ;;
		qq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# modify selected options of a zfs filesystem
modify () {
	name=$1
	while [ 1 -eq 1 ]
	do
		echo `zfs get all $name`
		echo "<---Modify $name--->"
		echo "1) Quota"
		echo "2) Reservation"
		echo "3) Mountpoint"
		echo "4) Share NFS"
		echo "5) Compression"
		echo "6) Execution"
		echo "7) Readonly"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)
			read -p "New quota: " quota
			zfs set quota=$quota $name
			;;
		2)
			read -p "New reservation: " reser
			zfs set reservation=$reser $name
			;;
		3)
			read -p "New mountpoint: " mntpnt
			zfs set mountpoint=$mntpnt $name
			;;
		4)
			# the exported filesystem will be automatically added and removed to and from /etc/exports
			read -p "Share NFS (on/off)" share
			zfs set sharenfs=$share $name
			if [ $share = on ]
			then
				mntpnt=zfs get mountpoint $name | grep-v "NAME" | cut -d' ' -f3
				read -p "Export all directories? (y/n): " check
				if [ $check = y ]
				then
					echo "$mntpnt -alldirs -maproot=root" >> /etc/exports
				else
					echo "$mntpnt -maproot=root" >> /etc/exports
				fi
				echo "Entry added to /etc/exports"
			elif [ $share = off ]
				then
					echo "Entry removed from /etc/exports"
					# the added space prevents other subdirectories from being removed
					cat /etc/exports | grep -v "$name " > /etc/exports
			fi
			;;
		5)
			read -p "Compression (on/off)" compr
			zfs set compression=$compr $name
			;;
		6)
			read -p "Allow execution (on/off)" exe
			zfs set exec=$exe $name
			;;
		7)
			read -p "Readonly (on/off)" rdnly
			zfs set readonly=$rdnly $name
			;;
		q)	break ;;
		qq)	main ;;
		qqq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# filesystems menu
filesystem () {
	ostype=`uname`
	while [ 1 -eq 1 ]
	do
		echo "<---Filesystems--->"
		echo "1) Mounted filesystems"
		echo "2) New filesystem"
		echo "3) Modify filesystems"
		echo "4) Remove filesystem"
		echo "5) Persistent filesystems"
		echo "6) Change persistent filesystems"
		echo "7) New persistent filesystem"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)	mount ;;
		2)
			read -p "Name: " name
			read -p "Mountoint: " mntpnt
			read -p "Share NFS (on/off): " share
			read -p "Compression (on/off): " compr
			zfs create -o mountpoint=$mntpnt -o sharenfs=$share -o compression=$compr $name
			;;
		3)
			zfs list
			read -p "Name: " name
			modify $name
			;;
		4)
			read -p "Name: " name
			read -p "Do you really want to delete $name and all its contents? (y/n): " check
			if [ check = y ]
			then
				zfs destroy -r $name
			else
				echo "Nothing has been changed."
			fi
			;;
		5)
			case "$ostype" in
			FreeBSD)	cat /etc/fstab ;;
			SunOS)	cat /etc/vfstab ;;
			AIX)	cat /etc/filesystems ;; # not tested but it should work
			*)	echo "OS could ot be recognized" ;;
			esac
			;;
		6)
			read -p "Which filesystem should no longer be persistent: " name
			read -p "Are you shure? (y/n): " check
			if [ check = y ]
			then
				# the added space prevents other subdirectories from being removed
				case "$ostype" in
				FreeBSD)
					cat /etc/fstab | grep -v "$name " > '/etc/fstab'
					;;
				SunOS)
					cat /etc/vfstab | grep -v "$name " > '/etc/vfstab'
					;;
				AIX)
					cat /etc/filesystems | grep -v "$name " > '/etc/filesystems'
					;;
				*)	echo "OS could ot be recognized" ;;
				esac
			else
				echo "Nothing has been chenged."
			fi
			;;
		7)
			# add a new line to the files in the correct format
			case "$ostype" in
			FreeBSD)
				read -p "Path of the filesystem: " name
				read -p "Mountpoint: " mntpnt
				read -p "Filesystem type: " fstype
				read -p "Options: " opt
				read -p "Dump: " dump
				read -p "#Pass: " pass
				echo "$name	$mnpnt	$fstype	$opt	$dump	$pass" >> 'etc/fstab'
				;;
			SunOS)
				fsck=-
				pass=-
				read -p "Device to mount: " name
				read -p "Device to fsck: " fsck
				read -p "Mountpoint: " mntpnt
				read -p "Filesystem type: " fstype
				read -p "Fsck pass: " pass
				read -p "Mount at boot?: " mntboot
				read -p "Mount options: " mntopt
				if [-z fsck ]
				then
					fsck=-
				fi
				if [ -z pass ]
				then
					pass=-
				fi
				if [ -z mntboot ]
				then
					mntboot=-
				fi
				if [ -z mntopt ]
				then
					mntopt=-
				fi
				echo "$name	$fsck	$mnpnt	$fstype	$pass	$mntboot	$mntopt" >> 'etc/vfstab'
				;;
			*)	echo "OS could ot be recognized" ;;
			esac
			;;
		q)	break ;;
		qq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# menu to edit a single user
useredit () {
	user=$1
	while [ 1 -eq 1 ]
	do
		echo "<---Edit $user--->"
		echo "1) Add to group"
		echo "2) Remove from group"
		echo "3) Change password"
		echo "4) Change home directory"
		echo "5) Change shell"
		echo "6) Lock $user"
		echo "7) Unlock $user"
		exho "q) Exit"
		read -p "> "
		case "$input" in
		1)
			read -p "Groupname: " group
			usermod -a -G $group $user
			;;
		2)
			read -p "Groupname: " group
			grouplist=groups $group | grep -v $group
			usermod -G $grouplist $user
			;;
		3)
			passwd $user
			;;
		4)
			read -p "New home directory: " home
			usermod -d $home $user
			;;
		5)
			read -p "New shell (sh csh ksh bash): " shell
			usermod -s $shell $user
			;;
		6)
			read -p "Do you really want to lock $user? (y/n): " check
			if [ check = y ]
			then
				passwd -l $user
			fi
			;;
		7)
			read -p "Do you really want to unlock $user? (y/n): " check
			if [ check = y ]
			then
				passwd -d $user
			fi
			;;
		q)	break ;;
		qq)	main ;;
		qqq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# menu to manage all users
usermgnt () {
	ostype=`uname`
	while [ 1 -eq 1 ]
	do
		echo "<---User management--->"
		echo "1) List all users"
		echo "2) Add new user"
		echo "3) Remove user"
		echo "4) Edit user"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1)	cat /etc/passwd | cut -d: -f1 ;;
		2)
			if [ $ostype = FreeBSD ]
			then
				adduser
			else
				# replicated functionality of adduser under solaris (and possibly aix -> not tested)
				read -p "Username: " name
				read -p "Home directory: " home
				useradd -d $home -m $name
				read -p "Full name: " fname
				usermod -c $fname $name
				passwd $name
				read -p "UID (Empty for default): " uid
				if [ !-z "$uid" ]
				then
					usermod -u $uid $name
				fi
				read -p "Shell (sh csh ksh bash): " shell
				usermod -s $shell $name
				while [ 1 -eq 1 ]
				do
					read -p "Add $name to another group? (enter only one, leave empty to end loop): " group
					if [ -z "$group" ]
					then
						break
					else
						usermod -a -G $group $user
					fi
				done
			fi
			;;
		3)
			if [ $ostype = FreeBSD ]
			then
				rmuser
			else
				read -p "Username: " name
				if [ !-z "$name" ]
				then
					read -p "Remove home directory (y/n): " rmhome
					if [ $rmhome = y ]
					then
						userdel -r $uname
					else
						userdel $uname
					fi
				else
					echo "No user was removed"
				fi
			fi
			;;
		4)
			read -p "Which user do you want to edit: " user
			if [ $ostype = FreeBSD ]
			then
				# freebsd already provides an interactive editor
				chpass $user
			else
				useredit $user
			fi
			;;
		q)	break ;;
		qq)	main ;;
		qqq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

# user menu
user () {
	ostype=`uname`
	while [ 1 -eq 1 ]
	do
		echo "<---Users--->"
		echo "1) Users currently logged in"
		echo "2) Log out a users"
		echo "3) Log out all users"
		echo "4) User management"
		echo "q) Exit"
		read -p "> " input
		case "$input" in
		1) 	who ;;
		2)
			read -p "Username: " user
			pkill -u $user
			;;
		3)
			# iterate over all users
			# if a username appears more than once the subsequent command will not kill any processes
			users=`who | awk '{print $1}' | xargs`
			for user in $users
			do
				if [ $user = root ] || [ $user = `whoami` ]
				then
					echo "$user will not be logged out"
				else
					pkill -u $user
				fi
			done
			;;
		4)	usermgnt ;;
		q)	break ;;
		qq)	exit 0 ;;
		*)	echo "Invalid input" ;;
		esac
	done
}

echo "Most options require root previleges!"
echo "Caution: Only some options will work under AIX!"
# due to the inability to test more complicated procedures
# simple ones "should" work
main
