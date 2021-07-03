#!/bin/bash 

echo "Welcome To Vutil setup"
if [[ $(id -u $(whoami)) != 0 ]];then
    echo "This script requires root escalation!"
    exit 1
fi

target="/usr/bin"
dependency=(
    "qemu_util.sh"
    "qemu_util_man.txt"
    "gvtg.sh"
    "looking-glass-helper.sh"
)

PROGRAM_DIR=$(dirname $(realpath $0))
source "$PROGRAM_DIR/utility.sh"
dependencyCheck ${dependency[@]}
Files=(${dependency[@]} "vutil") 

echo -e "Dependencies: \n${dependency[@]}"
echo ${Files[@]}
echo "Program directory : $PROGRAM_DIR"

Install() {
    for file in ${Files[@]} 
    do
        echo $file
        if [[ ! -f "/usr/bin/$file" ]];then
            ln -s "$PROGRAM_DIR/$file" $target
        fi
    done
}

Remove(){
    for file in ${Files[@]} 
    do
        if [[ ! -f "/usr/bin/$file" ]];then
            echo "Unlinking file : $file"
            unlink "$PROGRAM_DIR/$file" $target
        fi
    done
}

EXIT=0
ExitInstaller(){
   echo "Ctrl-c,exiting installer..." 
   echo "Reversing linked file..."
   Remove
   ((++EXIT))
   exit 2
}

echo -e "---------------------------"
#no arguments
if [[ -z $1 ]];then
   while [[ $EXIT == 0 ]];do

       prompt_text=$1
       # trap Ctrl-c
       echo "Menu:"
       texts=("0.exit" "1.install" "2.uninstall" )
       for txt in "${texts[@]}" 
       do
           echo -ne "$txt\n"
       done
       read -p "Command please: $prompt_text" answer

       case $answer in 
           "install" | 1 )
            ;;
           "uninstall" | 2 )
            ;;
           "exit" | 0 )
            ;;
       esac
       trap "ExitInstaller" 2
   done
fi

case $1 in
    "--install" | "-i")
        Install
        ;;
    "--uninstall" | "-r")
        Remove
        ;;
    *)
        echo "DUNNO WHACHU MEAN!"
        exit 1
        ;;
esac

# linking dependency
