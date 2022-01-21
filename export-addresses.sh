#!/bin/bash
yarn hardhat export-addresses --network "$@"
# lptokens, farminfo, addresses
cp -r ./build/*.json ../frontend/src/contracts/
cp -r ./build/artifacts/* ../frontend/src/contracts/artifacts
