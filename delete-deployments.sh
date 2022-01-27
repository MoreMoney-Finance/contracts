#!/bin/bash


echo
echo "Resetting these deployments:"
echo "${@:2}"
echo

for var in "${@:2}"
do
    rm ./deployments/"$1"/"$var".json
done