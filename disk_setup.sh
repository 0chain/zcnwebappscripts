hdd=()
ssd=()

ssd_path=/mnt/ssd
hdd_path=/mnt/hdd

# Pick sda type disk
for n in `lsblk  --noheadings --raw | awk '{print substr($0,0,3)}' | uniq -c | grep 1 | awk '{print $2}' | grep -E "(sd.)"`; do
    if [[ `lsblk -o name,rota | grep $n | awk '{print $2}'` == 1 ]]; then
        hdd+=("$n")
    fi
    if [[ `lsblk -o name,rota | grep $n | awk '{print $2}'` == 0 ]]; then
        ssd+=("$n")
    fi
done

# Pick nvme type disk
for n in `lsblk  --noheadings --raw | awk '{print substr($0,0,5)}' | uniq -c | grep 1 | awk '{print $2}' | grep -E "(nvme)[[:digit:]]"`; do
    if [[ `lsblk -o name,rota | grep $n | awk '{print $2}'` == 1 ]]; then
        hdd+=("$n")
    fi
    if [[ `lsblk -o name,rota | grep $n | awk '{print $2}'` == 0 ]]; then
        ssd+=("$n"n1)
    fi
done

for x in ${ssd[@]}; do
  echo ${x}
done

for x in ${hdd[@]}; do
  echo ${x}
done

