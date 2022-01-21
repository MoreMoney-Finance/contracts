./delete-deployments.sh $1 "$@"
hardhat deploy --network $1 --tags base,$1
./export-addresses.sh $1
hardhat custom-etherscan --network $1