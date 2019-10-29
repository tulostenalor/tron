#!/bin/bash

########################################
# 1. Kills all currently running apps on a device
# 2. Restarts systemUI & removes all visible system popups
########################################

killAllRunningApps() {
  DEVICE=$1

  # Getting list of all opened apps
  APPS=$(adb -s $DEVICE shell dumpsys window a | grep "/" | cut -d "{" -f2 | cut -d "/" -f1 | cut -d " " -f2)

  # Force closing opened apps
  for APP in $APPS ; do
    echo "Force closing: $APP"
    adb -s $DEVICE shell am force-stop $APP
  done

  # Wait for a while (allow system UI to restart) & navigate android home
  sleep 5
  adb -s $DEVICE shell input keyevent 3
  adb -s $DEVICE shell input keyevent 3
}
