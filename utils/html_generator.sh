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

generateDeviceStatus() {
    RESULT=$1
    TOTAL=$(echo "$RESULT" | wc -l)

    if [ $(echo "$RESULT" | grep -c "[/]") -eq $TOTAL ] ; then
        echo "pass"
    elif [ $(echo "$RESULT" | grep -c "FAIL") -gt 0 ] ; then
        echo "fail"
    elif [ $(echo "$RESULT" | grep -c "SKIPPED") -gt 0 ] ; then
        echo "skip"
    else
        echo "error"
    fi
}

generateClassStatus() {
    RESULT=$1
    TOTAL=$(echo "$RESULT" | wc -l)

    if [ $(echo "$RESULT" | grep -c "[/]") -eq $TOTAL ] ; then
        echo "pass"
    elif [ $(echo "$RESULT" | grep -c "FAIL") -gt 0 ] ; then
        echo "fail"
    elif [ $(echo "$RESULT" | grep -c "SKIPPED") -gt 0 ] ; then
        echo "skip"
    else
        echo "error"
    fi
}

generateTestLabelStatus() {
    RESULT=$1
    if [ $(echo "$RESULT" | grep -c "[/]") -eq 1 ] ; then
        echo "pass"
    elif [ $(echo "$RESULT" | grep -c "FAIL") -eq 1 ] ; then
        echo "fail"
    elif [ $(echo "$RESULT" | grep -c "SKIPPED") -eq 1 ] ; then
        echo "skip"
    else
        echo "error"
    fi
}

generateSwitchToggle() {
    HTML_CLASS=$1
    TOGGLE_COPY=$2

    echo "<p class=\"toggle\">$TOGGLE_COPY tests:<label class=\"switch\"><input type=\"checkbox\" id=\"toggle$TOGGLE_COPY\" checked onclick=\"toggleState('toggle$TOGGLE_COPY', '$HTML_CLASS')\"><span class=\"slider round\"></span></label></p>"
}

generateDeviceTestList() {
    DEVICE=$1
    DEVICE_INSTRUCTIONS=$(cat "$TIMES_OUTPUT" | grep "$DEVICE")

    DEVICE_STATUS=$(generateDeviceStatus "$(echo "$DEVICE_INSTRUCTIONS")")
    if [ "$DEVICE_STATUS" == "pass" ] ; then
        DEVICE_PROPERTIES="bgcolor=\"#336600\""
    elif [ "$DEVICE_STATUS" == "fail" ] ; then
        DEVICE_PROPERTIES="bgcolor=\"#990000\""
    elif [ "$DEVICE_STATUS" == "skip" ] ; then
        DEVICE_PROPERTIES="bgcolor=\"#808080\""
    elif [ "$DEVICE_STATUS" == "error" ] ; then
        echo "There has been a problem with status for device -> $DEVICE"        
    else
        exit 1
    fi

    DEVICE_MODEL="$(getDeviceDisplayName "$DEVICE")"

    DEVICE_HTML=""
    DEVICE_HTML+=$(echo "<table id="deviceTable" border="0" width="1200" align="center"><tr><td align="left" "$DEVICE_PROPERTIES">Device: $DEVICE_MODEL</td></tr>")

    CURRENT_CLASS_NAME=""
    TEST_LIST=$(echo "$DEVICE_INSTRUCTIONS" | cut -d "(" -f2- | cut -d ")" -f1)
    for TEST in $(echo "$TEST_LIST") ; do
        CLASS_NAME=$(echo "$TEST" | cut -d "#" -f1)
        TEST_NAME=$(echo "$TEST" | cut -d "#" -f2)

        if [ "$CURRENT_CLASS_NAME" != "$CLASS_NAME" ] ; then

            if [ "$DEVICE_STATUS" == "pass" ] ; then
                CLASS_PROPERTIES="bgcolor=\"#669900\" class=\"passedTest\""
            else
                CLASS_STATUS=$(generateClassStatus "$(echo "$DEVICE_INSTRUCTIONS" | grep $CLASS_NAME)")

                if [ "$CLASS_STATUS" == "pass" ] ; then
                    CLASS_PROPERTIES="bgcolor=\"#669900\" class=\"passedTest\""
                elif [ "$CLASS_STATUS" == "fail" ] ; then
                    CLASS_PROPERTIES="bgcolor=\"#cc0000\" class=\"failedTest\""
                elif [ "$CLASS_STATUS" == "skip" ] ; then
                    CLASS_PROPERTIES="bgcolor=\"#8c8c8c\" class=\"skippedTest\""
                elif [ "$CLASS_STATUS" == "error" ] ; then
                    echo "There has been a problem with status for class -> $CLASS_NAME ($DEVICE)"
                else
                    exit 1
                fi
            fi

            if [ "$CURRENT_CLASS_NAME" != "" ] ; then
                DEVICE_HTML+=$(echo "</table>")
            fi

            DEVICE_HTML+=$(echo "<table id="classTable" border="0" width="1150" align="center"><tr><td align="left" "$CLASS_PROPERTIES">CLASS: $CLASS_NAME</td></tr><table id="testTable" border="0" width="1100" align="center">")
            CURRENT_CLASS_NAME="$CLASS_NAME"
        fi

        TEST_HASH=$(getHash "$TEST")
        TEST_RELATIVE_PATH=$(echo "./$DEVICE/$TEST_HASH/index.html" | sed s/"#"/"%23"/g)

        if [[ "$DEVICE_STATUS" == "pass" || "$CLASS_STATUS" == "pass" ]] ; then
            TEST_PROPERTIES="bgcolor=\"#99cc00\" class=\"passedTest\""
            TEST_SUFIX=""
        else
            TEST_STATUS=$(generateTestLabelStatus "$(echo "$DEVICE_INSTRUCTIONS" | grep "($TEST)")")

            if [ "$TEST_STATUS" == "pass" ] ; then
                TEST_PROPERTIES="bgcolor=\"#99cc00\" class=\"passedTest\""
                TEST_SUFIX=""
            elif [ "$TEST_STATUS" == "fail" ] ; then
                TEST_PROPERTIES="bgcolor=\"#ff3300\" class=\"failedTest\""
                TEST_SUFIX="[x] FAIL"
            elif [ "$TEST_STATUS" == "skip" ] ; then
                TEST_PROPERTIES="bgcolor=\"#999999\" class=\"skippedTest\""
                TEST_SUFIX="[-] SKIPPED"
            elif [ "$TEST_STATUS" == "error" ] ; then
                echo "There has been a problem with status for test -> $TEST ($DEVICE)"    
            else
                exit 1
            fi
        fi
        DEVICE_HTML+=$(echo "<tr><td align="left" "$TEST_PROPERTIES"><a href="$TEST_RELATIVE_PATH">--> $TEST_NAME $TEST_SUFIX</a></td></tr>")
    done
    DEVICE_HTML+=$(echo "</table>")
    echo "$DEVICE_HTML" >> "$EXECUTION_SUMMARY"
}

