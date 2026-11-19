# MT5 Forex Robot

A conservative MetaTrader 5 Expert Advisor for MT5 with ATR-based trend/pullback entries and strict account-level risk controls.

## Strategy

- Enters only after a fast EMA crosses a slow EMA
- Uses ATR for stop-loss and take-profit
- Uses percentage-based position sizing
- No martingale, averaging down, grid, or recovery logic

## Safety

- Live trading is blocked by default
- Optional maximum open positions
- Optional daily loss kill switch
- Optional account drawdown kill switch
- Maximum spread filter
- Existing positions are prevented on the same symbol

## Repository files

- `src/FBK_MultiTimeframe_EA.mq5` — MQL5 Expert Advisor
- `docs/TESTING.md` — testing procedure
- `docs/RISK_CONTROLS.md` — controls and limitations

## Installation

1. Open MetaTrader 5.
2. Open the MetaEditor.
3. Copy the `.mq5` file into `MQL5/Experts/`.
4. Compile it.
5. Drag it onto a chart.
6. Enable `Algo Trading`.

## Recommended initial configuration

- `InpAllowLiveTrading=false`
- `InpRiskPerTradePercent=0.25`
- `InpDailyLossPercent=1.0`
- `InpMaxDrawdownPercent=5.0`
- `InpMaxOpenPositions=3`
- `InpSpreadLimitPoints=30`

## Important

This EA does not guarantee profits. Forex trading can lose capital. Use an appropriate demo account and verify the EA in the MT5 Strategy Tester before considering live use.
