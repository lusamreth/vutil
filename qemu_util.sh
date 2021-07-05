#!/bin/bash 


# All component in this script require root escalation
# plz thoroughly review it

#for decore
#underline=`tput smul`
#nounderline=`tput rmul`
#bold=`tput bold`
#normal=`tput sgr0`

DOMAIN="window10ame"
dir_path=$(dirname $(realpath $0))
source "$dir_path/utility.sh" 2>&1 > /dev/null

function set_pair_arg {
    SET='-set'
    # set the argument
    virt-xml $DOMAIN --edit --confirm --qemu-commandline=$SET &&
    virt-xml $DOMAIN --edit --confirm --qemu-commandline=$1
}


#<qemu:arg value='-audiodev'/>
#<qemu:arg value='pa,id=pa1,server=/run/user/1000/pulse/native'/>

#if [ $1 == "--appendaudio" ] then
#   doas virt-xml $DOMAIN --edit --confirm --qemu-commandline="-audiodev"
#fi

#INSTRUCTIONS=$1
#INS_LEN=${#INSTRUCTIONS[@]}
#if [[ $1 == "--append-instructions" ]]
#    then 
#    for ((i = 0 ; i < $INS_LEN ; i++)); do
#        echo $INSTRUCTIONS[$i]
#        set_pair_arg $INSTRUCTIONS[$i]
#    done
#fi

HugepageLoc="/mnt/hugepages"
NrHp="/proc/sys/vm/nr_hugepages"

AllocateHugepage() {

    SYS_RAM=8 # <- 8GB
    mb_factor=1024 # from G -> M

    MAX_RAM=$(expr $SYS_RAM \* $mb_factor ) 
    pagesize=2 # <- MB
    MAX_PAGES=$(( MAX_RAM / pagesize))

    Hugepages=$1

    if [[ $Hugepages -gt $MAX_PAGES ]];then 
        echoerr "The allocated ram is greater than available ram!"
        return;
    fi

    echo "Allocating hugepages..."
    #echo $Hugepages >> "${NrHp}"
    sysctl vm.nr_hugepages=$Hugepages >/dev/null  2>&1
    AllocPage=$(cat $NrHp)
    Retry=0
    
    #Retry 1000 times
    while [[ $Hugepages != $AllocPage ]] && [[ $Retry < 1000 ]]
    do
        echo 1 > /proc/sys/vm/compact_memory
        # 3 means destroying all caches
        echo 3 > /proc/sys/vm/drop_caches
        # not interested in detail
        sysctl vm.nr_hugepages=$Hugepages >/dev/null  2>&1
        let Retry+=1
    done
    if [[ $Hugepages -ne $AllocPage ]];then 

        echoerr "Allocated pages : $AllocPage < target : $Hugepages"
        echoerr "Cannot allocate hugepage for some reason!"
        # prevent freezing
        echo "Reverting back..."
        sysctl vm.nr_hugepages=0 >/dev/null  2>&1
        sleep 1s
        exit 1
    fi
    #sysctl vm.nr_hugepages=$1
    if [ -d $HugepageLoc ] 
        then echo "Hugepage location is already made!"
    else
        mkdir $HugepageLoc
    fi

    echo "Mount hugetlbfs to ${HugepageLoc}"
    mount -t hugetlbfs -o pagesize=2M none $HugepageLoc

    echo "Restarting libvrit"
    sv restart libvirtd >/dev/null 2>&1
}

#echo "12 23 11" | awk '{split($0,a); print a[3]; print a[2]; print a[1]}'
#echo "12,23,11" | awk '{split($0,a,'{delim}'); print a[3]; print a[2]; print a[1]}'
ResetHugepage() {
    VirtId=$(pidof libvirt)
    #VirtId=$(virsh list --all | grep -i $DOMAIN | awk '{split($0,a);print a[3]}')
    if [[ $VirtId -ne " " ]]
        then echo "The virtual machine is still running!"
        echoerr "Cannot deallocate hugepages!"
        return
    fi
    echo "Resetting Hugepages..."
    sysctl vm.nr_hugepages=0 >/dev/null  2>&1
    sleep 0.2s

    if [[ $(cat $NrHp) != 0 ]];then
        echoerr "Failed to reset hugepages! resources are busy"
        return
    fi

    if [[ -f $HugepageLoc ]];then
        umount $HugepageLoc
    fi
    #rm -r $HugepageLoc
}


