#!/bin/bash

# Sourcing global parameters
source ./config/config
source ./utils/converter.sh
source ./utils/html_generator.sh
source ./utils/test_manager.sh

INSTRUCTION_SET=$1
DEVICE=$2
CONCURRENT=$3

# If instruction set is missing there is nothing to do further
if [ -z $INSTRUCTION_SET ] ; then
    echo "Missing instruction set!"
    exit 1
fi

# If instruction set is missing there is nothing to work on
if [ -z $DEVICE ] ; then
    echo "Missing device paramter!"
    exit 1
fi

EXECUTION_PROGRESS=0
NUMBER_OF_INSTRUCTIONS=$(cat "$INSTRUCTION_SET" | grep -v "$TEST_DELIMITER" | wc -l | tr -d '\n\t\r ')

# Run instructions line by line from instruction set
for INSTRUCTION in $(cat "$INSTRUCTION_SET") ; do
    # Do nothing if instruction is a test delimiter
    if [ $INSTRUCTION == "$TEST_DELIMITER" ]; then
        continue
    fi

    # Run test setup tasks, if required by configuration
    if $TEST_SETUP_ENABLED ; then
        runSetupCommandIfRequired "$INSTRUCTION" "$DEVICE"
    fi

    if $CLEAR_DATA_BEFORE_TEST ; then
        # Clear data before test run
        # PROCESS_START=$(date +%s%3N)
        {
            adb -s $DEVICE shell pm clear $PACKAGE.debug
        } &> /dev/null
        # PROCESS_END=$(date +%s%3N)
        # echo "App data cleared, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
    fi

    # Create output directory for an instruction
    INSTRUCTION_HASH=$(getHash $INSTRUCTION)
    TEST_DIRECTORY="$TEST_OUTPUT/$DEVICE/$INSTRUCTION_HASH"
    mkdir -p $TEST_DIRECTORY

    # Test artefacts files
    TEST_FILE="running-test.txt"
    RUNNING_TEST="$TEST_DIRECTORY/$TEST_FILE"
    RECORDING_FILE="$TEST_DIRECTORY/$TEST_RECORDING_FILE"
    LOGCAT_FILE="$TEST_DIRECTORY/$TEST_LOGCAT_FILE"
    DB_FILE="$TEST_DIRECTORY/$TEST_DB_FILE"
    PREFERENCES_FILE="$TEST_DIRECTORY/$TEST_PREFERENCES_FILE"
    BUGREPORT_FILE="$TEST_DIRECTORY/$TEST_BUGREPORT_FILE"

    # Start video recording
    if $RECORD_VIDEO_FOR_EACH_TEST ; then
        # PROCESS_START=$(date +%s%3N)
        {
            adb -s $DEVICE shell screenrecord "$TEST_RECORDING_PARAMETERS" "$TEST_SDCARD_RECORDING" &
            PID_RECORDING=$!
        } &> /dev/null
        # PROCESS_END=$(date +%s%3N)
        # echo "Video recording started, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
    fi

    # Clear logcat before test start
    if [[ $COLLECT_LOGCAT_ON_SUCCESS || $COLLECT_LOGCAT_ON_FAILURE ]] ; then
        # PROCESS_START=$(date +%s%3N)
        {
            adb -s $DEVICE logcat -c
        } &> /dev/null
        # PROCESS_END=$(date +%s%3N)  
        # echo "Device logs cleared, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
    fi

    # Obtain class and method names
    INSTRUCTION_CLASS=$(echo $INSTRUCTION | cut -d "#" -f1 | rev | cut -d "." -f1 | rev)
    INSTRUCTION_METHOD=$(echo $INSTRUCTION | cut -d "#" -f2)
    PROGRESS=$(calculatePercentage "$(($EXECUTION_PROGRESS+1))" "$NUMBER_OF_INSTRUCTIONS")

    # Output message based on execution mode
    if $CONCURRENT ; then
        # If TEST_CONDITIONS_ENABLED flag is set to true, checks if device is capable of running the instruction
        # If device cannot run it, instruction is marked as skipped in report and device moves on to the next one
        if $TEST_CONDITIONS_ENABLED ; then
            if ! deviceCompatibleWithAnInstruction "$INSTRUCTION" "$DEVICE" ; then
                echo "RUN ($INSTRUCTION) device ($DEVICE), duration: 0.0 seconds, status: [-] SKIPPED" >> "$TIMES_OUTPUT"

                if $GENERATE_HTML_REPORT ; then
                    generateTestSummary $DEVICE $INSTRUCTION "[-] SKIPPED."
                fi
                continue
            fi
        fi

        echo "Instruction details => Class: $INSTRUCTION_CLASS | Method: $INSTRUCTION_METHOD"
        echo "Instruction running => Device: $DEVICE | $(($EXECUTION_PROGRESS+1)) of $NUMBER_OF_INSTRUCTIONS [$PROGRESS%]"
    else
        echo "Instruction details => Class: $INSTRUCTION_CLASS | Method: $INSTRUCTION_METHOD"
    fi

    # Execute instruction
    START_TIME=$(date +%s%3N)
    adb -s $DEVICE shell am instrument -w -r -e class $INSTRUCTION $TEST_RUNNER > $RUNNING_TEST
    END_TIME=$(date +%s%3N)

    # Capture duration test execution summary
    DURATION=$(convertMilisecondsToSeconds $((END_TIME-START_TIME)))

    if $RECORD_VIDEO_FOR_EACH_TEST ; then
        # Stop recording process
        # PROCESS_START=$(date +%s%3N)
        {
            kill $PID_RECORDING
            sleep 1
        } &> /dev/null
        # PROCESS_END=$(date +%s%3N)  
        # echo "Video recording stopped, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
    fi

    # Check if test run successfuly
    if grep -q "FAILURES!!!" $RUNNING_TEST ; then
        FAIL_REASON=$(head -5 "$RUNNING_TEST")
        FAIL_REASON=${FAIL_REASON//[$'\t\r\n ' / ]}
        FAIL_REASON=${FAIL_REASON//[$'\t\r\n']}
    else
        FAIL_REASON=""
    fi

    # If 'FAIL_REASON' is not empty - it signals a failure
    if [ ! -z "$FAIL_REASON" ] ; then

        # Collect logs on failure
        if $COLLECT_LOGCAT_ON_FAILURE ; then
            adb -s $DEVICE logcat -d "$TEST_LOGCAT_PARAMETERS" > $LOGCAT_FILE
            sed -i '/^$/d' $LOGCAT_FILE
        fi

        # Collect DB content on failure
        if $COLLECT_DB_ON_FAILURE ; then
            adb -s $DEVICE shell "run-as $PACKAGE cat $TEST_APP_DB_PATH" > $DB_FILE
        fi

        # Collect shared preferences on failure
        if $COLLECT_PREFERENCES_ON_FAILURE ; then
            adb -s $DEVICE shell "run-as $PACKAGE cat $TEST_APP_SHARED_PREF_PATH" > $PREFERENCES_FILE
        fi

        # Collect bugreport on failure
        if $COLLECT_BUGREPORT_ON_FAILURE ; then
            adb -s $DEVICE shell bugreport > $BUGREPORT_FILE
        fi

        # Pull recording on failure
        if (($RECORD_VIDEO_FOR_EACH_TEST) && ($COLLECT_VIDEO_ON_FAILURE)) ; then
            # PROCESS_START=$(date +%s%3N)
            {
                adb -s $DEVICE pull "$TEST_SDCARD_RECORDING" $RECORDING_FILE
            } &> /dev/null
            # PROCESS_END=$(date +%s%3N)  
            # echo "Video recording pulled on failure, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
        fi

        # Failure
        echo "[x] FAIL ($DURATION s)"
        echo ""

        # Log test execution
        echo "RUN ($INSTRUCTION) device ($DEVICE), duration: $DURATION seconds, status: [x] FAIL" >> "$TIMES_OUTPUT"

        # Generate html summary report for test if enabled
        if $GENERATE_HTML_REPORT ; then
            generateTestSummary $DEVICE $INSTRUCTION "[x] FAIL."
        fi
    else
        # Collect logs on success
        if $COLLECT_LOGCAT_ON_SUCCESS ; then
            adb -s $DEVICE logcat -d "$TEST_LOGCAT_PARAMETERS" > $LOGCAT_FILE
        fi

        # Collect DB content on success
        if $COLLECT_DB_ON_SUCCESS ; then
            adb -s $DEVICE shell "run-as $PACKAGE cat $TEST_APP_DB_PATH" > $DB_FILE
        fi

        # Collect shared preferences on success
        if $COLLECT_PREFERENCES_ON_SUCCESS ; then
            adb -s $DEVICE shell "run-as $PACKAGE cat $TEST_APP_SHARED_PREF_PATH" > $PREFERENCES_FILE
        fi

        # Collect bugreport on success
        if $COLLECT_BUGREPORT_ON_SUCCESS ; then
            adb -s $DEVICE shell bugreport > $BUGREPORT_FILE
        fi

        # Pull recording on success
        if (($RECORD_VIDEO_FOR_EACH_TEST) && ($COLLECT_VIDEO_ON_SUCCESS)) ; then
            # PROCESS_START=$(date +%s%3N)
            echo "Pulling video on success. Success: $COLLECT_VIDEO_ON_SUCCESS"
            {
                adb -s $DEVICE pull "$TEST_SDCARD_RECORDING" $RECORDING_FILE
            } &> /dev/null
            # PROCESS_END=$(date +%s%3N)  
            # echo "Video recording pulled on success, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
        fi

        echo "[/] OK ($DURATION s)"
        echo ""

        # Log test execution
        echo "RUN ($INSTRUCTION) device ($DEVICE), duration: $DURATION seconds, status: [/] OK" >> "$TIMES_OUTPUT"

        # Generate html summary report for test if enabled
        if $GENERATE_HTML_REPORT ; then
            generateTestSummary $DEVICE $INSTRUCTION "[/] OK."
        fi
    fi

    # Delete recording from the device
    if $RECORD_VIDEO_FOR_EACH_TEST ; then
        # PROCESS_START=$(date +%s%3N)
        {
            adb -s $DEVICE shell rm "$TEST_SDCARD_RECORDING"
        } &> /dev/null
        # PROCESS_END=$(date +%s%3N)  
        # echo "Video recording purged from device, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
    fi

    EXECUTION_PROGRESS=$(($EXECUTION_PROGRESS+1))
done
