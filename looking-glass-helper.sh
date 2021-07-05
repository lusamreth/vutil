#!/bin/bash

# This script was build with lG verion a5194b94ac
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
        echoerr "Require 2args(vertical and horizontal) to generate!"
        exit 1
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
    echo "Shmem Creation..."
    # created with user permission(w+r)
    if [[ ! -d $PATH ]];then 
        #BAHHHHHHH SYSTEMD REEEEEEEEE!
        #idk sorry
        if [[ ! -f $(whereis "systemd-tmpfiles") ]];then
            echo "Using normal mktemp!"
            mktemp -dp /dev/shm/looking-glass
        else
            echo "using systemd-tmpfiles"
            /bedrock/cross/bin/systemd-tmpfiles --create /bedrock/strata/arch/etc/tmpfiles.d/10-looking-glass.conf
        fi
    fi

    echo "Shared memory located at /dev/shm/looking-glass"
}


#<address type='pci' domain='0x0000' bus='0x09' slot='0x04' function='0x0'/>

function CheckQxl {
    qxl_enabled=$(echo -e "$DUMP" | grep "model type='qxl'")

    if [[ -z $qxl_enabled ]];then
        echo "Make sure to set qxl to none after installing intel driver!"
    fi
}

function CheckGvtg {
    echo "Checking if gvtg is enabled..."
    GvtgId=$1
    check_addrs=$(echo -e $DUMP | grep -A 3 "mdev" | grep "uuid='$GvtgId'")

    if [[ -z $check_addrs ]];then
        echoerr  "GVTG errors:"
        echoerr "BadAddress!\nPlease consider rechecking gvtg-address!"
        exit 1
    fi
}

function CheckShmem {
    
    IFS=$'x' read -ra RESOLUTION <<< "$1"
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
            exit 1
        fi
    }
}

function Checkdmabuff {
    echo "checking dma buffer..."
    dma_on=$(echo -e "$DUMP" | grep -i "x-igd-opregion=on")
    if [[ -z $dma_on ]];then
        echoerr "Consider enabling dma-buf!"
        echo "<qemu:arg value="-set"/>"
        echo "<qemu:arg value="device.hostdev0.x-igd-opregion=on"/>"
    fi
}

CheckSpec(){

    DOMAIN="$1"
    DUMP=$(virsh dumpxml $DOMAIN)

    readConfigFile "gvtg"
    Addrs=$(echo ${CONFIG['address']} | echo "fc1cc067-127d-44e6-a1de-b8158d7cc6e8")
    res=$(echo "${CONFIG['res']}" || ${CONFIG['resolution']})

    echo -e "resolution:$res\ngvtg:$Addrs"    
    draw_dash

    CheckGvtg $Addrs
    CheckShmem $res
    Checkdmabuff
    echo "Done!"
}

declare LG_OWNER
declare LG_ARGS
source "$(dirname $(realpath $0))/utility.sh"
SpicyArgs=""

function grabLGConfig {
    readConfigFile "looking-glass-client" 
    
    LG_OWNER=${CONFIG[owner]}
    echo "sll $LG_OWNER"
    #[[ -z  ]]
    #${CONFIG[owner]}
    for key in ${!CONFIG[@]};do
        key_inp=$(echo $key | tr "-" ":")
        Input="$(sudo -u $LG_OWNER looking-glass-client --help  | grep -i "$key_inp" | awk '{print $2}')"

        [[ -z $Input ]] || [[ ${CONFIG[$key]} == false ]] && continue
        # check if boolean value
        if [[ ${CONFIG[$key]} == true ]];then
            LG_ARGS+="$Input "
        else
            LG_ARGS+="$Input=${CONFIG[$key]} "
        fi
    done

    case $(echo ${CONFIG['renderer']} | tr '[:upper:]' '[:lower:]') in
        "opengl")
            render_type="opengl"
        ;;
        "egl" )
            render_type="egl"
        ;;
        *)
            echo "Render type not supported!"
            exit 1
        ;;
    esac

    echo "Render type $render_type"
        # renderer value are all booleans
    readConfigFile $render_type 
    for key in ${!CONFIG[@]};do
        if [[ ${CONFIG[$key]} ]];then
            SpicyArgs+="$render_type:$key "
        fi
    done
}


function StartLG {
    
    draw_dash

    echo "Since this scripts enable gvtg! the default renderer is opengl(igpu)!"
    change_conf "/home/lusamreth/.config/vutil/"
    grabLGConfig &> /dev/null 

    CheckSpec $1
    draw_dash

    echo "==>Arguments : ${LG_ARGS[@]}"
    draw_dash
    echo "LOOKING_GLASS_CLIENT_LOGS:"
    export XDG_RUNTIME_DIR=/dev/shm/looking-glass
    /usr/bin/sudo --preserve-env=XDG_RUNTIME_DIR -u $LG_OWNER looking-glass-client $LG_ARGS
}

if [[ $1 == "start" ]];then
    StartLG $2
fi
