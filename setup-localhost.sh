#!/bin/bash
mkdir -p ./deployments/localhost
rsync -avu "./deployments/avalanche/" "./deployments/localhost"
echo 31337 > ./deployments/localhost/.chainId

echo "Re-deploying:"
echo "$@"

for var in "$@"
do
    rm ./deployments/localhost/"$var".json
done

yarn hardhat deploy --network localhost
./export-addresses.sh localhost