generateHtmlExecutionSummary() {
    TOTAL_DURATION=$1
    DEVICE_LIST=$(cat $DEVICE_LIST_OUTPUT)
    EXECUTION_SUMMARY="$TEST_OUTPUT/index.html"

    cp ./html/execution_template.html "$EXECUTION_SUMMARY"

    NUMBER_OF_DEVICES=$(echo "$DEVICE_LIST" | wc -l)
    NUMBER_OF_TOTAL_TESTS=$(cat "$TIMES_OUTPUT" | wc -l)
    NUMBER_OF_PASSING_TESTS=$(cat "$TIMES_OUTPUT" | grep -c "OK")
    NUMBER_OF_FAILING_TESTS=$(cat "$TIMES_OUTPUT" | grep -c "FAIL")
    NUMBER_OF_SKIPPED_TESTS=$(cat "$TIMES_OUTPUT" | grep -c "SKIPPED")

    echo "<div id="testSummary">
            <h1>Execution summary</h1>
            <h3>$NUMBER_OF_DEVICES device(s) run $NUMBER_OF_TOTAL_TESTS tests, $NUMBER_OF_PASSING_TESTS have passed, $NUMBER_OF_FAILING_TESTS have failed and $NUMBER_OF_SKIPPED_TESTS been skipped in $TOTAL_DURATION</h3>
         </div>" >> "$EXECUTION_SUMMARY"

    echo "$(generateSwitchToggle "passedTest" "Passing")" >> "$EXECUTION_SUMMARY"
    echo "$(generateSwitchToggle "failedTest" "Failing")" >> "$EXECUTION_SUMMARY"
    echo "$(generateSwitchToggle "skippedTest" "Skipped")" >> "$EXECUTION_SUMMARY"

    FIRST_DEVICE=true
    for DEVICE in $(echo "$DEVICE_LIST") ; do
        generateDeviceTestList "$DEVICE" &
    done

    wait
    echo "</table></body></html>" >> "$EXECUTION_SUMMARY"
}