# ☕ Coffee Break - Subscription Smart Contract

A decentralized subscription service built on the Stacks blockchain using Clarity smart contracts. This contract enables creators to offer tiered content access with recurring payments, perfect for "buy me a coffee" style subscription models.

## 🚀 Features

- **Three Subscription Tiers**: Basic, Premium, and VIP with different pricing
- **Recurring Payments**: Automatic and manual renewal options
- **Flexible Management**: Subscribe, upgrade, cancel, and renew subscriptions
- **Revenue Management**: Contract owner can withdraw collected funds
- **Access Control**: Easy integration for gating content based on subscription status
- **Transparent Tracking**: View subscription details, balances, and subscriber counts

## 📋 Contract Overview

### Subscription Tiers

| Tier | Price | Duration |
|------|-------|----------|
| Basic | 5 STX | ~30 days |
| Premium | 10 STX | ~30 days |
| VIP | 20 STX | ~30 days |

*Duration is measured in blocks (approximately 4,320 blocks = 30 days)*

## 🔧 Installation & Deployment

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing
- Basic understanding of Clarity smart contracts

### Deploy Contract

1. Clone or copy the contract file as `coffee-break.clar`
2. Initialize Clarinet project:
```bash
clarinet new coffee-break-project
cd coffee-break-project
```

3. Add the contract to your `Clarinet.toml`:
```toml
[contracts.coffee-break]
path = "contracts/coffee-break.clar"
```

4. Test the contract:
```bash
clarinet test
```

5. Deploy to testnet/mainnet:
```bash
clarinet deploy --testnet
```

## 📚 API Reference

### Public Functions

#### `subscribe(tier, enable-auto-renewal)`
Create a new subscription.
- **tier**: `"basic"`, `"premium"`, or `"vip"`
- **enable-auto-renewal**: `true` or `false`
- **Returns**: `(ok true)` on success

```clarity
(contract-call? .coffee-break subscribe "premium" true)
```

#### `renew-subscription()`
Manually renew an existing subscription.
- **Returns**: `(ok true)` on success

```clarity
(contract-call? .coffee-break renew-subscription)
```

#### `cancel-subscription()`
Disable auto-renewal for current subscription.
- **Returns**: `(ok true)` on success

```clarity
(contract-call? .coffee-break cancel-subscription)
```

#### `upgrade-subscription(new-tier)`
Upgrade to a higher tier (pays difference in price).
- **new-tier**: Higher tier than current subscription
- **Returns**: `(ok true)` on success

```clarity
(contract-call? .coffee-break upgrade-subscription "vip")
```

#### `process-auto-renewal(subscriber)`
Process automatic renewal for a subscriber (callable by anyone when subscription expires).
- **subscriber**: Principal address of the subscriber
- **Returns**: `(ok true)` on success

