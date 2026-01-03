# IranVault Risk Engine

Real-time risk management service that validates orders, manages fund locking, and handles liquidations.

## Features

- **Real-time Order Validation**: Checks balance, exposure, leverage, and order size limits
- **Fund Locking**: Reserves funds before order execution
- **Liquidation Engine**: Automatic position liquidation based on margin ratios
- **Config-Driven Rules**: Risk parameters loaded from YAML configuration
- **Circuit Breaker**: Emergency stop mechanism for high rejection rates
- **Kill Switch**: Administrative emergency stop
- **Event-Driven**: Subscribes to NATS events, emits approval/rejection events

## Architecture

The Risk Engine sits between Order Service and Matching Engine:

```
Order Service → orders.created → Risk Engine → orders.approved/rejected → Matching Engine
Wallet Service ← funds.lock/unlock ← Risk Engine
```

## Risk Rules Configuration

Risk parameters are defined in `risk-rules.yaml`:

```yaml
maxOrderSize:
  BTC-USDT: 1
  BNB-PERP: 10

maxExposure:
  BTC-USDT: 5
  BNB-PERP: 50

maxLeverage: 3

maintenanceMargin: 0.005  # 0.5%
liquidationMargin: 0.003  # 0.3%

killSwitch: false

circuitBreaker:
  maxRejectionsPerMinute: 100
  timeoutSeconds: 300
```

## Event Contracts

### Input Events
- `orders.created`: New order validation request
- `wallet.updated`: Balance updates for caching
- `prices.updated`: Price updates for liquidation checks

### Output Events
- `orders.approved`: Order passed risk checks
- `orders.rejected`: Order failed risk checks
- `funds.lock`: Request to lock funds
- `funds.unlock`: Request to unlock funds
- `positions.liquidate`: Liquidation trigger

## API Endpoints

- `GET /health` - Health check with kill switch status
- `GET /rules` - Current risk rules
- `POST /kill-switch/:state` - Enable/disable kill switch

## Development

```bash
npm install
npm run dev
```

## Production

```bash
npm run build
npm start
```

## Safety Features

- **Idempotent Events**: Safe event replay
- **Circuit Breaker**: Automatic kill switch on high rejection rates
- **Kill Switch**: Manual emergency stop
- **Stateless Design**: Horizontal scaling support