
#! /bin/sh

os_check(){
	if [ -e /etc/redhat-release ]; then
		READHAT=`cat /etc/redhat-release | cut -d' ' -f1`
	else
		DEBIAN=`cat /etc/issue | cut -d' ' -f1`
	fi
	if [ "$READHAT" ==  "CenOS" -o "$REDHAT" == "Red" ]; then
		P_M = yum
	elif [ "$DEBIAN" == "Ubuntu" -o "$DEBIAN" == "ubuntu" ];then
		P_M = apt-get
	else
		Operating system does not support
		exit 1
	fi	
}

if [ $LOGNAME != root ]; then
	echo "Please use the root account operation"
	exit 1
fi

# &> means both >> and 2>
# if which iostat is null, then install iostat package
if ! which iostat &> /dev/null; then 
	echo "iostat command not found , now the install."
	sleep 1
	os_check
	$P_M install sysstat -y
	echo "----------------------------------------------------------------"
fi

while true;do
	select input in cpu_load disk_load disk_use disk_inode mem_use tcp_status cpu_top10 mem_top10 traffic JDK Tomcat nodeJs quit;do
		case $input in
			cpu_load)
			#CPU usage and load
			echo "-------cpu-----------------------------------------"
			i=1
			while [[ $i -le 3 ]];do
				echo -e "\033[32m refered value${i}\033[0m"
				UTIL=`vmstat | awk '{if(NR == 3) print 100-$15"%"}'`
				USER=`vmstat | awk '{if(NR == 3) print $13"%"}'`
				SYS=`vmstat | awk '{if(NR == 3) print $14"%"}'`
				IOWAIT=`vmstat | awk '{if(NR == 3) print $16"%"}'`
				echo "Util: $UTIL"
				echo "User use: $USER"
				echo "System use: $SYS"
				echo "I/O wait: $IOWAIT"
				i=$(($i+1))
				sleep 1
			done
			echo "------------------------------------------------"
			break
			;;
			disk_load)
			# DISK I/O load
			echo "-------------------------------------------------"
			i=1
			while [[ $i -le 3 ]]; do
				echo -e "\033[32m refered value${i}\033[0m"
				UTIL=`iostat -x -k | awk '/^[v|s]/{OFS=": ";print $1,$NF"%"}'`
				READ=`iostat -x -k | awk '/^[v|s]/{OFS=": ";print $1,$6"KB"}'`
				WRITE=`iostat -x -k | awk '/^[v|s]/{OFS=": ";print $1,$7"KB"}'`
				IOWAIT=`vmstat | awk '{if(NR == 3)print $16"%"}'`
				echo -e "Util:"
				echo -e "${UTIL}"
				echo -e "I/O Wait:$IOWAIT"
				echo -e "Read/s:\n$READ"
				echo -e "Write/s:\n$WRITE"
				i=$(($i + 1))
				sleep 1
			done
			echo "--------------------------------------------------"
			break
			;;
			disk_use)
			# DISK Use rate
			DISK_LOG=/tmp/disk_use.tmp
			# &&/\dev can't understand
			DISK_TOTAL=`fdisk -l | awk '/^Disk.*bytes/&&/\/dev/{printf $2 " ";printf "%d", $3;print "GB"}'`
			USE_RATE=`df -h | awk '/^\/dev/{print int($5)}'`
			for i in $USER_RATE; do
				if [ $i -gt 90 ]; then
					PART=`df -h | awk  '{if(int($5) == "$i")} print $6'`
					echo "$PART = ${i}%" >> $DISK_LOG
				fi
			done
			echo "-----------------------------------------------------"
			echo -e "Disk total:\n${DISK_TOTAL}"
			if [ -f $DISK_LOG ]; then
				echo "----------------------------------------------"
				cat $DISK_LOG
				echo "----------------------------------------------"
				rm -f $DISK_LOG
			else
				echo "----------------------------------------------"
				echo "Disk use rate no than 90% of the partion"
				echo "----------------------------------------------"
			fi
			break
			;;
			disk_inode)
			# DISK inode use rate
			INODE_LOG=/tmp/inode_use.tmp
			INODE_USE=`df -i | awk '/^\/dev/ {print int($5)}'`
			for i in $INODE_USE;do
				if [ $i -gt 90 ]; then
					PART=`df -h | awk '{if(int($5) == "$i") print $6}'`
					echo "$PART = ${i}%" >> $INODE_LOG
				fi
			done
			if [ -f $INODE_LOG ]; then
				echo "----------------------------------------------"
				rm -f $INODE_LOG
			else
				echo "-----------------------------------------------"
			 	echo "Inode use rate no than 90% of the partition"
				echo "-----------------------------------------------"
			fi
			break
			;;
			mem_use)
			# MEMORY use rate
			echo "-------------------------------------------------------"
			MEM_TOTAL=`free -m | awk '{if(NR == 2) printf "%.1f", $2/1024}END{print "G"}'`
			USE=`free -m | awk '{if(NR == 3) printf "%.1f", $3/1024}END{print "G"}'`
			FREE=`free -m | awk '{if(NR == 3) printf "%.1f", $4/1024}END{print "G"}'`
			CACHE=`free -m | awk '{if(NR == 2) printf "%.1f", ($6+$7)/1024}END{print "G"}'`
			echo -e "Total:$MEM_TOTAL"
			echo -e "Use:$USE"
			echo -e "Free:$FREE"
			echo -e "Cache:$CACHE"
			echo "--------------------------------------------------------"
			break
			;;
			tcp_status)
			#status of internet
			echo "---------------------------------------------------------"
			COUNT=`netstat -antp | awk '{status[$6]++} END{for(i in status) print i,status[i]}'`
			echo -e "TCP connection status:\n$COUNT"
			echo "----------------------------------------------------------"
			;;
			cpu_top10)
			# top10 process using CPU
			echo "---------------------------------------------------------"
			CPU_LOG=/tmp/cpu_top.tmp
			i = 1
			while [[ $i -le 3 ]]; do
				ps -aux | awk '{if($3 > 0.1) {{printf "PID: "$2" CPU: "$3"% "}for(i=11;i<=NF;i++) if(i == NF) printf $i"\n";else printf $i}}' |  sort -k4 -nr |head -10 > $CPU_LOG
				if [[ -n `cat $CPU_LOG` ]]; then
					echo -e "\033[32m refered${i}\033[0m"
					cat $CPU_LOG 
					> $CPU_LOG
				fi
				i=$(($i+1))
				sleep 1
			done
			echo "-----------------------------------------------------------"
			break
			;;
			mem_top10)
			# top10 process using MEMORY
			echo "-----------------------------------------------------------"
			MEM_LOG=/tmp/mem_top.tmp
			i=1
			while [[ $i -le 3 ]];do
				ps -aux | awk '{if($4 > 0.1) {{printf "PID: "$2" Memory:"$4"% "}for(i=11;i<=NF;i++) if(i == NF) printf $i"\n";else printf $i}}' | sort -k4 -nr | head -10 > $MEM_LOG
				if [[ -n `cat $MEM_LOG` ]]; then
					echo -e "\033[32m refered value${i}\033[0m"
					cat $MEM_LOG
					> $MEM_LOG
				else
					echo "No process using the Memory."
					break
				fi
				i=$(($i + 1))
				sleep 1
			done
			echo "-----------------------------------------------------------"
			break
			;;
			traffic)
			# view internet flow
			while true; do
				read -p "Please enter the network card name(eth[0-9] or em[0-9]):" eth
				if [[ `ifconfig | grep -c "\<$eth\>"` -eq 1 ]]; then
					break
				else
					echo "input format error or Don't have the card name. please input again."
				fi
			done
			echo "-----------------------------------------------------------"
			echo -e "In-------------------------------Out"
			i=1
			while [[ $i -le 3 ]]; do
				OLD_IN=`ifconfig $eth | awk -F'[: ]+' '/bytes/{if(NR == 8) print $4;else if(NR == 5)print $6}'`
				OLD_OUT=`ifconfig $eth | awk -F'[: ]+' '/bytes/{if(NR == 8) print $9;else if(NR == 7)print $6}'`
				NEW_IN=`ifconfig $eth | awk -F'[: ]+' '/bytes/{if(NR == 8) print $4;else if(NR == 5)print $6}'`
				NEW_OUT=`ifconfig $eth | awk -F'[: ]+' '/bytes/{if(NR == 8) print $9;else if(NR == 7)print $6}'`
				IN=`awk 'BEGIN{printf "%.1f\n", '$((${NEW_IN}-${OLD_IN}))'/1024/128}'`
				OUT=`awk 'BEGIN{printf "%.1f\n", '$((${NEW_OUT}-${OLD_OUT}))'/1024/128}'`
				echo "${IN}MB/s ${OUT}MB/s"
				i=$(($i+1))
				sleep 1
			done
			echo "-------------------------------------------------------------"
			break
			;;
			JDK)
			# show info Of JDK
			echo "---------------------------------------------------------------"
			path=`locate -r /bin/java | awk '{if(NR == 1) print}'`
			if [[ -z $path ]];then
				read -p "Not install JDK, do you want install now?[y/n]" flag
				if [ $flag == y| $flag == Y ];then
					echo "Start install from Java website"
					wget https://www.oracle.com/java/technologies/javase/javase-jdk8-downloads.html#license-lightbox
					tar -zxvf ./jdk-8u251-linux-i586.tar.gz
					echo "install successfully!"
				else
					echo "Not install yet"
				fi
			else
				echo "Your JDK information:"
				$path -version
			fi
			echo "---------------------------------------------------------------"
			break
			;;
			Tomcat)
			# find the excute path
			path=`locate -r .*tomcat.*/bin | awk '{if(NR==1) print}'`
			if [ -z $path ];then
				read -p "Not install tomcat, do you want install now?[y/n]" flag
				if [ $flag == y | $flag == Y  ]; then
					echo "Start install from apache websiate!"
					wget https://mirrors.cnnic.cn/apache/tomcat/tomcat-9/v9.0.7/bin/apache-tomcat-9.0.34.tar.gz
					tar -zxvf ./apache-tomcat-9.0.34.tar.gz
					echo "Install successfully!"
				else
					echo "Not install yet"
				fi
			else
				echo "Your tomcat information:"
				sh ${path}/version.sh
			fi
			echo "-----------------------------------------------------------------"
			break
			;;
			nodeJs)
			# show info of nodeJS
			echo "----------------------------------------------------------------"
			path=`locate -r bin/node | awk '{if(NR == 1) print}'`
			if [[ -z $path ]]; then
				read -p "Not install nodeJS, do you want install now?[y/n]" flag
				if [ $flag == y | $flag == Y  ]; then
					echo "Start install from nodeJS websiate!"
					wget https://nodejs.org/dist/v10.9.0/node-v10.9.0-linux-x64.tar.xz
					tar -zxvf ./node-v10.9.0-linux-x64.tar.xz 
					echo "Install successfully!"
				else
					echo "Not install yet"
				fi

			else
				echo "Your NodeJS information:"
				${path} -v
			fi
			echo "------------------------------------------------------------------"
			break
			;;
			quit)
				exit 0
			;;
			*)
			echo "------------------------------------------------------------------"
			echo "please enter number"
			echo "-------------------------------------------------------------------"

		esac
	done
done
			


			
			 












