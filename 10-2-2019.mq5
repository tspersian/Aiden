//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.01"
#include<Trade\Trade.mqh> 
#include <LibCisNewBar.mqh>
#include <Generic\ArrayList.mqh>

CisNewBar current_chart;
CisNewBar current_chart2;
//+---------------------
enum signal {buy,sell,none,closeBuy,closeSell};
//--- EA inputs
input string   EAinputs="EA inputs";                                           // EA inputs
input double   order_volume=0.01;                                              // Lot size
input int   POSITIONS=1;
//--- Trading timespan
input string   Tradingtimespan="Trading timespan";                             // Trading timespan
input char     time_h_start=1;                                                 // Trading start time
input char     time_h_stop=23;                                                 // Trading stop time
input bool     mon=true;                                                       // Work on Monday
input bool     tue=true;                                                      // Work on Tuesday
input bool     wen=true;                                                       // Work on Wednesday
input bool     thu=true;                                                       // Work on Thursday
input bool     fri=true;                                                       // Work on Friday 
input string InpFileName="optimize.csv";  // optimize file name

double cvolume=0;
int iHeikenAshi;
//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
CTrade trade2;
signal OpenSignal;
bool work_day=true;
double InitBalance;
double OPZ[51];
int TradePerDay=0;
MqlDateTime lastOptimize;
CArrayList<ulong>oList;
int CIN=14;
int SL=100,TP=100;
//+---------------------------------------------+
int OnInit()
  {
   if (false==ReadFileToArrayCSV(InpFileName,OPZ))
   {
      for (int i = 0;i<50;i++)
      {
         OPZ[i]++;
      }
   }
   TimeToStruct(TimeCurrent(),lastOptimize);
   Optimize();
   cvolume=order_volume;
   trade.SetExpertMagicNumber(939393);
   trade2.SetExpertMagicNumber(46);
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
bool ReadFileToArrayCSV(string FileName,double &Lines[])
  {
   ResetLastError();
   int h=FileOpen(FileName,FILE_READ|FILE_CSV,";");
   if(h==INVALID_HANDLE)
     {
      int ErrNum=GetLastError();
      printf("Error opening file %s # %i",FileName,ErrNum);
      return(false);
     }
   int lcnt=0; // variable for calculating lines 
   int fcnt=0; // variable for calculating line fields    
   while(!FileIsEnding(h))
     {
      int key=FileReadInteger(h);
      while(!FileIsLineEnding(h))
        { // read the rest of fields in the line
         int value=FileReadInteger(h);
         Lines[key] = value;
        }
     }
   FileClose(h);
   return(true);
  }
//+------------------------------------------------------------------+
void  OnDeinit(const int  reason)
  {
   int file_handle=FileOpen(InpFileName,FILE_READ|FILE_WRITE|FILE_CSV,";");
   if(file_handle!=INVALID_HANDLE)
     {
      PrintFormat("%s file is available for writing",InpFileName);
      PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
      //--- write the time and values of signals to the file
      for(int i=0;i<50;i++)
         FileWrite(file_handle,i,OPZ[i]);
      //--- close the file
      FileClose(file_handle);
      PrintFormat("Data is written, %s file is closed",InpFileName);
     }
   else
      PrintFormat("Failed to open %s file, Error code = %d",InpFileName,GetLastError());
  }
//+------------------------------------------------------------------+
int minDiff(MqlDateTime &a,MqlDateTime &b)
  {
   int yrDiff = MathAbs(a.year-b.year);
   int mnDiff = MathAbs(a.mon-b.mon);
   int dyDiff = MathAbs(a.day-b.day);
   int hrDiff = MathAbs(a.hour-b.hour);

   return yrDiff*8760;
  }
//+------------------------------------------------------------------+
void Optimize()
  {
   MqlDateTime currentOptimize;
   TimeToStruct(TimeCurrent(),currentOptimize);
   if(TradePerDay==0) return;
   if(currentOptimize.hour!=0) return;
   /*if(currentOptimize.day_of_year>lastOptimize.day_of_year+1) return;*/
   HistorySelect(0,TimeCurrent());
   if (HistoryDealsTotal()<50) return;
   double sdprofit=0;
   for(int i=HistoryDealsTotal()-1; i>=0; i--)
     {
      ulong dticket=HistoryDealGetTicket(i);
      if(oList.Contains(dticket)) continue;
      else oList.Add(dticket);
      long dmagic=HistoryDealGetInteger(dticket,DEAL_MAGIC);
      double dprofit=HistoryDealGetDouble(dticket,DEAL_PROFIT);
      ENUM_DEAL_ENTRY dentry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(dticket,DEAL_ENTRY);
      datetime dtime=(datetime)HistoryDealGetInteger(dticket,DEAL_TIME);
      ENUM_DEAL_TYPE dtype=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dticket,DEAL_TYPE);
      if(dmagic==939393)
        {
         sdprofit+=dprofit;
        }
     }
   double ProfitPerTrade=sdprofit/TradePerDay;
   double ProfitPerHour=sdprofit/24;
   TradePerDay=0;
   OPZ[CIN]+=(ProfitPerTrade+ProfitPerHour)/2;
   double rc=Rand(0,50);
   double cr=0;
   for(int i=0;i<50;i++)
     {
      if(rc<OPZ[i]+cr)
        {
         CIN=i+1;
         break;
        }
      cr+=OPZ[i];
      if(i==49)
        {
         rc=Rand(0,50);
         i=1;
        }
     }
   ArraySort(OPZ);
   TimeToStruct(TimeCurrent(),lastOptimize);
  }
