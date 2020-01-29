#!/bin/bash

# Sourcing global parameters
source ./config/config
source ./utils/thread.sh
source ./utils/converter.sh
source ./utils/junit_generator.sh
source ./utils/html_generator.sh

START_TIME=$(getCurrentDate)
CONCURRENT=$1
EXPECTED_DEVICE_NUMBER=$(cat $DEVICE_LIST_OUTPUT | wc -l | tr -d "\n\t\r ")

# Reset test duration summary file
if [ -e $TIMES_OUTPUT ]; then
    rm "$TIMES_OUTPUT"
fi

########################################
# Creates test instruction set for a device
# Parameters: 
# *$SET_NUMBER* => instruction set to use
# *$SELECTED_DEVICE* => target device, set is created for
########################################
createTestInstructionSet() {
    # Parameters
    SET_NUMBER=$1
    SELECTED_DEVICE=$2

    # Define instruction set file (and remove if already exists)
    INSTRUCTION_SET="$ARTEFACTS_OUTPUT/instruction-set-$SELECTED_DEVICE.txt"
    if [ -e $INSTRUCTION_SET ]; then
        rm $INSTRUCTION_SET
    fi

    i=0
    ADD_INSTRUCTIONS=false
    for LINE in $(cat "$INSTRUCTION_OUTPUT") ; do

        # When delimiter is found
        if [ $LINE == "$TEST_DELIMITER" ] ; then
            # If adding instructions is *true*, then hitting delimiter again means that set is complete
            if $ADD_INSTRUCTIONS ; then
                break
            fi

            # If correct set is reached then enable adding instructions, otherwise continue with next itteration 
            if [ $SET_NUMBER -eq $i ] ; then
                ADD_INSTRUCTIONS=true
            else
                i=$(( $i + 1 ))
            fi
            continue
        fi

        # Once designated set is reached and adding is enabled start adding instutions to test instruction set file
        if $ADD_INSTRUCTIONS; then
            echo $LINE >> $INSTRUCTION_SET
        fi
    done
}

