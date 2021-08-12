#!/usr/bin/env bash
function listdisks
{
    disk=()
    size=()
    name=()
    while IFS= read -r -d $'\0' device; do
        device=${device/\/dev\//}
        disk+=($device)
        name+=("`cat "/sys/class/block/$device/device/model"`")
        size+=("`cat "/sys/class/block/$device/size"`")
    done < <(find "/dev" -regex '/dev/sd[a-z]\|/dev/vd[a-z]\|/dev/hd[a-z]\|/dev/nvme[0-9]n[0-9]' -print0)
    echo -e "Device Name\tModel\t\t\tSize"
    for i in `seq 0 $((${#disk[@]}-1))`; do
        echo -e "${disk[$i]}\t\t${name[$i]}\t${size[$i]}"
    done
}
function gettarget
{
    echo
    echo "Enter the name of the device you want to install Arch on."
    echo "WARNING! THIS WILL DESTROY ALL THE DATA ON THE DISK!"
    read -p "Device: " TARGET
    TESTFILE="/dev/$TARGET"
    if [ -e $TESTFILE ]; then 
        clear
        TARGET="/dev/$TARGET"
        clear
        partitiondisk
    else
        echo "Target does not exist. Try again or press [ctrl]+[C] to terminate"
        clear
        listdisks
        gettarget
    fi
}
function partitiondisk
{
    sgdisk -Z $TARGET
    sgdisk -n 0:0:+1M -t 0:ef02 -c 0:"bios_boot" $TARGET
    sgdisk -n 0:0:+550M -t 0:ef00 -c 0:"efi_boot" $TARGET
    sgdisk -n 0:0:0 -t 0:8309 -c 0:"LUKS_Volume" $TARGET
    sgdisk -p $TARGET
    partprobe $TARGET
    fdisk -l $TARGET
}
clear
listdisks
gettarget

