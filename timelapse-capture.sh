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

# Flag controlled options
doResize=0
resizeResolution=""
doOptimization=1
outputFormat="png"

exitSignalReceived=0
backgroundJobsWaiting=( )
backgroundJobsRunningCount=0

##
# Print usage information for the script execution
##
printUsage() {
  echo "Timelapse Capture (c) Jakob Westhoff"
  echo
  echo "timelapse-capture [--option=<value>, ...] <interval> <target-path>"
  echo "  <interval> - Interval between screencaptures in seconds"
  echo "  <target-path> - Path to store screencaptures to"
  echo
  echo "Options:"
  echo "  --resize=<width>x<height> - Resize the screencapture to the given resolution (eg. 1920x1080)"
  echo "  --no-optimization - Don't optimize the screen capture for size"
  echo "  --format=<format> - Capture format (currently supported: png, jpg) (default: png)"
  echo
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
# Assert that the given format is valid
##
assertOutputFormatIsValid() {
  case "${1}" in
    png|jpg)
      : # Nothing to be done
    ;;
    *)
      echo "Unknown output format: ${1}"
      exit 2
    ;;
  esac
}

##
# Assert that the given argument is an integer
##
assertIntervalIsInteger() {
  case "${1}" in
    ''|*[!0-9]*)
      echo "Given interval '${1}' is not an integer"
      exit 2
    ;;
  esac
}

##
# Assert that the given resize value is valid
##
assertResizeValueIsValid() {
  if [ "${1}" -ne "1" ]; then
    return
  fi

  if ! [[ "${2}" =~ ^[0-9]+x[0-9]+$ ]]; then
    echo "Given resize resolution '${2}' is not a valid resolution"
    exit 2
  fi
}

##
# Assert that all the given paths and options are valid
##
assertFlagsAndArgumentsAreValid() {
  local interval="${1}"
  local targetPath="${2}"

  assertTargetPathExistsAndIsWritable "${targetPath}"
  assertOutputFormatIsValid "${outputFormat}"
  assertIntervalIsInteger "${interval}"
  assertResizeValueIsValid "${doResize}" "${resizeResolution}"
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
    echo -en "\rFinishing up - Background jobs (running/waiting): ${backgroundJobsRunningCount}/${#backgroundJobsWaiting[*]}"
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
# Update the currently displayed status message for a given status type and
# image counter value
##
updateStatus() {
  local status="${1}"
  local imageCounter="${2}"
  local nextTimeout="${3}"

  local formattedImageCounter="$(printf "%09d" "${imageCounter}")"

  echo -en "\r                                                                               "
  case "${status}" in
    Capturing)
      echo -en "\r[${formattedImageCounter}] ${status} - Background jobs (running/waiting): ${backgroundJobsRunningCount}/${#backgroundJobsWaiting[*]}"
      ;;
    *)
      echo -en "\r[${formattedImageCounter}] ${status} (next in ${nextTimeout}s) - Background jobs (running/waiting): ${backgroundJobsRunningCount}/${#backgroundJobsWaiting[*]}"
      ;;
  esac
}

##
# Enqueue a new background operation of a given type for a given captured image
##
enqueueBackgroundJob() {
  local jobType="${1}"
  local fullTargetPathname="${2}"

  backgroundJobsWaiting[${#backgroundJobsWaiting[*]}]="${jobType};${fullTargetPathname}"
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
    resizeAndOptimize)
      case "${outputFormat}" in
        png)
          (
            [ "${doResize}" -eq "1" ] && nice -n 10 -- mogrify -resize "${resizeResolution}^" -gravity center +repage -write "${fullTargetPathname}.mogrify.png" "${fullTargetPathname}" && mv "${fullTargetPathname}.mogrify.png" "${fullTargetPathname}";
            [ "${doOptimization}" -eq "1" ] && nice -n 10 -- pngcrush -ow -new -q -s "${fullTargetPathname}" "${fullTargetPathname}.pngcrush.tmp"
          ) &
          ;;
        jpg)
          (
            [ "${doResize}" -eq "1" ] && nice -n 10 -- mogrify -resize "${resizeResolution}^" -gravity center +repage -quality 95 -write "${fullTargetPathname}.mogrify.jpg" "${fullTargetPathname}" && mv "${fullTargetPathname}.mogrify.jpg" "${fullTargetPathname}";
            [ "${doOptimization}" -eq "1" ] && nice -n 10 -- jpeg-recompress --quiet --quality high --method ssim "${fullTargetPathname}" "${fullTargetPathname}.jpeg-recompress.jpg" && mv "${fullTargetPathname}.jpeg-recompress.jpg" "${fullTargetPathname}";
          ) &
          ;;
        *)
          echo "Unknown output format: ${outputFormat}"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Unknown job type: ${jobType}"
      exit 1
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

  echo "Writing screencaptures to '${targetPath}' as ${outputFormat} every ${interval}s..."

  local imageCounter=1
  local nextTimeout="0"
  while [ "${exitSignalReceived}" -ne "1" ]; do
    if [ "${nextTimeout}" -le 0 ]; then
      local imageName="$(printf "%09d.${outputFormat}" "${imageCounter}")"
      local fullTargetPathname="${targetPath}/${imageName}"
      updateStatus "Capturing" "${imageCounter}" "${nextTimeout}"
      screencapture -x -m -T0 -t${outputFormat} "${fullTargetPathname}"
      enqueueBackgroundJob "resizeAndOptimize" "${fullTargetPathname}"
      ((imageCounter++))
      nextTimeout="${interval}"
    else
      runNextWaitingBackgroundJob
      updateStatus "Waiting" "${imageCounter}" "${nextTimeout}"
      ((nextTimeout--))
      sleep 1
    fi
  done
}

if [ "$#" -lt 2 ]; then
  printUsage
  exit 1
fi

# Parse options
while [ "$#" -gt 2 ]; do
  case "$1" in
    --resize=*)
      doResize=1
      resizeResolution="${1#*=}"
      shift
      ;;
    --no-optimization)
      doOptimization=0
      shift
      ;;
    --format=*)
      outputFormat="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: ${1}"
      printUsage
      exit 1
      ;;
  esac
done

assertFlagsAndArgumentsAreValid "${1}" "${2}"
runCaptureLoop "${1}" "${2}"
