# 🌾 Fertsafe - Fertilizer Subsidy Tracker

> Ensuring government-subsidized fertilizer inputs reach the right farmers 🎯

## 📋 Overview

Fertsafe is a transparent blockchain-based system that tracks government fertilizer subsidies from allocation to distribution. It prevents fraud, ensures accountability, and guarantees that subsidized inputs reach verified farmers.

## ✨ Key Features

- 👨‍🌾 **Farmer Registration** - Secure farmer verification system
- 🏛️ **Government Admin Panel** - Multi-admin subsidy management
- 📦 **Fertilizer Inventory** - Real-time stock tracking
- 💰 **Subsidy Allocation** - Transparent fund distribution
- ⏰ **Time-bound Claims** - Prevents expired subsidy abuse
- 📊 **Analytics Dashboard** - Complete transparency metrics

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/fertsafe.git
cd fertsafe
```

2. Run tests:
```bash
clarinet test
```

3. Deploy locally:
```bash
clarinet integrate
```

## 📖 Usage Guide

### For Government Admins 🏛️

#### 1. Add Fertilizer Types
```clarity
(contract-call? .fertsafe add-fertilizer-type "NPK-20-20-20" u1000 u50000 u75)
```
- `fertilizer-type`: Name of fertilizer
- `stock`: Total units available
- `price`: Price per unit in micro-STX
- `subsidy-rate`: Subsidy percentage (75 = 75%)

#### 2. Verify Farmers
```clarity
(contract-call? .fertsafe verify-farmer 'SP1234...)
```

#### 3. Allocate Subsidies
```clarity
(contract-call? .fertsafe allocate-subsidy 'SP1234... "NPK-20-20-20" u100 u1000)
```
- `farmer`: Farmer's principal
- `fertilizer-type`: Type of fertilizer
- `amount`: Quantity allocated
- `validity-blocks`: Expiration in blocks

### For Farmers 👨‍🌾

#### 1. Register as Farmer
```clarity
(contract-call? .fertsafe register-farmer "John Doe" u50 "District A, County B")
```
- `name`: Farmer's name
- `farm-size`: Farm size in acres
- `location`: Farm location

#### 2. Claim Subsidies
```clarity
(contract-call? .fertsafe claim-subsidy u1)
```
- `subsidy-id`: ID of allocated subsidy

### Query Functions 🔍

#### Get Farmer Information
```clarity
(contract-call? .fertsafe get-farmer 'SP1234...)
```

#### Check Subsidy Status
```clarity
(contract-call? .fertsafe get-subsidy u1)
```

#### View Contract Statistics
```clarity
(contract-call? .fertsafe get-contract-stats)
```

#### Calculate Subsidy Amount
```clarity
(contract-call? .fertsafe calculate-subsidy-amount "NPK-20-20-20" u100)
```

## 🔐 Security Features

- ✅ **Role-based Access Control** - Only verified admins can allocate subsidies
- ✅ **Double-spending Prevention** - Each subsidy can only be claimed once
- ✅ **Time-bound Validity** - Subsidies expire after specified blocks
- ✅ **Farmer Verification** - Only verified farmers can claim subsidies
- ✅ **Transparent Tracking** - All transactions are publicly auditable

## 📊 Contract Data Structure

### Farmers Map
```clarity
{
    name: string,
    farm-size: uint,
    location: string,
    registered-at: uint,
    verified: bool,
    total-claimed: uint
}
```

### Subsidies Map
```clarity
{
    farmer: principal,
    fertilizer-type: string,
    amount: uint,
    allocated-at: uint,
    expires-at: uint,
    claimed: bool,
    claimed-at: optional<uint>
}
```

### Fertilizer Inventory
```clarity
{
    total-stock: uint,
    allocated: uint,
    price-per-unit: uint,
    subsidy-rate: uint
}
```

## 🛠️ Error Codes

| Code | Description |
|------|-------------|
| `u100` | Unauthorized access |
| `u101` | Resource not found |
| `u102` | Resource already exists |
| `u103` | Insufficient funds/stock |
| `u104` | Invalid amount |
| `u105` | Already claimed |
| `u106` | Subsidy expired |
| `u107` | Not eligible |

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 📈 Analytics

Track key metrics:
- 📊 Total subsidies allocated
- 💰 Total subsidies claimed
- 👥 Number of registered farmers
- 📦 Fertilizer inventory levels
- ⏱️ Average claim time

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙋‍♂️ Support

For support and questions:
- Create an issue on GitHub
- Join our community discussions
- Check the documentation

---

🌱
