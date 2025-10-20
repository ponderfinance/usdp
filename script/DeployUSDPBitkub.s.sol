// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

// Adapters and Oracle System
import {PonderOracleAdapter} from "../src/adapters/PonderOracleAdapter.sol";
import {MultiSourcePriceFeed} from "../src/oracles/MultiSourcePriceFeed.sol";

// Per-Collateral Price Feeds
import {KKUBPriceFeed} from "../src/bold/PriceFeeds/KKUBPriceFeed.sol";
import {stKUBPriceFeed} from "../src/bold/PriceFeeds/stKUBPriceFeed.sol";
import {wstKUBPriceFeed} from "../src/bold/PriceFeeds/wstKUBPriceFeed.sol";
import {xKOIPriceFeed} from "../src/bold/PriceFeeds/xKOIPriceFeed.sol";

// Core Bold Contracts
import {USDPToken} from "../src/bold/USDPToken.sol";
import {CollateralRegistry} from "../src/bold/CollateralRegistry.sol";
import {HintHelpers} from "../src/bold/HintHelpers.sol";
import {MultiTroveGetter} from "../src/bold/MultiTroveGetter.sol";
import {AddressesRegistry} from "../src/bold/AddressesRegistry.sol";
import {USDPAddressesRegistry} from "../src/bold/USDPAddressesRegistry.sol";
import {BorrowerOperations} from "../src/bold/BorrowerOperations.sol";
import {TroveManager} from "../src/bold/TroveManager.sol";
import {TroveNFT} from "../src/bold/TroveNFT.sol";
import {StabilityPool} from "../src/bold/StabilityPool.sol";
import {ActivePool} from "../src/bold/ActivePool.sol";
import {DefaultPool} from "../src/bold/DefaultPool.sol";
import {GasPool} from "../src/bold/GasPool.sol";
import {CollSurplusPool} from "../src/bold/CollSurplusPool.sol";
import {SortedTroves} from "../src/bold/SortedTroves.sol";

// Interfaces
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAddressesRegistry} from "../src/bold/Interfaces/IAddressesRegistry.sol";
import {ICollateralRegistry} from "../src/bold/Interfaces/ICollateralRegistry.sol";
import {ITroveManager} from "../src/bold/Interfaces/ITroveManager.sol";
import {IPriceFeed} from "../src/bold/Interfaces/IPriceFeed.sol";
import {IMetadataNFT} from "../src/bold/NFTMetadata/MetadataNFT.sol";
import {IInterestRouter} from "../src/bold/Interfaces/IInterestRouter.sol";
import {IWETH} from "../src/bold/Interfaces/IWETH.sol";

/**
 * @title DeployUSDPBitkub
 * @notice Deployment script for USDP (Liquity v2 fork) on Bitkub Chain Mainnet
 * @dev Supports phased deployment: Phase 0 (KKUB) → Phase 1 (LSTs) → Phase 2 (xKOI)
 *
 * IMPORTANT: This script deploys to Bitkub MAINNET (chain ID 96) because:
 * - Ponder oracle only exists on mainnet (0xCf814870800A3bcAC4A6b858424A9370A64C75AD)
 * - All collateral tokens are on mainnet
 * - No testnet deployment is possible
 *
 * Environment Variables:
 * - DEPLOYER: Private key of deployer (must have KUB for gas)
 * - PHASE: Deployment phase (0 = KKUB only, 1 = Add LSTs, 2 = Add xKOI)
 *
 * Usage:
 *   Phase 0: DEPLOYER=<key> PHASE=0 forge script script/DeployUSDPBitkub.s.sol:DeployUSDPBitkub \
 *            --rpc-url https://rpc.bitkubchain.io --broadcast --verify
 *
 *   Phase 1: DEPLOYER=<key> PHASE=1 forge script script/DeployUSDPBitkub.s.sol:DeployUSDPBitkub \
 *            --rpc-url https://rpc.bitkubchain.io --broadcast --verify
 *
 *   Phase 2: DEPLOYER=<key> PHASE=2 forge script script/DeployUSDPBitkub.s.sol:DeployUSDPBitkub \
 *            --rpc-url https://rpc.bitkubchain.io --broadcast --verify
 */
