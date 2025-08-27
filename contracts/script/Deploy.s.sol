// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KRWStablecoin.sol";
import "../src/WonConnectFactory.sol";

/**
 * @title Deploy
 * @dev Deployment script for WonConnect platform contracts
 */
contract Deploy is Script {
    // Deployment addresses (update these for different networks)
    address public constant TREASURY = 0x1234567890123456789012345678901234567890;
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy KRW Stablecoin
        console.log("Deploying KRW Stablecoin...");
        KRWStablecoin krwToken = new KRWStablecoin(TREASURY);
        console.log("KRW Stablecoin deployed to:", address(krwToken));
        
        // 2. Deploy WonConnect Factory
        console.log("Deploying WonConnect Factory...");
        WonConnectFactory factory = new WonConnectFactory(
            address(krwToken),
            TREASURY
        );
        console.log("WonConnect Factory deployed to:", address(factory));
        
        // 3. Configure contracts
        console.log("Configuring contracts...");
        
        // Add factory as minter for KRW token (for future features)
        krwToken.addMinter(address(factory));
        console.log("Added factory as KRW minter");
        
        // Verify lead investor (deployer for testing)
        factory.verifyLeadInvestor(
            deployer,
            "Test Lead Investor",
            "Demo credentials for hackathon"
        );
        console.log("Verified deployer as lead investor");
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Kaia");
        console.log("Deployer:", deployer);
        console.log("Treasury:", TREASURY);
        console.log("KRW Stablecoin:", address(krwToken));
        console.log("WonConnect Factory:", address(factory));
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Update frontend config with contract addresses");
        console.log("2. Mint test KRW tokens for demo investors");
        console.log("3. Create sample investment groups");
        console.log("4. Verify contracts on block explorer");
        
        // Save addresses to file for frontend integration
        _saveAddresses(address(krwToken), address(factory));
    }
    
    function _saveAddresses(address krwToken, address factory) internal {
        string memory addressesJson = string(abi.encodePacked(
            '{\n',
            '  "krwToken": "', vm.toString(krwToken), '",\n',
            '  "factory": "', vm.toString(factory), '",\n',
            '  "network": "kaia",\n',
            '  "deployedAt": ', vm.toString(block.timestamp), '\n',
            '}'
        ));
        
        vm.writeFile("./deployments/addresses.json", addressesJson);
        console.log("Contract addresses saved to ./deployments/addresses.json");
    }
}