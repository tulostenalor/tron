#!/bin/bash

########################################
# 1. Performs a cross check of selected and available devices to avoid deadlock
# 2. Returns list file of devices for further use
# 3. If device list is not provided all connected devices will be used
########################################
deviceCheck() {
  if [ "$1" == "" ] ; then
    adb devices | grep -v "List" | grep "device" | cut -f1 > $DEVICE_LIST_TEMP_OUTPUT
  else
    SELECTED_DEVICES=$1
    CONNECTED_DEVICES=$(adb devices | grep -v List | grep device)

    # Filter selected devices by validating with connected ones
    for DEVICE in $(echo "$SELECTED_DEVICES" | tr "," " ") ; do
      echo "$CONNECTED_DEVICES" | grep "$DEVICE" | cut -f1 >> $DEVICE_LIST_TEMP_OUTPUT
    done
  fi

  # Get APK minSdk
  MIN_SDK=$(apkanalyzer manifest min-sdk $APP_PATH/$APP_PREFIX | tr -d '\n\t\r ')

  # Check if device meets APK criteria
  for DEVICE in $(cat $DEVICE_LIST_TEMP_OUTPUT) ; do
    
    # Gather basic details about a device
    generateDeviceProperties $DEVICE
    DEVICE_SDK=$(getProperty $DEVICE buildSdk | tr -d '\n\t\r ')

    # If device meets minsdk criteria add it to the list
    if [ $DEVICE_SDK -ge $MIN_SDK ] ; then
      echo "$DEVICE" >> "$DEVICE_LIST_OUTPUT"
    else
      echo "[!] Rejecting device: $DEVICE (with sdk: $DEVICE_SDK) as it does not meet APKs minSdk of: $MIN_SDK"
    fi
  done

  # Remove obsolete config file
  rm "$DEVICE_LIST_TEMP_OUTPUT"

   # Do not continue if no devices connected
  if [ ! -f $DEVICE_LIST_OUTPUT ] ; then
    echo "[!] No connected devices!"
    exit 1
  fi
}

########################################
# 1. Generates a list of device properties
# 2. Stories properties in specified location for each device
########################################
generateDeviceProperties() {
  DEVICE=$1
  PROPERTIES_OUTPUT="$TEST_OUTPUT/$DEVICE/device-properties.txt"

  mkdir -p "$TEST_OUTPUT/$DEVICE/"
  echo "productModel:$(adb -s $DEVICE shell getprop ro.product.model)" > "$PROPERTIES_OUTPUT"
  echo "productManufactuer:$(adb -s $DEVICE shell getprop ro.product.manufacturer)" >> "$PROPERTIES_OUTPUT"
  echo "buildSdk:$(adb -s $DEVICE shell getprop ro.build.version.sdk)" >> "$PROPERTIES_OUTPUT"
  echo "buildVersion:$(adb -s $DEVICE shell getprop ro.build.version.release)" >> "$PROPERTIES_OUTPUT"
}

########################################
# 1. Returns a display nmae for a device
# 2. Requires device SN to be provided
########################################
getDeviceDisplayName() {
  DEVICE=$1

  echo "$(getProperty $DEVICE productManufactuer) - $(getProperty $DEVICE productModel) ($(getProperty $DEVICE buildVersion))"
}

########################################
# 1. Returns a value of devices property
# 2. Requires device SN and property name to be provided
########################################
getProperty() {
  DEVICE=$1
  PROPERTY=$2

  echo "$(cat $TEST_OUTPUT/$DEVICE/device-properties.txt | grep $PROPERTY | cut -d ":" -f2 | tr -d '\n\t\r')"
}

########################################
# 1. Checks if device is meeting conditions for running the instruction set
# 2. Compares device SDK with the one specified in test conditions configuration
# 3. It uses a comparision operator also provided from the same config
########################################
deviceCompatibleWithInstructionSet() {
  INSTRUCTIONS=$1
  DEVICE=$2

  DEVICE_SDK=$(getProperty $DEVICE buildSdk)

  for CONDITION in $(echo "$TEST_CONDITIONS" | grep "test_condition") ; do
    CONDITION_SELECTOR=$(echo "$CONDITION" | cut -d "|" -f1)
    CONDITION_SDK=$(echo "$CONDITION" | cut -d "|" -f2)
    CONDITION_OPERATOR=$(echo "$CONDITION" | cut -d "|" -f3)

    if grep -q "$CONDITION_SELECTOR" "$INSTRUCTIONS" ; then
      if [ ! "$DEVICE_SDK" $CONDITION_OPERATOR "$CONDITION_SDK" ] ; then
        return 1 # false
      fi
    fi
  done

  return 0 # true
}

########################################
# 1. Checks if device is meeting conditions for running a particular instruction
# 2. Compares device SDK with the one specified in test conditions configuration
# 3. It uses a comparision operator also provided from the same config
########################################
deviceCompatibleWithAnInstruction() {
  INSTRUCTION=$1
  DEVICE=$2

  DEVICE_SDK=$(getProperty $DEVICE buildSdk)

  for CONDITION in $(echo "$TEST_CONDITIONS" | grep "test_condition") ; do
    CONDITION_SELECTOR=$(echo "$CONDITION" | cut -d "|" -f1)
    CONDITION_SDK=$(echo "$CONDITION" | cut -d "|" -f2)
    CONDITION_OPERATOR=$(echo "$CONDITION" | cut -d "|" -f3)

    CONDITION_CHECK=$(echo "$INSTRUCTION" | grep "$CONDITION_SELECTOR" | wc -l | tr -d '\n\t\r ')

    if [ $CONDITION_CHECK -gt 0 ] ; then
      if [ ! "$DEVICE_SDK" $CONDITION_OPERATOR "$CONDITION_SDK" ] ; then
        return 1 # false
      fi
    fi
  done

  return 0 # true
}
