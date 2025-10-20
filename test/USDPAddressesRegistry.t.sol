// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {USDPAddressesRegistry} from "../src/bold/USDPAddressesRegistry.sol";

/**
 * @title USDPAddressesRegistryTest
 * @notice Tests for USDPAddressesRegistry - our wrapper that solves the chicken-egg deployment problem
 * @dev This contract extends AddressesRegistry to set collToken/WETH in constructor
 */
contract USDPAddressesRegistryTest is Test {
    // Mock addresses
    address constant MOCK_OWNER = address(0x1);
    address constant MOCK_COLL_TOKEN = address(0x2);
    address constant MOCK_WETH = address(0x3);

    // Liquity parameters (matching mainnet deployment)
    uint256 constant CCR = 1.5e18; // 150%
    uint256 constant MCR = 1.1e18; // 110%
    uint256 constant BCR = 0.05e18; // 5% buffer
    uint256 constant SCR = 1.2e18; // 120%
    uint256 constant LIQUIDATION_PENALTY_SP = 0.05e18; // 5%
    uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION = 0.1e18; // 10%

    USDPAddressesRegistry registry;

    function setUp() public {
        // Deploy registry with mock addresses
        registry = new USDPAddressesRegistry(
            MOCK_OWNER,
            MOCK_COLL_TOKEN,
            MOCK_WETH,
            CCR,
            MCR,
            BCR,
            SCR,
            LIQUIDATION_PENALTY_SP,
            LIQUIDATION_PENALTY_REDISTRIBUTION
        );
    }

    // ============ Deployment Tests ============

    function test_Deployment_SetsOwner() public {
        assertEq(registry.owner(), MOCK_OWNER, "Owner should be set");
    }

    function test_Deployment_SetsCollToken() public {
        assertEq(address(registry.collToken()), MOCK_COLL_TOKEN, "CollToken should be set in constructor");
    }

    function test_Deployment_SetsWETH() public {
        assertEq(address(registry.WETH()), MOCK_WETH, "WETH should be set in constructor");
    }

    function test_Deployment_SetsTemporaryAddresses() public {
        // All temporary addresses should be set to owner
        assertEq(address(registry.activePool()), MOCK_OWNER, "ActivePool should be owner temporarily");
        assertEq(address(registry.defaultPool()), MOCK_OWNER, "DefaultPool should be owner temporarily");
        assertEq(address(registry.borrowerOperations()), MOCK_OWNER, "BorrowerOperations should be owner temporarily");
        assertEq(address(registry.troveManager()), MOCK_OWNER, "TroveManager should be owner temporarily");
    }

    function test_Deployment_SetsParameters() public {
        assertEq(registry.CCR(), CCR, "CCR mismatch");
        assertEq(registry.MCR(), MCR, "MCR mismatch");
        assertEq(registry.SCR(), SCR, "SCR mismatch");
        assertEq(registry.LIQUIDATION_PENALTY_SP(), LIQUIDATION_PENALTY_SP, "Liquidation penalty SP mismatch");
        assertEq(registry.LIQUIDATION_PENALTY_REDISTRIBUTION(), LIQUIDATION_PENALTY_REDISTRIBUTION, "Liquidation penalty redistribution mismatch");
    }

    function test_Deployment_RejectsZeroCollToken() public {
        vm.expectRevert("Invalid collateral token");
        new USDPAddressesRegistry(
            MOCK_OWNER,
            address(0), // Zero collToken
            MOCK_WETH,
            CCR,
            MCR,
            BCR,
            SCR,
            LIQUIDATION_PENALTY_SP,
            LIQUIDATION_PENALTY_REDISTRIBUTION
        );
    }

    function test_Deployment_RejectsZeroWETH() public {
        vm.expectRevert("Invalid WETH");
        new USDPAddressesRegistry(
            MOCK_OWNER,
            MOCK_COLL_TOKEN,
            address(0), // Zero WETH
            CCR,
            MCR,
            BCR,
            SCR,
            LIQUIDATION_PENALTY_SP,
            LIQUIDATION_PENALTY_REDISTRIBUTION
        );
    }

    // ============ Event Emission Tests ============
    // Note: Events are inherited from AddressesRegistry and emitted in USDPAddressesRegistry constructor

    // ============ Integration Note ============
    // The deployment flow is:
    // 1. USDPAddressesRegistry constructor sets:
    //    - collToken and WETH to real addresses
    //    - activePool, defaultPool, borrowerOperations, troveManager to owner (temporary)
    // 2. This allows constructors to call approve() without reverting
    // 3. After all contracts are deployed, setAddresses() overwrites temporary addresses with real ones
    // 4. The deployment script in DeployUSDPBitkub.s.sol demonstrates this pattern
}