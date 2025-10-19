// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title PonderOracleAdapter
/// @notice Adapts Ponder TWAP oracle to Bold's price feed interface
/// @dev Uses KUSDT as BASE_TOKEN to avoid chicken-egg problem with USDP

interface IPonderPriceOracle {
    function consult(address pair, address tokenIn, uint256 amountIn, uint32 period)
        external view returns (uint256 amountOut);
    function lastUpdateTime(address pair) external view returns (uint256);
}

interface IPonderFactory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface ILiquidStakingToken {
    function getExchangeRate() external view returns (uint256);  // 18 decimals
}

contract PonderOracleAdapter {
    IPonderPriceOracle public immutable ORACLE;
    IPonderFactory public immutable FACTORY;
    address public immutable BASE_TOKEN;  // KUSDT initially

    uint32 public constant TWAP_PERIOD = 14400;  // 4 hours
    uint256 public constant STALENESS_THRESHOLD = 1200;  // 20 minutes

    address public owner;

    mapping(address => address) public collateralToPair;  // KKUB => KUSDT/KKUB pair
    mapping(address => bool) public isLST;  // true for stKUB, wstKUB
    mapping(address => address) public lstToUnderlying;  // stKUB => KKUB

    error StalePrice();
    error InvalidCollateral();
    error Unauthorized();
    error PairNotFound();

    event CollateralRegistered(address indexed collateral, address indexed pair);
    event LSTRegistered(address indexed lst, address indexed underlying);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(
        address _oracle,
        address _factory,
        address _baseToken  // Use KUSDT (0x7d984C24d2499D840eB3b7016077164e15E5faA6 on Bitkub)
    ) {
        require(_oracle != address(0), "Invalid oracle address");
        require(_factory != address(0), "Invalid factory address");
        require(_baseToken != address(0), "Invalid base token address");

        ORACLE = IPonderPriceOracle(_oracle);
        FACTORY = IPonderFactory(_factory);
        BASE_TOKEN = _baseToken;
        owner = msg.sender;
    }

    /// @notice Register collateral with its trading pair
    /// @param collateral The collateral token address (e.g., KKUB)
    function registerCollateral(address collateral) external onlyOwner {
        address pair = FACTORY.getPair(collateral, BASE_TOKEN);
        if (pair == address(0)) revert PairNotFound();

        collateralToPair[collateral] = pair;
        emit CollateralRegistered(collateral, pair);
    }

    /// @notice Register LST with its underlying (e.g., stKUB => KKUB)
    /// @param lst The liquid staking token address
    /// @param underlying The underlying token address
    function registerLST(address lst, address underlying) external onlyOwner {
        require(lst != address(0), "Invalid LST address");
        require(underlying != address(0), "Invalid underlying address");

        isLST[lst] = true;
        lstToUnderlying[lst] = underlying;
        emit LSTRegistered(lst, underlying);
    }

    /// @notice Get price in USD (18 decimals)
    /// @param collateral Address of collateral token
    /// @return price Price in USD with 18 decimals
    function getPrice(address collateral) external view returns (uint256 price) {
        address pair = collateralToPair[collateral];
        if (pair == address(0)) revert InvalidCollateral();

        // Get TWAP: 1 collateral token = X BASE_TOKEN
        // amountIn = 1e18 (1 token with 18 decimals)
        uint256 amountOut = ORACLE.consult(pair, collateral, 1e18, TWAP_PERIOD);

        // If LST, multiply by exchange rate (stKUB is worth more than 1 KKUB)
        if (isLST[collateral]) {
            uint256 exchangeRate = ILiquidStakingToken(collateral).getExchangeRate();
            amountOut = (amountOut * exchangeRate) / 1e18;
        }

        // BASE_TOKEN is KUSDT (≈ $1.00), so amountOut is already USD price
        return amountOut;
    }

    /// @notice Check if price is fresh (updated within staleness threshold)
    /// @param collateral Address of collateral token
    /// @return bool True if price is fresh
    function isFresh(address collateral) external view returns (bool) {
        address pair = collateralToPair[collateral];
        if (pair == address(0)) return false;

        uint256 lastUpdate = ORACLE.lastUpdateTime(pair);
        return block.timestamp <= lastUpdate + STALENESS_THRESHOLD;
    }

    /// @notice Transfer ownership to a new address
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
