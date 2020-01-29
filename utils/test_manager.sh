#!/bin/bash

########################################
# 1. Performs a setup action for a specific instruction if conditions are meet
########################################
runSetupCommandIfRequired() {
  INSTRUCTION=$1
  DEVICE=$2

  for CONDITION in $(echo "$TEST_CONDITIONS" | grep "test_setup") ; do
    CONDITION_SELECTOR=$(echo "$CONDITION" | cut -d "|" -f1)
    CONDITION_COMMAND=$(echo "$CONDITION" | cut -d "|" -f2)

    CONDITION_CHECK=$(echo "$INSTRUCTION" | grep "$CONDITION_SELECTOR" | wc -l | tr -d '\n\t\r ')

    if [ $CONDITION_CHECK -gt 0 ] ; then
      if [ "$CONDITION_COMMAND" == "clear" ] ; then
        {
          adb -s $DEVICE shell pm clear $DEBUG_PACKAGE
        } &> /dev/null
      fi
    fi
  done
}

########################################
# 1. Validates outcome of a test against specific conditions
########################################
checkTestResult() {
  CAUSES=$(echo "$1" | tr ',' '\n' | tr ' ' '~')
  RUNNING_TEST=$2

  for CAUSE in $(echo -e "$CAUSES") ; do
    POSSIBLE_CAUSE=$(echo "$CAUSE" | tr '~' ' ')

    if grep -q "$POSSIBLE_CAUSE" $RUNNING_TEST ; then
      return 0 # true
    fi
  done
  return 1 # false
}
