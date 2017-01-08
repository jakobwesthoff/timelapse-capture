#!/bin/bash
###
# Copyright (c) 2017 Jakob Westhoff
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
###

trap onExit SIGHUP SIGINT SIGTERM

MAX_BACKGROUND_JOBS=2

exitSignalReceived=0
backgroundJobsWaiting=( )
backgroundJobsRunningCount=0

##
# Print usage information for the script execution
##
printUsage() {
  echo "Timelapse Capture (c) Jakob Westhoff"
  echo
  echo "timelapse-capture <interval> <target-path>"
  echo "  <interval> - Interval between screencaptures in seconds"
  echo "  <target-path> - Path to store screencaptures to"
  echo
}

##
# Trap handler executed once the script should be terminated.
#
# The handler mainly takes care of finishing the execution of all the queued
# background operations.
##
onExit() {
  exitSignalReceived=1
  echo
  echo "Waiting for unfinished background operations..."

  runNextWaitingBackgroundJob
  while [ "${backgroundJobsRunningCount}" -gt 0 ] || [ "${#backgroundJobsWaiting[*]}" -gt 0 ]; do
    runNextWaitingBackgroundJob
    echo -en "\r                                                                               "
    echo -en "\rWaiting - Background jobs (running/waiting): ${backgroundJobsRunningCount}/${#backgroundJobsWaiting[*]}"
    sleep .4
  done
  echo
  echo "Everything done."
}

##
# Run every next waiting background job until either the limit is reached
# or no more jobs are waiting
##
runNextWaitingBackgroundJob() {
  updateBackgroundJobsRunningCount

  if [ ${#backgroundJobsWaiting[*]} -eq 0 ]; then
    return
  fi

  if [ "${backgroundJobsRunningCount}" -ge "${MAX_BACKGROUND_JOBS}" ]; then
    return
  fi

  local nextJob=${backgroundJobsWaiting[0]}
  backgroundJobsWaiting=("${backgroundJobsWaiting[@]:1}")

  runBackgroundJob "${nextJob}"
  runNextWaitingBackgroundJob
}

##
# Assert that the given targetPath exists and is writable
##
assertTargetPathExistsAndIsWritable() {
  local targetPath="${1}"

  if [ ! -d "${targetPath}" ]; then
    echo "Target path: '${targetPath}' is not a directory"
    exit 2
  fi

  if [ ! -w "${targetPath}" ]; then
    echo "Target path: '${targetPath}' is not writable"
    exit 2
  fi
}

##
# Update the currently displayed status message for a given status type and
# image counter value
##
updateStatus() {
  local status="${1}"
  local imageCounter="${2}"

  echo -en "\r                                                                               "
  echo -en "\r${status} image ${imageCounter} - Background jobs (running/waiting): ${backgroundJobsRunningCount}/${#backgroundJobsWaiting[*]}"
}

##
# Enqueue a new background operation of a given type for a given captured image
##
enqueueBackgroundJob() {
  local jobType="${1}"
  local fullTargetPathname="${2}"

  backgroundJobsWaiting[${#backgroundJobsWaiting[*]}]="${jobType};${fullTargetPathname}"
  updateBackgroundJobsRunningCount
  runNextWaitingBackgroundJob
}

##
# Update the count of currently running background jobs
##
updateBackgroundJobsRunningCount() {
  backgroundJobsRunningCount=$(jobs -l|grep 'Running'|wc -l)
}

##
# Run a specific background job from the queue
##
runBackgroundJob() {
  local enqueuedJob="${1}"

  local jobType="${enqueuedJob%%;*}"
  local fullTargetPathname="${enqueuedJob##*;}"

  case "${jobType}" in
    pngcrush)
      nice -n 10 -- pngcrush -ow -new -q -s "${fullTargetPathname}" "${fullTargetPathname}.pngcrush.tmp" &
    ;;
    resize)
      (echo "RESIZE!"; sleep 1.5) &
    ;;
  esac

  updateBackgroundJobsRunningCount
}

##
# Main routine running the capturing and background process enqueueing in a loop
##
runCaptureLoop() {
  local interval="${1}"
  local targetPath="${2}"

  assertTargetPathExistsAndIsWritable "${targetPath}"

  echo "Writing screencaptures to '${targetPath}' every ${interval}s..."

  local imageCounter=1
  while [ "${exitSignalReceived}" -ne "1" ]; do
    local imageName="$(printf "%09d.png" "${imageCounter}")"
    local fullTargetPathname="${targetPath}/${imageName}"
    updateStatus "Capturing" "${imageCounter}"
    screencapture -x -m -T0 -tpng "${fullTargetPathname}"
    enqueueBackgroundJob "resize" "${fullTargetPathname}"
    enqueueBackgroundJob "pngcrush" "${fullTargetPathname}"
    updateStatus "Captured" "${imageCounter}"
    ((imageCounter++))
    sleep "${interval}"
  done
}

if [ "$#" -lt 2 ]; then
  printUsage
  exit 1
fi

runCaptureLoop "${1}" "${2}"
