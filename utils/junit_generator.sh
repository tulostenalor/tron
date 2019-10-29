#!/bin/bash

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
        TOTAL_TEST_DURATION=$(getTotalExecutionTime $DEVICE)

        generateJunitReport $DEVICE
    done
}

########################################
# 1. Generates JUnit xml file based on raw test output in sharded mode
########################################
generateJunitReport() {

    # Based on parameters presence different paths and variables will be used
    if [ $# -eq 0 ] ; then
        REPORT_PATH="./test-results/test-summary.xml"
        TOTAL_TEST_DURATION=$(getTotalExecutionTime)
        SUMMARY_PATHS="./test-results/*/*/running-test.txt"
    else
        DEVICE=$1
        REPORT_PATH="./test-results/$DEVICE/test-summary.xml"
        TOTAL_TEST_DURATION=$(getTotalExecutionTime $DEVICE)
        SUMMARY_PATHS="./test-results/$DEVICE/*/running-test.txt"
    fi

     # Generate test timestamp
    REPORT_TIMESTAMP="$(date +"%T")T$(date +"%F")"

    # Init junit xml file
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<testsuite hostname=\"local-host\" name=\"$REPORT_PATH\" time=\"$TOTAL_TEST_DURATION\" timestamp=\"$REPORT_TIMESTAMP\"><properties />" > $REPORT_PATH

    # Converts raw instrumentation output into JUnit xml file
    for SUMMARY in $(ls -1 $SUMMARY_PATHS) ; do
        TESTCASE_CLASS=$(cat $SUMMARY | grep "INSTRUMENTATION_STATUS: class=" | tail -1 | cut -d "=" -f2)
        TESTCASE_NAME=$(cat $SUMMARY | grep "INSTRUMENTATION_STATUS: test=" | tail -1 | cut -d "=" -f2)
        if [ $# -eq 0 ] ; then
            TESTCASE_DURATION=$(cat "$TIMES_OUTPUT" | grep "$TESTCASE_CLASS#$TESTCASE_NAME" | cut -d " " -f6)
        else
            TESTCASE_DURATION=$(cat "$TIMES_OUTPUT" | grep "$DEVICE" | grep "$TESTCASE_CLASS#$TESTCASE_NAME" | cut -d " " -f6)
        fi

        # In case of test failure
        if grep -q "Tests run: 1,  Failures: 1" $SUMMARY ; then
            FAILURE_LINE=$(cat $SUMMARY | grep -n "There was 1 failure:" | cut -d ":" -f1 | tr -d "\n\t\r ")
            FAILURE_TYPE=$(sed -n "$(($FAILURE_LINE+2))p" $SUMMARY | cut -d ":" -f1 | cut -d "<" -f1 | tr -d "\n\t\r ")
            FAILURE_MESSAGE=$(sed -n "$(($FAILURE_LINE+2))p" $SUMMARY | cut -d ":" -f2 | cut -d "<" -f1 | tr -d "\n\t\r ")
            STACKTRACE_LENGHT=$(cat $SUMMARY | wc -l | tr -d "\n\t\r ")
            FAILURE_STACKTRACE=$(cat $SUMMARY | tail -$(($STACKTRACE_LENGHT-$FAILURE_LINE-2)))

            echo -e "\t<testcase classname=\"$TESTCASE_CLASS\" name=\"$TESTCASE_NAME\" time=\"$TESTCASE_DURATION\">" >> $REPORT_PATH

            echo -e "\t\t<failure message=\"$FAILURE_MESSAGE\" type=\"$FAILURE_TYPE\">" >> $REPORT_PATH 
            echo "$FAILURE_STACKTRACE" >> $REPORT_PATH
            echo -e "\t\t</failure>\n\t</testcase>" >> $REPORT_PATH
        else
            echo -e "\t<testcase classname=\"$TESTCASE_CLASS\" name=\"$TESTCASE_NAME\" time=\"$TESTCASE_DURATION\" />" >> $REPORT_PATH
        fi
    done

    # Close the junit report
    echo "</testsuite>" >> $REPORT_PATH
}