########################################
# Scans list of devices that completed preparation process
# Updates sharded run paramters with new device details
########################################
updateDeviceList() {
    for DEVICE in $(cat $DEVICE_LIST_PREP_COMPLETE) ; do
        if [[ ! "${DEVICES[@]}" =~ "${DEVICE}" ]] ; then
            DEVICES+=("$DEVICE")
            THREADS=${#DEVICES[@]}
            THREAD_POOL[${#THREAD_POOL[@]}]=$DEFAULT_PID

            echo "[!] New device ($DEVICE) added, now with total of $THREADS devices."
        fi
    done
}

# For concurrent run we await all devices to complete their preparation process prior continuing
# Execution time will not benefit from asynchronous execution in this mode
if $CONCURRENT ; then
    echo "Awaiting all devices to complete preperation."

    TIMEOUT=0
    while [ $(cat $DEVICE_LIST_PREP_COMPLETE | wc -l | tr -d "\n\t\r ") -ne $EXPECTED_DEVICE_NUMBER ] ; do
        if [ $TIMEOUT -gt 600 ] ; then
            echo "Took too long to prepare all devices!"
            exit 1
        fi

        sleep 0.5
        let TIMEOUT=TIMEOUT+1
    done
fi

# Pull list of ready devices into an array
DEVICES=()
for DEVICE in $(cat $DEVICE_LIST_PREP_COMPLETE) ; do
    DEVICES+=("$DEVICE")
done

# Number of parallel threads is equal to number of devices
THREADS=${#DEVICES[@]}

# Assign default (idle) pid to all device threads
THREAD_POOL=()
for ((i=0;i<$THREADS;i++)); do
    THREAD_POOL[i]=$DEFAULT_PID
done

# Calculate total number of tests (based on delimter occurance) and execution mode selected
if $CONCURRENT ; then
    NUMBER_OF_TESTS=$THREADS
else
    NUMBER_OF_TESTS=$(grep -c "$TEST_DELIMITER" $INSTRUCTION_OUTPUT)
fi

########################################
# Test execution starts here
########################################
ZOMBIE_THREADS=()
EXECUTION_PROGRESS=0
TEST_RUN_COMPLETE=false
while true ; do
    # It will attempt to update list of currently running devices when expected number is not meet
    if [[ $EXPECTED_DEVICE_NUMBER -ne $THREADS ]] ; then
        updateDeviceList
    fi

    # Find first idle process in thread pool (initially all are)
    THREAD=-1
    IDLE_THREAD=0
    for PROCESS in "${!THREAD_POOL[@]}" ; do
        PID=${THREAD_POOL[$PROCESS]}
        if ! isProcessRunning $PID ; then

            # When an idle process is found:
            # If TEST_CONDITIONS_ENABLED flag is set to true, check if selected thread (tied to a device) is capable or running the instruction
            # In specific case if none of the threads (devices) meets the conditions of the instruction, execution is stopped
            # If TEST_CONDITIONS_ENABLED flag is set to false, then first free thread is selected to run the instruction
            if [[ "${ZOMBIE_THREADS[@]}" =~ "${PROCESS}" ]] && [[ $TEST_CONDITIONS_ENABLED ]] ; then
                if [ ${#ZOMBIE_THREADS[@]} -eq $EXPECTED_DEVICE_NUMBER ] ; then
                    echo "===== There are no devices compatible with this instruction set! ====="
                    exit 1
                else
                    continue
                fi
            else
                THREAD=$PROCESS
            fi

            # When an idle process is found:
            # If test run is complete (TEST_RUN_COMPLETE=true), start counting idle threads
            # If test run is ongoing, break the loop after first idle process is found
            if $TEST_RUN_COMPLETE ; then
                IDLE_THREAD=$(($IDLE_THREAD+1))
            else
                break
            fi
        fi
    done

    # If no idle thread is found then sleep and try again later
    # If number of idle threads equal number of all threads - test run is complete
    if [ $THREAD -eq -1 ]; then
        sleep 0.1
        continue
    elif [ $IDLE_THREAD -eq $THREADS ] ; then
        echo "===== Execution complete ====="
        break
    fi

    # When number of executed tests matches total number of tests - test run is complete & flag is set
    if [ $EXECUTION_PROGRESS -eq $NUMBER_OF_TESTS ] ; then
        TEST_RUN_COMPLETE=true
        continue
    fi

    # Select a device that will run the next test instruction set
    SELECTED_DEVICE=${DEVICES[$THREAD]}

    # Create test instruction set file to execute based on execution mode
    if $CONCURRENT ; then
        INSTRUCTIONS="$ARTEFACTS_OUTPUT/instruction-log.txt"
    else 
        INSTRUCTIONS="$ARTEFACTS_OUTPUT/instruction-set-$SELECTED_DEVICE.txt"
        createTestInstructionSet $EXECUTION_PROGRESS $SELECTED_DEVICE

        # If TEST_CONDITIONS_ENABLED flag is set to true, checks if device is capable of running the instruction set
        # If device cannot run it, its added to ZOMBIE_THREADS pool and new (next available) device will be selected
        # If device is capable of running the instruction set, then ZOMBIE_THREAD pool is being cleared
        if $TEST_CONDITIONS_ENABLED ; then
            if ! deviceCompatibleWithInstructionSet "$INSTRUCTIONS" "$SELECTED_DEVICE" ; then
                ZOMBIE_THREADS+=($THREAD)
                continue
            else
                ZOMBIE_THREADS=()
            fi
        fi
    fi
    
    # Run test instruction set on a selected device
    ./core/execute.sh "$INSTRUCTIONS" "$SELECTED_DEVICE" $CONCURRENT &
    PID=$!

    # Output message
    PROGRESS=$(calculatePercentage "$(($EXECUTION_PROGRESS+1))" "$NUMBER_OF_TESTS")
    echo -e "\033[1;34mInstruction set started: \033[0m\033[1;30m$(($EXECUTION_PROGRESS+1)) \033[0mof \033[1;30m$NUMBER_OF_TESTS \033[0m[\033[1;30m$PROGRESS%\033[0m]"
    
    # Assigning a new PID to a thread in a pool
    THREAD_POOL[$THREAD]=$PID

    # Increment number of test runs
    EXECUTION_PROGRESS=$(($EXECUTION_PROGRESS+1))
done

# Generate JUnit report based on flag and execution mode
if $GENERATE_JUNIT_REPORT ; then
    if $CONCURRENT ; then
        generateConcurrentJunitReport
    else
        generateJunitReport
    fi
fi

# Capture end time
END_TIME=$(getCurrentDate)
TOTAL_DURATION=$(convertMilisecondsToMinutesSeconds $((END_TIME-START_TIME)))

# Duration summary
echo "****"
echo -e "Total duration: \033[1;30m$TOTAL_DURATION\033[0m"
echo "****"

if $GENERATE_HTML_REPORT ; then
    generateHtmlExecutionSummary "$TOTAL_DURATION"
fi
