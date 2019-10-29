#!/bin/bash

########################################
# 1. Shapes instrumentation tests into instructions log
# 2. Instruction log can then be divided into sets for parallelization
# 3. Instruction log can be run as a whole for concurrency
########################################

# Sourcing global parameters
source ./config/config

# If scan output file is missing there is nothing to do further
if [ ! -f $SCAN_OUTPUT ] ; then
    echo "Missing raw test output!"
    exit 1
fi

# Remove plan if already exists, we need a frest start
if [ -e $INSTRUCTION_OUTPUT ]; then
    rm $INSTRUCTION_OUTPUT
fi

# Declare variables
TEST_NAMES=()
CLASS_NAMES=()
TOTAL_TESTS=0

# Itterate through the lines in scan file to generate instruction file
INDEX=-1
while read LINE; do
    # When package is matched, class name can be found in the same line
    if [[ $LINE == "$PACKAGE"* ]] ; then
        CLASS_NAME=$(echo "$LINE" | cut -d '=' -f2 | cut -d ':' -f1 | tr -d '\t\r\n ')
        PARAMETERISED_CLASS=$(echo "$CLASS_NAME" | grep -c "\\$" | tr -d '\t\r\n ')
        continue
    fi

    # When test line is found, extract name and check for duplications
    if [[ $LINE == *"test="* ]] ; then

        # Different implementation for parameterised tests
        if [ $PARAMETERISED_CLASS -gt 0 ] ; then
            CLASS_NAME=$(echo "$CLASS_NAME" | cut -d "$" -f1)
            TEST_NAME=""
        else
            TEST_NAME=$(echo "$LINE" | cut -d '=' -f2 | tr -d '\t\r\n ')
        fi

        # Find duplications by itterating through existing tests
        TEST_DUPLICATION="false"
        for TEST in "${!TEST_NAMES[@]}" ; do
            # If duplicated test & class name is found, set duplication flag to true (TEST_DUPLICATION="true")
            if [ "${TEST_NAMES[$TEST]}" == "$TEST_NAME" ] && [ "${CLASS_NAMES[$TEST]}" == "$CLASS_NAME" ] ; then
                TEST_DUPLICATION="true"
                break
            fi
        done

        # If test is a duplicat then do not add it
        if [ "$TEST_DUPLICATION" == "false" ] ; then
            TEST_NAMES+=("$TEST_NAME")
            CLASS_NAMES+=("$CLASS_NAME")
            INDEX=$((INDEX + 1))
        fi

        continue
    fi
done < "$SCAN_OUTPUT"

# Covert array of tests into instruction set
for N in "${!CLASS_NAMES[@]}" ; do

    # Add delimiter
    echo "$TEST_DELIMITER" >> $INSTRUCTION_OUTPUT

    # Add instruction line (varies between parameterised tests)
    if [ "${TEST_NAMES[$N]}" == "" ] ; then
        echo "${CLASS_NAMES[$N]}" >> $INSTRUCTION_OUTPUT
    else
        echo "${CLASS_NAMES[$N]}#${TEST_NAMES[$N]}" >> $INSTRUCTION_OUTPUT
    fi

    # Count number of tests
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
done

# Total test output
echo "TOTAL INSTRUCTION SETS=$TOTAL_TESTS"

# If no test have been selected there is no point to continue
if [ $TOTAL_TESTS -eq 0 ] ; then
    echo "No tests to run!"
    exit 1
fi