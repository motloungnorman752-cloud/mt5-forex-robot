# MT5 Forex Robot

A conservative MetaTrader 5 EMA pullback Expert Advisor. It is an experimental strategy: **it has not been compiled or backtested in MetaTrader from this repository authoring environment**.

## Strategy

- 50 EMA and 200 EMA determine trend direction.
- A completed candle pulls back to the fast EMA.
- The candle then closes back on the trend side.
- Entry occurs only on the new completed-bar boundary.
- ATR determines stop and target distances.
- Default reward-to-risk is 3 ATR / 2 ATR.
- No martingale, averaging, grid, recovery, or pyramid logic.

## Universe

- Default: `EURUSD,GBPUSD,USDJPY` using the names entered in the EA.
- `InpMarketWatchSymbols=true` scans symbols already listed in Market Watch.
- Broker suffixes must match the exact symbols shown in MT5 Market Watch.
- `InpTimeframe=PERIOD_CURRENT` uses the chart timeframe.
- One EA instance processes one timeframe; attach more instances only after validating deployments.

## Risk safeguards

- Real-account trading blocked by default (`InpAllowLiveTrading=false`).
- 0.25% default equity risk per trade; input validation limits this to 1%.
- 1% daily loss lock persisted through terminal restarts.
- 5% equity drawdown lock using a persisted terminal high-water mark.
- Maximum of three EA positions by magic number.
- Maximum spread and 5-lot hard caps.
- `OrderCalcProfit`-based position sizing and broker volume-step normalization.
- Existing positions on a symbol prevent a new EA entry on that symbol.

Risk locks stop new entries. They do not close open positions. Gaps, slippage, rejected orders, disconnections, commission, swap, and correlated exposure can exceed planned risk.

## Installation

1. Copy `src/FBK_MultiTimeframe_EA.mq5` to `MQL5/Experts/` in MT5.
2. Compile it in MetaEditor and resolve every error or warning.
3. Attach it to a chart and enable Algo Trading.
4. Test exact broker symbols and timeframe in Strategy Tester.
5. Forward-test on demo for at least 30–60 calendar days.
6. Never enable `InpAllowLiveTrading=true` until independent validation is complete.

## Repository files

- `src/FBK_MultiTimeframe_EA.mq5`
- `docs/TESTING.md`
- `docs/RISK_CONTROLS.md`

Forex and CFD trading can lose capital rapidly. No automated trading software guarantees profit or capital preservation.
