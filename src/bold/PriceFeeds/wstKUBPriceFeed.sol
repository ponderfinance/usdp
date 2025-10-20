// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./PonderPriceFeed.sol";

/// @title wstKUBPriceFeed
/// @notice Price feed for wstKUB (wrapped staked KUB) collateral on Bitkub Chain
contract wstKUBPriceFeed is PonderPriceFeedBase {
    address public constant wstKUB = 0x7AC168c81F4F3820Fa3F22603ce5864D6aB3C547;

    constructor(address _multiSourceFeed, address _borrowerOperationsAddress)
        PonderPriceFeedBase(_multiSourceFeed, wstKUB, _borrowerOperationsAddress)
    {}
}