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
ARGUMENT=""

while getopts d:p:c:a:m:e: flag ; do
    case "${flag}" in
        d) SELECTED_DEVICES=${OPTARG};;
        p) TARGET_PACKAGE=${OPTARG};;
        c) TARGET_CLASS=${OPTARG};;
        a) ANNOTATION=${OPTARG};;
        m) MODE=${OPTARG};;
        e) ARGUMENT=${OPTARG};;
        *) echo "Invalid flag!";;
    esac
done

# Preparing envirounment
mkdir -p $ARTEFACTS_OUTPUT
mkdir -p $TEST_OUTPUT

rm -rf $ARTEFACTS_OUTPUT/**
rm -rf $TEST_OUTPUT/**

# Execution mode (sharded=false|concurrent=true)
CONCURRENT=$MODE

# Cross check selected devices with available ones and creates a list of execution devices
deviceCheck "$SELECTED_DEVICES"

# Prepare devices for tests (closes running apps, installs target apps)
initiateScriptInParallelOnDevices "./utils/instrumentation_prep.sh" "Preparation"

# Scans exisitng package for instrumentation tests with application of provided filters
./core/scan.sh "$TARGET_PACKAGE" "$TARGET_CLASS" "$ANNOTATION"

# Converts an output of the scan into instruction set that can be executed by devices
./core/instruct.sh

# Export global variables for downstream scripts to share
export TEST_CONDITIONS=$(cat "$TEST_CONDITION_INPUT")
export TEST_RUNNER=$(cat "$TEST_RUNNER_OUTPUT")
export ARGUMENT="$ARGUMENT"

# Commands devices to run instructions
./core/command.sh $CONCURRENT

# Teardown for devices
# runScriptInParallelOnDevices "./utils/instrumentation_post.sh" "Teardown"