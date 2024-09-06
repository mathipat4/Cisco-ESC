#!/bin/bash

source_dir="/var/BackupRestore/"
destination_dir="/var/BackupRestore/Backup/"
date=`date +"%Y_%m_%d_%H_%M_%S"`
hostname=`hostname`
password="Csco@123"
op_mode_cmd="sudo escadm op_mode show"
op_mode=`echo "$password" | sudo -S -p "" $op_mode_cmd 2>&1 | awk -F '= ' '{print $2}'`

if [ ! -d "$source_dir" ]; then
    sudo mkdir -p "$source_dir"
    if [ $? -ne 0 ]; then
        echo "Failed to create source directory: $source_dir"
        exit 1
    fi
fi

if [ ! -d "$destination_dir" ]; then
    echo "Creating backup dir"
    sudo mkdir -p "$destination_dir"
    sudo chmod 777 "$destination_dir"
    if [ $? -ne 0 ]; then
        echo "Failed to create destination directory: $destination_dir"
        exit 1
    fi
fi
sudo find /var/tmp/ -type f -mtime +8 -name "esc_backup*" -exec rm -f {} \;
sudo find /var/BackupRestore/Backup/ -type f -mtime +8 -name "*" -exec rm -f {} \;

cd $source_dir
echo "Changing mode to Maintenance"
sudo escadm op_mode set --mode=maintenance
if [ $? -eq 0 ]; then
        op_mode=`echo "$password" | sudo -S -p "" $op_mode_cmd 2>&1 | awk -F '= ' '{print $2}'`
        echo $op_mode
        if [ "${op_mode}" == "MAINTENANCE" ];then
                echo "In MAINTENANCE mode; Backup started"
                sudo escadm backup --file ${hostname}_${date}_backup.tar.bz2
                sudo mv ${hostname}_${date}_backup.tar.bz2 ${destination_dir}
                if [ $? -ne 0 ]; then
                        echo "copy failed!"
                        exit 0
                fi
                echo "Backup Done, Changing mode to OPERATION"
                sudo escadm op_mode set --mode=operation
                op_mode=`echo "$password" | sudo -S -p "" $op_mode_cmd 2>&1 | awk -F '= ' '{print $2}'`
                if [ "${op_mode}" == "OPERATION" ];then
                echo "BACKUP done successfully, Changed mode from MAINTENANCE to OPERATION!!"
                else
                echo "Failed changing mode to OPEARTION"
                fi
        else
        echo "Node not in Maintainence mode"
        fi
else
echo "Failed to change mode to maintainence"
fi
sudo /opt/cisco/esc/confd/bin/netconf-console --host 127.0.0.1 --port 830 -u admin -p Csco@123 --get-config > /home/admin/${hostname}_${date}_ESC_Config.xml
sudo mv /home/admin/${hostname}_${date}_ESC_Config.xml /var/BackupRestore/Backup/
cd /opt/cisco/vnfs/config
sudo cp *.cfg *.txt *.sh /var/BackupRestore/Backup/
cd $destination_dir
sudo mkdir BGLR_101_Backup_${date} | sudo mv * BGLR_101_Backup_${date}/
sudo tar -cvzf BGLR_101_Backup_${date}.tar.gz BGLR_101_Backup_${date}/

echo "Deleting Unzipped Directory"
sudo rm -rf BGLR_101_Backup_${date}
echo "Backup Done ! Your Backup File is at ${destination_dir}"
