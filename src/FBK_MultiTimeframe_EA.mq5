//+------------------------------------------------------------------+
//|                                         FBK_MultiTimeframe_EA.mq5|
//|   Conservative EMA pullback EA - demo/test first, no guarantees  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.20"
#property strict

#include <Trade/Trade.mqh>

input group "Universe"
input bool            InpMarketWatchSymbols = false;
input string          InpSymbols           = "EURUSD,GBPUSD,USDJPY";
input ENUM_TIMEFRAMES InpTimeframe         = PERIOD_CURRENT;

input group "Strategy"
input int    InpFastEMA          = 50;
input int    InpSlowEMA          = 200;
input int    InpATRPeriod        = 14;
input double InpATRStop          = 2.0;
input double InpATRTakeProfit    = 3.0;
input int    InpSlippagePoints   = 20;
input ulong  InpMagic            = 260519;

input group "Risk limits"
input double InpRiskPerTradePercent = 0.25;
input double InpDailyLossPercent    = 1.0;
input double InpMaxDrawdownPercent  = 5.0;
input int    InpMaxOpenPositions    = 3;
input int    InpMaxSpreadPoints     = 30;
input double InpMaxLots             = 5.0;

input group "Live safety"
input bool InpAllowLiveTrading = false;

CTrade trade;
string g_symbols[];
datetime g_lastBar[];
string g_statePrefix;

int OnInit()
{
   if(InpFastEMA < 2 || InpSlowEMA <= InpFastEMA || InpATRPeriod < 2 ||
      InpATRStop <= 0.0 || InpATRTakeProfit <= 0.0 ||
      InpRiskPerTradePercent <= 0.0 || InpRiskPerTradePercent > 1.0 ||
      InpDailyLossPercent <= 0.0 || InpDailyLossPercent > 20.0 ||
      InpMaxDrawdownPercent <= 0.0 || InpMaxDrawdownPercent > 50.0 ||
      InpMaxOpenPositions < 1 || InpMaxLots <= 0.0)
   {
      Print("Invalid EA input. Review strategy and risk values.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetAsyncMode(false);

   g_statePrefix = StringFormat("FBEA_%I64d_%I64u", AccountInfoInteger(ACCOUNT_LOGIN), InpMagic);
   if(!BuildSymbolList()) return(INIT_FAILED);

   ArrayResize(g_lastBar, ArraySize(g_symbols));
   for(int i = 0; i < ArraySize(g_lastBar); ++i) g_lastBar[i] = 0;

   RefreshPersistedState();
   Print("EA initialized: ", ArraySize(g_symbols), " symbol(s), timeframe ",
         EnumToString(EffectiveTimeframe()),
         ", real trading ", InpAllowLiveTrading ? "explicitly enabled" : "blocked");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   if(!TradingEnvironmentAllowed()) return;

   RefreshPersistedState();
   if(CheckRiskLocks()) return;

   for(int i = 0; i < ArraySize(g_symbols); ++i)
   {
      if(CheckRiskLocks()) return;
      ProcessSymbol(i);
   }
}

ENUM_TIMEFRAMES EffectiveTimeframe()
{
   if(InpTimeframe == PERIOD_CURRENT)
      return((ENUM_TIMEFRAMES)_Period);
   return(InpTimeframe);
}

bool BuildSymbolList()
{
   if(InpMarketWatchSymbols)
   {
      int total = SymbolsTotal(true);
      if(total <= 0)
      {
         Print("No symbols are present in Market Watch.");
         return(false);
      }

      ArrayResize(g_symbols, total);
      for(int i = 0; i < total; ++i)
         g_symbols[i] = SymbolName(i, true);
      return(true);
   }

   string entries[];
   int count = StringSplit(InpSymbols, ',', entries);
   ArrayResize(g_symbols, 0);

   for(int i = 0; i < count; ++i)
   {
      StringTrimLeft(entries[i]);
      StringTrimRight(entries[i]);
      if(entries[i] == "") continue;

      int n = ArraySize(g_symbols);
      ArrayResize(g_symbols, n + 1);
      g_symbols[n] = entries[i];
   }

   if(ArraySize(g_symbols) == 0)
   {
      Print("InpSymbols contains no usable symbol names.");
      return(false);
   }
   return(true);
}

bool TradingEnvironmentAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return(false);
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return(false);
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return(false);
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return(false);

   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL && !InpAllowLiveTrading)
      {
         static datetime lastWarning = 0;
         if(TimeCurrent() - lastWarning > 60)
         {
            Print("Real-account trading is blocked; InpAllowLiveTrading=false.");
            lastWarning = TimeCurrent();
         }
         return(false);
      }
   }
   return(true);
}