contract DeployUSDPBitkub is Script {
    // ========== Bitkub Mainnet Addresses (from protocol/addresses/96.json) ==========
    address constant PONDER_ORACLE = 0xCf814870800A3bcAC4A6b858424A9370A64C75AD;
    address constant PONDER_FACTORY = 0x20B17e92Dd1866eC647ACaA38fe1f7075e4B359E;

    // ========== Bitkub Token Addresses ==========
    address constant KUSDT = 0x7d984C24d2499D840eB3b7016077164e15E5faA6;
    address constant KKUB = 0x67eBD850304c70d983B2d1b93ea79c7CD6c3F6b5;
    address constant stKUB = 0xcba2aeEc821b0B119857a9aB39E09b034249681A;
    address constant wstKUB = 0x7AC168c81F4F3820Fa3F22603ce5864D6aB3C547;
    address constant xKOI = 0x6C8119d33fD43f6B254d041Cd5d2675586731dd5;

    // ========== Collateral Parameters (from RFC-001) ==========
    // KKUB: Conservative DeFi blue chip
    uint256 constant MCR_KKUB = 1.20e18; // 120%
    uint256 constant CCR_KKUB = 1.40e18; // 140%
    uint256 constant SCR_KKUB = 1.30e18; // 130%
    uint256 constant BCR_KKUB = 0.05e18; // 5% extra buffer for batches (on top of MCR = 125% total)
    uint256 constant LIQUIDATION_PENALTY_SP_KKUB = 0.05e18; // 5%
    uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION_KKUB = 0.05e18; // 5%

    // stKUB: Liquid Staking Token
    uint256 constant MCR_stKUB = 1.30e18; // 130%
    uint256 constant CCR_stKUB = 1.50e18; // 150%
    uint256 constant SCR_stKUB = 1.40e18; // 140%
    uint256 constant BCR_stKUB = 0.10e18; // 10% extra buffer (140% total for batches)
    uint256 constant LIQUIDATION_PENALTY_SP_stKUB = 0.07e18; // 7%
    uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION_stKUB = 0.07e18; // 7%

    // wstKUB: Wrapped Liquid Staking Token
    uint256 constant MCR_wstKUB = 1.30e18; // 130%
    uint256 constant CCR_wstKUB = 1.50e18; // 150%
    uint256 constant SCR_wstKUB = 1.40e18; // 140%
    uint256 constant BCR_wstKUB = 0.10e18; // 10% extra buffer (140% total for batches)
    uint256 constant LIQUIDATION_PENALTY_SP_wstKUB = 0.07e18; // 7%
    uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION_wstKUB = 0.07e18; // 7%

    // xKOI: Governance token (highest risk)
    uint256 constant MCR_xKOI = 1.75e18; // 175%
    uint256 constant CCR_xKOI = 2.00e18; // 200%
    uint256 constant SCR_xKOI = 1.85e18; // 185%
    uint256 constant BCR_xKOI = 0.15e18; // 15% extra buffer (190% total for batches)
    uint256 constant LIQUIDATION_PENALTY_SP_xKOI = 0.10e18; // 10%
    uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION_xKOI = 0.10e18; // 10%

    // ========== Oracle Parameters ==========
    uint32 constant TWAP_PERIOD = 14400; // 4 hours (in seconds)

    // ========== Deployment State ==========
    address public deployer;
    uint256 public deploymentPhase;

    // Oracle System
    PonderOracleAdapter public ponderAdapter;
    MultiSourcePriceFeed public multiSourceFeed;

    // Price Feeds
    KKUBPriceFeed public kkubPriceFeed;
    stKUBPriceFeed public stkubPriceFeed;
    wstKUBPriceFeed public wstkubPriceFeed;
    xKOIPriceFeed public xkoiPriceFeed;

    // Core Contracts
    USDPToken public usdpToken;
    CollateralRegistry public collateralRegistry;
    HintHelpers public hintHelpers;
    MultiTroveGetter public multiTroveGetter;

    // Branch Contracts (per collateral)
    struct BranchContracts {
        address collateral;
        AddressesRegistry addressesRegistry;
        BorrowerOperations borrowerOperations;
        TroveManager troveManager;
        TroveNFT troveNFT;
        StabilityPool stabilityPool;
        ActivePool activePool;
        DefaultPool defaultPool;
        GasPool gasPool;
        CollSurplusPool collSurplusPool;
        SortedTroves sortedTroves;
        IPriceFeed priceFeed;
    }

    BranchContracts public kkubBranch;
    BranchContracts public stkubBranch;
    BranchContracts public wstkubBranch;
    BranchContracts public xkoiBranch;

    function run() external {
        // Get deployer from environment
        uint256 privateKey = vm.envUint("DEPLOYER");
        deployer = vm.addr(privateKey);

        // Get deployment phase (0 = KKUB only, 1 = Add LSTs, 2 = Add xKOI)
        deploymentPhase = vm.envOr("PHASE", uint256(0));

        console2.log("================================================================================");
        console2.log("USDP Deployment Script - Bitkub Chain");
        console2.log("================================================================================");
        console2.log("Deployer:        ", deployer);
        console2.log("Deployer balance:", deployer.balance);
        console2.log("Chain ID:        ", block.chainid);
        console2.log("Phase:           ", deploymentPhase);
        console2.log("================================================================================");

        vm.startBroadcast(privateKey);

        // Step 1: Deploy Oracle System
        console2.log("\n[1/6] Deploying Oracle System...");
        deployOracleSystem();

        // Step 2: Deploy USDP Token
        console2.log("\n[2/6] Deploying USDP Token...");
        usdpToken = new USDPToken(deployer);
        console2.log("  USDPToken:           ", address(usdpToken));

        // Step 3: Deploy Core Helper Contracts (needs collateral data)
        console2.log("\n[3/6] Deploying Core Helpers (deferred until after branches)...");

        // Step 4: Deploy Branch Contracts per Phase
        if (deploymentPhase == 0) {
            console2.log("\n[4/6] Deploying KKUB Branch (Phase 0)...");
            deployKKUBBranch();
        } else if (deploymentPhase == 1) {
            console2.log("\n[4/6] Deploying KKUB + LST Branches (Phase 1)...");
            deployKKUBBranch();
            deployLSTBranches();
        } else if (deploymentPhase == 2) {
            console2.log("\n[4/6] Deploying All Branches (Phase 2)...");
            deployKKUBBranch();
            deployLSTBranches();
            deployxKOIBranch();
        }

        // Step 5: Deploy CollateralRegistry with all collaterals
        console2.log("\n[5/6] Deploying CollateralRegistry...");
        deployCollateralRegistry();

        // Step 6: Wire everything together
        console2.log("\n[6/6] Wiring contracts together...");
        wireContracts();

        vm.stopBroadcast();

        // Print deployment summary
        printDeploymentSummary();
    }

    function deployOracleSystem() internal {
        // Deploy PonderOracleAdapter (uses existing Ponder oracle)
        ponderAdapter = new PonderOracleAdapter(
            PONDER_ORACLE,
            PONDER_FACTORY,
            KUSDT // Use KUSDT as BASE_TOKEN initially (chicken-egg problem with USDP)
        );
        console2.log("  PonderOracleAdapter: ", address(ponderAdapter));

        // Register KKUB collateral (needed for price feeds)
        ponderAdapter.registerCollateral(KKUB);
        console2.log("  Registered KKUB collateral");

        // Deploy MultiSourcePriceFeed
        multiSourceFeed = new MultiSourcePriceFeed(
            address(ponderAdapter)
        );
        console2.log("  MultiSourcePriceFeed:", address(multiSourceFeed));
    }

    function deployKKUBBranch() internal {
        console2.log("  Deploying KKUB branch...");

        // Deploy KKUBPriceFeed
        // Note: We deploy with zero address for borrowerOperations initially
        // Will set it properly in wiring phase
        kkubPriceFeed = new KKUBPriceFeed(
            address(multiSourceFeed),
            address(0) // borrowerOperations not deployed yet
        );
        console2.log("    KKUBPriceFeed:     ", address(kkubPriceFeed));

        // Deploy Branch
        kkubBranch = deployBranch(
            KKUB,
            kkubPriceFeed,
            MCR_KKUB,
            CCR_KKUB,
            SCR_KKUB,
            BCR_KKUB,
            LIQUIDATION_PENALTY_SP_KKUB,
            LIQUIDATION_PENALTY_REDISTRIBUTION_KKUB
        );
    }

    function deployLSTBranches() internal {
        console2.log("  Deploying LST branches...");

        // Register LSTs with PonderOracleAdapter
        ponderAdapter.registerLST(stKUB, KKUB);
        ponderAdapter.registerLST(wstKUB, KKUB);
        console2.log("    Registered stKUB and wstKUB as LSTs");

        // Deploy stKUB Branch
        stkubPriceFeed = new stKUBPriceFeed(
            address(multiSourceFeed),
            address(0)
        );
        console2.log("    stKUBPriceFeed:    ", address(stkubPriceFeed));

        stkubBranch = deployBranch(
            stKUB,
            stkubPriceFeed,
            MCR_stKUB,
            CCR_stKUB,
            SCR_stKUB,
            BCR_stKUB,
            LIQUIDATION_PENALTY_SP_stKUB,
            LIQUIDATION_PENALTY_REDISTRIBUTION_stKUB
        );

        // Deploy wstKUB Branch
        wstkubPriceFeed = new wstKUBPriceFeed(
            address(multiSourceFeed),
            address(0)
        );
        console2.log("    wstKUBPriceFeed:   ", address(wstkubPriceFeed));

        wstkubBranch = deployBranch(
            wstKUB,
            wstkubPriceFeed,
            MCR_wstKUB,
            CCR_wstKUB,
            SCR_wstKUB,
            BCR_wstKUB,
            LIQUIDATION_PENALTY_SP_wstKUB,
            LIQUIDATION_PENALTY_REDISTRIBUTION_wstKUB
        );
    }

    function deployxKOIBranch() internal {
        console2.log("  Deploying xKOI branch...");

        // Register xKOI collateral
        ponderAdapter.registerCollateral(xKOI);
        console2.log("    Registered xKOI collateral");

        xkoiPriceFeed = new xKOIPriceFeed(
            address(multiSourceFeed),
            address(0)
        );
        console2.log("    xKOIPriceFeed:     ", address(xkoiPriceFeed));

        xkoiBranch = deployBranch(
            xKOI,
            xkoiPriceFeed,
            MCR_xKOI,
            CCR_xKOI,
            SCR_xKOI,
            BCR_xKOI,
            LIQUIDATION_PENALTY_SP_xKOI,
            LIQUIDATION_PENALTY_REDISTRIBUTION_xKOI
        );
    }

    function deployBranch(
        address collateral,
        IPriceFeed priceFeed,
        uint256 mcr,
        uint256 ccr,
        uint256 scr,
        uint256 bcr,
        uint256 liquidationPenaltySP,
        uint256 liquidationPenaltyRedistribution
    ) internal returns (BranchContracts memory branch) {
        branch.collateral = collateral;
        branch.priceFeed = priceFeed;

        // Deploy USDPAddressesRegistry (with collateral and WETH pre-set)
        // Note: activePool is temporarily set to deployer address (will be updated via setAddresses)
        branch.addressesRegistry = new USDPAddressesRegistry(
            deployer,
            collateral,  // Set collateral immediately
            KKUB,        // Use KKUB as WETH/gas token
            ccr,
            mcr,
            bcr,
            scr,
            liquidationPenaltySP,
            liquidationPenaltyRedistribution
        );
        console2.log("      AddressesRegistry:", address(branch.addressesRegistry));

        // Deploy Branch Contracts
        branch.borrowerOperations = new BorrowerOperations(branch.addressesRegistry);
        branch.troveManager = new TroveManager(branch.addressesRegistry);
        branch.troveNFT = new TroveNFT(branch.addressesRegistry);
        branch.stabilityPool = new StabilityPool(branch.addressesRegistry);
        branch.activePool = new ActivePool(branch.addressesRegistry);
        branch.defaultPool = new DefaultPool(branch.addressesRegistry);
        branch.gasPool = new GasPool(branch.addressesRegistry);
        branch.collSurplusPool = new CollSurplusPool(branch.addressesRegistry);
        branch.sortedTroves = new SortedTroves(branch.addressesRegistry);

        console2.log("      BorrowerOperations:", address(branch.borrowerOperations));
        console2.log("      TroveManager:      ", address(branch.troveManager));
        console2.log("      StabilityPool:     ", address(branch.stabilityPool));

        return branch;
    }

    function deployCollateralRegistry() internal {
        // Collect collaterals and trove managers based on phase
        IERC20Metadata[] memory collaterals;
        ITroveManager[] memory troveManagers;

        if (deploymentPhase == 0) {
            collaterals = new IERC20Metadata[](1);
            troveManagers = new ITroveManager[](1);

            collaterals[0] = IERC20Metadata(KKUB);
            troveManagers[0] = ITroveManager(address(kkubBranch.troveManager));
        } else if (deploymentPhase == 1) {
            collaterals = new IERC20Metadata[](3);
            troveManagers = new ITroveManager[](3);

            collaterals[0] = IERC20Metadata(KKUB);
            collaterals[1] = IERC20Metadata(stKUB);
            collaterals[2] = IERC20Metadata(wstKUB);

            troveManagers[0] = ITroveManager(address(kkubBranch.troveManager));
            troveManagers[1] = ITroveManager(address(stkubBranch.troveManager));
            troveManagers[2] = ITroveManager(address(wstkubBranch.troveManager));
        } else {
            collaterals = new IERC20Metadata[](4);
            troveManagers = new ITroveManager[](4);

            collaterals[0] = IERC20Metadata(KKUB);
            collaterals[1] = IERC20Metadata(stKUB);
            collaterals[2] = IERC20Metadata(wstKUB);
            collaterals[3] = IERC20Metadata(xKOI);

            troveManagers[0] = ITroveManager(address(kkubBranch.troveManager));
            troveManagers[1] = ITroveManager(address(stkubBranch.troveManager));
            troveManagers[2] = ITroveManager(address(wstkubBranch.troveManager));
            troveManagers[3] = ITroveManager(address(xkoiBranch.troveManager));
        }

        // Deploy CollateralRegistry
        collateralRegistry = new CollateralRegistry(
            usdpToken,
            collaterals,
            troveManagers
        );
        console2.log("  CollateralRegistry:  ", address(collateralRegistry));

        // Deploy HintHelpers and MultiTroveGetter
        hintHelpers = new HintHelpers(collateralRegistry);
        multiTroveGetter = new MultiTroveGetter(collateralRegistry);

        console2.log("  HintHelpers:         ", address(hintHelpers));
        console2.log("  MultiTroveGetter:    ", address(multiTroveGetter));
    }

    function wireContracts() internal {
        console2.log("  Wiring KKUB branch...");
        wireBranch(kkubBranch);

        if (deploymentPhase >= 1) {
            console2.log("  Wiring LST branches...");
            wireBranch(stkubBranch);
            wireBranch(wstkubBranch);
        }

        if (deploymentPhase >= 2) {
            console2.log("  Wiring xKOI branch...");
            wireBranch(xkoiBranch);
        }

        // Set CollateralRegistry on USDPToken
        console2.log("  Setting CollateralRegistry on USDPToken...");
        usdpToken.setCollateralRegistry(address(collateralRegistry));
    }

    function wireBranch(BranchContracts memory branch) internal {
        // Set addresses in AddressesRegistry
        IAddressesRegistry.AddressVars memory addressVars = IAddressesRegistry.AddressVars({
            collToken: IERC20Metadata(branch.collateral),
            borrowerOperations: branch.borrowerOperations,
            troveManager: branch.troveManager,
            troveNFT: branch.troveNFT,
            metadataNFT: IMetadataNFT(address(0)), // TODO: Deploy MetadataNFT if needed
            stabilityPool: branch.stabilityPool,
            priceFeed: branch.priceFeed,
            activePool: branch.activePool,
            defaultPool: branch.defaultPool,
            gasPoolAddress: address(branch.gasPool),
            collSurplusPool: branch.collSurplusPool,
            sortedTroves: branch.sortedTroves,
            interestRouter: IInterestRouter(address(0)), // TODO: Add governance later
            hintHelpers: hintHelpers,
            multiTroveGetter: multiTroveGetter,
            collateralRegistry: collateralRegistry,
            boldToken: usdpToken,
            WETH: IWETH(KKUB) // Use KKUB as gas token equivalent
        });

        branch.addressesRegistry.setAddresses(addressVars);

        // Set branch addresses on USDPToken
        usdpToken.setBranchAddresses(
            address(branch.troveManager),
            address(branch.stabilityPool),
            address(branch.borrowerOperations),
            address(branch.activePool)
        );
    }

    function printDeploymentSummary() internal view {
        console2.log("\n");
        console2.log("================================================================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("================================================================================");

        console2.log("\nOracle System:");
        console2.log("  PonderOracleAdapter: ", address(ponderAdapter));
        console2.log("  MultiSourcePriceFeed:", address(multiSourceFeed));

        console2.log("\nCore Contracts:");
        console2.log("  USDPToken:           ", address(usdpToken));
        console2.log("  CollateralRegistry:  ", address(collateralRegistry));
        console2.log("  HintHelpers:         ", address(hintHelpers));
        console2.log("  MultiTroveGetter:    ", address(multiTroveGetter));

        console2.log("\nKKUB Branch:");
        printBranchSummary(kkubBranch);

        if (deploymentPhase >= 1) {
            console2.log("\nstKUB Branch:");
            printBranchSummary(stkubBranch);

            console2.log("\nwstKUB Branch:");
            printBranchSummary(wstkubBranch);
        }

        if (deploymentPhase >= 2) {
            console2.log("\nxKOI Branch:");
            printBranchSummary(xkoiBranch);
        }

        console2.log("\n");
        console2.log("================================================================================");
        console2.log("Deployment complete! Phase", deploymentPhase);
        console2.log("================================================================================");
    }

    function printBranchSummary(BranchContracts memory branch) internal view {
        console2.log("  Collateral:          ", branch.collateral);
        console2.log("  AddressesRegistry:   ", address(branch.addressesRegistry));
        console2.log("  BorrowerOperations:  ", address(branch.borrowerOperations));
        console2.log("  TroveManager:        ", address(branch.troveManager));
        console2.log("  StabilityPool:       ", address(branch.stabilityPool));
        console2.log("  PriceFeed:           ", address(branch.priceFeed));
    }
}