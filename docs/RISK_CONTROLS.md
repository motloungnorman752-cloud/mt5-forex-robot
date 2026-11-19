# Risk Controls

## Defaults

- 0.25% equity risk per trade; input is rejected above 1%.
- 1% daily equity-loss lock, persisted until the next broker-server day.
- 5% maximum equity drawdown lock based on a persisted high-water mark.
- At most three open EA positions by magic number.
- 30-point maximum spread and 5-lot hard cap.
- Real account trading blocked unless the explicit `InpAllowLiveTrading` input is enabled.

## Behavior and limitations

- Risk locks stop new entries but do not close existing positions.
- Daily baseline, daily lock, and equity peak use MT5 terminal Global Variables. Do not delete those variables if you need persistence. They are terminal-local, not broker-side, and a different terminal/VPS will not automatically share them.
- The high-water mark begins at the EA's first initialization; it cannot reconstruct prior equity peaks.
- A daily lock resets on the next broker-server calendar day.
- Position sizing uses `OrderCalcProfit` for one lot between entry and stop. If the broker's minimum volume would exceed the risk budget, the EA skips the trade.
- Existing positions on the same symbol block entries to avoid interference with netting accounts or manual trades.
- The EA does not model portfolio correlation; three individually sized positions may share risk factors.
- Spread, gaps, slippage, commissions, swap, rejected orders, disconnections, and broker rules can cause actual losses to differ from planned risk.
- A stop-loss is not a guarantee of execution at its requested price.

## Before use

Verify symbol specifications, suffixes, trading hours, volume steps, stop levels, spread, commissions, swaps, margin, account mode, and the broker's current EA rules. Test on the exact account type and server. No setting guarantees profit or prevents loss.
