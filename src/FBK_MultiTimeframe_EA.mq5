//+------------------------------------------------------------------+
//|                                        FBK_MultiTimeframe_EA.mq5 |
//|               Conservative multi-symbol trend/pullback EA        |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input group "Trading Symbols"
input bool   InpAllChartSymbols = true;       // true: trade each chart symbol where attached
input string InpSymbols         = "EURUSD,GBPUSD,USDJPY";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;

input group "Strategy"
input int    InpFastEMA   = 50;
input int    InpSlowEMA   = 200;
input int    InpATRPeriod = 14;
input double InpATRStop   = 2.0;
input double InpATRTP     = 3.0;
input int    InpSlippage  = 20;
input ulong  InpMagic     = 260519;

input group "Risk"
input double InpRiskPerTradePercent = 0.25;
input double InpDailyLossPercent    = 1.0;
input double InpMaxDrawdownPercent  = 5.0;
input int    InpMaxOpenPositions    = 3;
input double InpMaxSymbolExposurePct = 2.0;

input group "Live Safety"
input bool   InpAllowLiveTrading = false;
input bool   InpRequireNewBar    = true;
input int    InpSpreadLimitPoints = 30;

CTrade trade;
datetime barTime[];
double dayStartEquity = 0.0;
MqlDateTime dayNow;
int priorDay = -1;

int OnInit() {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   TimeToStruct(TimeTradeServer(), dayNow);
   priorDay = dayNow.day;

   Print("EA initialized. Live trading is ", InpAllowLiveTrading ? "ALLOWED" : "BLOCKED");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick() {
   if (!terminalAlive()) return;

   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   if (now.day != priorDay) {
      priorDay = now.day;
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }

   if (riskKillSwitch()) return;

   if (ArraySize(barTime) < 1) ArrayResize(barTime, 1);

   string symbols[];
   buildSymbolList(symbols);

   for (int i = 0; i < ArraySize(symbols); i++) {
      if (riskKillSwitch()) break;
      processSymbol(symbols[i]);
   }

   manageOpenPositions();
}

bool terminalAlive() {
   if (!TerminalInfoInteger(TERMINAL_CONNECTED)) return false;
   if (!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;

   if ((bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == false) return false;
   if ((bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == false) return false;

   if (MQLInfoInteger(MQL_TESTER)) return true;

   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if (mode == ACCOUNT_TRADE_MODE_REAL && !InpAllowLiveTrading) {
      static datetime lastWarning = 0;
      if (TimeCurrent() - lastWarning > 60) {
         Print("LIVE TRADING BLOCKED: set InpAllowLiveTrading=true only after testing.");
         lastWarning = TimeCurrent();
      }
      return false;
   }
   return true;
}

void buildSymbolList(string &symbols[]) {
   if (InpAllChartSymbols) {
      ArrayResize(symbols, 1);
      symbols[0] = _Symbol;
      return;
   }

   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   ArrayResize(symbols, count);
   for (int i = 0; i < count; i++) {
      symbols[i] = Trim(parts[i]);
   }
}

string Trim(string text) {
   StringTrimLeft(text);
   StringTrimRight(text);
   return text;
}

bool riskKillSwitch() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if (dayStartEquity > 0) {
      double dailyLoss = (dayStartEquity - equity) / dayStartEquity * 100.0;
      if (dailyLoss >= InpDailyLossPercent) {
         PrintFormat("Kill switch: daily loss %.2f%% reached", dailyLoss);
         return true;
      }
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double peak = MathMax(balance, equity);
   if (peak > 0) {
      double drawdown = (peak - equity) / peak * 100.0;
      if (drawdown >= InpMaxDrawdownPercent) {
         PrintFormat("Kill switch: drawdown %.2f%% reached", drawdown);
         return true;
      }
   }

   if (countMyPositions() >= InpMaxOpenPositions) return true;
   return false;
}

int countMyPositions() {
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      count++;
   }
   return count;
}

void processSymbol(const string symbol) {
   if (symbol == "") return;
   if (!SymbolSelect(symbol, true)) return;

   ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if (tradeMode == SYMBOL_TRADE_MODE_DISABLED) return;

   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if (InpSpreadLimitPoints > 0 && spread > InpSpreadLimitPoints) return;

   if (hasPosition(symbol)) return;

   datetime currentBar = iTime(symbol, InpTimeframe, 0);
   if (InpRequireNewBar) {
      static string lastSymbol[];
      static datetime lastBar[];
      int n = ArraySize(lastSymbol);
      int k = -1;
      for (int i = 0; i < n; i++) if (lastSymbol[i] == symbol) k = i;
      if (k < 0) {
         k = n;
         ArrayResize(lastSymbol, k + 1);
         ArrayResize(lastBar, k + 1);
         lastSymbol[k] = symbol;
         lastBar[k] = 0;
      }
      if (lastBar[k] == currentBar) return;
      lastBar[k] = currentBar;
   }

   double fast[], slow[], atr[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(atr, true);

   int hFast = iMA(symbol, InpTimeframe, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   int hSlow = iMA(symbol, InpTimeframe, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   int hATR  = iATR(symbol, InpTimeframe, InpATRPeriod);
   if (hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hATR == INVALID_HANDLE) return;

   if (CopyBuffer(hFast, 0, 0, 3, fast) != 3) return;
   if (CopyBuffer(hSlow, 0, 0, 3, slow) != 3) return;
   if (CopyBuffer(hATR, 0, 0, 3, atr) != 3) return;

   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);
   IndicatorRelease(hATR);

   double close1 = iClose(symbol, InpTimeframe, 1);
   double atrValue = atr[1];
   if (close1 <= 0 || atrValue <= 0) return;

   bool bullish = fast[1] > slow[1] && fast[2] <= slow[2];
   bool bearish = fast[1] < slow[1] && fast[2] >= slow[2];

   if (!bullish && !bearish) return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if (bullish) {
      double sl = NormalizeDouble(ask - atrValue * InpATRStop, digits);
      double tp = NormalizeDouble(ask + atrValue * InpATRTP, digits);
      double lots = calculateLots(symbol, ask - sl);
      if (lots > 0) trade.Buy(lots, symbol, ask, sl, tp, "Trend pullback buy");
   } else {
      double sl = NormalizeDouble(bid + atrValue * InpATRStop, digits);
      double tp = NormalizeDouble(bid - atrValue * InpATRTP, digits);
      double lots = calculateLots(symbol, sl - bid);
      if (lots > 0) trade.Sell(lots, symbol, bid, sl, tp, "Trend pullback sell");
   }
}

bool hasPosition(const string symbol) {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) == (long)InpMagic) return true;
   }
   return false;
}

double calculateLots(const string symbol, double stopDistance) {
   if (stopDistance <= 0) return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPerTradePercent / 100.0;

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   if (tickValue <= 0 || tickSize <= 0 || volumeStep <= 0) return 0.0;

   double lot = riskMoney / (stopDistance / tickSize * tickValue);
   lot = MathFloor(lot / volumeStep) * volumeStep;

   lot = MathMax(volMin, MathMin(volMax, lot));

   double positionNotionalPct = lot * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE)
                              / equity * 100.0;
   if (positionNotionalPct > InpMaxSymbolExposurePct) {
      lot = 0.0;
   }
   return NormalizeDouble(lot, 2);
}

void manageOpenPositions() {
   // Reserved for future broker-specific trailing and exit rules.
}
//+------------------------------------------------------------------+
