#!/bin/bash
# Copyright (c) 2021
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA
#
# Authored by: Kris Henriksen <krishenriksen.work@gmail.com>
#
# Wi-Fi-dialog
#

sudo chmod 666 /dev/tty1
printf "\033c" > /dev/tty1

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

if ! dpkg -s "dialog" &> /dev/null ; then
  printf "\e[32mInstalling dependencies ...\n" > /dev/tty1
  sudo apt update && sudo apt install -y dialog --no-install-recommends
fi

ExitMenu() {
  printf "\033c" > /dev/tty1
  pgrep -f oga_controls | sudo xargs kill -9
  exit 0
}

Select() {
  KEYBOARD="osk-sdl"

  if ! command -v $KEYBOARD &> /dev/null; then
    KEYBOARD="./osk-sdl"

    if [ ! -f "$KEYBOARD" ]; then
      KEYBOARD="/roms/ports/AnberPorts/bin/osk-sdl"
    fi
  fi

  # get password from input
  PASS=`$KEYBOARD -p "Enter Wi-Fi password" | tail -n 1`

  dialog --infobox "\nConnecting to Wi-Fi $1 ..." 5 50 > /dev/tty1

  # try to connect
  output=`nmcli device wifi connect "$1" password "$PASS"`
  
  dialog --infobox "\n$output" 6 55 > /dev/tty1
  sleep 3
  ExitMenu
}

#
# Joystick controls
#
# only one instance
if ! pgrep -x "oga_controls" > /dev/null; then
  CONTROLS="oga_controls"

  if ! command -v $CONTROLS &> /dev/null; then
    CONTROLS="./oga_controls"

    if [ ! -f "$CONTROLS" ]; then
      CONTROLS="/roms/ports/AnberPorts/bin/oga_controls"
    fi
  fi

  sudo $CONTROLS Wi-Fi.sh &
fi

MainMenu() {
  list=`sudo nmcli -f ALL --mode tabular --terse --fields IN-USE,SSID,CHAN,SIGNAL,SECURITY dev wifi`

  # Set colon as the delimiter
  IFS=':'

  while IFS= read -r list; do
    # Read the split words into an array based on colon delimiter
    read -a strarr <<< "$list"

    INUSE=`printf '%-5s' "${strarr[0]}"`
    SSID="${strarr[1]}"
    CHAN=`printf '%-5s' "${strarr[2]}"`
    SIGNAL=`printf '%-5s' "${strarr[3]}%"`
    SECURITY="${strarr[4]}"

    options+=("$SSID" "$INUSE $CHAN $SIGNAL $SECURITY")
  done <<< "$list"

  while true; do
    selection=(dialog \
   	--backtitle "Connections" \
   	--title "SSID  IN-USE  CHANNEL  SIGNAL  SECURITY" \
   	--no-collapse \
   	--clear \
	--cancel-label "Select + Start to Exit" \
    --menu "" 15 55 15)

    choices=$("${selection[@]}" "${options[@]}" 2>&1 > /dev/tty1)

    for choice in $choices; do
      case $choice in
        *) Select $choice ;;
      esac
    done
  done
}

dialog --infobox "\nScanning available Wi-Fi access points ..." 5 50 > /dev/tty1
MainMenu