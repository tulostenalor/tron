#!/bin/bash

# Sourcing parameters
source ./config/config
source ./utils/app_manager.sh
source ./utils/device_manager.sh

# Passed parameters
DEVICE=$1
PROCESS_NUMBER=$2

{
  # Uninstalling the packages
  adb -s $DEVICE uninstall $INSTRUMENTATION_PACKAGE
  adb -s $DEVICE uninstall $DEBUG_PACKAGE

  # Enabling stay awake before waking up the device
  adb -s $DEVICE shell settings put global stay_on_while_plugged_in 3

  # Disabling / enabling animations based on configuration
  if [ "$ANIMATIONS_DISABLED" == "true" ] ; then
    adb -s $DEVICE shell settings put global window_animation_scale 0.0
    adb -s $DEVICE shell settings put global transition_animation_scale 0.0
    adb -s $DEVICE shell settings put global animator_duration_scale 0.0
    adb -s $DEVICE shell settings put system accelerometer_rotation 0
  else
    adb -s $DEVICE shell settings put global window_animation_scale 1.0
    adb -s $DEVICE shell settings put global transition_animation_scale 1.0
    adb -s $DEVICE shell settings put global animator_duration_scale 1.0
    adb -s $DEVICE shell settings put system accelerometer_rotation 1
  fi

  # Setting screen brightness & ensure mocking location is off
  adb -s $DEVICE shell settings put system screen_brightness $BRIGHTNESS
  adb -s $DEVICE shell settings put secure mock_location 0
  adb -s $DEVICE shell settings put system screen_off_timeout 600000

  # Disable non-SDK interface popup (only affecting Pie)
  adb -s $DEVICE shell settings put global hidden_api_policy_pre_p_apps $HIDDEN_API_POLICY
  adb -s $DEVICE shell settings put global hidden_api_policy_p_apps $HIDDEN_API_POLICY

  # Clean device screenshots
  adb -s $DEVICE shell rm -r -f ./sdcard/Pictures/Screenshots/**

  # Killing all running apps (including systemUI, thus purging all popups)
  killAllRunningApps $DEVICE

  # Installing main & test apps
  adb -s $DEVICE install $APP_PATH/$APP_PREFIX
  adb -s $DEVICE install $TEST_PATH/$TEST_PREFIX

  # Clear logs before instrumentation
  adb -s $DEVICE logcat -c
} &> /dev/null

echo "$DEVICE" >> "$DEVICE_LIST_PREP_COMPLETE"
