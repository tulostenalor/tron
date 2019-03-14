#!/bin/bash

########################################
# 1. Runs a selected script on multiple devices in parallel
# 2. Awaits taks completion on all devices before allowing further instructions
########################################
runScriptOnMultipleThreads() {
  SELECTED_DEVICES=$1
  SCRIPT_PATH=$2
  OUTPUT_MESSAGE=$3

  PROCESSES=""
  PROCESS_NUMBER=1
  for DEVICE in $SELECTED_DEVICES ; do
    {
      # Runs selected script and passes device S/N as an argument
      sh "$SCRIPT_PATH" "$DEVICE" &
    } &> /dev/null
    PROCESSES=$(echo "$PROCESSES%$PROCESS_NUMBER ")

    echo "$OUTPUT_MESSAGE => $PROCESS_NUMBER for device => $DEVICE"
    let PROCESS_NUMBER=PROCESS_NUMBER+1
  done

  # Awaits all process (threads) to complete
  wait $PROCESSES
}

########################################
# Returns 0 if process is running and 1 if not
# Parameters: 
# *$1* => PID of the process to check
########################################
isProcessRunning() {
    # If pid equals default one then its idle
    if [ $1 -eq $DEFAULT_PID ] ; then
        return 1
    fi

    if ps -p $1 > /dev/null
    then
       return 0
    else
       return 1
    fi
}