//+------------------------------------------------------------------+
void CloseAllBuyPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0)
        {
         trade.PositionClose(i);
        }
     }
  }
//+------------------------------------------------------------------+
signal Archer()
  {
   int HighEMA=iMA(_Symbol,PERIOD_H1,86,0,MODE_EMA,PRICE_CLOSE);//86
   int LowEMA=iMA(_Symbol,PERIOD_H1,21,0,MODE_EMA,PRICE_CLOSE);//21
   int Momentum=iMomentum(_Symbol,PERIOD_H1,8,PRICE_CLOSE);
   iHeikenAshi=iCustom(_Symbol,PERIOD_H1,"heiken_ashi_smoothed");
   int Stochastic=iStochastic(_Symbol,PERIOD_H1,8,3,3,MODE_SMA,STO_CLOSECLOSE);

   double HighEMAValue[];
   double LowEMAValue[];
   double MomentumValue[];
   double HeikenAshiValue[];
   double StochasticValue[];
   double StochasticSignal[];

   ArraySetAsSeries(HighEMAValue,true);
   CopyBuffer(HighEMA,0,0,3,HighEMAValue);

   ArraySetAsSeries(LowEMAValue,true);
   CopyBuffer(LowEMA,0,0,3,LowEMAValue);

   ArraySetAsSeries(MomentumValue,true);
   CopyBuffer(Momentum,0,0,3,MomentumValue);

   ArraySetAsSeries(HeikenAshiValue,true);
   CopyBuffer(iHeikenAshi,4,0,3,HeikenAshiValue);

   ArraySetAsSeries(StochasticValue,true);
   CopyBuffer(Stochastic,0,0,3,StochasticValue);

   ArraySetAsSeries(StochasticSignal,true);
   CopyBuffer(Stochastic,1,0,3,StochasticSignal);

   if(HeikenAshiValue[0]==0)
     {
      if(LowEMAValue[2]<HighEMAValue[2] && LowEMAValue[0]>HighEMAValue[0])
        {
         if(MomentumValue[0]>100)
           {
            if(StochasticValue[0]>40 && StochasticValue[0]<StochasticSignal[0])
              {
               return buy;
              }
           }
        }
     }
   if(HeikenAshiValue[0]==1)
     {
      if(LowEMAValue[2]>HighEMAValue[2] && LowEMAValue[0]<HighEMAValue[0])
        {
         if(MomentumValue[0]<100)
           {
            if(StochasticValue[0]<80 && StochasticValue[0]>StochasticSignal[0])
              {
               return sell;
              }
           }
        }
     }
   return none;
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   bool NC=false;
   bool NCH1=false;
   int period_seconds=PeriodSeconds(_Period);
   int period_secondsH1=PeriodSeconds(PERIOD_H1);
   datetime new_time=TimeCurrent()/period_seconds*period_seconds;
   datetime new_time2=TimeCurrent()/period_secondsH1*period_secondsH1;
   if(current_chart.isNewBar(new_time)) NC=true;
   if(current_chart2.isNewBar(new_time2)) NCH1=true;
   double Balance= AccountInfoDouble(ACCOUNT_BALANCE);
   double Equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int pos=PositionsTotal();
   Optimize();
   double price_ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double price_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   signal CurrentSignal=none;
   signal ArcherCurrentSignal=none;
   signal HA=none;
   if(NCH1)
     {
      ArcherCurrentSignal=Archer();
     }
   if(NC)
     {
      CurrentSignal=ManualDem(CIN);
      signal HA1=HeikenAshi(PERIOD_M1);
      signal HA2=HeikenAshi(PERIOD_M10);
      signal HA3=HeikenAshi(PERIOD_M20);
      signal HA4=HeikenAshi(PERIOD_M30);
      signal HA5=HeikenAshi(PERIOD_H1);
      int b=1,s=1;
      if(HA1==buy) b++;
      else if(HA1==sell) s++;
      if(HA2==buy) b++;
      else if(HA2==sell) s++;
      if(HA3==buy) b++;
      else if(HA3==sell) s++;
      if(HA4==buy) b++;
      else if(HA4==sell) s++;
      if(HA5==buy) b++;
      else if(HA5==sell) s++;
      if(b>s) HA=buy;
      else if(b<s) HA=sell;
     }

//---
   time_now_var=TimeCurrent(time_now_str);
   bool work=false;
   switch(time_now_str.day_of_week)
     {
      case 1: if(mon==false){work_day=false;}
      else {work_day=true;}
      break;
      case 2: if(tue==false){work_day=false;}
      else {work_day=true;}
      break;
      case 3: if(wen==false){work_day=false;}
      else {work_day=true;}
      break;
      case 4: if(thu==false){work_day=false;}
      else {work_day=true;}
      break;
      case 5: if(fri==false){work_day=false;}
      else {work_day=true;}
      break;
     }

   Comment("\nDem: ",CIN,"\nVolume: ",cvolume,"\n Signal big: ",EnumToString(ArcherCurrentSignal),"\n Signal small: ",EnumToString(CurrentSignal));

   if(time_h_start>time_h_stop)
     {
      if(time_now_str.hour>=time_h_start || time_now_str.hour<=time_h_stop)
        {
         work=true;
        }
     }
   else
     {
      if(time_now_str.hour>=time_h_start && time_now_str.hour<=time_h_stop)
        {
         work=true;
        }
     }
   if(NC && pos>0)
     {
      TrailingStop(price_ask,price_bid);
     }
   if(NCH1 && pos>0)
     {
      TrailingStopH1(price_ask,price_bid);
     }
   if(CurrentSignal!=none && pos<POSITIONS)
     {
      if(Equity>=InitBalance*1.5) CloseAllBuyPositions();
      if(Balance<InitBalance) cvolume+=order_volume;
      else cvolume=order_volume;
     }
   if(work==true && work_day==true)
     {
      if(CurrentSignal==buy && HA==buy)
        {
         if(pos<POSITIONS)
           {
            trade.Buy(cvolume,_Symbol,price_ask,price_ask-SL*_Point,price_ask+TP*_Point,"");
            OpenSignal=buy;
            TradePerDay++;
           }
        }
      else if(CurrentSignal==sell && HA==sell)
        {
         if(pos<POSITIONS)
           {
            trade.Sell(cvolume,_Symbol,price_bid,price_bid+SL*_Point,price_bid-TP*_Point,"");
            OpenSignal=sell;
            TradePerDay++;
           }
        }
      if(ArcherCurrentSignal==buy)
        {
         if(pos<POSITIONS+1)
           {
            trade2.Buy(cvolume,_Symbol,price_ask,price_ask-(SL*500)*_Point,price_ask+(TP*500)*_Point,"AR");
            OpenSignal=buy;
            TradePerDay++;
           }
        }
      else if(ArcherCurrentSignal==sell)
        {
         if(pos<POSITIONS+1)
           {
            trade2.Sell(cvolume,_Symbol,price_bid,price_bid+(SL*500)*_Point,price_bid-(TP*500)*_Point,"AR");
            OpenSignal=sell;
            TradePerDay++;
           }
        }
     }
   if(InitBalance>=Equity)
     {
      SL = MathMax(SL/2,50);
      TP = MathMax(TP/2,50);
     }
   else
     {
      SL = (int)MathMax(SL*1.2,100);
      TP = (int)MathMax(TP*1.2,100);
     }
  }
