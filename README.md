# USDP Protocol

USDP is a decentralized stablecoin protocol on Kub Chain, forked from Liquity v2 (Bold). It enables users to borrow USDP stablecoins against multiple collateral types with user-set interest rates.

## Overview

USDP is a multi-collateral CDP (Collateralized Debt Position) protocol that allows users to:
- Deposit collateral (KKUB, stKUB, wstKUB, xKOI) and mint USDP stablecoins
- Set their own interest rates (competitive market-driven rates)
- Maintain decentralized, censorship-resistant positions
- Earn yield in Stability Pool by providing USDP liquidity

### Key Features

- **Multi-Collateral**: Support for KKUB, stKUB, wstKUB, and xKOI
- **User-Set Interest Rates**: Borrowers choose their own annual interest rate
- **Liquity v2 Architecture**: Battle-tested protocol design from Liquity
- **Ponder DEX Oracle**: Uses existing Ponder DEX TWAP oracle for price feeds
- **Phased Rollout**: Gradual deployment (KKUB → LSTs → xKOI)

## Architecture

### Oracle System

USDP uses the existing Ponder DEX TWAP oracle on Bitkub Chain:
- **PonderOracleAdapter**: Wraps Ponder oracle at `0xCf814870800A3bcAC4A6b858424A9370A64C75AD`
- **MultiSourcePriceFeed**: Aggregates price sources (upgradeable adapters)
- **Per-Collateral Price Feeds**: KKUBPriceFeed, stKUBPriceFeed, wstKUBPriceFeed, xKOIPriceFeed
- **LST Support**: Multiplies stKUB/wstKUB prices by exchange rates

### Core Contracts

Based on Liquity v2 (Bold) architecture:
- **USDPToken**: ERC20 stablecoin with per-branch minting
- **CollateralRegistry**: Central registry of all collateral types
- **Branch Contracts (per collateral)**:
  - BorrowerOperations: Open/adjust/close troves
  - TroveManager: Liquidations, redemptions, interest accrual
  - StabilityPool: Liquidation backstop + yield
  - TroveNFT: ERC-721 representing positions

### Collateral Parameters

| Collateral | MCR | CCR | SCR | Liquidation Penalty | Risk Profile |
|------------|-----|-----|-----|---------------------|--------------|
| KKUB       | 120% | 140% | 130% | 5% | Conservative (DeFi blue chip) |
| stKUB      | 130% | 150% | 140% | 7% | Moderate (LST, staking risk) |
| wstKUB     | 130% | 150% | 140% | 7% | Moderate (LST, wrapped) |
| xKOI       | 175% | 200% | 185% | 10% | High (Governance token) |

**Definitions**:
- **MCR**: Minimum Collateral Ratio (individual trove minimum)
- **CCR**: Critical Collateral Ratio (liquidation trigger)
- **SCR**: Shutdown Collateral Ratio (system-wide emergency)

## Deployment

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository
git clone <repo-url>
cd usdp-protocol

# Install dependencies
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run specific test
forge test --match-contract PonderOracleAdapterTest

# Run with gas report
forge test --gas-report
```

### Deploy to Bitkub Mainnet

USDP supports **phased deployment** to gradually introduce collateral types:

#### Phase 0: KKUB Only

```bash
DEPLOYER=<private_key> \
PHASE=0 \
forge script script/DeployUSDPBitkub.s.sol:DeployUSDPBitkub \
  --rpc-url https://rpc.bitkubchain.io \
  --broadcast \
  --verify
```

#### Phase 1: Add LSTs (stKUB + wstKUB)

```bash
DEPLOYER=<private_key> \
PHASE=1 \
forge script script/DeployUSDPBitkub.s.sol:DeployUSDPBitkub \
  --rpc-url https://rpc.bitkubchain.io \
  --broadcast \
  --verify
```

#### Phase 2: Add xKOI

```bash
DEPLOYER=<private_key> \
PHASE=2 \
forge script script/DeployUSDPBitkub.s.sol:DeployUSDPBitkub \
  --rpc-url https://rpc.bitkubchain.io \
  --broadcast \
  --verify
```

### Environment Variables

- `DEPLOYER`: Private key of deployer account (must have KUB for gas)
- `PHASE`: Deployment phase (0, 1, or 2)

## Deployed Addresses (Bitkub Mainnet)

### Existing Infrastructure
- **Ponder Oracle**: `0xCf814870800A3bcAC4A6b858424A9370A64C75AD`
- **Ponder Factory**: `0x20B17e92Dd1866eC647ACaA38fe1f7075e4B359E`

### Collateral Tokens
- **KKUB**: `0x67eBD850304c70d983B2d1b93ea79c7CD6c3F6b5`
- **stKUB**: `0xcba2aeEc821b0B119857a9aB39E09b034249681A`
- **wstKUB**: `0x7AC168c81F4F3820Fa3F22603ce5864D6aB3C547`
- **xKOI**: `0x6C8119d33fD43f6B254d041Cd5d2675586731dd5`
- **KUSDT**: `0x7d984C24d2499D840eB3b7016077164e15E5faA6`

### USDP Contracts
*To be filled after deployment*

## Usage Examples

### Opening a Trove

```solidity
// 1. Approve collateral
IERC20(KKUB).approve(borrowerOperations, collateralAmount);

