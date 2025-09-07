# 🌾 Farm Investment Contracts

A Clarity smart contract system that enables investors to fund agricultural projects in exchange for revenue shares and NFT-backed yield rights.

## 🚀 Features

- **Farm Creation**: Farmers can create investment opportunities with funding goals
- **Investment System**: Investors can fund farms and receive proportional ownership
- **NFT Yield Rights**: Each investment generates an NFT representing yield rights
- **Revenue Distribution**: Automated yield calculation and distribution system
- **Harvest Cycles**: Time-based harvest cycles for realistic farming operations

## 📋 Contract Functions

### 🏗️ Farm Management
- `create-farm` - Create a new farm investment opportunity
- `deactivate-farm` - Deactivate a farm (owner only)
- `add-farm-revenue` - Add revenue to farm (owner only)
- `withdraw-farm-funds` - Withdraw funds from farm (owner only)

### 💰 Investment Functions
- `invest-in-farm` - Invest STX in a farm and receive yield NFT
- `distribute-yields` - Distribute yields to investors (farm owner only)
- `claim-yield` - Claim pending yield rewards
- `calculate-investor-yield` - Calculate yield for specific investor

### 🎨 NFT Functions
- `transfer-yield-nft` - Transfer yield rights NFT to another user

### 📊 Read-Only Functions
- `get-farm` - Get farm details
- `get-investment` - Get investment details
- `get-farm-investor-info` - Get investor information for a farm
- `get-nft-metadata` - Get NFT metadata
- `get-farm-revenue` - Get total farm revenue
- `get-pending-yield` - Get pending yield for investor

## 🛠️ Usage Examples

### Creating a Farm
```clarity
(contract-call? .farm-investment-contracts create-farm 
  "Organic Tomato Farm" 
  u1000000 
  u75 
  u1440)
```

### Investing in a Farm
```clarity
(contract-call? .farm-investment-contracts invest-in-farm u1 u100000)
```

### Adding Revenue (Farm Owner)
```clarity
(contract-call? .farm-investment-contracts add-farm-revenue u1 u50000)
```

### Claiming Yields
```clarity
(contract-call? .farm-investment-contracts claim-yield u1)
```

## 🔧 Development Setup

1. Install Clarinet
2. Clone this repository
3. Run tests:
```bash
clarinet test
```

4. Deploy locally:
```bash
clarinet console
```

## 📈 Investment Flow

1. **Farm Creation** 🌱 - Farmer creates investment opportunity
2. **Investment** 💵 - Investors fund the farm and receive NFTs
3. **Farming Operations** 🚜 - Farmer operates and generates revenue
4. **Revenue Addition** 📊 - Farmer adds revenue to the contract
5. **Yield Distribution** 💰 - Yields are calculated and made available
6. **Yield Claiming** 🎯 - Investors claim their share of profits

## 🎯 Key Benefits

- **Transparency**: All investments and yields tracked on-chain
- **NFT Ownership**: Tradeable yield rights as NFTs
- **Automated Distribution**: Smart contract handles yield calculations
- **Flexible Investment**: Multiple investors per farm with proportional shares
- **Time-Based Harvests**: Realistic farming cycle implementation

## ⚠️ Important Notes

- Investments are locked until yields are distributed
- Farm owners control revenue reporting and yield distribution
- NFTs represent yield rights and can be transferred
- Harvest cycles prevent premature yield distribution
- All amounts are in microSTX (1 STX = 1,000,000 microSTX)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the MIT License.
```

**Git Commit Message:**
```
feat: implement farm investment contracts with NFT yield rights system
```

**GitHub Pull Request Title:**
```
🌾 Add Farm Investment Contracts with NFT-backed Yield Rights
```

**GitHub Pull Request Description:**
```
## Summary
This PR introduces a comprehensive farm investment contract system that allows investors to fund agricultural projects in exchange for revenue shares and NFT-backed yield rights.

## What's Added
- **Smart Contract**: Complete Clarity contract with farm creation, investment, and yield distribution
- **NFT System**: Yield rights represented as transferable NFTs
- **Revenue Sharing**: Automated calculation and distribution of farm profits
- **
