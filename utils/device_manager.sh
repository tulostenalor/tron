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

generateDeviceProperties() {
  DEVICE=$1
  PROPERTIES_OUTPUT="$TEST_OUTPUT/$DEVICE/device-properties.txt"

  mkdir -p "$TEST_OUTPUT/$DEVICE/"
  echo "productModel:$(adb -s $DEVICE shell getprop ro.product.model)" > "$PROPERTIES_OUTPUT"
  echo "productManufactuer:$(adb -s $DEVICE shell getprop ro.product.manufacturer)" >> "$PROPERTIES_OUTPUT"
  echo "buildSdk:$(adb -s $DEVICE shell getprop ro.build.version.sdk)" >> "$PROPERTIES_OUTPUT"
  echo "buildVersion:$(adb -s $DEVICE shell getprop ro.build.version.release)" >> "$PROPERTIES_OUTPUT"
}

getDeviceDisplayName() {
  DEVICE=$1

  echo "$(getProperty $DEVICE productManufactuer) - $(getProperty $DEVICE productModel) ($(getProperty $DEVICE buildVersion))"
}

getProperty() {
  DEVICE=$1
  PROPERTY=$2

  echo "$(cat $TEST_OUTPUT/$DEVICE/device-properties.txt | grep $PROPERTY | cut -d ":" -f2)"
}

deviceCompatible() {
  INSTRUCTIONS=$1
  DEVICE=$2
  EXCLUSIONS=$3

  DEVICE_SDK=$(getProperty $DEVICE buildSdk)

  for EXCLUSION in $(echo "$EXCLUSIONS") ; do
    EXCLUSION_SELECTOR=$(echo "$EXCLUSION" | cut -d "|" -f1)
    EXCLUSION_SDK=$(echo "$EXCLUSION" | cut -d "|" -f2)
    EXCLUSION_CONDITION=$(echo "$EXCLUSION" | cut -d "|" -f3)

    if grep -q "$EXCLUSION_SELECTOR" "$INSTRUCTIONS" ; then
      if [ ! "$DEVICE_SDK" $EXCLUSION_CONDITION "$EXCLUSION_SDK" ] ; then
        return 1
      fi
    fi
  done

  return 0
}
