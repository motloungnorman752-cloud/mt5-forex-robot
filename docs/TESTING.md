# Testing Procedure

This EA has not been compiled or executed in MetaTrader in this repository authoring environment. The following checks are mandatory before use.

## Compile

- Copy the source to `MQL5/Experts/`.
- Open it in MetaEditor and compile.
- Verify no errors and review warnings.
- Confirm input names, compiler build, and exact broker symbol behavior.

## Strategy Tester

Use an exact broker symbol and account type. Configure:

- real ticks where available
- realistic spread and commission
- swap and slippage
- sufficient historical depth
- normal and volatile periods
- out-of-sample and walk-forward testing

Evaluate maximum equity drawdown, profit factor, expectancy, trade count, realized costs, per-symbol results, and order rejections. Do not optimize against only the best historical period.

## Safety validation on demo

Verify:

- real-account mode blocks entries when `InpAllowLiveTrading=false`
- the new-bar check prevents duplicate signals
- existing positions block additional entries on the same symbol
- spread and position-count limits work
- broker suffixes and unavailable symbols fail safely
- stop/target levels meet broker stop-level rules
- minimum volume behavior skips trades that exceed the risk budget
- the daily lock persists after restart and resets on the next broker-server day
- the equity peak persists through terminal restart

## Forward test

Run on demo for at least 30–60 calendar days across the intended symbols and timeframe. Monitor execution rejects, VPS restarts, Global Variables, margin, disconnections, and realized vs. planned risk.

## Live use

Keep real trading disabled unless you independently decide the broker, strategy, execution, and risk settings have passed validation. A live opt-in does not make the strategy profitable or safe. Start with minimum size and continuous monitoring.