//+------------------------------------------------------------------+
signal HeikenAshi(ENUM_TIMEFRAMES _period=PERIOD_H1)
  {
   MqlRates RateArray[];
   ArrayResize(RateArray,3);
   if(!CopyRates(_Symbol,_period,0,3,RateArray)) return none;
   double HAC=(RateArray[0].open+RateArray[0].high+RateArray[0].low+RateArray[0].close)/4;
   double HAO=(RateArray[1].open+RateArray[1].close)/2;
   if(HAO<HAC) return buy;
   else return sell;
   return none;
  }
//+------------------------------------------------------------------+
signal ManualDem(int len)
  {
   MqlRates RateArray[];
   double DeMax[],DeMin[];
   ArrayResize(RateArray,len);
   ArrayResize(DeMax,len);
   ArrayResize(DeMin,len);
   if(!CopyRates(_Symbol,_Period,0,len,RateArray)) return none;

   static double LMA;
   double MA=SMARate(RateArray);

   for(int i=1;i<ArraySize(RateArray);i++)
     {
      DeMax[i-1]=RateArray[i].high-RateArray[i-1].high;
      DeMax[i-1]=(DeMax[i-1]>0?DeMax[i-1]:0);
      DeMin[i-1]=RateArray[i-1].low-RateArray[i].low;
      DeMin[i-1]=(DeMin[i-1]>0?DeMin[i-1]:0);
     }
   double MADeMax=SMA(DeMax);
   double MADeMin=SMA(DeMin);
   double root=MADeMax+MADeMin;
   root=NormalizeDouble(root,5);
   if(root==0) return none;
   double DeM=MADeMax/root;
   bool UT=false;
   double std=Stdev(MA,LMA);
   if(MA>LMA)
     {
      UT=true;
      LMA=MA;
     }
   if(DeM>0.7 && !UT)
     {
      return sell;
     }
   else if(DeM<0.3 && UT)
     {
      return buy;
     }
   return none;
  }
