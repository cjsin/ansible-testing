#!/bin/bash

echo "Waiting for ${1}" 1>&2

while [[ ! -e "${1}" ]]
do
    sleep 1
done

echo "Detected ${1}" 1>&2
stat "${1}"
echo "."
