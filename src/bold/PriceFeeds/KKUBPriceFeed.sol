// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./PonderPriceFeed.sol";

/// @title KKUBPriceFeed
/// @notice Price feed for KKUB collateral on Bitkub Chain
contract KKUBPriceFeed is PonderPriceFeedBase {
    address public constant KKUB = 0x67eBD850304c70d983B2d1b93ea79c7CD6c3F6b5;

    constructor(address _multiSourceFeed, address _borrowerOperationsAddress)
        PonderPriceFeedBase(_multiSourceFeed, KKUB, _borrowerOperationsAddress)
    {}
}