// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MultiSourcePriceFeed
/// @notice Aggregates multiple price sources with min() safety
/// @dev This is the ONLY contract that PriceFeed.sol talks to
///      You can update adapters without redeploying Bold contracts

interface IPriceAdapter {
    function getPrice(address collateral) external view returns (uint256);
    function isFresh(address collateral) external view returns (bool);
}

contract MultiSourcePriceFeed is Ownable2Step {
    address public ponderAdapter;  // Mutable - can upgrade to new adapter
    address public bitkubAdapter;  // Optional secondary feed

    bool public useBitkubFeed;

    error StalePrice(string source);
    error InvalidAdapter();

    event PonderAdapterUpdated(address indexed oldAdapter, address indexed newAdapter);
    event BitkubFeedEnabled(address indexed adapter);
    event BitkubFeedDisabled();

    constructor(address _ponderAdapter) Ownable(msg.sender) {
        require(_ponderAdapter != address(0), "Invalid ponder adapter");
        ponderAdapter = _ponderAdapter;
    }

    /// @notice Get collateral price (min of all sources)
    /// @param collateral The collateral token address
    /// @return price The USD price with 18 decimals
    function fetchPrice(address collateral) external view returns (uint256 price) {
        // Get Ponder price
        uint256 ponderPrice = IPriceAdapter(ponderAdapter).getPrice(collateral);
        if (!IPriceAdapter(ponderAdapter).isFresh(collateral)) {
            revert StalePrice("Ponder");
        }

        // Phase 0: Only Ponder oracle
        if (!useBitkubFeed || bitkubAdapter == address(0)) {
            return ponderPrice;
        }

        // Phase 1+: min(ponder, bitkub) for safety
        uint256 bitkubPrice = IPriceAdapter(bitkubAdapter).getPrice(collateral);
        if (!IPriceAdapter(bitkubAdapter).isFresh(collateral)) {
            revert StalePrice("Bitkub");
        }

        // Return minimum price for safety (protects against oracle manipulation)
        return ponderPrice < bitkubPrice ? ponderPrice : bitkubPrice;
    }

    /// @notice Update Ponder adapter (e.g., switch from KUSDT to USDP base)
    /// @param _newAdapter The new adapter address
    function setPonderAdapter(address _newAdapter) external onlyOwner {
        require(_newAdapter != address(0), "Invalid adapter");
        address oldAdapter = ponderAdapter;
        ponderAdapter = _newAdapter;
        emit PonderAdapterUpdated(oldAdapter, _newAdapter);
    }

    /// @notice Enable Bitkub feed (governance only)
    /// @param _bitkubAdapter The Bitkub adapter address
    function enableBitkubFeed(address _bitkubAdapter) external onlyOwner {
        require(_bitkubAdapter != address(0), "Invalid adapter");
        bitkubAdapter = _bitkubAdapter;
        useBitkubFeed = true;
        emit BitkubFeedEnabled(_bitkubAdapter);
    }

    /// @notice Disable Bitkub feed
    function disableBitkubFeed() external onlyOwner {
        useBitkubFeed = false;
        emit BitkubFeedDisabled();
    }
}
