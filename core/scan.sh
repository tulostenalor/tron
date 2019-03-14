#!/bin/bash

########################################
# 1. Dry run to generate list of all available instrumentation tests
# 2. Results are saved in *SCAN_OUTPUT* file
########################################

# Sourcing global parameters
source ./config/config

# Sourcing passed parameters
TARGET_PACKAGE=$1
TARGET_CLASS=$2
ANNOTATION=$3

# Assigning first available device
DEVICE=$(cat $DEVICE_LIST_OUTPUT | tail -1)

# Ensuring scan output is being removed
if [ -e $SCAN_OUTPUT ]; then
    rm $SCAN_OUTPUT
fi

# Build annotation filter if provided
if [ -n "$ANNOTATION" ] ; then
    ANNOTATION=$(echo "-e annotation $ANNOTATION_PACKAGE.$ANNOTATION")
fi

# Build package filter if provided & filtering by class and annotation
PACKAGES=""
if [ -n "$TARGET_PACKAGE" ] ; then
    for TARGET in $(echo "$TARGET_PACKAGE" | tr ',' '\n') ; do
        if [ -n "$PACKAGES" ] ; then 
            PACKAGES="$PACKAGES,$PACKAGE.$TARGET"
        else
            PACKAGES="$PACKAGE.$TARGET"
        fi
    done
# In case no classes have been passes we assume there is no filtering and entire sutie will be executed    
elif [ -z "$TARGET_CLASS" ] ; then
    PACKAGES="$PACKAGE"
fi

# Building class filter if provided & filtering by class and annotation
CLASSES=""
if [ -n "$TARGET_CLASS" ] ; then
    for TARGET in $(echo "$TARGET_CLASS" | tr ',' '\n') ; do
        if [ -n "$CLASSES" ] ; then 
            CLASSES="$CLASSES,$PACKAGE.$TARGET"
        else
            CLASSES="$PACKAGE.$TARGET"
        fi
    done

    adb -s $DEVICE shell am instrument -w -r -e log true -e class $CLASSES $ANNOTATION $RUNNER_PACKAGE/$TEST_RUNNER >> $SCAN_OUTPUT
fi

# Filtering by package and annotation only occurs when package filter have been supplied or there is no class filter
if [ -n "$PACKAGES" ] ; then
    adb -s $DEVICE shell am instrument -w -r -e log true -e package $PACKAGES $ANNOTATION $RUNNER_PACKAGE/$TEST_RUNNER >> $SCAN_OUTPUT
fi