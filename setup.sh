#!/bin/bash 

echo "Welcome To Vutil setup"
if [[ $(id -u $(whoami)) != 0 ]];then
    echo "This script requires root escalation!"
    exit 1
fi

target="/usr/bin"
dependency=(
    "qemu_util.sh"
    "looking-glass-helper.sh"
    "qemu_util_man.txt"
    "utility.sh"
    "gvtg.sh"
)

PROGRAM_DIR=$(dirname $(realpath $0))
source "$PROGRAM_DIR/utility.sh"
dependencyCheck ${dependency[@]}
Files=(${dependency[@]} "vutil") 

echo -e "Dependencies: \n${dependency[@]}"
echo "Main entry : vutil"
echo "Program directory : $PROGRAM_DIR"

GlassInstall() {
    ln -s "$PROGRAM_DIR/looking-glass-helper.sh" "$target/glass-helper"
    chmod +x "$target/glass-helper"

}

Install() {
    for file in ${Files[@]} 
    do
        if [[ ! -f "/usr/bin/$file" ]];then
            echo "Linking file : $file"
            ln -s "$PROGRAM_DIR/$file" $target
        fi
    done
    echo "Installing done!"
    exit 0
}

Remove(){
    for file in ${Files[@]} 
    do
        if [[ -f "/usr/bin/$file" ]];then
            echo "Unlinking file : $file"
            unlink "$target/$file" 
        fi
    done
    echo "Succesfully remove vutil!"
    exit 0
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
       #read -p "Command please: $prompt_text" answer
       read -p "$prompt_text" answer
       echo -e "---------------------------"
       case $answer in 
           "install" | "1" )
               GlassInstall
               Install
            ;;
           "uninstall" | "2" )
               Remove
            ;;
           "exit" | 0 )
               echo "Exiting installer"
               exit 1
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
