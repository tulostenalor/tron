#!/bin/bash

########################################
# 1. Generates a html report for test run
# 2. Copies template into appriopiate test dir
# 3. Populates template with correct test data
########################################

source ./config/config
source ./utils/device_manager.sh

generateTestSummary() {
    DEVICE=$1
    INSTRUCTION=$2
    STATUS=$3

    DEVICE_MODEL="$(getDeviceDisplayName $DEVICE)"

    MARKER="&&&&&"
    TEST_DETAILS="<div id=\"testSummary\"><h1 id=\"deviceName\">Device: $DEVICE_MODEL</h1><h3 id=\"testStatus\">Test: $INSTRUCTION - $STATUS</h3></div>"

    cp ./html/test_template.html "$TEST_DIRECTORY/index.html"
    sed -i -e "s~$MARKER~$TEST_DETAILS~" "$TEST_DIRECTORY/index.html"
}

generateDeviceLabelProperties() {
    DEVICE=$1
    FAILED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "FAIL" | wc -l | tr -d "\n\t\r ")
    SKIPPED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "SKIPPED" | wc -l | tr -d "\n\t\r ")

    if [ $FAILED -gt 0 ] ; then
        echo "bgcolor=\"#990000\""
    elif [ $SKIPPED -gt 0 ] ; then
        echo "bgcolor=\"#808080\""
    else
        echo "bgcolor=\"#336600\""
    fi
}

generateClassLabelProperties() {
    CLASS=$1
    FAILED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$CLASS" | grep "FAIL" | wc -l | tr -d "\n\t\r ")
    SKIPPED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$CLASS" | grep "SKIPPED" | wc -l | tr -d "\n\t\r ")

    if [ $FAILED -gt 0 ] ; then
        echo "bgcolor=\"#cc0000\" class=\"failedTest\""
    elif [ $SKIPPED -gt 0 ] ; then
        echo "bgcolor=\"#8c8c8c\" class=\"skippedTest\""
    else
        echo "bgcolor=\"#669900\" class=\"passedTest\""
    fi
}

generateTestLabelProperties() {
    DEVICE=$1
    TEST=$2
    FAILED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$TEST" | grep "FAIL" | wc -l | tr -d "\n\t\r ")
    SKIPPED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$TEST" | grep "SKIPPED" | wc -l | tr -d "\n\t\r ")

    if [ $FAILED -gt 0 ] ; then
        echo "bgcolor=\"#ff3300\" class=\"failedTest\""
    elif [ $SKIPPED -gt 0 ] ; then
        echo "bgcolor=\"#999999\" class=\"skippedTest\""
    else
        echo "bgcolor=\"#99cc00\" class=\"passedTest\""
    fi
}

generateTestLabelSufix() {
    DEVICE=$1
    TEST=$2
    FAILED=$(cat $TIMES_OUTPUT | grep "$DEVICE" | grep "$TEST" | grep "FAIL" | wc -l | tr -d "\n\t\r ")

    if [ $FAILED -gt 0 ] ; then
        echo "[x] FAIL"
    else
        echo ""
    fi
}

generateSwitchToggle() {
    HTML_CLASS=$1
    TOGGLE_COPY=$2

    # failedTest
    # Failed
    echo "<p class=\"toggle\">$TOGGLE_COPY tests:<label class=\"switch\"><input type=\"checkbox\" checked onclick=\"toggleClass('$HTML_CLASS')\"><span class=\"slider round\"></span></label></p>"
}

