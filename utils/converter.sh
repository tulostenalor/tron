#!/bin/bash

convertMilisecondsToSeconds() {
  MILISECONDS=$1

  echo "scale=2;${MILISECONDS}/1000" | bc
}

convertMilisecondsToMinutesSeconds() {
  MILISECONDS=$1

  MINUTES=$(echo "scale=0;${MILISECONDS}/60000" | bc)
  SECONDS=$(echo "scale=0;(${MILISECONDS}%60000)/1000" | bc)

  echo "$MINUTES minute(s) $SECONDS second(s)."
}

calculatePercentage() {
  BASE=$1
  TARGET=$2

  # Initial calculation with high precision
  echo "scale=2;(${BASE}*100)/${TARGET}" | bc
}

getHash() {
  STRING=$1

  echo "$STRING" | shasum | cut -d " " -f1 
}

getCurrentDate() {
  OSTYPE=$(uname -s)

  if [ "$OSTYPE" == "Darwin" ] ; then
    echo "$(gdate +%s%N | cut -b1-13)"
  else
    echo "$(date +%s%3N)"
  fi
}
