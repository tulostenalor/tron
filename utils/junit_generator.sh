#!/bin/bash

source ./utils/converter.sh
source ./utils/test_manager.sh

########################################
# 1. Generates total test duration for given parameters
# 2. Computes total execution time and returns its value
########################################
getTotalExecutionTime() {
    DEVICE=$1
    TEST_TIMESTAMPS=$(cat "$TIMES_OUTPUT" | grep -v "COMPLETE SET" | grep "$DEVICE" | cut -d " " -f6)

    TOTAL_TEST_DURATION=0
    for TIME in $TEST_TIMESTAMPS ; do 
        TOTAL_TEST_DURATION=$(echo "scale=2;$TOTAL_TEST_DURATION+$TIME" | bc)
    done

    echo $TOTAL_TEST_DURATION
}

########################################
# 1. Generates JUnit xml file based on raw test output in concurrent mode
########################################
generateConcurrentJunitReport() {
    # Converts raw instrumentation output into JUnit xml file
    for DEVICE in $(cat $DEVICE_LIST_OUTPUT) ; do
        generateJunitReport $DEVICE &
    done

    wait
}

########################################
# 1. Generates JUnit xml file based on raw test output in sharded mode
########################################
generateJunitReport() {

    # Based on parameters presence different paths and variables will be used
    if [ $# -eq 0 ] ; then
        REPORT_PATH="./test-results/test-summary.xml"
        TOTAL_TEST_DURATION=$(getTotalExecutionTime)
        DEVICE_INSTRUCTIONS=$(cat "$TIMES_OUTPUT")
    else
        DEVICE=$1
        REPORT_PATH="./test-results/$DEVICE/test-summary.xml"
        TOTAL_TEST_DURATION=$(getTotalExecutionTime $DEVICE)
        DEVICE_INSTRUCTIONS=$(cat "$TIMES_OUTPUT" | grep "$DEVICE")
    fi

     # Generate test timestamp
    REPORT_TIMESTAMP="$(date +"%T")T$(date +"%F")"

    # Generate a list of tests
    TEST_LIST=$(echo "$DEVICE_INSTRUCTIONS" | cut -d "(" -f2- | cut -d ")" -f1)

    # Init junit xml file
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<testsuite hostname=\"local-host\" name=\"$REPORT_PATH\" time=\"$TOTAL_TEST_DURATION\" timestamp=\"$REPORT_TIMESTAMP\"><properties />" > $REPORT_PATH

    # Converts raw instrumentation output into JUnit xml file
    for TEST in $(echo "$TEST_LIST") ; do
        # Get test properties
        CLASS_NAME=$(echo "$TEST" | cut -d "#" -f1)
        TEST_NAME=$(echo "$TEST" | cut -d "#" -f2)

        # Get test duration
        TEST_DURATION=$(echo "$DEVICE_INSTRUCTIONS" | grep "$TEST" | cut -d " " -f6 | tr -d "\n\t\r ")

        # Generte output based on results
        if [ $(echo "$TEST" | grep -c "[/]") -eq 1 ] ; then
            echo -e "\t<testcase classname=\"$CLASS_NAME\" name=\"$TEST_NAME\" time=\"$TEST_DURATION\" />" >> $REPORT_PATH
        elif [ $(echo "$TEST" | grep -c "FAIL") -eq 1 ] ; then
            TEST_HASH=$(getHash "$TEST")
            if [ $# -eq 0 ] ; then
                TEST_SUMMARY="./*/$TEST_HASH/running-test.txt"
            else
                TEST_SUMMARY="./$DEVICE/$TEST_HASH/running-test.txt"
            fi

            FAILURE_LINE=$(cat $TEST_SUMMARY | grep -n "There was 1 failure:" | cut -d ":" -f1 | tr -d "<>&\n\t\r ")
            FAILURE_TYPE=$(sed -n "$(($FAILURE_LINE+2))p" $TEST_SUMMARY | cut -d ":" -f1 | tr -d "<>&\n\t\r ")
            FAILURE_MESSAGE=$(sed -n "$(($FAILURE_LINE+2))p" $TEST_SUMMARY | cut -d ":" -f2 | tr -d "<>&\n\t\r ")
            STACKTRACE_LENGHT=$(cat $TEST_SUMMARY | wc -l | tr -d "<>&\n\t\r ")
            FAILURE_STACKTRACE=$(cat $TEST_SUMMARY | tail -$(($STACKTRACE_LENGHT-$FAILURE_LINE-2)))

            echo -e "\t<testcase classname=\"$CLASS_NAME\" name=\"$TEST_NAME\" time=\"$TEST_DURATION\">" >> $REPORT_PATH
            echo -e "\t\t<failure message=\"$FAILURE_MESSAGE\" type=\"$FAILURE_TYPE\">" >> $REPORT_PATH 
            echo "$FAILURE_STACKTRACE" | tr -d "<>&" >> $REPORT_PATH
            echo -e "\t\t</failure>\n\t</testcase>" >> $REPORT_PATH
        else
            echo -e "\t<testcase classname=\"$CLASS_NAME\" name=\"$TEST_NAME\" time=\"$TEST_DURATION\" />" >> $REPORT_PATH
        fi
    done
    # Close the junit report
    echo "</testsuite>" >> $REPORT_PATH
}