// 2. Open trove
borrowerOperations.openTrove(
    msg.sender,           // owner
    0,                    // ownerIndex
    10 ether,             // collAmount (10 KKUB)
    5000 ether,           // boldAmount (5000 USDP)
    0,                    // upperHint
    0,                    // lowerHint
    0.05 ether,           // annualInterestRate (5%)
    type(uint256).max,    // maxUpfrontFee
    address(0),           // addManager
    address(0),           // removeManager
    address(0)            // receiver
);
```

### Providing Stability Pool Liquidity

```solidity
// 1. Approve USDP
usdpToken.approve(stabilityPool, amount);

// 2. Deposit to stability pool
stabilityPool.provideToSP(
    10000 ether,  // amount
    true          // claim rewards
);
```

### Checking Oracle Price

```solidity
// Get KKUB price
(uint256 price, bool oracleFailure) = kkubPriceFeed.fetchPrice();
// price is in USD with 18 decimals
```

## Oracle System Deep Dive

### Price Feed Flow

```
Ponder DEX (TWAP)
    ↓
PonderOracleAdapter (wraps oracle, handles LST exchange rates)
    ↓
MultiSourcePriceFeed (aggregates sources, upgradeable)
    ↓
KKUBPriceFeed (per-collateral, implements IPriceFeed)
    ↓
BorrowerOperations / TroveManager (consume prices)
```

### LST Exchange Rate Handling

For stKUB and wstKUB:
1. Get TWAP price from Ponder DEX (stKUB/KUSDT or wstKUB/KUSDT)
2. Get exchange rate from LST contract (`getExchangeRate()`)
3. Multiply: `finalPrice = twapPrice * exchangeRate / 1e18`

This ensures LST prices reflect both market price and accrued staking rewards.

### Upgrading Oracle (Future)

When USDP gains liquidity:
```solidity
// Deploy new adapter with USDP as BASE_TOKEN
PonderOracleAdapter newAdapter = new PonderOracleAdapter(
    PONDER_ORACLE,
    PONDER_FACTORY,
    address(usdpToken)  // Now use USDP instead of KUSDT
);

// Upgrade (owner only)
multiSourceFeed.setPonderAdapter(address(newAdapter));
```

## Security Considerations

### Oracle Risks
- **TWAP Period**: 4-hour TWAP protects against short-term manipulation
- **LST Risk**: Exchange rate manipulation could affect stKUB/wstKUB pricing
- **Liquidity Depth**: Low liquidity pairs may be more susceptible to manipulation

### Liquidation Risks
- **MCR Buffer**: Conservative MCRs provide safety margin
- **CCR > MCR**: Critical ratio above minimum prevents cascading liquidations
- **Stability Pool**: Provides liquidation backstop before redistribution

### Smart Contract Risks
- **Liquity v2 Audit**: Base protocol audited, but fork changes introduce risk
- **Oracle Adapter**: Custom adapter should be audited separately
- **Upgradeability**: Only oracle adapters are upgradeable (immutable core)

## Development

### Project Structure

```
usdp-protocol/
├── src/
│   ├── adapters/
│   │   └── PonderOracleAdapter.sol    # Wraps Ponder TWAP oracle
│   ├── oracles/
│   │   └── MultiSourcePriceFeed.sol   # Aggregates price sources
│   ├── bold/
│   │   ├── USDPToken.sol              # Main stablecoin
│   │   ├── BorrowerOperations.sol     # Trove management
│   │   ├── TroveManager.sol           # Liquidations & redemptions
│   │   ├── StabilityPool.sol          # Liquidation backstop
│   │   ├── CollateralRegistry.sol     # Collateral registry
│   │   └── PriceFeeds/
│   │       ├── PonderPriceFeed.sol    # Base price feed
│   │       ├── KKUBPriceFeed.sol      # KKUB-specific
│   │       ├── stKUBPriceFeed.sol     # stKUB-specific
│   │       ├── wstKUBPriceFeed.sol    # wstKUB-specific
│   │       └── xKOIPriceFeed.sol      # xKOI-specific
├── script/
│   └── DeployUSDPBitkub.s.sol         # Deployment script
├── test/
│   └── ...                            # Tests
└── docs/
    └── RFC-001-USDP-Deployment.md     # Deployment RFC
```

### Adding New Collateral

1. **Deploy Price Feed**:
```solidity
contract NewCollateralPriceFeed is PonderPriceFeedBase {
    address public constant NEW_COLLATERAL = 0x...;

    constructor(address _multiSourceFeed, address _borrowerOps)
        PonderPriceFeedBase(_multiSourceFeed, NEW_COLLATERAL, _borrowerOps)
    {}
}
```

2. **Deploy Branch Contracts**:
```bash
# Add to deployment script and redeploy with new phase
```

3. **Register with CollateralRegistry**:
```solidity
collateralRegistry.addCollateral(newCollateral, newTroveManager);
```

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Code Style

- Solidity version: `0.8.24`
- Follow Bold's naming conventions
- Document all public functions
- Write tests for new features

## Resources

- **Liquity v2 Docs**: https://docs.liquity.org/
- **Bold Protocol**: https://github.com/liquity/bold
- **Ponder DEX**: https://ponder.finance 
- **Kub Chain**: https://www.kubchain.com/

## License

MIT License - see LICENSE file for details

## Contact

- **Team**: Ponder Finance
- **Website**: https://ponder.finance
- **Twitter**: https://x.com/ponderdex

---

**⚠️ Disclaimer**: USDP is experimental software. Use at your own risk. Understand the risks before depositing funds.