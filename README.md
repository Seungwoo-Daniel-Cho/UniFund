# UniFund

## Install

```bash
npm install
```

## Compile

```bash
npm run compile
```

## Test

```bash
npm test
```

## Local deployment

Terminal 1:

```bash
npm run node
```

Terminal 2:

```bash
npm run deploy:local
```

## Sepolia deployment

Create `.env`:

```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY=YOUR_PRIVATE_KEY_WITHOUT_0x_OPTIONAL_OK_IF_WALLET_EXPORT_ALREADY_HAS_IT
```

Then:

```bash
npm run deploy:sepolia
```

## Demo flow

1. Deploy `UniFundTreasury`.
2. A donor calls `donate(...)` — funds enter the treasury but no voting rights are granted.
3. A student calls `transferAndJoinMembership()` with exact membership fee.
4. Committee members call `approveMembership(student)` until threshold is met.
5. A committee member calls `proposeSpending(...)` with description, amount, and recipient.
6. During the objection window, regular members and committee members may call `opposeSpending(requestId)`.
7. After the window, anyone can call `executeSpending(requestId)` if the request was not rejected by >50% objections.
8. (?) Committee can keep a reserve via `setReserveBalance(...)` and mark idle funds via `allocateIdleTreasury(...)`.
