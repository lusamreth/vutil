#!/bin/bash

# Success Run gvtg passthrough without building custom qemu (REFRESH_RATE_FIX)
if [[ -z $(whereis looking-glass-client) ]];then
    echo "Missing looking-glass-client!"
    exit
fi

echoerr() { echo -e "$@" 1>&2; }

#Big brain solution
#https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
#unsigned int v; // compute the next highest power of 2 of 32-bit v
#
#v--;
#v |= v >> 1;
#v |= v >> 2;
#v |= v >> 4;
#v |= v >> 8;
#v |= v >> 16;
#v++;

# dec :range from 0 -> 255(8bits)
bin=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

RoundTopower2() {
   v=$1
   #unsigned_int
   v=$((v | v>>1))
   v=$((v | v>>2))
   v=$((v | v>>4))
   v=$((v | v>>8)) 
   v=$((v | v>>16))
   echo $((v+1))
}

function generate_ivshmem {
    RES=($1 $2)
    echo ${RES[@]}
    if [[ ${#RES[@]} < 2 ]];then 
        echo "Require 2args(vertical and horizontal) to generate!"
        exit 0
    fi

    Hpixel=${RES[0]}
    Vpixel=${RES[1]}
    BaseNum=$(($((Hpixel * Vpixel * 2 * 4)) + 2))
    MEM=$((BaseNum / 1024 / 1024))
    Pow2Mem=$(RoundTopower2 $(($MEM + 10)))
    echo $Pow2Mem

}

RESOLUTION=("1080" "1920")

# i used systemd-tmpfiles from bedrock linux
function create_shm {
    PATH="/dev/shm/looking-glass"
    # created with user permission(w+r)
    if [[ -z $PATH ]];then 
        mktemp -d $PATH
    fi
    #systemd-tmpfiles --create /bedrock/strata/arch/etc/tmpfiles.d/10-looking-glass.conf
}


#<address type='pci' domain='0x0000' bus='0x09' slot='0x04' function='0x0'/>

DUMP=$(virsh dumpxml window10ame)

function CheckQxl {
    qxl_enabled=echo -e "$DUMP" | grep "model type='qxl'"

    if [[ -z $qxl_enabled ]];then
        echo "Make sure to set qxl to none after installing intel driver!"
    fi
}

function CheckGvtg {
    GvtgId=$1
    check_addrs=$(echo -e $DUMP | grep -A 3 "mdev" | grep "uuid='$GvtgId'")
    if [[ -z $check_addrs ]];then
        echoerr "BadAddress!\nPlease consider rechecking gvtg-address!"
        echo false
        exit 0
    fi
}

function CheckShmem {
    REQUIRED_MEM=$(generate_ivshmem ${RESOLUTION[@]})

    echo "Checking Spec..."
    SPEC=("<shmem name='looking-glass'>"
    "<model type='ivshmem-plain'/>"
    "<size unit='M'>$REQUIRED_MEM</size>"
    )

    FETCHED="$(echo -e "$DUMP" | grep -i -A 2 "<shmem name='looking-glass'>")"
    for((i=0;i<${#SPEC[@]};i++)){
        TEST=$(echo -e "$FETCHED" | grep -i "${SPEC[i]}")
        if [[ -z $TEST ]];then
            
            echoerr "Xml doesn't match with spec!:"
            echoerr "TEST :$TEST"
            echoerr "Spec : ${SPEC[i]}"
            exit 0
        fi
    }
    echo "Done!"
}

function Checkdmabuff {
    dma_on=echo -e "$DUMP" | grep -i "x-igd-opregion=on"
    if [[ -z $dma_on ]];then
        echoerr "Consider enabling dma-buf!"
        echo "<qemu:arg value="-set"/>"
        echo "<qemu:arg value="device.hostdev0.x-igd-opregion=on"/>"
    fi
}

CheckSpec(){
    CheckGvtg
    CheckShmem
    Checkdmabuff
}

function StartlG {
    DOMAIN=$1
    start_err=$(virsh start $DOMAIN 2 2>&1 >> /dev/null)
    if [[ -n $start_err ]];then
        echoerr "Cannot Start virtual machine"
        echoerr $start_err
    fi
    readPrompt "Running with Fullscreen?" 
    echo "Since this scripts enable gvtg! the default renderer is opengl(igpu)!"
    EscapeChar=69 # <- F12
    ReadConfigFile "looking-glass-client"
    for key in ${!$CONFIG[@]};do
        if ${CONFIG[vsync]}
    done
    looking-glass-client -F -g OpenGL -m $EscapeChar opengl:vsync
}

StartlG