generateHtmlExecutionSummary() {
    TOTAL_DURATION=$1
    DEVICE_LIST=$(cat $DEVICE_LIST_OUTPUT)
    EXECUTION_SUMMARY="$TEST_OUTPUT/index.html"

    cp ./html/execution_template.html "$EXECUTION_SUMMARY"

    NUMBER_OF_DEVICES=$(cat $DEVICE_LIST_OUTPUT | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_TOTAL_TESTS=$(cat $TIMES_OUTPUT | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_PASSING_TESTS=$(cat $TIMES_OUTPUT | grep "OK" | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_FAILING_TESTS=$(cat $TIMES_OUTPUT | grep "FAIL" | wc -l | tr -d "\n\t\r ")
    NUMBER_OF_SKIPPED_TESTS=$(cat $TIMES_OUTPUT | grep "SKIPPED" | wc -l | tr -d "\n\t\r ")

    echo "<div id="testSummary">
            <h1>Execution summary</h1>
            <h3>$NUMBER_OF_DEVICES device(s) run $NUMBER_OF_TOTAL_TESTS tests, $NUMBER_OF_PASSING_TESTS have passed, $NUMBER_OF_FAILING_TESTS have failed and $NUMBER_OF_SKIPPED_TESTS been skipped in $TOTAL_DURATION</h3>
         </div>" >> "$EXECUTION_SUMMARY"

    echo "$(generateSwitchToggle "passedTest" "Passing")" >> "$EXECUTION_SUMMARY"
    echo "$(generateSwitchToggle "failedTest" "Failing")" >> "$EXECUTION_SUMMARY"
    echo "$(generateSwitchToggle "skippedTest" "Skipped")" >> "$EXECUTION_SUMMARY"

    FIRST_DEVICE=true
    for DEVICE in $(echo "$DEVICE_LIST") ; do 
        PROPERTIES=$(generateDeviceLabelProperties $DEVICE)
        TEST_LIST=$(cat $TIMES_OUTPUT | grep "$DEVICE" | cut -d "(" -f2- | cut -d ")" -f1 | sort)

        if [ ! $FIRST_DEVICE ] ; then
          echo "</table>" >> "$EXECUTION_SUMMARY"
        else
          FIRST_DEVICE=false
        fi

        DEVICE_MODEL="$(getDeviceDisplayName $DEVICE)"

        echo "<table id="deviceTable" border="0" width="1200" align="center">" >> "$EXECUTION_SUMMARY"
        echo "<tr><td align="left" "$PROPERTIES">Device: $DEVICE_MODEL</td></tr>" >> "$EXECUTION_SUMMARY"

        CURRENT_CLASS_NAME=""
        for TEST in $(echo "$TEST_LIST") ; do
            CLASS_NAME=$(echo "$TEST" | cut -d "#" -f1)
            TEST_NAME=$(echo "$TEST" | cut -d "#" -f2)

            if [ "$CURRENT_CLASS_NAME" != "$CLASS_NAME" ] ; then
                PROPERTIES=$(generateClassLabelProperties $CLASS_NAME)

                if [ "$CURRENT_CLASS_NAME" != "" ] ; then
                    echo "</table>" >> "$EXECUTION_SUMMARY"
                fi

                echo "<table id="classTable" border="0" width="1150" align="center">" >> "$EXECUTION_SUMMARY"
                echo "<tr><td align="left" "$PROPERTIES">CLASS: $CLASS_NAME</td></tr>" >> "$EXECUTION_SUMMARY"
                echo "<table id="testTable" border="0" width="1100" align="center">" >> "$EXECUTION_SUMMARY"
                CURRENT_CLASS_NAME="$CLASS_NAME"
            fi

            TEST_HASH=$(getHash $TEST)
            TEST_RELATIVE_PATH=$(echo "./$DEVICE/$TEST_HASH/index.html" | sed s/"#"/"%23"/g)
            PROPERTIES=$(generateTestLabelProperties $DEVICE $TEST)
            TEST_SUFIX=$(generateTestLabelSufix $DEVICE $TEST)

            echo "<tr><td align="left" "$PROPERTIES"><a href="$TEST_RELATIVE_PATH">--> $TEST_NAME $TEST_SUFIX</a></td></tr>" >> "$EXECUTION_SUMMARY"
        done
        echo "</table>" >> "$EXECUTION_SUMMARY"
    done

    echo "</table></body></html>" >> "$EXECUTION_SUMMARY"
}