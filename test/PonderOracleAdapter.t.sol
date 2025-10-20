// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {PonderOracleAdapter} from "../src/adapters/PonderOracleAdapter.sol";

/**
 * @title PonderOracleAdapterTest
 * @notice Basic unit tests for PonderOracleAdapter
 * @dev Tests constructor, ownership, and LST registration without requiring mainnet fork
 */
contract PonderOracleAdapterTest is Test {
    // Mock addresses
    address constant MOCK_ORACLE = address(0x1);
    address constant MOCK_FACTORY = address(0x2);
    address constant MOCK_BASE_TOKEN = address(0x3);
    address constant MOCK_LST = address(0x4);
    address constant MOCK_UNDERLYING = address(0x5);

    PonderOracleAdapter adapter;
    address deployer = address(this);

    function setUp() public {
        // Deploy adapter with mock addresses
        adapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );
    }

    // ============ Deployment Tests ============

    function test_Deployment() public {
        assertEq(address(adapter.ORACLE()), MOCK_ORACLE, "Oracle address mismatch");
        assertEq(address(adapter.FACTORY()), MOCK_FACTORY, "Factory address mismatch");
        assertEq(adapter.BASE_TOKEN(), MOCK_BASE_TOKEN, "Base token mismatch");
        assertEq(adapter.TWAP_PERIOD(), 14400, "TWAP period should be 4 hours");
    }

    function test_Deployment_SetsOwner() public {
        assertEq(adapter.owner(), deployer, "Owner should be deployer");
    }

    function test_TwapPeriod() public {
        assertEq(adapter.TWAP_PERIOD(), 14400, "TWAP period should be 4 hours (14400 seconds)");
    }

    // ============ LST Registration Tests ============

    function test_RegisterLST() public {
        // Register LST
        adapter.registerLST(MOCK_LST, MOCK_UNDERLYING);

        assertTrue(adapter.isLST(MOCK_LST), "LST should be registered");
        assertEq(adapter.lstToUnderlying(MOCK_LST), MOCK_UNDERLYING, "Underlying should match");
    }

    function test_RegisterLST_OnlyOwner() public {
        vm.prank(address(0x123)); // Not owner
        vm.expectRevert();
        adapter.registerLST(MOCK_LST, MOCK_UNDERLYING);
    }

    function test_RegisterLST_RejectsZeroAddress() public {
        vm.expectRevert("Invalid LST address");
        adapter.registerLST(address(0), MOCK_UNDERLYING);
    }

    function test_RegisterLST_RejectsZeroUnderlying() public {
        vm.expectRevert("Invalid underlying address");
        adapter.registerLST(MOCK_LST, address(0));
    }

    function test_RegisterLST_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit PonderOracleAdapter.LSTRegistered(MOCK_LST, MOCK_UNDERLYING);
        adapter.registerLST(MOCK_LST, MOCK_UNDERLYING);
    }

    function test_RegisterLST_Multiple() public {
        address lst1 = address(0x10);
        address underlying1 = address(0x20);
        address lst2 = address(0x30);
        address underlying2 = address(0x40);

        adapter.registerLST(lst1, underlying1);
        adapter.registerLST(lst2, underlying2);

        assertTrue(adapter.isLST(lst1), "LST1 should be registered");
        assertTrue(adapter.isLST(lst2), "LST2 should be registered");
        assertEq(adapter.lstToUnderlying(lst1), underlying1, "LST1 underlying mismatch");
        assertEq(adapter.lstToUnderlying(lst2), underlying2, "LST2 underlying mismatch");
    }

    // ============ Ownership Tests ============

    function test_TransferOwnership_TwoStepProcess() public {
        address newOwner = address(0x456);

        // Step 1: Current owner initiates transfer
        adapter.transferOwnership(newOwner);
        assertEq(adapter.owner(), deployer, "Owner should not change yet");

        // Step 2: New owner accepts
        vm.prank(newOwner);
        adapter.acceptOwnership();
        assertEq(adapter.owner(), newOwner, "Owner should be new owner");
    }

    function test_TransferOwnership_OnlyOwnerCanInitiate() public {
        address notOwner = address(0x123);
        address newOwner = address(0x456);

        vm.prank(notOwner);
        vm.expectRevert();
        adapter.transferOwnership(newOwner);
    }

    // Note: renounceOwnership is not overridden in PonderOracleAdapter
    // so this test is removed. The contract uses standard Ownable2Step behavior.

    // ============ View Function Tests ============

    function test_IsLST_ReturnsFalseForUnregistered() public {
        assertFalse(adapter.isLST(address(0x999)), "Unregistered address should not be LST");
    }

    function test_LstToUnderlying_ReturnsZeroForUnregistered() public {
        assertEq(adapter.lstToUnderlying(address(0x999)), address(0), "Should return zero address");
    }
}