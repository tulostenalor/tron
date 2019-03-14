#!/bin/bash

########################################
# 1. Generates a html report for test run
# 2. Copies template into appriopiate test dir
# 3. Populates template with correct test data
########################################

source ./config/config

generateTestSummary() {
    DEVICE=$1
    INSTRUCTION=$2
    STATUS=$3

    MARKER="&&&&&"
    TEST_DETAILS="<div id=\"testSummary\"><h1 id=\"deviceName\">Device: $DEVICE</h1><h3 id=\"testStatus\">Test: $INSTRUCTION - $STATUS</h3></div>"

    cp ./html/test_template.html "$TEST_DIRECTORY/index.html"
    sed -i -e "s~$MARKER~$TEST_DETAILS~" "$TEST_DIRECTORY/index.html"
}

generateHtmlExecutionSummary() {
    DEVICE_LIST=$(cat $DEVICE_LIST_OUTPUT)
    EXECUTION_SUMMARY="$TEST_OUTPUT/index.html"

    cp ./html/execution_template.html "$EXECUTION_SUMMARY"

    NUMBER_OF_DEVICES=$(cat $DEVICE_LIST_OUTPUT | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_TOTAL_TESTS=$(cat $TIMES_OUTPUT | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_PASSING_TESTS=$(cat $TIMES_OUTPUT | grep "OK" | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_FAILING_TESTS=$(cat $TIMES_OUTPUT | grep "FAIL" | wc -l | tr -d "\n\t\r ")

    echo "<div id="testSummary"> 
            <h1>Execution summary</h1>
            <h3>$NUMBER_OF_DEVICES device(s) run $NUMBER_OF_TOTAL_TESTS tests in total, $NUMBER_OF_PASSING_TESTS have passed and $NUMBER_OF_FAILING_TESTS have failed.</h3>
         </div>" >> "$EXECUTION_SUMMARY"

    FIRST_DEVICE=true
    for DEVICE in $(echo "$DEVICE_LIST") ; do 
        DEVICE_STATUS=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "FAIL" | wc -l | tr -d "\n\t\r ")
        TEST_LIST=$(cat $TIMES_OUTPUT | grep "$DEVICE" | cut -d "(" -f2- | cut -d ")" -f1 | sort)

        if [ $DEVICE_STATUS -eq 0 ] ; then
            COLOR="#336600"
        else
            COLOR="#990000"
        fi

        if [ ! $FIRST_DEVICE ] ; then
          echo "</table>" >> "$EXECUTION_SUMMARY"
        else
          FIRST_DEVICE=false
        fi

        echo "<table id="deviceTable" border="0" width="1200" align="center">" >> "$EXECUTION_SUMMARY"
        echo "<tr><td align="left" bgcolor="$COLOR">Device: $DEVICE</td></tr>" >> "$EXECUTION_SUMMARY"

        CURRENT_CLASS_NAME=""
        for TEST in $(echo "$TEST_LIST") ; do
            CLASS_NAME=$(echo "$TEST" | cut -d "#" -f1)
            TEST_NAME=$(echo "$TEST" | cut -d "#" -f2)

            if [ "$CURRENT_CLASS_NAME" != "$CLASS_NAME" ] ; then
                CLASS_STATUS=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$CLASS_NAME" | grep "FAIL" | wc -l | tr -d "\n\t\r ")

                if [ "$CURRENT_CLASS_NAME" != "" ] ; then
                    echo "</table>" >> "$EXECUTION_SUMMARY"
                fi

                if [ $CLASS_STATUS -eq 0 ] ; then
                    COLOR="#669900"
                else
                    COLOR="#cc0000"
                fi

                echo "<table id="classTable" border="0" width="1150" align="center">" >> "$EXECUTION_SUMMARY"
                echo "<tr><td align="left" bgcolor="$COLOR">CLASS: $CLASS_NAME</td></tr>" >> "$EXECUTION_SUMMARY"
                echo "<table id="testTable" border="0" width="1100" align="center">" >> "$EXECUTION_SUMMARY"
                CURRENT_CLASS_NAME="$CLASS_NAME"
            fi

            TEST_HASH=$(getHash $TEST)
            TEST_RELATIVE_PATH=$(echo "./$DEVICE/$TEST_HASH/index.html" | sed s/"#"/"%23"/g)
            TEST_STATUS=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$TEST" | grep "FAIL" | wc -l | tr -d "\n\t\r ")

            if [ $TEST_STATUS -eq 0 ] ; then
                COLOR="#99cc00"
            else
                COLOR="#ff3300"
            fi

            echo "<tr><td align="left" bgcolor="$COLOR" id="testRow"><a href="$TEST_RELATIVE_PATH">--> $TEST_NAME</a></td></tr>" >> "$EXECUTION_SUMMARY"
        done
        echo "</table>" >> "$EXECUTION_SUMMARY"
    done

    echo "</table></body></html>" >> "$EXECUTION_SUMMARY"
}