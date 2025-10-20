// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./PonderPriceFeed.sol";

/// @title stKUBPriceFeed
/// @notice Price feed for stKUB (staked KUB) collateral on Bitkub Chain
contract stKUBPriceFeed is PonderPriceFeedBase {
    address public constant stKUB = 0xcba2aeEc821b0B119857a9aB39E09b034249681A;

    constructor(address _multiSourceFeed, address _borrowerOperationsAddress)
        PonderPriceFeedBase(_multiSourceFeed, stKUB, _borrowerOperationsAddress)
    {}
}