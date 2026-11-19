# Testing Procedure

Do not enable live trading until all stages pass.

## 1. Compile

- Open `FBK_MultiTimeframe_EA.mq5` in MetaEditor.
- Confirm compilation produces no errors.

## 2. Strategy testing

Test on several symbols and timeframes using broker-realistic settings:

- current broker symbol names
- real or conservative spread
- commission and swap
- realistic slippage
- sufficient tick or real-tick history
- testing period covering normal and volatile market conditions

Review:

- maximum drawdown
- win rate and payoff ratio
- profit factor
- number of trades
- slippage
- per-symbol results
- results in out-of-sample and walk-forward periods

## 3. Demo forward test

Run for at least 30 to 60 calendar days. Record:

- execution rejects
- failed stop-loss or take-profit requests
- broker disconnections
- symbol availability
- margin behavior
- daily-loss and drawdown triggers

## 4. Live activation

Before enabling `InpAllowLiveTrading=true`:

- verify account, symbol suffixes, and server
- enable only the intended chart or symbols
- start with minimal size
- verify stop-loss placement
- monitor the first sessions continuously
- keep `InpAllowLiveTrading=false` until explicit readiness
