// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./AddressesRegistry.sol";

/// @title USDPAddressesRegistry
/// @notice Extended AddressesRegistry that accepts collateral token in constructor
/// @dev This wrapper solves the chicken-egg problem in deployment where BorrowerOperations
///      constructor needs collToken to be set, but setAddresses() requires all contracts
///      to be deployed first. We set collToken and WETH immediately, and use owner as a
///      temporary placeholder for activePool (will be overwritten by setAddresses later).
contract USDPAddressesRegistry is AddressesRegistry {
    constructor(
        address _owner,
        address _collToken,
        address _weth,
        uint256 _ccr,
        uint256 _mcr,
        uint256 _bcr,
        uint256 _scr,
        uint256 _liquidationPenaltySP,
        uint256 _liquidationPenaltyRedistribution
    ) AddressesRegistry(
        _owner,
        _ccr,
        _mcr,
        _bcr,
        _scr,
        _liquidationPenaltySP,
        _liquidationPenaltyRedistribution
    ) {
        require(_collToken != address(0), "Invalid collateral token");
        require(_weth != address(0), "Invalid WETH");

        // Set collToken and WETH immediately so constructors work
        collToken = IERC20Metadata(_collToken);
        WETH = IWETH(_weth);

        // Set all addresses that are needed for approve() calls in constructors to owner temporarily
        // BorrowerOperations needs: activePool
        // ActivePool needs: defaultPool
        // GasPool needs: borrowerOperations, troveManager
        // All of these will be properly set via setAddresses() after all contracts are deployed
        activePool = IActivePool(_owner);
        defaultPool = IDefaultPool(_owner);
        borrowerOperations = IBorrowerOperations(_owner);
        troveManager = ITroveManager(_owner);

        emit CollTokenAddressChanged(_collToken);
        emit WETHAddressChanged(_weth);
        emit ActivePoolAddressChanged(_owner); // Temporary, will be updated later
        emit DefaultPoolAddressChanged(_owner); // Temporary, will be updated later
        emit BorrowerOperationsAddressChanged(_owner); // Temporary, will be updated later
        emit TroveManagerAddressChanged(_owner); // Temporary, will be updated later
    }
}