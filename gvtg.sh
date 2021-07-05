#!/bin/bash

#guid="621043c8-0532-4a32-b5ae-b7f6d87d2953"
guid="fc1cc067-127d-44e6-a1de-b8158d7cc6e8"
gdom="0000:00"
pcilane="0000:00:02.0"
gtype="i915-GVTg_V5_4"

SYSPATH="/sys/devices/pci${gdom}/${pcilane}/mdev_supported_types/i915-GVTg_V5_4"

#i915-GVTg_V5_1  # Video memory: <512MB, 2048MB>, resolution: up to 1920x1200
#i915-GVTg_V5_2  # Video memory: <256MB, 1024MB>, resolution: up to 1920x1200
#i915-GVTg_V5_4  # Video memory: <128MB, 512MB>, resolution: up to 1920x1200
#i915-GVTg_V5_8  # Video memory: <64MB, 384MB>, resolution: up to 1024x768
#"/sys/bus/pci/devices/pci${gdom}/${pci-lane}/mdev_supported_types/${gtype}/remove"
DISABLEPATH="/sys/bus/pci/devices/$pcilane/$guid/remove"

enableGvtg(){
    if [[ -d "$SYSPATH/devices/$guid" ]]; then
        echo "intel's virtual gpu is already created!"
        echo "GPU DEVICE PATH : $SYSPATH/devices/$guid"
    else
        echo "Enabling gvtg" && echo "${guid}" > "$SYSPATH/create"
    fi
}

disableGvtg(){
    ls $DISABLEPATH
    echo 1 > $DISABLEPATH &&
    echo "Disable gvtg"
}
#EXPECTED
QEMUCMD='
  <qemu:commandline>
    <qemu:arg value="-set"/>
    <qemu:arg value="device.hostdev0.x-igd-opregion=on"/>
    <qemu:arg value="-set"/>
    <qemu:arg value="device.hostdev0.xres=1366"/>
    <qemu:arg value="-set"/>
    <qemu:arg value="device.hostdev0.yres=768"/>
    <qemu:arg value="-set"/>
    <qemu:arg value="device.hostdev0.display=on"/>
    <qemu:arg value="-set"/>
    <qemu:arg value="device.hostdev0.ramfb=on"/>
    <qemu:arg value="-set"/>
    <qemu:arg value="device.hostdev0.driver=vfio-pci-nohotplug"/>
  </qemu:commandline>
'

#MDEV DEVICE
MDEV='
<devices>
<hostdev mode="subsystem" type="mdev" managed="no" model="vfio-pci" display="off">
  <source>
    <address uuid='${GVT_GUID}'/>
  </source>
  <address type="pci" domain="0x0000" bus="0x09" slot="0x00" function="0x0"/>
</hostdev>
</devices>'

DISPLAY='
<video>
  <model type="none"/>
</video>
'
function println {
    echo -e "${1}\n"
}

split_iter=()
function split_newline {
    #Disable glob, any special wrapper 
    set -o noglob         # See special Note, below.
        IFS=$'\n' read -ra spliter <<< $1 
        for i in "${ADDR[@]}"; #accessing each element of array  
        do
            echo $i
        done
        #echo ${#bar[@]}
    set +o noglob         # See special Note, below.
    split_iter=$bar
    #echo -e ${split_iter[1]}
    echo -e $split_iter
}

function provideGvtgInfo(){
    INFO_LINES=(
        "GVT_GUID:\n${guid}\n" #hello
        "QEMUCMD:\n${QEMUCMD}"
        "GVT-DEVICE:\n${MDEV}"
    )

    for((i=0;i<${#INFO_LINES[@]};i++)) {
        echo -e "${INFO_LINES[$i]}"
    }
    echo "Tree:"
    tree /sys/devices/pci0000:00/0000:00:02.0/mdev_supported_types/
}