string ServerDateString()
{
   MqlDateTime tm;
   TimeToStruct(TimeTradeServer(), tm);
   return(StringFormat("%04d%02d%02d", tm.year, tm.mon, tm.day));
}

void RefreshPersistedState()
{
   string dateVar  = g_statePrefix + "_DATE";
   string dayVar   = g_statePrefix + "_DAY_EQ";
   string lockVar  = g_statePrefix + "_DAY_LOCK";
   string peakVar  = g_statePrefix + "_EQ_PEAK";
   string today    = ServerDateString();

   double todayNumber = (double)StringToInteger(today);
   if(!GlobalVariableCheck(dateVar) || GlobalVariableGet(dateVar) != todayNumber)
   {
      GlobalVariableSet(dateVar, todayNumber);
      GlobalVariableSet(dayVar, AccountInfoDouble(ACCOUNT_EQUITY));
      GlobalVariableSet(lockVar, 0.0);
   }

   if(!GlobalVariableCheck(peakVar))
      GlobalVariableSet(peakVar, AccountInfoDouble(ACCOUNT_EQUITY));

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > GlobalVariableGet(peakVar))
      GlobalVariableSet(peakVar, equity);
}

bool CheckRiskLocks()
{
   string lockVar = g_statePrefix + "_DAY_LOCK";
   if(GlobalVariableCheck(lockVar) && GlobalVariableGet(lockVar) > 0.5)
      return(true);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string dayVar = g_statePrefix + "_DAY_EQ";
   if(GlobalVariableCheck(dayVar))
   {
      double dayEquity = GlobalVariableGet(dayVar);
      if(dayEquity > 0.0)
      {
         double lossPct = (dayEquity - equity) / dayEquity * 100.0;
         if(lossPct >= InpDailyLossPercent)
         {
            GlobalVariableSet(lockVar, 1.0);
            PrintFormat("Daily loss limit reached: %.2f%%. New entries locked until next server day.", lossPct);
            return(true);
         }
      }
   }

   string peakVar = g_statePrefix + "_EQ_PEAK";
   if(GlobalVariableCheck(peakVar))
   {
      double peak = GlobalVariableGet(peakVar);
      if(peak > 0.0)
      {
         double drawdownPct = (peak - equity) / peak * 100.0;
         if(drawdownPct >= InpMaxDrawdownPercent)
         {
            PrintFormat("Equity drawdown limit reached: %.2f%%. New entries locked.", drawdownPct);
            return(true);
         }
      }
   }

   if(CountMyPositions() >= InpMaxOpenPositions)
      return(true);

   return(false);
}

int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         ++count;
   }
   return(count);
}

bool SymbolHasAnyPosition(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetString(POSITION_SYMBOL) == symbol)
         return(true);
   }
   return(false);
}

bool SymbolTradingAllowed(const string symbol)
{
   if(!SymbolSelect(symbol, true)) return(false);

   ENUM_SYMBOL_TRADE_MODE mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return(false);

   if(InpMaxSpreadPoints > 0)
   {
      long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpreadPoints) return(false);
   }
   return(true);
}

