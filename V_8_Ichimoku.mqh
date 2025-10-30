//+------------------------------------------------------------------+
//|                  EA_Ichimoku_USD.mq4                             |
//|  Estrategia: Cruce Tenkan/Kijun con control en USD               |
//|  Autor:  (modificado según solicitud del usuario)         |
//+------------------------------------------------------------------+
#property strict
#define clrNone 0

//--- parámetros
extern double Lots            = 0.01;     // Tamaño del lote
extern int    MaxTrades       = 5;        // Máximo de operaciones simultáneas
extern int    MagicNumber     = 51029;    // Identificador único del EA

extern double StopLossUSD     = 1.0;      // Stop Loss en USD
extern double TakeProfitUSD   = 3;      // Take Profit en USD
extern bool   UseTrailing     = true;     // Activar trailing dinámico
extern double TrailingStartUSD= 1.0;      // Activar trailing al llegar a +3 USD
extern double TrailingStepUSD = 0.3;      // SL a +1 USD de la ganancia actual

//--- parámetros Ichimoku
extern int TenkanPeriod = 9;
extern int KijunPeriod  = 26;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   lastBarTime = Time[0];
   Print("EA Ichimoku (USD control) inicializado correctamente.");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   // Esperar cierre de vela
   if(Time[0] == lastBarTime) return;
   lastBarTime = Time[0];

   bool buySignal  = TenkanCrossUp(1);
   bool sellSignal = TenkanCrossDown(1);
   int currentTrades = CountOpenTrades();

   if(buySignal && currentTrades < MaxTrades)
      OpenTrade(OP_BUY);

   if(sellSignal && currentTrades < MaxTrades)
      OpenTrade(OP_SELL);

   if(UseTrailing)
      ApplyTrailing();
  }
//+------------------------------------------------------------------+
int CountOpenTrades()
  {
   int cnt=0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
            cnt++;
     }
   return(cnt);
  }
//+------------------------------------------------------------------+
void OpenTrade(int type)
  {
   double price = (type==OP_BUY)?Ask:Bid;
   double sl=0,tp=0;
   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
   int digits = MarketInfo(Symbol(),MODE_DIGITS);

   double slPoints = (StopLossUSD / (tickValue * Lots)) / 10.0;
   double tpPoints = (TakeProfitUSD / (tickValue * Lots)) / 10.0;
   double point = MarketInfo(Symbol(), MODE_POINT);

   if(type == OP_BUY)
     {
      sl = NormalizeDouble(price - slPoints * point * 10, digits);
      tp = NormalizeDouble(price + tpPoints * point * 10, digits);
     }
   else
     {
      sl = NormalizeDouble(price + slPoints * point * 10, digits);
      tp = NormalizeDouble(price - tpPoints * point * 10, digits);
     }

   int ticket = OrderSend(Symbol(), type, Lots, price, 3, sl, tp,
                          "Ichimoku EA USD", MagicNumber, 0, clrNone);

   if(ticket < 0)
      Print("Error al abrir orden: ", GetLastError());
   else
      Print("Orden abierta: ", (type==OP_BUY?"BUY":"SELL"),
            " ticket=", ticket," SL=$",StopLossUSD," TP=$",TakeProfitUSD);
  }
//+------------------------------------------------------------------+
void ApplyTrailing()
  {
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int digits = MarketInfo(Symbol(), MODE_DIGITS);

   for(int i=0;i<OrdersTotal();i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol()) continue;

      double profitUSD = OrderProfit() + OrderSwap() + OrderCommission();

      if(profitUSD >= TrailingStartUSD)
        {
         double newSLPrice;

         if(OrderType() == OP_BUY)
           {
            newSLPrice = Bid - (TrailingStepUSD / (tickValue * Lots));
            if(newSLPrice > OrderStopLoss())
               OrderModify(OrderTicket(), OrderOpenPrice(),
                           NormalizeDouble(newSLPrice, digits),
                           OrderTakeProfit(), 0, clrNone);
           }
         else if(OrderType() == OP_SELL)
           {
            newSLPrice = Ask + (TrailingStepUSD / (tickValue * Lots));
            if(newSLPrice < OrderStopLoss() || OrderStopLoss()==0)
               OrderModify(OrderTicket(), OrderOpenPrice(),
                           NormalizeDouble(newSLPrice, digits),
                           OrderTakeProfit(), 0, clrNone);
           }
        }
     }
  }
//+------------------------------------------------------------------+
bool TenkanCrossUp(int shift)
  {
   double t1 = Tenkan(shift), k1 = Kijun(shift);
   double t2 = Tenkan(shift+1), k2 = Kijun(shift+1);
   return (t1 > k1 && t2 <= k2);
  }
bool TenkanCrossDown(int shift)
  {
   double t1 = Tenkan(shift), k1 = Kijun(shift);
   double t2 = Tenkan(shift+1), k2 = Kijun(shift+1);
   return (t1 < k1 && t2 >= k2);
  }
//+------------------------------------------------------------------+
double Tenkan(int shift)
  {
   double highest = High[iHighest(NULL,0,MODE_HIGH,TenkanPeriod,shift)];
   double lowest  = Low[iLowest(NULL,0,MODE_LOW,TenkanPeriod,shift)];
   return (highest + lowest)/2.0;
  }
double Kijun(int shift)
  {
   double highest = High[iHighest(NULL,0,MODE_HIGH,KijunPeriod,shift)];
   double lowest  = Low[iLowest(NULL,0,MODE_LOW,KijunPeriod,shift)];
   return (highest + lowest)/2.0;
  }
//+------------------------------------------------------------------+
