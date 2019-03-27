#!/bin/bash

########################################
# 1. 
########################################
runSetupCommandIfRequired() {
  INSTRUCTION=$1
  DEVICE=$2
  TEST_CONDITIONS=$3

  for CONDITION in $(echo "$TEST_CONDITIONS" | grep "test_setup") ; do
    CONDITION_SELECTOR=$(echo "$CONDITION" | cut -d "|" -f1)
    CONDITION_COMMAND=$(echo "$CONDITION" | cut -d "|" -f2)

    CONDITION_CHECK=$(echo "$INSTRUCTION" | grep "$CONDITION_SELECTOR" | wc -l | tr -d '\n\t\r ')

    if [ $CONDITION_CHECK -gt 0 ] ; then
      if [ "$CONDITION_COMMAND" == "clear" ] ; then
        adb -s $DEVICE shell pm clear $DEBUG_PACKAGE
      fi
    fi
  done
}
