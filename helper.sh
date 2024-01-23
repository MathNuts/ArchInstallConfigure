#!/bin/bash

# Variables
kb_layout="no-latin1"
ping_test="google.com"
mirror_countries="country=NO&country=NL"
mirrorlist="/etc/pacman.d/mirrorlist"
zoneinfo="Europe/Oslo"

# Colors
#   Grey
LG='\033[0;37m'
#   Purple
P='\033[0;35m'
#   Green
G='\033[0;32m'
#   None
X='\033[0m'

# Variables
spaces="                      "


prefix () {
    now=$(date +%H:%M:%S)
    prefix="${P}[Installer]${X}${LG}[${now}]${X} "
    echo -e "$prefix"
}

# Lists options numbered 1 to n
# Usage: options opts
#   opts    -   String of newline separated options
options () {
    n=1
    echo "$1" | while read line ; do
        echo "${spaces}$n. $line" | tee /dev/fd/3
        n=$((n+1))
    done
}

# Returns selected option value
# Usage: chooser opts label
#   opts    -   String of newline separated options
#   label   -   Category
#   full    -   Return the full value instead of first word
chooser () {

    read -p "${spaces}$2 number (default=1): " val 2>&3

    if [[ ! $val ]]; then
        val=1
    fi

    res=$(echo "$1" | awk "NR==$val")

    if  [[ $3 ]]; then
        echo "$res"
    else
        echo "$res" | cut -d " " -f1
    fi
}

# Yes/no promt
# Usage: yesno promt
#   promt   -   Question to answer
yesno () {
    read -p "$(prefix)$1 (y/n default=n): " answer 2>&3
    echo "$answer"
}

# Input promt
# Usage: input promt
#   promt   -   Promt message
#   hidden  -   Hide input
input () {
    if [[ $2 == "hidden" ]] ; then
        read -s -p "$(prefix)$1: " var 2>&3
    else
        read -p "$(prefix)$1: " var 2>&3
    fi
    echo "$var"
}

# Pauses execution
# Usage: pause message
#   message -   Pause message
pause () {
    read -p "$(prefix)$1" 2>&3
}

# Logs a message to the console
# Usage: log message
#   message -   Message to be printed
log () {
    message="$1"
    n=1
    echo -en "$(prefix)" | tee /dev/fd/3
    echo -e "$message" | while read -r line ; do
        if [[ $n > 1 ]] ; then
            echo -en "$spaces" | tee /dev/fd/3
        fi
        echo -e "${line}" | tee /dev/fd/3
        n=$((n+1))
    done
}