MountPulseaudio() {
    
    # because the script is called from current user 
    # pulse server is run under user permission not as a system
    # therefore we need switch to current user permission

    PA_SERVER=()
    default_pa="/run/user/1000/pulse/native"
    if [[ -n $1 ]];then
        default_pa=$1
    fi

    FetchPA() {
        if [[ -f "/run/user/1000/pulse/pid" ]];then
            echo "pulseaudio is already enable!"
            PA_SERVER[0]="server=unix:$default_pa"
        else
            echo "scanning /tmp file..."
            tmp_pulse_file=$(ls /tmp/ | grep "pulse")
            PA_SERVER[0]="/tmp/$tmp_pulse_file"
        fi
    }

    FetchPA

    if [[ ${#PA_SERVER[@]} -gt 1 ]];then
        echo "Error! Pa server need to be only one!"
        return 
    fi

    echo "scannin domain $DOMAIN"
    DUMP="$(virsh dumpxml $DOMAIN)"
    existed_server=$(echo -e "$DUMP" | grep "server=unix:")
    DEV=$(echo -e "$DUMP" | grep -i "ich9-intel-hda")

    if [[ -z "$DEV" ]];then
        function AppendingHDA {
            echo "Inserting.."
            virt-xml $DOMAIN --edit --qemu-commandline="ich9-intel-hda,bus=pcie.0,addr=0x1b" &&
            virt-xml $DOMAIN --edit --qemu-commandline="hda-micro,audiodev=hda" &&
            echo "Completed"
        }

        readPrompt "Setting ich9-intel-hda as audio device in order to work! [y/n]" AppendingClosure
    fi

    if [[ -z $existed_server ]];then
        function AppendingPA {
            echo "Appending pulseaudio server..."
            virt-xml $DOMAIN --edit --qemu-commandline="server=unix:$PA_SERVER[0]" 
        }
        readPrompt "Require pulseaudio server! " AppendingPA 
    fi

    IFS=$',' read -ra CHUNKS <<<  $existed_server

    extracted_server=$(echo ${CHUNKS[2]} | sed "s/'\/>//g")
    different=$(diff <(echo "${PA_SERVER[0]}") <(echo $extracted_server))

    if [[ -n $different ]];then
        echo "Spot a different between xml and the running server!"
        echo $different
    fi
    
}

#<qemu:arg value="-device"/>
#<qemu:arg value="ich8-intel-hda,bus=pcie.0,addr=0x1b"/>

#if [ $1="--hugepage" ] 
#    then AllocateHugepage 4
#fi

reduce_jittering () {
    sysctl vm.stat_interval=120
    sysctl -w kernel.watchdog=0
    # THP can allegedly result in jitter. Better keep it off.
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    # Force P-states to P0
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
}
TOTAL_CORES='0-7'
VIRT_CORES='0-5'

#cset to isolate core
shield_vm() {
    cset set -c $TOTAL_CORES -s machine.slice
    # Shield two cores cores for host and rest for VM(s)
    cset shield --kthread on --cpu $VIRT_CORES
}

TOTAL_CORES_MASK=FFF            # 0-11, bitmask 0b111111111111
HOST_CORES="6-7"

#great guide for cpu shielding
#https://null-src.com/posts/qemu-optimization/post.php
unshield_vm() {
    echo $TOTAL_CORES_MASK > /sys/bus/workqueue/devices/writeback/cpumask
    cset shield --reset
}
function print_help {
    #runtime_dir=$(pwd)
    runtime_dir="/home/lusamreth/vutil"
    cat "$runtime_dir/qemu_util_man.txt"     
}

function startHook {
    
    GVTG_PATH=$1
    echo "setting up virtual machine"

    draw_dash
    DEFAULT_HP=2056
    HP=$1
    
    if [[ -z $HP ]];then
        HP=$DEFAULT_HP
    fi

    echo "hugepage point to default $HP"
    MountPulseaudio
    draw_dash
    ResetHugepage 
    # prevent race condition
    
    wait $(jobs -p)
    draw_dash
    AllocateHugepage $HP 
    enableGvtg

}

stopHook() {
    echo "Initializing stopping hook!"
    ResetHugepage
    disableGvtg
    wait $(jobs -p)
}

function stop_vm {
    domain=$1
    echo "Shutting down vm $domain..."
    timeout -k 30 20 virsh shutdown $domain
    echo "Sucessfully shutdown"
}

function destroyVm {
    domain=$1
    completed=false
    echo "forcing off vm $domain..."
    timeout -k 30 20 virsh destroy $domain && completed=true
    echo $completed
    stopHook
    echo "Sucessfully forced shutdown"
}


#<qemu:arg value="-audiodev"/>
#<qemu:arg value="pa,id=audio1,server=/run/user/1000/pulse/native"/>
#get pulseaudio server string
#pactl info | grep 'Server String' | awk '{print $3}
#flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify
#doas sysctl vm.nr_hugepages=4
#  <memoryBacking>
#    <hugepages>
#      <page size="1048576" unit="KiB"/>
#    </hugepages>
#  </memoryBacking>
#virsh setmem UAKVM2 4G
