#!/bin/bash
mkdir -p ./deployments/localhost
rsync -avu "./deployments/avalanche/" "./deployments/localhost"
echo 31337 > ./deployments/localhost/.chainId

./delete-deployments.sh localhost "$@"

yarn hardhat deploy --network localhost
./export-addresses.sh localhost