```clarity
(contract-call? .coffee-break process-auto-renewal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Read-Only Functions

#### `is-subscription-active(subscriber)`
Check if a user has an active subscription.
- **subscriber**: Principal address to check
- **Returns**: `true` if active, `false` if expired/not found

```clarity
(contract-call? .coffee-break is-subscription-active 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### `get-subscription-info(subscriber)`
Get detailed subscription information.
- **subscriber**: Principal address to query
- **Returns**: Object with tier, active status, blocks remaining, auto-renewal status, and total paid

```clarity
(contract-call? .coffee-break get-subscription-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### `get-contract-balance()`
View total STX balance held by the contract.

```clarity
(contract-call? .coffee-break get-contract-balance)
```

#### `get-total-subscribers()`
Get the total number of subscribers.

```clarity
(contract-call? .coffee-break get-total-subscribers)
```

### Owner Functions

#### `withdraw-funds(amount, recipient)`
Withdraw collected subscription fees (owner only).
- **amount**: Amount in microSTX to withdraw
- **recipient**: Principal to receive the funds

```clarity
(contract-call? .coffee-break withdraw-funds u5000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### `update-tier-price(tier, new-price)`
Update pricing for a subscription tier (owner only).
- **tier**: Tier to update (`"basic"`, `"premium"`, or `"vip"`)
- **new-price**: New price in microSTX

```clarity
(contract-call? .coffee-break update-tier-price "basic" u7000000)
```

## 🔒 Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR_NOT_AUTHORIZED` | Caller not authorized for this action |
| 101 | `ERR_INSUFFICIENT_BALANCE` | Insufficient contract balance |
| 102 | `ERR_SUBSCRIPTION_NOT_FOUND` | No subscription found for user |
| 103 | `ERR_SUBSCRIPTION_EXPIRED` | Subscription has expired |
| 104 | `ERR_INVALID_AMOUNT` | Invalid tier or amount specified |
| 105 | `ERR_ALREADY_SUBSCRIBED` | User already has active subscription |

## 🛠️ Integration Examples

### Frontend Integration (JavaScript)

```javascript
import { openContractCall } from '@stacks/connect';
import { stringAsciiCV, boolCV } from '@stacks/transactions';

// Subscribe to premium tier
const subscribeToService = async () => {
  await openContractCall({
    contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    contractName: 'coffee-break',
    functionName: 'subscribe',
    functionArgs: [
      stringAsciiCV('premium'),
      boolCV(true)
    ],
  });
};

// Check subscription status
const checkAccess = async (userAddress) => {
  const response = await fetch(`/api/stacks/read-only/${contractAddress}/coffee-break/is-subscription-active?subscriber=${userAddress}`);
  const hasAccess = await response.json();
  return hasAccess;
};
```

### Content Gating Example

```javascript
// Middleware for protecting premium content
const requireSubscription = async (req, res, next) => {
  const userAddress = req.user.stacksAddress;
  const hasActiveSubscription = await checkSubscriptionStatus(userAddress);
  
  if (!hasActiveSubscription) {
    return res.status(403).json({ 
      error: 'Active subscription required',
      subscribeUrl: '/subscribe' 
    });
  }
  
  next();
};

app.get('/premium-content', requireSubscription, (req, res) => {
  res.json({ content: 'This is premium content!' });
});
```

## 🔄 Auto-Renewal Implementation

The contract supports auto-renewal but requires an external service to trigger it. Here's a simple implementation:

```javascript
// Auto-renewal service (run as cron job)
const processAutoRenewals = async () => {
  const expiredSubscriptions = await getExpiredSubscriptionsWithAutoRenewal();
  
  for (const subscription of expiredSubscriptions) {
    try {
      await contractCall('process-auto-renewal', [subscription.subscriber]);
      console.log(`Renewed subscription for ${subscription.subscriber}`);
    } catch (error) {
      console.error(`Failed to renew ${subscription.subscriber}:`, error);
    }
  }
};

// Run every hour
setInterval(processAutoRenewals, 60 * 60 * 1000);
```

## 🧪 Testing

### Unit Tests (Clarinet)

```clarity
;; Test basic subscription
(define-test-suite subscription-tests
  (test "can-subscribe-to-basic-tier"
    (let ((result (contract-call? .coffee-break subscribe "basic" true)))
      (expect-ok result)))
      
  (test "subscription-is-active-after-subscribe"
    (begin
      (contract-call? .coffee-break subscribe "premium" true)
      (expect-true (contract-call? .coffee-break is-subscription-active tx-sender))))
      
  (test "can-upgrade-subscription"
    (begin
      (contract-call? .coffee-break subscribe "basic" true)
      (expect-ok (contract-call? .coffee-break upgrade-subscription "premium")))))
```

### Manual Testing

1. Deploy to testnet
2. Subscribe to a tier
3. Check subscription status
4. Test renewal and cancellation
5. Test owner functions

## 🚀 Use Cases

- **Content Creators**: Blog subscriptions, premium articles, exclusive content
- **Online Courses**: Tiered access to educational materials
- **Software Services**: SaaS subscription management
- **Community Access**: Premium Discord/forum access
- **Digital Products**: Recurring access to tools and resources

**Happy coding! ☕️**