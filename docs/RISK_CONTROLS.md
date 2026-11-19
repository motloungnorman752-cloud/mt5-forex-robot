# Risk Controls

## Defaults

- 0.25% equity risk per trade, with input validation from >0% through 1%
- 1% equity loss lock for the broker-server day
- 5% high-water-mark drawdown lock
- 3-position cap by EA magic number
- 30-point spread cap
- 5-lot hard cap
- live real-account trading blocked by default

## Persistence

- Daily date, baseline, and lock use terminal-local MT5 Global Variables.
- The equity peak is also terminal-local and begins from initialization.
- A lock may not share across a different terminal or VPS.
- No reset occurs when the EA is restarted on the same server day.
- The stored peak is not reconstructable from earlier account history.
- Global Variable permissions or deletions can remove safeguards.

## Position sizing

- Calculated from `ACCOUNT_EQUITY * risk percent`.
- Uses `OrderCalcProfit` for one lot from entry to stop.
- Normalizes volume to the broker's volume step.
- Applies minimum and maximum volume limits and `InpMaxLots`.
- Sends no order if the minimum lot would exceed the risk budget.

## Limitations

- Risk locks prevent new entries but do not close open trades.
- Existing manual or unrelated EA positions on the same symbol prevent entries.
- The EA does not account for portfolio correlation.
- Gaps and slippage can execute a stop at a worse price.
- Disconnection or VPS failure can interrupt protective behavior.
- Commission, swap, margin calls, and partial fills can alter actual risk.
- No setting guarantees profitability or prevents loss.
