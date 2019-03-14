#!/bin/bash -e

# Build & package information
source ./config/config
source ./utils/thread.sh
source ./utils/device_manager.sh

# Filters & parameters
SELECTED_DEVICES=""
TARGET_PACKAGE=""
TARGET_CLASS=""
ANNOTATION=""
MODE=false

while getopts d:p:c:a:m: flag ; do
    case "${flag}" in
        d) SELECTED_DEVICES=${OPTARG};;
        p) TARGET_PACKAGE=${OPTARG};;
        c) TARGET_CLASS=${OPTARG};;
        a) ANNOTATION=$OPTARG;;
        m) MODE=$OPTARG;;
        *) echo "Invalid flag passed!";;
    esac
done

# Filters
# TARGET_PACKAGE=""
# TARGET_CLASS=""
# ANNOTATION="SmallTest"
# ANNOTATION=""

# Preparing envirounment
mkdir -p $ARTEFACTS_OUTPUT
mkdir -p $TEST_OUTPUT

rm -rf $ARTEFACTS_OUTPUT/**
rm -rf $TEST_OUTPUT/**

# Execution mode
CONCURRENT=$MODE

# Cross check selected devices with available ones and creates a list of devices
deviceCheck "$SELECTED_DEVICES"

# Prepare devices for tests (closes running apps, installs target apps)
runScriptOnMultipleThreads "$SELECTED_DEVICES" "./utils/instrumentation_prep.sh" "Preparation"

# Scans exisitng package for instrumentation tests with application of provided filters
./core/scan.sh "$TARGET_PACKAGE" "$TARGET_CLASS" "$ANNOTATION"

# Converts output of the scan into instruction set that can be executed by devices
./core/instruct.sh

# Commands devices to run instructions
./core/command.sh $CONCURRENT

# Teardown for devices
runScriptOnMultipleThreads "$SELECTED_DEVICES" "./utils/instrumentation_post.sh" "Teardown"