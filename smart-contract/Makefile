-include .env

fork test:; forge test --fork-url $(SEPOLIA_RPC_URL) -vvvv

deploy:; forge script script/DeployEngine.s.sol:DeployEngine --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv