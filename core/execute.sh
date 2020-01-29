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
            adb -s $DEVICE logcat -v threadtime > $LOGCAT_FILE &
            PID_LOGCAT=$!
        } &> /dev/null
        # PROCESS_END=$(date +%s%3N)  
        # echo "Device logs cleared, took: $(convertMilisecondsToSeconds $((PROCESS_END-PROCESS_START))) seconds."
    fi
    
    # Obtain class and method names
    INSTRUCTION_CLASS=$(echo $INSTRUCTION | cut -d "#" -f1 | rev | cut -d "." -f1 | rev)
    INSTRUCTION_METHOD=$(echo $INSTRUCTION | cut -d "#" -f2)
    INSTRUCTION_SUFFIX="=> \033[1;30mClass: \033[0m\033[3m$INSTRUCTION_CLASS \033[0m| \033[1;30mMethod: \033[0m\033[3m$INSTRUCTION_METHOD\033[0m"
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
        echo -e "\033[1;33mInstruction running \033[0m=> \033[1;30mDevice: \033[0m\033[3m$DEVICE | \033[1;30m$(($EXECUTION_PROGRESS+1)) \033[0mof \033[1;30m$NUMBER_OF_INSTRUCTIONS \033[0m[\033[1;30m$PROGRESS%\033[0m]"
    fi

    CURRENT_ATTEMPT=1
    while [ $CURRENT_ATTEMPT -le $RUN_ATTEMPTS ] ; do
        # Additional message when rerunning an instruction set
        if [ $CURRENT_ATTEMPT -gt 1 ] ; then
            echo -e "\033[1;35m[!] Rerunning instruction \033[0m=> \033[1;30mDevice: \033[0m\033[3m$DEVICE | \033[1;30mRerun attempt: \033[0m\033[3m$(($CURRENT_ATTEMPT-1)) $INSTRUCTION_SUFFIX"
        fi

        # Clear app data before a test
        if $CLEAR_DATA_FOR_EACH_TEST || [ $CURRENT_ATTEMPT -gt 1 ] ; then
        {
            adb -s $DEVICE shell pm clear $PACKAGE.debug
        } &> /dev/null
        fi

        # Start video recording
        if $RECORD_VIDEO_FOR_EACH_TEST || [[ $CURRENT_ATTEMPT -gt 1 && $RECORD_VIDEO_FOR_RERUN ]] ; then
            {
                adb -s $DEVICE shell screenrecord "$TEST_RECORDING_PARAMETERS" "$TEST_SDCARD_RECORDING" &
                PID_RECORDING=$!
            } &> /dev/null
        fi

        # Clear logcat before test start
        if $RECORD_LOGCAT_FOR_EACH_TEST || [[ $CURRENT_ATTEMPT -gt 1 && $RECORD_VIDEO_FOR_RERUN ]] ; then
            {
                adb -s $DEVICE logcat -c
                adb -s $DEVICE logcat -v threadtime > $LOGCAT_FILE &
                PID_LOGCAT=$!
            } &> /dev/null
        fi

        # Execute instruction
        START_TIME=$(getCurrentDate)
        adb -s $DEVICE shell am instrument -w -r $ARGUMENT -e class $INSTRUCTION $TEST_RUNNER > $RUNNING_TEST
        END_TIME=$(getCurrentDate)

        # Capture duration test execution summary
        DURATION=$(convertMilisecondsToSeconds $((END_TIME-START_TIME)))

        if $RECORD_VIDEO_FOR_EACH_TEST || [[ $CURRENT_ATTEMPT -gt 1 && $RECORD_VIDEO_FOR_RERUN ]] ; then
            {
                kill $PID_RECORDING
                sleep 1
            } &> /dev/null
        fi

        # Collect logs on failure
        if $RECORD_LOGCAT_FOR_EACH_TEST || [[ $CURRENT_ATTEMPT -gt 1 && $RECORD_VIDEO_FOR_RERUN ]] ; then
            {
                kill $PID_LOGCAT
                sleep 1
            } &> /dev/null
        fi

        if checkTestResult "$FAILURE_CAUSES" "$RUNNING_TEST" ; then
            IS_FAILURE=true
        else
            IS_FAILURE=false
            break
        fi

        # Increment rerun count
        let CURRENT_ATTEMPT=CURRENT_ATTEMPT+1
    done

    ##### Checks here ->

    # Check if test run successfuly
    if $IS_FAILURE ; then
        # Collect logs on failure
        if ! $COLLECT_LOGCAT_ON_FAILURE ; then
            {
                rm $LOGCAT_FILE
            } &> /dev/null
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
        if (($RECORD_VIDEO_FOR_EACH_TEST) && ($COLLECT_VIDEO_ON_FAILURE)) || [[ $CURRENT_ATTEMPT -gt 1 && $RECORD_VIDEO_FOR_RERUN && $COLLECT_VIDEO_ON_FAILURE ]] ; then
            {
                adb -s $DEVICE pull "$TEST_SDCARD_RECORDING" $RECORDING_FILE
                adb -s $DEVICE shell rm "$TEST_SDCARD_RECORDING"
            } &> /dev/null
        fi

        # Failure
        echo -e "\033[1;31m[x] FAIL ($DURATION s) \033[0m$INSTRUCTION_SUFFIX"
        echo ""

        # Log to failure list
        echo -e "$TEST_DELIMITER\n$INSTRUCTION" >> "$TEST_FAILURES_OUTPUT"

        # Log test execution
        echo "RUN ($INSTRUCTION) device ($DEVICE), duration: $DURATION seconds, status: [x] FAIL" >> "$TIMES_OUTPUT"

        # Generate html summary report for test if enabled
        if $GENERATE_HTML_REPORT ; then
            generateTestSummary $DEVICE $INSTRUCTION "[x] FAIL."
        fi
    elif checkTestResult "$SKIPPED_CAUSES" "$RUNNING_TEST" ; then
        echo "RUN ($INSTRUCTION) device ($DEVICE), duration: 0.0 seconds, status: [-] SKIPPED" >> "$TIMES_OUTPUT"
        if $GENERATE_HTML_REPORT ; then
            generateTestSummary $DEVICE $INSTRUCTION "[-] SKIPPED."
        fi
        
        echo "\033[1;30m[-] SKIPPED (0.0 s) \033[0m$INSTRUCTION_SUFFIX"
        echo ""
    else
        # Collect logs on success
        if ! $COLLECT_LOGCAT_ON_SUCCESS ; then
            {
                rm $LOGCAT_FILE
            } &> /dev/null
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
        if (($RECORD_VIDEO_FOR_EACH_TEST) && ($COLLECT_VIDEO_ON_SUCCESS)) || [[ $CURRENT_ATTEMPT -gt 1 && $RECORD_VIDEO_FOR_RERUN && $COLLECT_VIDEO_ON_SUCCESS ]] ; then
            {
                adb -s $DEVICE pull "$TEST_SDCARD_RECORDING" $RECORDING_FILE
                adb -s $DEVICE shell rm "$TEST_SDCARD_RECORDING"
            } &> /dev/null
        fi

        echo -e "\033[1;32m[/] OK ($DURATION s) \033[0m$INSTRUCTION_SUFFIX"
        echo ""

        # Log test execution
        echo "RUN ($INSTRUCTION) device ($DEVICE), duration: $DURATION seconds, status: [/] OK" >> "$TIMES_OUTPUT"

        # Generate html summary report for test if enabled
        if $GENERATE_HTML_REPORT ; then
            generateTestSummary $DEVICE $INSTRUCTION "[/] OK."
        fi
    fi
    EXECUTION_PROGRESS=$(($EXECUTION_PROGRESS+1))
done
