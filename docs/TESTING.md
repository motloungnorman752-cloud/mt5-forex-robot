# Testing Procedure

The EA has not been compiled or tested in MetaTrader in this repository authoring environment. Complete these steps locally before use.

## 1. Compile

- Copy `src/FBK_MultiTimeframe_EA.mq5` into MT5 `MQL5/Experts/`.
- Open it in MetaEditor and compile.
- Resolve compiler warnings/errors and verify the actual input names/defaults.

## 2. Strategy Tester

Use the intended FBK/RocketX server and test broker-realistic conditions:

- exact broker symbol names and account type
- real ticks where available
- spread, commission, swap, and slippage assumptions
- multiple market regimes, including volatile periods
- at least one out-of-sample period and walk-forward test

Review maximum equity drawdown, number of trades, expectancy, profit factor, costs, order rejections, and per-symbol/timeframe outcomes. Avoid optimizing parameters against the entire test period.

## 3. Validate safeguards

On demo/tester, verify:

- no entries while real-account opt-in is false
- daily loss lock persists after EA/terminal restart and resets only on the next server day
- equity drawdown lock uses the persisted peak
- no order if min volume exceeds calculated risk
- spread and position-count limits
- symbols with suffixes and unavailable symbols fail safely
- no duplicate or conflicting orders on symbols with existing positions

## 4. Demo forward test

Run for at least 30–60 calendar days, across intended symbols and timeframes. Monitor logs and compare planned risk with realized results. Test disconnections/restarts and inspect Global Variables.

## 5. Live use

No live use is recommended until compile, backtest, and demo checks pass and you understand the risk. The default blocks real-account trading. Enabling `InpAllowLiveTrading=true` is a deliberate user action and does not mean the EA is verified or safe for deployment. Start with minimum size and monitor continuously if you independently decide to proceed.
