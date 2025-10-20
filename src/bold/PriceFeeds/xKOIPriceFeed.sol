// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./PonderPriceFeed.sol";

/// @title xKOIPriceFeed
/// @notice Price feed for xKOI governance token collateral on Bitkub Chain
contract xKOIPriceFeed is PonderPriceFeedBase {
    address public constant xKOI = 0x6C8119d33fD43f6B254d041Cd5d2675586731dd5;

    constructor(address _multiSourceFeed, address _borrowerOperationsAddress)
        PonderPriceFeedBase(_multiSourceFeed, xKOI, _borrowerOperationsAddress)
    {}
}