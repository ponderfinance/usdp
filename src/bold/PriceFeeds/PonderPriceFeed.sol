// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../oracles/MultiSourcePriceFeed.sol";
import "../Interfaces/IPriceFeed.sol";

/// @title PonderPriceFeedBase
/// @notice Base contract for collateral-specific price feeds using Ponder TWAP oracle
/// @dev Each collateral gets its own deployed instance
abstract contract PonderPriceFeedBase is IPriceFeed {
    MultiSourcePriceFeed public immutable multiSourceFeed;
    address public immutable collateralAddress;
    address public borrowerOperationsAddress;

    uint256 public override lastGoodPrice;

    event LastGoodPriceUpdated(uint256 price);
    event PriceFetchFailed(string reason);

    constructor(
        address _multiSourceFeed,
        address _collateralAddress,
        address _borrowerOperationsAddress
    ) {
        require(_multiSourceFeed != address(0), "Invalid multiSourceFeed");
        require(_collateralAddress != address(0), "Invalid collateral");
        // Note: borrowerOperationsAddress can be zero during deployment, it's not used by the price feed

        multiSourceFeed = MultiSourcePriceFeed(_multiSourceFeed);
        collateralAddress = _collateralAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;

        // Initialize lastGoodPrice
        _fetchPriceInitial();
    }

    function _fetchPriceInitial() internal {
        try multiSourceFeed.fetchPrice(collateralAddress) returns (uint256 price) {
            lastGoodPrice = price;
        } catch {
            revert("PonderPriceFeed: Failed to fetch initial price");
        }
    }

    /// @notice Fetch price for this collateral (IPriceFeed interface)
    /// @return price The USD price with 18 decimals
    /// @return oracleFailure True if oracle failed to provide a fresh price
    function fetchPrice() public override returns (uint256, bool) {
        try multiSourceFeed.fetchPrice(collateralAddress) returns (uint256 price) {
            lastGoodPrice = price;
            emit LastGoodPriceUpdated(price);
            return (price, false);
        } catch Error(string memory reason) {
            emit PriceFetchFailed(reason);
            return (lastGoodPrice, true);
        } catch {
            emit PriceFetchFailed("Unknown error");
            return (lastGoodPrice, true);
        }
    }

    /// @notice Fetch redemption price (same as regular price for our system)
    /// @return price The USD price with 18 decimals
    /// @return oracleFailure True if oracle failed to provide a fresh price
    function fetchRedemptionPrice() external override returns (uint256, bool) {
        return fetchPrice();
    }
}
