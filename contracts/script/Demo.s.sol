// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KRWStablecoin.sol";
import "../src/WonConnectFactory.sol";
import "../src/InvestmentGroup.sol";

/**
 * @title Demo
 * @dev Demo script showing WonConnect platform functionality
 */
contract Demo is Script {
    KRWStablecoin public krwToken;
    WonConnectFactory public factory;
    
    // Demo addresses (generated for demo purposes)
    address public constant GP = 0x1111111111111111111111111111111111111111;
    address public constant INVESTOR1 = 0x2222222222222222222222222222222222222222;
    address public constant INVESTOR2 = 0x3333333333333333333333333333333333333333;
    address public constant TREASURY = 0x4444444444444444444444444444444444444444;
    
    function run() external {
        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Load deployed contracts
        _loadContracts();
        
        // Run demo scenario
        console.log("=== WONCONNECT PLATFORM DEMO ===\n");
        
        // Step 1: Setup demo accounts
        _setupDemoAccounts();
        
        // Step 2: Create investment group
        address groupAddress = _createInvestmentGroup();
        
        // Step 3: Simulate investor commitments  
        _simulateInvestorCommitments(groupAddress);
        
        // Step 4: Execute investment
        _executeInvestment(groupAddress);
        
        // Step 5: Simulate exit and profit distribution
        _simulateExitAndProfits(groupAddress);
        
        vm.stopBroadcast();
        
        console.log("\n=== DEMO COMPLETED SUCCESSFULLY ===");
        console.log("Platform demonstrates:");
        console.log("[OK] KRW stablecoin-based investments");
        console.log("[OK] Private syndicate creation");
        console.log("[OK] LP NFT share tokens");
        console.log("[OK] Automated profit distribution");
        console.log("[OK] Platform fee collection");
    }
    
    function _loadContracts() internal {
        // In a real deployment, you'd load these from addresses.json
        // For demo, deploy fresh contracts
        krwToken = new KRWStablecoin(TREASURY);
        factory = new WonConnectFactory(address(krwToken), TREASURY);
        
        // Setup initial configuration
        krwToken.addMinter(address(factory));
        
        console.log("Contracts loaded:");
        console.log("KRW Token:", address(krwToken));
        console.log("Factory:", address(factory));
    }
    
    function _setupDemoAccounts() internal {
        console.log("Setting up demo accounts...");
        
        // Mint demo KRW tokens
        krwToken.mint(GP, 100_000_000 * 1e18);        // 100M KRW for GP
        krwToken.mint(INVESTOR1, 50_000_000 * 1e18);  // 50M KRW for investor 1
        krwToken.mint(INVESTOR2, 30_000_000 * 1e18);  // 30M KRW for investor 2
        
        console.log("Minted demo KRW tokens");
        
        // Verify GP
        factory.verifyLeadInvestor(
            GP,
            "Demo Foodtech GP", 
            "Specialized in Korean foodtech startups"
        );
        
        console.log("Verified GP:", GP);
        
        // Purchase subscriptions for investors
        vm.startPrank(INVESTOR1);
        krwToken.approve(address(factory), 1_000_000 * 1e18);
        factory.purchaseSubscription("professional", 12); // 12 months professional
        vm.stopPrank();
        
        vm.startPrank(INVESTOR2);
        krwToken.approve(address(factory), 500_000 * 1e18);
        factory.purchaseSubscription("basic", 6); // 6 months basic
        vm.stopPrank();
        
        console.log("Investors purchased subscriptions");
    }
    
    function _createInvestmentGroup() internal returns (address) {
        console.log("\nCreating investment group...");
        
        // GP creates subscription first
        vm.startPrank(GP);
        krwToken.approve(address(factory), 10_000_000 * 1e18);
        factory.purchaseSubscription("professional", 12);
        
        // Approve operating fee
        krwToken.approve(address(factory), 5_000_000 * 1e18);
        
        // Create investment group
        InvestmentGroup.SAFETerms memory safeTerms = InvestmentGroup.SAFETerms({
            valuationCap: 10_000_000_000 * 1e18,  // 10B KRW valuation cap
            discountRate: 2000,                    // 20% discount
            hasMostFavoredNation: true,
            hasProRataRights: true
        });
        
        address groupAddress = factory.createInvestmentGroup(
            "Korean Foodtech Startup A",
            "AI-powered food delivery optimization platform targeting Korean market",
            2_000_000_000 * 1e18,  // 2B KRW target
            10_000_000 * 1e18,     // 10M KRW minimum
            500_000_000 * 1e18,    // 500M KRW maximum
            block.timestamp + 30 days,  // 30 days to raise
            800,                    // 8% hurdle rate
            2000,                   // 20% carry rate
            safeTerms
        );
        
        vm.stopPrank();
        
        console.log("Investment group created:", groupAddress);
        return groupAddress;
    }
    
    function _simulateInvestorCommitments(address groupAddress) internal {
        console.log("\nSimulating investor commitments...");
        
        InvestmentGroup group = InvestmentGroup(groupAddress);
        
        // Investor 1 commits 200M KRW
        vm.startPrank(INVESTOR1);
        krwToken.approve(groupAddress, 200_000_000 * 1e18);
        group.commitInvestment(200_000_000 * 1e18);
        vm.stopPrank();
        
        console.log("Investor 1 committed: 200M KRW");
        
        // Investor 2 commits 150M KRW  
        vm.startPrank(INVESTOR2);
        krwToken.approve(groupAddress, 150_000_000 * 1e18);
        group.commitInvestment(150_000_000 * 1e18);
        vm.stopPrank();
        
        console.log("Investor 2 committed: 150M KRW");
        
        (,, uint256 targetAmount, uint256 totalCommitted,,,,,) = group.getGroupInfo();
        console.log("Total committed:", totalCommitted / 1e18, "KRW");
        console.log("Target amount:", targetAmount / 1e18, "KRW");
        console.log("Progress:", (totalCommitted * 100) / targetAmount, "%");
    }
    
    function _executeInvestment(address groupAddress) internal {
        console.log("\nExecuting investment...");
        
        InvestmentGroup group = InvestmentGroup(groupAddress);
        
        // Advance time to after deadline
        vm.warp(block.timestamp + 31 days);
        
        // GP executes investment
        vm.prank(GP);
        group.executeInvestment();
        
        console.log("Investment executed successfully");
        
        uint256 totalInvested;
        InvestmentGroup.GroupState state;
        (,,,, totalInvested,, state,,) = group.getGroupInfo();
        console.log("Total invested:", totalInvested / 1e18, "KRW");
        console.log("Group state:", uint(state)); // 1 = Active
    }
    
    function _simulateExitAndProfits(address groupAddress) internal {
        console.log("\nSimulating exit and profit distribution...");
        
        InvestmentGroup group = InvestmentGroup(groupAddress);
        
        // Advance time by 2 years (typical investment period)
        vm.warp(block.timestamp + 730 days);
        
        // Simulate successful exit - 5x return
        uint256 exitAmount = 1_750_000_000 * 1e18; // 1.75B KRW (5x on 350M invested)
        
        vm.startPrank(GP);
        krwToken.mint(GP, exitAmount); // Mint exit proceeds
        krwToken.approve(groupAddress, exitAmount);
        group.processExit(exitAmount);
        vm.stopPrank();
        
        console.log("Exit processed successfully");
        console.log("Exit amount:", exitAmount / 1e18, "KRW");
        
        uint256 totalReturned;
        InvestmentGroup.GroupState state;
        (,,,,, totalReturned, state,,) = group.getGroupInfo();
        console.log("Total returned:", totalReturned / 1e18, "KRW");
        console.log("Return multiple:", (totalReturned * 100) / (350_000_000 * 1e18), "x");
        console.log("Group state:", uint(state)); // 2 = Exited
        
        // Check LP NFT profit distribution
        LPShareNFT nft = group.lpShareNFT();
        console.log("Profit pool in NFT contract:", nft.profitPool() / 1e18, "KRW");
        console.log("Profit per share:", nft.profitPerShare() / 1e18);
    }
}