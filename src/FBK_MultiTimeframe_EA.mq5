//+------------------------------------------------------------------+
//|                                         FBK_MultiTimeframe_EA.mq5|
//| Conservative EMA pullback EA with persistent account safeguards  |
//+------------------------------------------------------------------+
#property version   "1.10"
#property strict

#include <Trade/Trade.mqh>

input group "Universe"
input bool            InpMarketWatchSymbols = false; // true: scan symbols in Market Watch
input string          InpSymbols             = "EURUSD,GBPUSD,USDJPY"; // broker symbol names, if not using Market Watch
input ENUM_TIMEFRAMES InpTimeframe           = PERIOD_CURRENT; // chart timeframe by default

input group "Strategy"
input int      InpFastEMA       = 50;
input int      InpSlowEMA       = 200;
input int      InpATRPeriod     = 14;
input double   InpATRStop       = 2.0;
input double   InpATRTakeProfit = 3.0;
input int      InpSlippagePoints = 20;
input ulong    InpMagic         = 260519;

input group "Risk limits"
input double InpRiskPerTradePercent = 0.25;
input double InpDailyLossPercent    = 1.0;
input double InpMaxDrawdownPercent  = 5.0;
input int    InpMaxOpenPositions    = 3;
input int    InpMaxSpreadPoints     = 30; // 0 disables spread filter
input double InpMaxLots             = 5.0; // additional hard volume cap

input group "Live safety"
input bool InpAllowLiveTrading = false; // must be deliberately enabled for real accounts

CTrade trade;
string g_symbols[];
string g_statePrefix;
string g_dayKey;
datetime g_lastBar[];
bool g_riskLocked = false;

int OnInit()
{
   if(InpFastEMA < 2 || InpSlowEMA <= InpFastEMA || InpATRPeriod < 2 ||
      InpATRStop <= 0.0 || InpATRTakeProfit <= 0.0 ||
      InpRiskPerTradePercent <= 0.0 || InpRiskPerTradePercent > 1.0 ||
      InpDailyLossPercent <= 0.0 || InpDailyLossPercent > 20.0 ||
      InpMaxDrawdownPercent <= 0.0 || InpMaxDrawdownPercent > 50.0 ||
      InpMaxOpenPositions < 1 || InpMaxLots <= 0.0)
   {
      Print("Invalid inputs. Risk per trade must be >0 and <=1%; review all limits.");
      return INIT_PARAMETERS_INCORRECT;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetAsyncMode(false);

   g_statePrefix = StringFormat("FBEA_%I64d_%I64u", AccountInfoInteger(ACCOUNT_LOGIN), InpMagic);
   if(!BuildSymbolList()) return INIT_FAILED;
   ArrayResize(g_lastBar, ArraySize(g_symbols));
   ArrayInitialize(g_lastBar, 0);
   RefreshDailyBaseline();
   UpdateEquityPeak();

   Print("EA initialized; timeframe=", EnumToString(EffectiveTimeframe()),
         ", symbols=", ArraySize(g_symbols),
         ", real-account trading=", InpAllowLiveTrading ? "enabled by input" : "blocked");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!TradingEnvironmentAllowed()) return;
   RefreshDailyBaseline();
   UpdateEquityPeak();
   if(CheckRiskLocks()) return;

   for(int i = 0; i < ArraySize(g_symbols); ++i)
   {
      if(CheckRiskLocks()) return;
      ProcessSymbol(i);
   }
}

ENUM_TIMEFRAMES EffectiveTimeframe()
{
   return InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTimeframe;
}

bool BuildSymbolList()
{
   if(InpMarketWatchSymbols)
   {
      int total = SymbolsTotal(true);
      if(total <= 0) { Print("Market Watch has no symbols."); return false; }
      ArrayResize(g_symbols, total);
      for(int i = 0; i < total; ++i) g_symbols[i] = SymbolName(i, true);
      return true;
   }

   string entries[];
   int count = StringSplit(InpSymbols, ',', entries);
   if(count <= 0) { Print("InpSymbols is empty."); return false; }
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
   return ArraySize(g_symbols) > 0;
}

bool TradingEnvironmentAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;

   if(!MQLInfoInteger(MQL_TESTER) &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL && !InpAllowLiveTrading)
   {
      static datetime lastWarning = 0;
      if(TimeCurrent() - lastWarning > 60)
      {
         Print("Real-account trading blocked. Keep disabled until validated; explicit opt-in is required.");
         lastWarning = TimeCurrent();
      }
      return false;
   }
   return true;
}

string ServerDate()
{
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   return StringFormat("%04d%02d%02d", t.year, t.mon, t.day);
}

void RefreshDailyBaseline()
{
   string date = ServerDate();
   string dateVar = g_statePrefix + "_DATE";
   string equityVar = g_statePrefix + "_DAYEQ";
   string lockVar = g_statePrefix + "_DAYLOCK";
   if(!GlobalVariableCheck(dateVar) || (long)GlobalVariableGet(dateVar) != (long)StringToInteger(date))
   {
      GlobalVariableSet(dateVar, (double)StringToInteger(date));
      GlobalVariableSet(equityVar, AccountInfoDouble(ACCOUNT_EQUITY));
      GlobalVariableSet(lockVar, 0.0);
   }
   g_dayKey = date;
}

void UpdateEquityPeak()
{
   string peakVar = g_statePrefix + "_PEAK";
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!GlobalVariableCheck(peakVar)) GlobalVariableSet(peakVar, equity);
   else if(equity > GlobalVariableGet(peakVar)) GlobalVariableSet(peakVar, equity);
}

bool CheckRiskLocks()
{
   string dayLock = g_statePrefix + "_DAYLOCK";
   if(GlobalVariableCheck(dayLock) && GlobalVariableGet(dayLock) > 0.5)
   {
      g_riskLocked = true;
      return true;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayStart = GlobalVariableGet(g_statePrefix + "_DAYEQ");
   if(dayStart > 0.0 && (dayStart - equity) / dayStart * 100.0 >= InpDailyLossPercent)
   {
      GlobalVariableSet(dayLock, 1.0);
      g_riskLocked = true;
      Print("Daily loss limit reached; entries locked until next broker-server day.");
      return true;
   }

   double peak = GlobalVariableGet(g_statePrefix + "_PEAK");
   if(peak > 0.0 && (peak - equity) / peak * 100.0 >= InpMaxDrawdownPercent)
   {
      g_riskLocked = true;
      Print("Maximum equity drawdown reached; new entries are locked. Restarting will not reset the stored peak.");
      return true;
   }

   if(CountMyPositions() >= InpMaxOpenPositions) return true;
   return false;
}

int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == (long)InpMagic) ++count;
   }
   return count;
}

bool AnyPositionOnSymbol(const string symbol)
{
   // Avoid modifying/netting with a manual or other-EA position on the same symbol.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetString(POSITION_SYMBOL) == symbol) return true;
   }
   return false;
}

void ProcessSymbol(const int index)
{
   string symbol = g_symbols[index];
   if(!SymbolSelect(symbol, true)) return;
   if(SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL trade_mode_disabled) return;
}

//+------------------------------------------------------------------+