double MathRandRange(double x,double y) { return(x+MathMod(MathRand(),MathAbs(x-y))); }
//+------------------------------------------------------------------+  
double Stdev(double a,double b)
  {
   return MathSqrt(MathPow(a-b,2))/2;
  }
//+------------------------------------------------------------------+
double SMA(double &CArray[])
  {
   return ArraySum(CArray)/ArraySize(CArray);
  }
//+------------------------------------------------------------------+
double ArraySum(double &rates[])
  {
   double SM=0;
   for(int i=0;i<ArraySize(rates);i++)
     {
      SM+=rates[i];
     }
   return SM;
  }
//+------------------------------------------------------------------+
double SMARate(MqlRates &CArray[])
  {
   return ArraySumRate(CArray)/ArraySize(CArray);
  }
//+------------------------------------------------------------------+
double ArraySumRate(MqlRates &rates[])
  {
   double SM=0;
   for(int i=0;i<ArraySize(rates);i++)
     {
      SM+=(rates[i].low+rates[i].high+rates[i].close)/3;
     }
   return SM;
  }
//+------------------------------------------------------------------+
void TrailingStopH1(double price_ask,double price_bid)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      if(symbol==_Symbol)
        {
         ulong PositionTicket=PositionGetInteger(POSITION_TICKET);
         double SLC=PositionGetDouble(POSITION_SL);
         double TPC=PositionGetDouble(POSITION_TP);
         string CMC=PositionGetString(POSITION_COMMENT);
         long MGC=PositionGetInteger(POSITION_MAGIC);
         if(MGC==939393) continue;
         if(CMC==NULL && CMC=="") continue;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            double NSL=NormalizeDouble(price_ask-1000*_Point,_Digits);
            double NSL2=NormalizeDouble(price_ask-100*_Point,_Digits);
            if(NSL>SLC)
              {
               if(trade.PositionModify(PositionTicket,NSL,TPC+200*_Point))
                 {
                  Print("error");
                 }
              }
            else if(NSL2<SLC)
              {
               if(trade.PositionModify(PositionTicket,NSL2,TPC-100*_Point))
                 {
                  Print("error");
                 }
              }
           }
         else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            double NSL=NormalizeDouble(price_ask+500*_Point,_Digits);
            double NSL2=NormalizeDouble(price_ask+50*_Point,_Digits);
            if(NSL<SLC)
              {
               if(!trade.PositionModify(PositionTicket,NSL,TPC-200*_Point))
                 {
                  Print("error");
                 }
              }
            else if(NSL2<SLC)
              {
               if(!trade.PositionModify(PositionTicket,NSL2,TPC+100*_Point))
                 {
                  Print("error");
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
void TrailingStop(double price_ask,double price_bid)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      if(symbol==_Symbol)
        {
         ulong PositionTicket=PositionGetInteger(POSITION_TICKET);
         double SLC=PositionGetDouble(POSITION_SL);
         double TPC=PositionGetDouble(POSITION_TP);
         string CMC=PositionGetString(POSITION_COMMENT);
         long MGC=PositionGetInteger(POSITION_MAGIC);
         double PPC=PositionGetDouble(POSITION_PROFIT);
         signal HASHI=HeikenAshi();
         if(MGC==46) continue;
         if(CMC!=NULL && CMC!="") continue;
         int lSL=50,lSL2=1;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            double NSL=NormalizeDouble(price_ask+(PPC>0?50:20)*_Point,_Digits);
            double NSL2=NormalizeDouble(price_ask-(PPC>0?50:20)*_Point,_Digits);
            if(HASHI==buy)
              {
               if(trade.PositionModify(PositionTicket,NSL,TPC+(PPC>0?10:5)*_Point))
                 {
                  Print("error");
                 }
              }
            else
              {
               if(trade.PositionModify(PositionTicket,NSL2,TPC-(PPC>0?10:2)*_Point))
                 {
                  Print("error");
                 }
              }
           }
         else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            double NSL=NormalizeDouble(price_bid-(PPC>0?50:20)*_Point,_Digits);
            double NSL2=NormalizeDouble(price_bid+(PPC>0?50:20)*_Point,_Digits);
            if(HASHI==sell)
              {
               if(!trade.PositionModify(PositionTicket,NSL,TPC-(PPC>0?10:5)*_Point))
                 {
                  Print("error");
                 }
              }
            else
              {
               if(!trade.PositionModify(PositionTicket,NSL2,TPC+(PPC>0?10:2)*_Point))
                 {
                  Print("error");
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
double Rand(const double min,const double max)
  {
   double f=(MathRand()/32768.0);

   return min + (int)(f * (max - min));
  }
//+------------------------------------------------------------------+
