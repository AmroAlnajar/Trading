//+------------------------------------------------------------------+
//|                                                     EmaCross.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
#include <Trade\PositionInfo.mqh>

CPositionInfo position;
CTrade Trading;

int input shortMaPeriod = 5; // Short MA
int input longMaPeriod = 8;  // Long MA

double inpStopLoss = 50;
double inpTakeProfit = 100;

int input startHour = 00; //start hour
int input endHour = 23; //stop hour
double input trailingStop = 150;  

double ema8[],ema14[];

datetime lastCandleCloseTime = 0;

double totalProfitLoss = 0;
double input initialLotSize = 0.1;
double input incrementalLotSize = 0.1;

double dynamicLotSize = 0.1;
double initialAccountBalance = 0;

double input targetProfit = 150;

bool tradeActive = true;

int OnInit() {
   
   initialAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}

void OnTrade(void)
  {
  
      if(position.Profit() > 0){
         dynamicLotSize = initialLotSize;
      
      }
   
  }

void OnTick() {

      if(tradeActive == true)
      {
         ExecuteTradingLogic();
         ExecuteTrailingLogic();
      }     


      if(AccountInfoDouble(ACCOUNT_EQUITY) >= initialAccountBalance + targetProfit)
      {
         // Close all positions
         for (int i = 0; i < PositionsTotal(); i++) {
            ulong ticketNr = PositionGetTicket(i);
            Trading.PositionClose(ticketNr);
         }
         tradeActive = false;
      }
}

void OnTimer() {
   if (TimeCurrent() > lastCandleCloseTime) {
      lastCandleCloseTime = TimeCurrent();
      ExecuteTradingLogic();
   }
}
  
bool isSellSignal() {
   return (ema8[1] < ema14[1] && ema8[2] > ema14[2]); // Use previous candle values
}

bool isBuySignal() {
   return (ema8[1] > ema14[1] && ema8[2] < ema14[2]); // Use previous candle values
}

void ExecuteTradingLogic()
{
   MqlDateTime mdt;
   TimeCurrent(mdt);
   int currentHour = mdt.hour;
      
   if(currentHour >= startHour && currentHour<= endHour) {
      
      double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
      double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

      int ema8Def = iMA(_Symbol, _Period, shortMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      int ema14Def = iMA(_Symbol, _Period, longMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      ArraySetAsSeries(ema8, true);
      ArraySetAsSeries(ema14, true);
      
      CopyBuffer(ema8Def, 0,0,3,ema8);
      CopyBuffer(ema14Def, 0,0,3,ema14);
   
      if(isBuySignal() && PositionsTotal() < 1) {
      
            double sl = 0;//Ask - inpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tp = 0;//Ask + inpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            Trading.PositionOpen(_Symbol, ORDER_TYPE_BUY, dynamicLotSize, Ask,sl,tp,"CROSS EA BUY");
            dynamicLotSize += incrementalLotSize;
      }

      if(isSellSignal() && PositionsTotal() < 1) {
            double sl = 0;//Bid + inpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tp = 0; //Bid - inpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            Trading.PositionOpen(_Symbol, ORDER_TYPE_SELL, dynamicLotSize, Bid, sl,tp,"CROSS EA SELL");
            dynamicLotSize+=incrementalLotSize;                      
      }
         
         
         if(isSellSignal())
         { 
            for (int i = 0; i < PositionsTotal(); i++) 
            {
                ulong ticketNr = PositionGetTicket(i);
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {                
                  Trading.PositionClose(ticketNr);
                }
            }
         }
   
   
         if(isBuySignal())
         {
            for (int i = 0; i < PositionsTotal(); i++) 
            {
               ulong ticketNr = PositionGetTicket(i);
                  
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) 
               {
                  Trading.PositionClose(ticketNr);
               }
            }
          }
   }
}

void ExecuteTrailingLogic()
{

   for (int i = 0; i < PositionsTotal(); i++) {
   
      if(PositionGetSymbol(i) == _Symbol) {

         ulong ticketNr = PositionGetTicket(i);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double originalTp = PositionGetDouble(POSITION_TP);
         double originalSl = PositionGetDouble(POSITION_SL);

         ENUM_POSITION_TYPE PositionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);  
      
         if(PositionType == POSITION_TYPE_BUY) {         
            
            double profitBuy = NormalizeDouble((SymbolInfoDouble(_Symbol, SYMBOL_BID)-PositionGetDouble(POSITION_PRICE_OPEN)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0);

                  
            if(profitBuy >= trailingStop && bid - trailingStop*Point() > originalSl) {
               Trading.PositionModify(ticketNr,bid - trailingStop*Point(),originalTp);
            }
         }
         else if (PositionType == POSITION_TYPE_SELL) {
         
            double profitSell = NormalizeDouble((PositionGetDouble(POSITION_PRICE_OPEN)-SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0);
            
            if(profitSell >= trailingStop && (ask + trailingStop*Point() < originalSl || originalSl == 0)) {
               Trading.PositionModify(ticketNr,ask + trailingStop*Point(),originalTp);
            }
         }
      }
   }
}


void ExecuteBreakEvenLogic() {

   for (int i = 0; i < PositionsTotal(); i++) {
   
      if(PositionGetSymbol(i) == _Symbol) {
      
         ulong ticketNr = PositionGetTicket(i);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double originalTp = PositionGetDouble(POSITION_TP);
         double originalSl = PositionGetDouble(POSITION_SL);
         
         double tpInPoints = MathAbs((NormalizeDouble((originalTp - openPrice), _Digits)/Point()));
             
         ENUM_POSITION_TYPE PositionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                 
         if(PositionType == POSITION_TYPE_BUY) {         
            
            double profitBuy = NormalizeDouble((SymbolInfoDouble(_Symbol, SYMBOL_BID)-PositionGetDouble(POSITION_PRICE_OPEN)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0);

            if(profitBuy >= 50) {
               Print("Setting the SL to price open, current progress in points:", tpInPoints/2);
               Trading.PositionModify(ticketNr, PositionGetDouble(POSITION_PRICE_OPEN), originalTp);
            }
         }
         else if (PositionType == POSITION_TYPE_SELL) {   
         
            double profitSell = NormalizeDouble((PositionGetDouble(POSITION_PRICE_OPEN)-SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0);

            if(profitSell >= 50) {
               Print("Setting the SL to price open, current progress in points:", tpInPoints/2);
               Trading.PositionModify(ticketNr, PositionGetDouble(POSITION_PRICE_OPEN), originalTp);
            }
         }
      }
   }


}