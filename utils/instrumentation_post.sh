#!/bin/bash

DEVICE=$1

{
    # Re-enabling animations
    adb -s $DEVICE shell settings put global window_animation_scale 1.0
    adb -s $DEVICE shell settings put global transition_animation_scale 1.0
    adb -s $DEVICE shell settings put global animator_duration_scale 1.0
    adb -s $DEVICE shell settings put system accelerometer_rotation 1

    # Set minimum brightness
    adb -s $DEVICE shell settings put system screen_brightness 1

    # Uninstalling the packages
    adb -s $DEVICE uninstall $INSTRUMENTATION_PACKAGE
    adb -s $DEVICE uninstall $DEBUG_PACKAGE

    # Clean device screenshots
    adb -s $DEVICE shell rm -r -f ./sdcard/Pictures/Screenshots/**
} &> /dev/null
