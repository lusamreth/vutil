#!/bin/env bash

echoerr() { echo -e "$@" 1>&2; }

function diffs() {
        diff "${@:3}" <(sort "$1") <(sort "$2")
}

function readPrompt {
    while true
    do
      # (1) prompt user, and read command line argument
      prompt_text=$1
      read -p "$prompt_text" answer
      command=$2
      # (2) handle the input we were given
          case $answer in
           [yY]* ) 
                   eval $command
                   break;;

           [nN]* ) exit;;

           * )     echoerr "bruh, just enter Y or N, omg!.";;
           esac
    done
}

function dependencyCheck {
    # take all arg
    dependencies=("$@")
    PROGRAM_DIR=$(dirname $(realpath $0))
    i=0
    cache_err_msg=()
    for((i=0;i<${#dependencies[@]};i++)) {
        dep=${dependencies[i]}
        path="$PROGRAM_DIR/$dep"
        if [[ "$dep" == *.sh ]];then
            source "$path" 2>&1 > /dev/null
        fi

        if [[ -n $(ls -l $path 2>&1 >/dev/null ) ]];then
            cache_err_msg[$i]="Missing dependency ${dep}"
            i=$((i+1))
        fi 
    }
    if [[ ${#cache_err_msg[@]} > 0 ]];then
        echoerr "$cache_err_msg[@]"
    fi
}
configPath=""

dir=$(dirname $(realpath $(echo $0)))
declare -A CONFIG
function readConfigFile {
    
    echo "Reading Config..."
    Conf_dir=$configPath
    if [[ -z $configPath ]];then
        Conf_dir="$HOME/.config/vutil"
    fi
    if [[ ! -f "$Conf_dir/config.ini" ]];then
        echo "No config files!"
    fi

    FETCH_SECTION=$1
    SECs=($(crudini --get "$Conf_dir/config.ini" $FETCH_SECTION))
    # generate dictionary 
    CONFIG=() #// reset dictionary
    for key in "${!SECs[@]}"; do
        echo ${SECs[key]}
        CONFIG["${SECs[key]}"]="$(crudini --get "$Conf_dir/config.ini" $FETCH_SECTION ${SECs[key]})"
    done
}
function change_conf {
    configPath=$1
}

function WriteSDLIni {
    WordBuffer=$1   

    HEX=${WordBuffer[0]}
    NUM=${WordBuffer[1]}
    HEAD=${WordBuffer[2]}

    echo    "[$HEAD]" >> "$dir/SDLS.ini"
    echo    "HEX=$HEX"     >> "$dir/SDLS.ini"
    echo    "NUM=$NUM"     >> "$dir/SDLS.ini"
    echo -e "\n"        >> "$dir/SDLS.ini"
}

function convertRawSDLtoIni {
    RAWFILE=$1
    declare -a myarray
    declare -a WordBuffer

    let i=0
    let internal_counter=0

    while IFS=$'\n' read -r line_data; do
        case $line_data in
            [0-9]* )
                ((++internal_counter))
                pos=1
                IsHex=$(((16#$line_data)) 2>&1 >/dev/null)
                if [[ -n $IsHex ]];then
                    pos=0
                fi

                WordBuffer[$pos]=$line_data
                ;;
            "" )
                continue;;
                #echo "whitespace";;
            *)
                ((++internal_counter))
                sec=$(echo "$line_data" | tr "_" "-" | tr '[:upper:]' '[:lower:]')
                echo $sec
                WordBuffer[2]=$sec
                WriteSDLIni $WordBuffer
                ;;
        esac

        echo ${#WordBuffer[@]}
        if [ $internal_counter == 3 ];then
            internal_counter=0
            #echo "WoRD BUFFERR ${WordBuffer[@]}"
        fi

        ((++i))
    done < $RAWFILE
}

function findRawSDL {

    if [[ ! -f "$dir/SDLS.ini" ]] ;then
        if [[ ! -f "$dir/RAWSDLScanCode.txt" ]];then
            echoerr "Please copy the table from https://wiki.libsdl.org/SDLScancodeLookup"
            exit 1
        fi
        convertRawSDLtoIni "$dir/RAWSDLScanCode.txt"
    fi
}

#ConvertRawSDLtoIni "$dir/RAWSDLScanCode.txt"
function lookUpCode {
    findRawSDL
    keystroke="$1"
    #cat "$dir/SDLS.ini"

    cfg_parser "$dir/SDLS.ini"
    PREFIX="sdl-scancode-$keystroke"
    sleep 0.5s
    crudini --get "$dir/SDLS.ini" $PREFIX num
}

function draw_dash {
    export TERMINFO=/bedrock/cross/terminfo

    columns=$(tput cols)
    rows=$(tput lines)

    i=0
    dash=""
    while [[ $i != $columns ]];
    do
       dash+="-"
       ((++i))
    done
    echo $dash
}


# Straight from stackoverflow!!!! 
# want a sufficient config parser(ini)


#bash "$dir/getkeyfromsection.sh" "b.ini" "bruh" "vsync"
