#!/bin/bash
# First wait for it to be killed (disappear)
for i in {1..10}; do
  if ! xcrun simctl spawn AA6E1A1D-4141-453D-9A5F-76BCA4834AE1 launchctl list | grep audiobookshelf > /dev/null; then
    break
  fi
  sleep 1
done
# Now wait for it to come back up
for i in {1..30}; do
  if xcrun simctl spawn AA6E1A1D-4141-453D-9A5F-76BCA4834AE1 launchctl list | grep audiobookshelf > /dev/null; then
    echo "App launched!"
    exit 0
  fi
  sleep 2
done
echo "Timeout"
