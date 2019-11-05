#!/bin/sh
pid=""
tailpid=""
interrupted=0

cleanup()
{
    interrupted=1
    echo "Interrupted"
    kill $pid
    kill $tailpid
}

trap INT TERM cleanup

set -m #enable job control
set -vx
while sleep 0.5
do
  date
done > /log.txt &
pid=$!

tail -f /log.txt > /dev/tty1 &
tailpid=$!

wait %1
echo "Performing delayed exit."
count=15
while (( count-- ))
do
    echo "${count}"
    sleep 1
done
echo "Exiting."
exit 0
