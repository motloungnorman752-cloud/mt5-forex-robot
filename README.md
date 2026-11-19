# MT5 Forex Robot

An experimental MetaTrader 5 Expert Advisor implementing a simple EMA-trend pullback entry with ATR-based exits and conservative, persistent risk limits. It is not a profit guarantee and has **not** been compiled or validated in MetaTrader here.

## Strategy

- Trend: 50 EMA above/below 200 EMA.
- Entry: a completed candle pulls back to the fast EMA, followed by a completed candle closing back on the trend side.
- Stop and target: ATR multiples (defaults 2x and 3x).
- One position per symbol; no martingale, grid, averaging down, or recovery logic.
- Signals use completed bars; the EA evaluates once per new bar for each configured symbol.

## Universe and timeframe

- Default scans the explicitly entered broker symbol names on the chart timeframe (`PERIOD_CURRENT`). Change names for broker suffixes (for example, `.m`) as shown in Market Watch.
- `InpMarketWatchSymbols=true` scans symbols currently visible in Market Watch; it does not mean every instrument the broker offers.
- To use a different timeframe, set `InpTimeframe`. A single EA instance uses one timeframe.
- Multiple instances can duplicate signals. The shared magic number and one-position-per-symbol check reduce duplicates, but configure and validate deployments carefully.

## Safety settings

- Real-account entries are blocked unless `InpAllowLiveTrading=true`.
- Default per-trade risk: 0.25% equity; accepted input is capped at 1%.
- Daily loss lock: 1%, persisted across terminal restarts until the next broker-server day.
- Equity high-water mark persists in MT5 Global Variables; max drawdown default is 5% and blocks new entries.
- Maximum three EA positions, 30-point spread filter, and 5-lot hard cap by default.
- Position size is calculated from broker profit calculation at the proposed stop. If minimum lot size exceeds the risk budget, no order is sent.
- Existing positions on a symbol (including manual positions) prevent a new EA order on that symbol.

Risk locks prevent new entries; they do not automatically close open positions. Emergency stop/close procedures remain the trader's responsibility. Gaps, slippage, execution failures, and correlated exposure can exceed planned risk.

## Install

1. In MT5 choose **File → Open Data Folder**.
2. Copy `src/FBK_MultiTimeframe_EA.mq5` to `MQL5/Experts/`.
3. Open it in MetaEditor and compile. Resolve any broker/build-specific issues before testing.
4. Run Strategy Tester with realistic spread, commission, swaps, and tick data.
5. Forward-test on demo before considering live use. Keep `InpAllowLiveTrading=false` until independent validation is complete.

The repository authoring environment cannot run MetaEditor, so compilation and backtest results are not claimed. Forex/CFD trading can lose money; this software is educational and experimental.
