#!/bin/bash
tty=/dev/tty1
echo Pausing during network stop
count=60
echo > "${tty}"
while (( count-- ))
do
    echo -en "\r...$(printf %2d ${count} )" >> "${tty}"
    sleep 0.5
done
echo Continuing.
