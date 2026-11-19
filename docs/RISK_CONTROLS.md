# Risk Controls

## Defaults

- 0.25% account equity risk per trade
- 1.0% daily-loss kill switch
- 5.0% account drawdown kill switch
- maximum three open EA positions
- no live trading until explicitly enabled

## Important limitations

- `Max open positions` is account-wide for this EA magic number.
- Daily-loss tracking is reset by the EA when the broker server day changes.
- EA state can be reset by restart or VPS interruption.
- Kill switches do not prevent every gap or slippage loss.
- The EA does not guarantee a positive return.
- The EA does not account for all correlated symbols or external manual positions.

## Broker checks

Confirm in MT5:

- allowed volume and volume step
- contract size
- stop-level and freeze-level requirements
- margin model
- market and trading hours
- spread and commission conditions
- whether trading is permitted for the selected symbol and account
