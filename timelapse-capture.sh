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

MAX_OPTIMIZATIONS=2

exitSignalReceived=0
optimizationJobsWaiting=( )
optimizationJobsRunning=0

onExit() {
  exitSignalReceived=1
  echo
  echo "Waiting for unfinished optimizations to settle..."

  updateOptimizationJobsRunning
  runEnqueuedOptimzations
  while [ "${optimizationJobsRunning}" -gt 0 ] || [ "${#optimizationJobsWaiting[*]}" -gt 0 ]; do
    updateOptimizationJobsRunning
    runEnqueuedOptimzations
    echo -en "\r                                                                               "
    echo -en "\rWaiting - Optimizing ${optimizationJobsRunning} images (${#optimizationJobsWaiting[*]} waiting)"
    sleep .4
  done
  echo
  echo "Everything done."
}

runEnqueuedOptimzations() {
  if [ ${#optimizationJobsWaiting[*]} -eq 0 ]; then
    return
  fi

  if [ "${optimizationJobsRunning}" -ge "${MAX_OPTIMIZATIONS}" ]; then
    return
  fi

  local nextJob=${optimizationJobsWaiting[0]}
  optimizationJobsWaiting=("${optimizationJobsWaiting[@]:1}")

  runOptimization "${nextJob}"
  runEnqueuedOptimzations
}

printUsage() {
  echo "Timelapse Capture (c) Jakob Westhoff"
  echo
  echo "timelapse-capture <interval> <target-path>"
  echo "  <interval> - Interval between screencaptures in seconds"
  echo "  <target-path> - Path to store screencaptures to"
  echo
}

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

updateStatus() {
  local status="${1}"
  local imageCounter="${2}"

  echo -en "\r                                                                               "
  echo -en "\r${status} image ${imageCounter} - Optimizing ${optimizationJobsRunning} images in the background (${#optimizationJobsWaiting[*]} waiting)"
}

enqueueImageOptimization() {
  local fullTargetPathname="${1}"
  optimizationJobsWaiting[${#optimizationJobsWaiting[*]}]="${fullTargetPathname}"
  updateOptimizationJobsRunning
  runEnqueuedOptimzations
}

updateOptimizationJobsRunning() {
  optimizationJobsRunning=$(jobs -l|grep 'Running'|wc -l)
}

runOptimization() {
  local fullTargetPathname="${1}"
  nice -n 10 -- pngcrush -ow -new -q -s "${fullTargetPathname}" "${fullTargetPathname}.pngcrush.tmp" &
  updateOptimizationJobsRunning
}

runCapture() {
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
    enqueueImageOptimization "${fullTargetPathname}"
    updateStatus "Captured" "${imageCounter}"
    ((imageCounter++))
    sleep "${interval}"
  done
}

if [ "$#" -lt 2 ]; then
  printUsage
  exit 1
fi

runCapture "${1}" "${2}"