len_ssd=${#ssd[@]}
len_hdd=${#hdd[@]}

# Resolve the type of disk sda vs nvme
ssd_partition=()
for i in "${ssd[@]}"; do
    ssd_partition+=(/dev/"$i"p1)
done
echo "${ssd_partition[@]}"

hdd_partition=()
for i in "${hdd[@]}"; do
    hdd_partition+=(/dev/"$i"1)
done
echo "${hdd_partition[@]}"

# when there is no additional ssd/hdd
if [[ $len_hdd == 0 ]] && [[ $len_ssd == 0 ]]; then
    echo "no additional ssd or hdd present"
    mkdir -p $hdd_path
    mkdir -p $ssd_path
fi

# when only ssd is present
if [[ $len_hdd == 0 ]] && [[ $len_ssd != 0 ]]; then
    echo "Only SSD"
    if [[ $len_ssd == 1 ]] ; then
        for n in ${ssd[0]}
        do
            if [[ `sudo partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `sudo partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                sudo parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                # partprobe -s
                until sudo mkfs.ext4 /dev/${n}p1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
                sudo mount /dev/${n}p1 /mnt/
                sudo mkdir -p $ssd_path
                sudo mkdir -p $hdd_path
                if grep -q '/mnt/' /etc/fstab; then
                    echo "Entry in fstab exists."
                else
                    if [[ $(blkid /dev/${n}p1 -sUUID -ovalue)  == '' ]]; then
                        echo "Disk is not mounted."
                    else
                        sudo echo "UUID=$(blkid /dev/${n}p1 -sUUID -ovalue) /mnt ext4 defaults 0 0" >> /etc/fstab
                    fi                  
                fi
            fi
        done
    fi

    if [[ $len_ssd > 1 ]] ; then
        for n in ${ssd[@]}
        do
            if [[ `sudo partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `sudo partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                sudo parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                until sudo mkfs.ext4 /dev/${n}p1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                done
            fi
        done
        if [[ `sudo partprobe -d -s /dev/$n` == *"gpt partitions"* ]]; then
            # partprobe -s
            sudo pvcreate ${ssd_partition[@]}<<EOF
y
y
EOF
            echo y | sudo vgcreate ssdvg ${ssd_partition[@]}
            echo y | sudo lvcreate -l 100%FREE -n lvssd ssdvg
            sudo mkfs.ext4 /dev/ssdvg/lvssd -F
            sudo mount /dev/ssdvg/lvssd /mnt
            sudo mkdir -p $ssd_path
            sudo mkdir -p $hdd_path
            if grep -q '/mnt' /etc/fstab; then
                echo "Entry in fstab exists."
            else
                if [[ $(sudo blkid /dev/ssdvg/lvssd -sUUID -ovalue)  == '' ]]; then
                    echo "Disk is not mounted."
                else
                    sudo echo "UUID=$(sudo blkid /dev/ssdvg/lvssd -sUUID -ovalue) /mnt ext4 defaults 0 0" >> sudo /etc/fstab
                fi               
            fi
        fi

    fi
fi

# when only hdd is present
if [[ $len_hdd != 0 ]] && [[ $len_ssd == 0 ]]; then
    echo "Only HDD"
    if [[ $len_hdd == 1 ]] ; then
        for n in ${hdd[0]}
        do
            if [[ `partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                # partprobe -s
                until mkfs.ext4 /dev/${n}1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
                mount /dev/${n}1 /mnt
                mkdir -p /mnt/ssd
                mkdir -p /mnt/hdd
                if grep -q '/mnt' /etc/fstab; then
                    echo "Entry in fstab exists."
                else
                    if [[ $(blkid /dev/${n}1 -sUUID -ovalue)  == '' ]]; then
                        echo "Disk is not mounted."
                    else
                        echo "UUID=$(blkid /dev/${n}1 -sUUID -ovalue) /mnt ext4 defaults 0 0" >> /etc/fstab
                    fi
                    
                fi
            fi
        done
    fi

    if [[ $len_hdd > 1 ]] ; then
        for n in ${hdd[@]}
        do
            if [[ `partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                until mkfs.ext4 /dev/${n}1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
            fi
        done
        if [[ `partprobe -d -s /dev/$n` == *"gpt partitions"* ]]; then
            # partprobe -s
            pvcreate ${hdd_partition[@]}
            vgcreate hddvg ${hdd_partition[@]}
            lvcreate -l 100%FREE -n lvhdd hddvg
            mkfs.ext4 /dev/hddvg/lvhdd
            mount /dev/hddvg/lvhdd /mnt
            mkdir -p /mnt/ssd
            mkdir -p /mnt/hdd
            if grep -q '/mnt' /etc/fstab; then
                echo "Entry in fstab exists."
            else
                if [[ $(blkid /dev/hddvg/lvhdd -sUUID -ovalue)  == '' ]]; then
                    echo "Disk is not mounted."
                else
                    echo "UUID=$(blkid /dev/hddvg/lvhdd -sUUID -ovalue) /mnt ext4 defaults 0 0" >> /etc/fstab
                fi
            fi
        fi

    fi
fi

# when ssd and hdd both are present
if [[ $len_hdd != 0 ]] && [[ $len_ssd != 0 ]]; then
    echo "Both SSD & HDD are present - setup SSD"
    if [[ $len_ssd == 1 ]] ; then
        for n in ${ssd[0]}
        do
            if [[ `partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                # partprobe -s
                until mkfs.ext4 /dev/${n}1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
                mkdir -p /mnt/ssd
                mount /dev/${n}1 /mnt/ssd
                if grep -q '/mnt/ssd' /etc/fstab; then
                    echo "Entry in fstab exists."
                else
                    if [[ $(blkid /dev/${n}1 -sUUID -ovalue)  == '' ]]; then
                        echo "Disk is not mounted."
                    else
                        echo "UUID=$(blkid /dev/${n}1 -sUUID -ovalue) /mnt/ssd ext4 defaults 0 0" >> /etc/fstab
                    fi
                    
                fi
            fi
        done
    fi

    if [[ $len_ssd > 1 ]] ; then
        for n in ${ssd[@]}
        do
            if [[ `partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                until mkfs.ext4 /dev/${n}1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
            fi
        done
        if [[ `partprobe -d -s /dev/$n` == *"gpt partitions"* ]]; then
            # partprobe -s
            mkdir -p /mnt/ssd
            pvcreate ${ssd_partition[@]}
            vgcreate ssdvg ${ssd_partition[@]}
            lvcreate -l 100%FREE -n lvssd ssdvg
            mkfs.ext4 /dev/ssdvg/lvssd
            mount /dev/ssdvg/lvssd /mnt/ssd
            if grep -q '/mnt/ssd' /etc/fstab; then
                echo "Entry in fstab exists."
            else
                if [[ $(blkid /dev/ssdvg/lvssd -sUUID -ovalue)  == '' ]]; then
                    echo "Disk is not mounted."
                else
                    echo "UUID=$(blkid /dev/ssdvg/lvssd -sUUID -ovalue) /mnt/ssd ext4 defaults 0 0" >> /etc/fstab
                fi             
            fi
        fi

    fi
fi


# when ssd and hdd both are present
if [[ $len_hdd != 0 ]] && [[ $len_ssd != 0 ]]; then
    echo "Both SSD & HDD are present - setup HDD"
    if [[ $len_hdd == 1 ]] ; then
        for n in ${hdd[0]}
        do
            if [[ `partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                # partprobe -s
                until mkfs.ext4 /dev/${n}1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
                mkdir -p /mnt/hdd
                mount /dev/${n}1 /mnt/hdd
                if grep -q '/mnt/hdd' /etc/fstab; then
                    echo "Entry in fstab exists."
                else
                    if [[ $(blkid /dev/${n}1 -sUUID -ovalue)  == '' ]]; then
                        echo "Disk is not mounted."
                    else
                        echo "UUID=$(blkid /dev/${n}1 -sUUID -ovalue) /mnt/hdd ext4 defaults 0 0" >> /etc/fstab
                    fi                
                fi
            fi
        done
    fi

    if [[ $len_hdd > 1 ]] ; then
        for n in ${hdd[@]}
        do
            if [[ `partprobe -d -s /dev/$n` = "/dev/$n: msdos partitions" ]] || [[ `partprobe -d -s /dev/$n` = "/dev/$n: gpt partitions" ]] ; then
                echo /dev/$n
                parted -a optimal --script /dev/$n mklabel gpt mkpart primary 0% 100%
                until mkfs.ext4 /dev/${n}1 &> /dev/null
                do
                    echo "Waiting for disk format ..."
                    sleep 1
                done
            fi
        done
        if [[ `partprobe -d -s /dev/$n` == *"gpt partitions"* ]]; then
            # partprobe -s
            mkdir -p /mnt/hdd
            pvcreate ${hdd_partition[@]}
            vgcreate hddvg ${hdd_partition[@]}
            lvcreate -l 100%FREE -n lvhdd hddvg
            mkfs.ext4 /dev/hddvg/lvhdd
            mount /dev/hddvg/lvhdd /mnt/hdd
            if grep -q '/mnt/hdd' /etc/fstab; then
                echo "Entry in fstab exists."
            else
                if [[ $(blkid /dev/hddvg/lvhdd -sUUID -ovalue)  == '' ]]; then
                    echo "Disk is not mounted."
                else
                    echo "UUID=$(blkid /dev/hddvg/lvhdd -sUUID -ovalue) /mnt/hdd ext4 defaults 0 0" >> /etc/fstab
                fi
            fi
        fi

    fi
fi
