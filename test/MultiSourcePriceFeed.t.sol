// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MultiSourcePriceFeed} from "../src/oracles/MultiSourcePriceFeed.sol";
import {PonderOracleAdapter} from "../src/adapters/PonderOracleAdapter.sol";

/**
 * @title MultiSourcePriceFeedTest
 * @notice Basic unit tests for MultiSourcePriceFeed
 * @dev Tests constructor, adapter management, and ownership without requiring mainnet fork
 */
contract MultiSourcePriceFeedTest is Test {
    // Mock addresses
    address constant MOCK_ORACLE = address(0x1);
    address constant MOCK_FACTORY = address(0x2);
    address constant MOCK_BASE_TOKEN = address(0x3);

    PonderOracleAdapter ponderAdapter;
    MultiSourcePriceFeed multiSourceFeed;
    address deployer = address(this);

    function setUp() public {
        // Deploy mock adapter
        ponderAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );

        // Deploy MultiSourcePriceFeed
        multiSourceFeed = new MultiSourcePriceFeed(
            address(ponderAdapter)
        );
    }

    // ============ Deployment Tests ============

    function test_Deployment() public {
        assertEq(multiSourceFeed.ponderAdapter(), address(ponderAdapter), "Ponder adapter mismatch");
        assertEq(multiSourceFeed.bitkubAdapter(), address(0), "Bitkub adapter should be zero");
        assertFalse(multiSourceFeed.useBitkubFeed(), "Should not use Bitkub feed initially");
    }

    function test_Deployment_SetsOwner() public {
        assertEq(multiSourceFeed.owner(), deployer, "Owner should be deployer");
    }

    function test_Deployment_RejectsZeroAdapter() public {
        vm.expectRevert("Invalid ponder adapter");
        new MultiSourcePriceFeed(address(0));
    }

    // ============ Ponder Adapter Management ============

    function test_SetPonderAdapter_Success() public {
        // Deploy new adapter
        PonderOracleAdapter newAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );

        // Update adapter
        multiSourceFeed.setPonderAdapter(address(newAdapter));

        assertEq(multiSourceFeed.ponderAdapter(), address(newAdapter), "Adapter should be updated");
    }

    function test_SetPonderAdapter_OnlyOwner() public {
        address newAdapter = address(0x123);

        vm.prank(address(0x456)); // Not owner
        vm.expectRevert();
        multiSourceFeed.setPonderAdapter(newAdapter);
    }

    function test_SetPonderAdapter_RejectsZeroAddress() public {
        vm.expectRevert("Invalid adapter");
        multiSourceFeed.setPonderAdapter(address(0));
    }

    function test_SetPonderAdapter_EmitsEvent() public {
        PonderOracleAdapter newAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );

        vm.expectEmit(true, true, false, false);
        emit MultiSourcePriceFeed.PonderAdapterUpdated(address(ponderAdapter), address(newAdapter));
        multiSourceFeed.setPonderAdapter(address(newAdapter));
    }

    // ============ Bitkub Feed Management ============

    function test_EnableBitkubFeed() public {
        // Deploy second adapter
        PonderOracleAdapter bitkubAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );

        multiSourceFeed.enableBitkubFeed(address(bitkubAdapter));

        assertEq(multiSourceFeed.bitkubAdapter(), address(bitkubAdapter), "Bitkub adapter should be set");
        assertTrue(multiSourceFeed.useBitkubFeed(), "Should use Bitkub feed");
    }

    function test_EnableBitkubFeed_OnlyOwner() public {
        vm.prank(address(0x456)); // Not owner
        vm.expectRevert();
        multiSourceFeed.enableBitkubFeed(address(0x123));
    }

    function test_EnableBitkubFeed_RejectsZeroAddress() public {
        vm.expectRevert("Invalid adapter");
        multiSourceFeed.enableBitkubFeed(address(0));
    }

    function test_EnableBitkubFeed_EmitsEvent() public {
        PonderOracleAdapter bitkubAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );

        vm.expectEmit(true, false, false, false);
        emit MultiSourcePriceFeed.BitkubFeedEnabled(address(bitkubAdapter));
        multiSourceFeed.enableBitkubFeed(address(bitkubAdapter));
    }

    function test_DisableBitkubFeed() public {
        // First enable
        PonderOracleAdapter bitkubAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );
        multiSourceFeed.enableBitkubFeed(address(bitkubAdapter));

        // Then disable
        multiSourceFeed.disableBitkubFeed();

        assertFalse(multiSourceFeed.useBitkubFeed(), "Should not use Bitkub feed");
    }

    function test_DisableBitkubFeed_OnlyOwner() public {
        vm.prank(address(0x456)); // Not owner
        vm.expectRevert();
        multiSourceFeed.disableBitkubFeed();
    }

    function test_DisableBitkubFeed_EmitsEvent() public {
        // First enable
        PonderOracleAdapter bitkubAdapter = new PonderOracleAdapter(
            MOCK_ORACLE,
            MOCK_FACTORY,
            MOCK_BASE_TOKEN
        );
        multiSourceFeed.enableBitkubFeed(address(bitkubAdapter));

        // Then disable and check event
        vm.expectEmit(false, false, false, false);
        emit MultiSourcePriceFeed.BitkubFeedDisabled();
        multiSourceFeed.disableBitkubFeed();
    }

    // ============ Ownership Tests ============

    function test_TransferOwnership_TwoStepProcess() public {
        address newOwner = address(0x456);

        // Step 1: Current owner initiates transfer
        multiSourceFeed.transferOwnership(newOwner);
        assertEq(multiSourceFeed.owner(), deployer, "Owner should not change yet");

        // Step 2: New owner accepts
        vm.prank(newOwner);
        multiSourceFeed.acceptOwnership();
        assertEq(multiSourceFeed.owner(), newOwner, "Owner should be new owner");
    }

    function test_TransferOwnership_OnlyOwnerCanInitiate() public {
        address notOwner = address(0x123);
        address newOwner = address(0x456);

        vm.prank(notOwner);
        vm.expectRevert();
        multiSourceFeed.transferOwnership(newOwner);
    }
}