void ProcessSymbol(const int index)
{
   string symbol = g_symbols[index];
   if(!SymbolTradingAllowed(symbol)) return;
   if(SymbolHasAnyPosition(symbol)) return;

   ENUM_TIMEFRAMES tf = EffectiveTimeframe();
   datetime currentBar = iTime(symbol, tf, 0);
   if(currentBar == 0) return;

   if(currentBar == g_lastBar[index]) return;
   g_lastBar[index] = currentBar;

   int fastHandle = iMA(symbol, tf, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   int slowHandle = iMA(symbol, tf, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   int atrHandle  = iATR(symbol, tf, InpATRPeriod);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
      if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
      if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
      return;
   }

   double fast[];
   double slow[];
   double atr[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(atr, true);

   bool copied = CopyBuffer(fastHandle, 0, 0, 3, fast) == 3;
   copied = copied && CopyBuffer(slowHandle, 0, 0, 3, slow) == 3;
   copied = copied && CopyBuffer(atrHandle, 0, 0, 3, atr) == 3;

   IndicatorRelease(fastHandle);
   IndicatorRelease(slowHandle);
   IndicatorRelease(atrHandle);
   if(!copied) return;

   double atrValue = atr[1];
   if(atrValue <= 0.0) return;

   double close1 = iClose(symbol, tf, 1);
   double high1  = iHigh(symbol, tf, 1);
   double low1   = iLow(symbol, tf, 1);
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0) return;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   bool longPullback = fast[1] > slow[1] && low1 <= fast[1] && close1 >= fast[1];
   bool shortPullback = fast[1] < slow[1] && high1 >= fast[1] && close1 <= fast[1];

   trade.SetTypeFillingBySymbol(symbol);

   if(longPullback)
   {
      double sl = NormalizeDouble(ask - atrValue * InpATRStop, digits);
      double tp = NormalizeDouble(ask + atrValue * InpATRTakeProfit, digits);
      sl = AdjustLongStop(symbol, ask, sl);
      tp = AdjustLongTarget(symbol, ask, tp);

      if(!ValidStops(symbol, ORDER_TYPE_BUY, ask, sl, tp)) return;
      double volume = CalculateVolume(symbol, ORDER_TYPE_BUY, ask, sl);
      if(volume > 0.0)
         trade.Buy(volume, symbol, ask, sl, tp, "FBK EMA pullback buy");
   }

   if(shortPullback)
   {
      double sl = NormalizeDouble(bid + atrValue * InpATRStop, digits);
      double tp = NormalizeDouble(bid - atrValue * InpATRTakeProfit, digits);
      sl = AdjustShortStop(symbol, bid, sl);
      tp = AdjustShortTarget(symbol, bid, tp);

      if(!ValidStops(symbol, ORDER_TYPE_SELL, bid, sl, tp)) return;
      double volume = CalculateVolume(symbol, ORDER_TYPE_SELL, bid, sl);
      if(volume > 0.0)
         trade.Sell(volume, symbol, bid, sl, tp, "FBK EMA pullback sell");
   }
}

bool ValidStops(const string symbol, ENUM_ORDER_TYPE type, double entry,
                double stop, double target)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long freeze = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   long stops  = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);

   double extra = (double)MathMax(freeze, stops) * point;
   if(extra < point) extra = point;

   if(type == ORDER_TYPE_BUY)
   {
      if(stop >= entry || target <= entry) return(false);
      if(entry - stop < extra || target - entry < extra) return(false);
   }
   else
   {
      if(stop <= entry || target >= entry) return(false);
      if(stop - entry < extra || entry - target < extra) return(false);
   }
   return(true);
}

double AdjustLongStop(const string symbol, double entry, double stop)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minimum = entry - (double)level * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(stop > minimum) stop = minimum;
   return(NormalizeDouble(stop, digits));
}

double AdjustLongTarget(const string symbol, double entry, double target)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minimum = entry + (double)level * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(target < minimum) target = minimum;
   return(NormalizeDouble(target, digits));
}

double AdjustShortStop(const string symbol, double entry, double stop)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double maximum = entry + (double)level * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(stop < maximum) stop = maximum;
   return(NormalizeDouble(stop, digits));
}

double AdjustShortTarget(const string symbol, double entry, double target)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double maximum = entry - (double)level * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(target > maximum) target = maximum;
   return(NormalizeDouble(target, digits));
}

double CalculateVolume(const string symbol, ENUM_ORDER_TYPE type,
                       double entry, double stop)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return(0.0);

   double riskMoney = equity * InpRiskPerTradePercent / 100.0;
   double lossPerLot = 0.0;
   if(!OrderCalcProfit(type, symbol, 1.0, entry, stop, lossPerLot))
   {
      Print("OrderCalcProfit failed for ", symbol, ", error=", GetLastError());
      return(0.0);
   }

   lossPerLot = MathAbs(lossPerLot);
   if(lossPerLot <= 0.0) return(0.0);

   double volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double volumeMin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double volumeMax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(volumeStep <= 0.0 || volumeMin <= 0.0 || volumeMax <= 0.0)
      return(0.0);

   double lot = riskMoney / lossPerLot;
   lot = MathFloor((lot + 1e-9) / volumeStep) * volumeStep;
   lot = MathMin(lot, InpMaxLots);
   lot = MathMin(lot, volumeMax);

   if(lot < volumeMin) return(0.0);
   return(NormalizeDouble(lot, 8));
}
//+------------------------------------------------------------------+
