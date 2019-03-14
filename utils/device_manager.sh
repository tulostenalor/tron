#!/bin/bash

########################################
# 1. Performs a cross check of selected and available devices to avoid deadlock
# 2. Returns list file of devices for further use
# 3. If device list is not provided all connected devices will be used
########################################
deviceCheck() {
  if [ "$1" == "" ] ; then
    adb devices | grep -v "List" | grep "device" | cut -f1 > $DEVICE_LIST_OUTPUT
  else
    SELECTED_DEVICES=$1
    CONNECTED_DEVICES=$(adb devices | grep -v List | grep device)

    # Filter selected devices by validating with connected ones
    for DEVICE in $(echo "$SELECTED_DEVICES" | tr "," " ") ; do
      echo "$CONNECTED_DEVICES" | grep "$DEVICE" | cut -f1 >> $DEVICE_LIST_OUTPUT
    done
  fi
}
