#!/bin/bash
# First wait for it to be killed (disappear)
for i in {1..10}; do
  if ! xcrun simctl spawn CC7BF58A-218E-4EC6-A084-F673841B51E3 launchctl list | grep audiobookphile > /dev/null; then
    break
  fi
  sleep 1
done
# Now wait for it to come back up
for i in {1..30}; do
  if xcrun simctl spawn CC7BF58A-218E-4EC6-A084-F673841B51E3 launchctl list | grep audiobookphile > /dev/null; then
    echo "App launched!"
    exit 0
  fi
  sleep 2
done
echo "Timeout"
