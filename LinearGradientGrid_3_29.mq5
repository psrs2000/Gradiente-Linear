//+------------------------------------------------------------------+
//|                                  Linear Gradient Grid v3.29      |
//|                                Copyright 2025-2026, Trading Expert|
//|                  v3.29: COOLDOWN WITH BACKOFF AFTER STOP LOSS    |
//+------------------------------------------------------------------+

//Changelog:
//v3.01: Identification by TICKET (not by price)
//v3.02: Opposite order calculated using ORIGINAL PRICE
//v3.02: Handling of PARTIAL and COMPLETE fills
//v3.03: Configurable DELAY between orders
//v3.04: OPTIMIZED CSV - Saved only at critical moments (OnDeinit, CreateGrid, ExecuteTargetAction, manual buttons)
//v3.05: DEBUG VERSION: Full logs in OnTradeTransaction
//v3.07: Compares dealVolume vs originalVolume
//v3.07: Does NOT depend on OrderSelect!
//v3.07: Works in DEMO and REAL
//v3.08: Validates LotSize >= Minimum Lot
//v3.09: Delay BEFORE creating orders (FIXED!)
//v3.10: Order consolidation (same type/price)
//v3.10: Does not reset ticket (traceability)
//v3.11: OPTIMIZATION - Updates only the order that changed (50% fewer operations)
//v3.11: Compares existing order before cancel/recreate
//v3.12: EXACT COMPARISON - Removes tolerances (deterministic market)
//v3.12: Consolidation uses exact price equality (not approximate)
//v3.13: SAFE CANCELLATION - Does not try to cancel an already executed order
//v3.13: Uses CancelAllEAOrders() instead of direct OrderDelete
//v3.14: INDEX VALIDATION - Calculates and creates orders only if index >= 0
//v3.14: Works with one-sided grids (only BUY or only SELL)
//v3.15: TARGET FIX - Blocks automatic reactivation after target is reached
//v3.15: Deactivates BEFORE closing positions (avoids dangling order)
//v3.15: Double cancellation to ensure complete cleanup
//v3.17: REMOVES BOOK PROTECTION - Protection was harmful (partial/cascade fills are normal)
//v3.18: ACTIVE VERIFICATION - Waits for cancellations to be confirmed before creating new orders
//v3.18: Removes OrderDelay parameter (replaced by active verification)
//v3.19: ACTIVATE WITHOUT CREATING - Loads CSV on activation without creating orders (maps existing book orders)
//v3.20: LABEL FIX MT5 - Deletes object before recreating (compatibility with MT5 update)
//v3.21: NETTING SUPPORT - Target/Loss works in HEDGE (by MagicNumber) and NETTING (consolidated position)
//v3.22: SMART SYNC - Uses HistoryDeals to rebuild array after disconnect (OnTimer)
//v3.23: DYNAMIC BREAK EVEN - When profit reaches X% of target, limit becomes zero
//v3.23: TRAILING LOSS - For each $X rise, minimum guaranteed profit increases $X
//v3.23: SYNC FIX - Window uses disconnection timestamp (not last sync)
//v3.24: BREAK EVEN VALUE - Break Even triggers at fixed value ($) independent of profit target
//v3.25: CSV BACKUP - Creates automatic CSV backup when deactivating EA
//v3.25: IMPROVED SYNC - Clearly shows whether sync ran or not
//v3.26: TICK SIZE - Rounds prices to asset tick size (fixes J/K)
//v3.27: BOOK VERIFICATION - After reconnection, verifies that extreme orders exist and recreates if needed
//v3.28: MAX INVENTORY - Inserts protective Stop order when positions reach configured limit
//v3.28: STOP at midpoint between last executed and next pending
//v3.28: Stop volume = volume of the next order in the array (respects J)
//v3.28: HEDGE closes oldest position | NETTING reduces consolidated position
//v3.29: COOLDOWN - Pause after stop loss with exponential backoff (30 -> 60 -> 120 -> deactivate)
//v3.29 (revised): MAX INVENTORY - Replaced pending Stop with MARKET ORDER with hysteresis
//                 - When positions > limit: sends opposite market order to return to the limit
//                 - Hysteresis: volume = k * volumeMin + volume of next grid order
//                 - HEDGE: closes k oldest positions + buffer market order of v_next
//                 - Fixes SYMBOL_TRADE_STOPS_LEVEL rejection and guarantees a hard ceiling


#property copyright    "Copyright 2025-2026, Trading Expert"
#property version      "3.29"
#property description  "Linear-gradient symmetric grid with K (distance) and J (volume) progressive multipliers."
#property description  "Partial-grid architecture: only the two extreme orders are kept live in the book."
#property description  "Break-even and trailing-loss protection, maximum-inventory stop protection,"
#property description  "and post-stop-loss cooldown with exponential backoff."
#property strict

// Include required libraries
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enums for configuration                                          |
//+------------------------------------------------------------------+
enum ENUM_STATUS {
   STATUS_INACTIVE = 0, // Inactive
   STATUS_ACTIVE   = 1  // Active
};

enum ENUM_PERSISTENCE {
   PERSISTENCE_KEEP          = 0, // Keep everything running
   PERSISTENCE_CLOSE_ORDERS  = 1, // Only close orders
   PERSISTENCE_CLOSE_ALL     = 2, // Close orders and positions
   PERSISTENCE_DEACTIVATE    = 3  // Deactivate keeping orders
};

enum ENUM_TARGET_ACTION {
   ACTION_CLOSE_AND_DEACTIVATE = 0, // Close everything and deactivate
   ACTION_CLOSE_AND_RECREATE   = 1  // Close everything and recreate grid
};

// v3.29: Specific action for stop loss (independent of profit target)
enum ENUM_STOP_ACTION {
   STOP_ACTION_DEACTIVATE = 0, // Close everything and deactivate
   STOP_ACTION_RECREATE   = 1, // Close and recreate grid
   STOP_ACTION_COOLDOWN   = 2  // Cooldown with exponential backoff
};

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+

input group "### General Grid Settings | NewDist = PrevDist*(1+K)"
input double   KMultiplierAbove = 0.0;     // K for grid above (0 = fixed distance)
input double   KMultiplierBelow = 0.0;     // K for grid below (0 = fixed distance)

input group "### General Volume Settings | NewVol = PrevVol*(1+J)"
input double   JVolumeMultiplierAbove = 0.0;  // J for volume above (0 = fixed)
input double   JVolumeMultiplierBelow = 0.0;  // J for volume below (0 = fixed)
input double   MaxVolume             = 0;     // Maximum volume (0 = no limit)

input group "### Grid Above Current Price"
input double   InitialGapAbove      = 50;     // Initial gap above (Pips)
input double   OrderDistanceAbove   = 20;     // Distance between orders above (Pips)
input int      OrderCountAbove      = 5;      // Number of orders above
input bool     EnableGridAbove      = true;   // Enable grid above

input group "### Grid Below Current Price"
input double   InitialGapBelow      = 50;     // Initial gap below (Pips)
input double   OrderDistanceBelow   = 20;     // Distance between orders below (Pips)
input int      OrderCountBelow      = 5;      // Number of orders below
input bool     EnableGridBelow      = true;   // Enable grid below

input group "### Reference Settings"
input double   ReferencePrice = 0;  // Reference Price (0 = Current Price)

input group "### Volume and Gain Settings"
input double   LotSize  = 1;    // Lot size
input double   GainPips = 100;  // Gain in Pips

input group "### Persistence Settings"
input ENUM_PERSISTENCE Persistence = PERSISTENCE_DEACTIVATE;  // Persistence type
input string   StartTime  = "09:00";  // Start time (HH:MM)
input bool     AutoStart  = true;     // Enable automatic start
input string   CloseTime  = "17:30";  // Close time (HH:MM)

input group "### Grid Persistence Settings"
input bool     StartWithPreviousGrid = false;  // Start with previous grid

input group "### Technical Settings"
input int      Slippage      = 3;             // Slippage (Points)
input int      MagicNumber   = 12345;         // Magic number
input bool     BrazilianMode = true;          // Adjust for Brazilian market
input bool     DebugMode     = false;         // Debug mode
input ENUM_STATUS InitialStatus = STATUS_INACTIVE;  // Initial status

input group "### Profit/Loss Target (HEDGE Only)"
input double   ProfitTarget = 0;   // Profit target ($) - 0 = disabled
input double   MaxLoss      = 0;   // Loss limit ($) - 0 = disabled
input ENUM_TARGET_ACTION ActionOnTarget = ACTION_CLOSE_AND_DEACTIVATE;  // Action on target

input group "### Maximum Inventory (Protective Stop)"
input int      MaxInventory = 0;   // Maximum position inventory (0 = disabled)

input group "### Break Even and Trailing Loss"
input bool     UseBreakEven      = false;   // Use Break Even?
input double   BreakEvenValue    = 0;       // Break Even activates at $ (0 = disabled)
input bool     UseTrailingLoss   = false;   // Use Trailing Loss?
input double   TrailingLossValue = 10.0;    // Trailing Loss: Increment in $

input group "### Action After Stop Loss (MaxLoss)"
input ENUM_STOP_ACTION ActionAfterStopLoss = STOP_ACTION_DEACTIVATE;  // Action after stop loss
input int      InitialPauseMinutes     = 30;     // Cooldown: Initial pause (minutes)
input int      MaxConsecutiveAttempts  = 3;      // Cooldown: Max attempts before deactivating
input bool     ReuseGridAfterPause     = false;  // Cooldown: Reuse previous grid on resume

//+------------------------------------------------------------------+
//| STRUCT: Order info with unique ticket                            |
//+------------------------------------------------------------------+
struct OriginalOrderInfo
{
   ulong ticket;              // Unique order ticket (0 = not sent to MT5)
   double originalPrice;      // Original order price
   double volume;             // Order volume (CAN BE UPDATED on partials!)
   ENUM_ORDER_TYPE orderType; // Order type
   string comment;            // Order comment
};

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;
bool   robotActive = false;
double pointsPerPip;
int    pipDigits;
bool   isHedge = false;

// v3.15: Flag to block automatic reactivation after target reached
bool targetReachedToday = false;
int  lastCheckDay       = -1;

// v3.21: Timestamp to reset profit/loss calculation
// When target is hit and grid is recreated, only deals after this moment are considered
datetime lastProfitLossReset = 0;

// v3.22: Sync control after reconnection
datetime lastSync               = 0;
bool     inDisconnection        = false;
datetime disconnectionTimestamp = 0;  // v3.23: Exact disconnection moment

// v3.22: Break Even and dynamic Trailing Loss control
double dynamicLoss         = 0;     // Current dynamic loss (starts = MaxLoss)
bool   breakEvenActivated  = false; // Flag: has Break Even been activated?
double trailingBaseLevel   = 0;     // Base profit level for Trailing calculation

// v3.29: Post Stop Loss cooldown control
bool     inCooldown        = false;
datetime cooldownStart     = 0;
int      currentAttempt    = 0;
int      cooldownSeconds   = 0;

// Array to store the WHOLE grid (memory)
OriginalOrderInfo originalOrders[];

// Control panel variables
int   panelWidth  = 230;
int   panelHeight = 250;
int   panelX      = 0;
int   panelY      = 0;
color panelColor  = clrWhiteSmoke;
color textColor   = clrBlack;

//+------------------------------------------------------------------+
//| Basic helper functions                                           |
//+------------------------------------------------------------------+
double PipsToPoints(double pips)
{
   return pips * pointsPerPip;
}

double PointsToPips(double points)
{
   return points / pointsPerPip;
}

//+------------------------------------------------------------------+
//| v3.26: Round price to asset tick size                            |
//+------------------------------------------------------------------+
double RoundPrice(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize > 0)
   {
      price = MathRound(price / tickSize) * tickSize;
   }

   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| Round volume to broker volume step / limits                      |
//+------------------------------------------------------------------+
double RoundVolume(double volume)
{
   double volumeMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volumeMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathRound(volume / volumeStep) * volumeStep;

   if(volume < volumeMin)
      volume = volumeMin;
   if(volumeMax > 0 && volume > volumeMax)
      volume = volumeMax;

   if(MaxVolume > 0 && volume > MaxVolume)
      volume = MaxVolume;

   volume = NormalizeDouble(volume, 2);

   return volume;
}

//+------------------------------------------------------------------+
//| v3.10: Add order to the array (with consolidation)               |
//+------------------------------------------------------------------+
void AddOrderToArray(ENUM_ORDER_TYPE type, double price,
                     double volume, string comment)
{
   if(DebugMode)
      Print("Adding order: ", EnumToString(type),
            " @ ", DoubleToString(price, _Digits),
            " vol: ", DoubleToString(volume, 2));

   //--- v3.26: Round price to tick size
   price = RoundPrice(price);

   //--- Check whether an order of same type and price already exists
   bool foundDuplicate = false;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      // Check if same type
      if(originalOrders[i].orderType != type)
         continue;

      // Check whether it is EXACTLY the same price (no tolerance)
      if(originalOrders[i].originalPrice == price)
      {
         //--- CONSOLIDATE volumes
         double previousVolume = originalOrders[i].volume;
         originalOrders[i].volume += volume;
         originalOrders[i].volume = RoundVolume(originalOrders[i].volume);

         if(DebugMode)
         {
            Print("ORDER CONSOLIDATED!");
            Print("   Type: ", EnumToString(type));
            Print("   Price: ", DoubleToString(price, _Digits));
            Print("   Previous volume: ", DoubleToString(previousVolume, 2));
            Print("   Added volume: ", DoubleToString(volume, 2));
            Print("   Total volume: ", DoubleToString(originalOrders[i].volume, 2));
         }

         foundDuplicate = true;
         break;
      }
   }

   if(!foundDuplicate)
   {
      //--- ADD new order
      int size = ArraySize(originalOrders);
      ArrayResize(originalOrders, size + 1);

      originalOrders[size].ticket        = 0;
      originalOrders[size].originalPrice = price;
      originalOrders[size].volume        = RoundVolume(volume);
      originalOrders[size].orderType     = type;
      originalOrders[size].comment       = comment;

      if(DebugMode)
      {
         Print("ORDER ADDED to array");
         Print("   Index: ", size);
         Print("   Type: ", EnumToString(type));
         Print("   Price: ", DoubleToString(price, _Digits));
         Print("   Volume: ", DoubleToString(originalOrders[size].volume, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| Search order in array by TICKET                                  |
//+------------------------------------------------------------------+
int FindOrderByTicket(ulong searchedTicket)
{
   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].ticket == searchedTicket)
      {
         if(DebugMode)
            Print("Order found in array: index ", i, ", ticket #", searchedTicket);
         return i;
      }
   }

   if(DebugMode)
      Print("Order NOT found in array: ticket #", searchedTicket);

   return -1; // Not found
}

//+------------------------------------------------------------------+
//| v3.23: Search order in array by PRICE and TYPE                   |
//+------------------------------------------------------------------+
int FindOrderByPriceAndType(double searchedPrice, ENUM_ORDER_TYPE searchedType)
{
   double tolerance = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].orderType == searchedType)
      {
         if(MathAbs(originalOrders[i].originalPrice - searchedPrice) <= tolerance)
         {
            if(DebugMode)
               Print("Order found by price/type: index ", i,
                     ", price ", DoubleToString(searchedPrice, _Digits));
            return i;
         }
      }
   }

   if(DebugMode)
      Print("Order NOT found by price/type: ",
            DoubleToString(searchedPrice, _Digits), " ", EnumToString(searchedType));

   return -1;
}

//+------------------------------------------------------------------+
//| Save grid state to CSV                                           |
//+------------------------------------------------------------------+
void SaveGridState()
{
   if(ArraySize(originalOrders) == 0)
   {
      if(DebugMode)
         Print("Array empty, nothing to save in CSV");
      return;
   }

   string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

   int handle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);

   if(handle == INVALID_HANDLE)
   {
      Print("Error creating CSV file: ", GetLastError());
      return;
   }

   // Header with Ticket field
   FileWriteString(handle, "Ticket,Type,Price,Volume,Comment\n");

   // Write ALL orders from the array
   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      string line = StringFormat("%I64u,%d,%f,%f,%s\n",
                                 originalOrders[i].ticket,
                                 (int)originalOrders[i].orderType,
                                 originalOrders[i].originalPrice,
                                 originalOrders[i].volume,
                                 originalOrders[i].comment);
      FileWriteString(handle, line);
   }

   FileClose(handle);

   if(DebugMode)
      Print("Grid saved to CSV with ", ArraySize(originalOrders), " orders");
}

//+------------------------------------------------------------------+
//| v3.25: Create CSV backup with timestamp                          |
//+------------------------------------------------------------------+
void BackupCSV()
{
   string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

   if(!FileIsExist(fileName, FILE_COMMON))
   {
      if(DebugMode)
         Print("No CSV to back up");
      return;
   }

   // Build backup name with date/time
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   string backupName = StringFormat("%s_%d_Grade_BKP_%04d%02d%02d_%02d%02d%02d.csv",
                                    _Symbol, MagicNumber,
                                    time.year, time.mon, time.day,
                                    time.hour, time.min, time.sec);

   // Copy file
   if(FileCopy(fileName, FILE_COMMON, backupName, FILE_COMMON))
   {
      Print("CSV backup created: ", backupName);
   }
   else
   {
      Print("Error creating CSV backup: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Load previous grid from CSV                                      |
//| v3.19: Optional parameter to skip creating orders                |
//+------------------------------------------------------------------+
void LoadPreviousGrid(bool createOrdersInMT5 = true)
{
   string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

   if(!FileIsExist(fileName, FILE_COMMON))
   {
      if(DebugMode)
         Print("CSV file not found: ", fileName);
      return;
   }

   int handle = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);

   if(handle == INVALID_HANDLE)
   {
      Print("Error opening CSV file: ", GetLastError());
      return;
   }

   if(DebugMode)
      Print("Loading grid from CSV...");

   // Clear array
   ArrayResize(originalOrders, 0);

   // Skip header
   string header = FileReadString(handle);

   int orderCounter = 0;

   // Read each line
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);

      if(line == "" || StringLen(line) < 5)
         continue;

      // Split values by comma
      string values[];
      StringSplit(line, ',', values);

      if(ArraySize(values) < 5)
         continue;

      // Extract info including TICKET
      ulong ticket = StringToInteger(values[0]);
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)StringToInteger(values[1]);
      double price = StringToDouble(values[2]);
      double volume = StringToDouble(values[3]);
      string comment = values[4];

      if(price <= 0 || volume <= 0)
         continue;

      // Append to array
      int size = ArraySize(originalOrders);
      ArrayResize(originalOrders, size + 1);
      originalOrders[size].ticket        = ticket;
      originalOrders[size].originalPrice = price;
      originalOrders[size].volume        = volume;
      originalOrders[size].orderType     = type;
      originalOrders[size].comment       = comment;

      orderCounter++;
   }

   FileClose(handle);

   if(DebugMode)
      Print("Grid loaded: ", orderCounter, " orders");

   // v3.19: Only create orders if requested
   if(createOrdersInMT5)
      InsertExtremeOrders();
}

//+------------------------------------------------------------------+
//| Create complete initial grid                                     |
//+------------------------------------------------------------------+
void CreateInitialGrid()
{
   //--- Determine reference price
   double currentPrice = (ReferencePrice > 0) ? ReferencePrice : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(DebugMode)
      Print("Creating initial grid with reference: ", DoubleToString(currentPrice, _Digits));

   //--- Clear array
   ArrayResize(originalOrders, 0);

   //===== CREATE BUYs (BELOW PRICE) =====
   if(EnableGridBelow)
   {
      double currentVolume = LotSize;

      for(int i = 0; i < OrderCountBelow; i++)
      {
         // Calculate sum of growing distances
         double distancesSum = 0;
         double dist = OrderDistanceBelow;

         for(int j = 0; j < i; j++)
         {
            distancesSum += MathRound(dist);
            dist = dist + (dist * KMultiplierBelow);
         }

         double price = RoundPrice(currentPrice - (InitialGapBelow + distancesSum) * pointsPerPip);
         double orderVolume = RoundVolume(currentVolume);

         // Append to array (WITHOUT creating in MT5)
         int size = ArraySize(originalOrders);
         ArrayResize(originalOrders, size + 1);
         originalOrders[size].ticket        = 0;
         originalOrders[size].originalPrice = price;
         originalOrders[size].volume        = orderVolume;
         originalOrders[size].orderType     = ORDER_TYPE_BUY_LIMIT;
         originalOrders[size].comment       = "Initial Grid";

         if(DebugMode)
            Print("  BUY added: ", DoubleToString(price, _Digits), " vol: ", orderVolume);

         // Compute next volume
         currentVolume = currentVolume * (1.0 + JVolumeMultiplierBelow);
      }
   }

   //===== CREATE SELLs (ABOVE PRICE) =====
   if(EnableGridAbove)
   {
      double currentVolume = LotSize;

      for(int i = 0; i < OrderCountAbove; i++)
      {
         // Calculate sum of growing distances
         double distancesSum = 0;
         double dist = OrderDistanceAbove;

         for(int j = 0; j < i; j++)
         {
            distancesSum += MathRound(dist);
            dist = dist + (dist * KMultiplierAbove);
         }

         double price = RoundPrice(currentPrice + (InitialGapAbove + distancesSum) * pointsPerPip);
         double orderVolume = RoundVolume(currentVolume);

         // Append to array (WITHOUT creating in MT5)
         int size = ArraySize(originalOrders);
         ArrayResize(originalOrders, size + 1);
         originalOrders[size].ticket        = 0;
         originalOrders[size].originalPrice = price;
         originalOrders[size].volume        = orderVolume;
         originalOrders[size].orderType     = ORDER_TYPE_SELL_LIMIT;
         originalOrders[size].comment       = "Initial Grid";

         if(DebugMode)
            Print("  SELL added: ", DoubleToString(price, _Digits), " vol: ", orderVolume);

         // Compute next volume
         currentVolume = currentVolume * (1.0 + JVolumeMultiplierAbove);
      }
   }

   if(DebugMode)
      Print("Grid created with ", ArraySize(originalOrders), " orders");

   //--- Save CSV
   SaveGridState();

   //--- Insert the 2 extreme orders in MT5
   InsertExtremeOrders();
}

//+------------------------------------------------------------------+
//| Insert extreme orders into the book - OPTIMIZED v3.11            |
//| Creates only orders that really need to be updated               |
//+------------------------------------------------------------------+
void InsertExtremeOrders()
{
   if(DebugMode)
      Print("Updating extreme orders in book...");

   //===== STEP 1: Compute the 2 extremes that SHOULD exist =====

   int largestBuyIndex = -1;
   double largestBuyPrice = 0;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].orderType == ORDER_TYPE_BUY_LIMIT)
      {
         if(originalOrders[i].originalPrice > largestBuyPrice)
         {
            largestBuyPrice = originalOrders[i].originalPrice;
            largestBuyIndex = i;
         }
      }
   }

   int smallestSellIndex = -1;
   double smallestSellPrice = DBL_MAX;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].orderType == ORDER_TYPE_SELL_LIMIT)
      {
         if(originalOrders[i].originalPrice < smallestSellPrice)
         {
            smallestSellPrice = originalOrders[i].originalPrice;
            smallestSellIndex = i;
         }
      }
   }

   //===== VALIDATION: Check if array is completely empty =====
   if(largestBuyIndex < 0 && smallestSellIndex < 0)
   {
      Print("========================================");
      Print("WARNING: Array empty!");
      Print("All grid and return orders have been executed.");
      Print("EA awaiting new instructions.");
      Print("========================================");
      return;  // Exit safely
   }

   //===== Compute prices only for extremes that EXIST =====
   double expectedBuyPrice  = 0;
   double expectedBuyVolume = 0;
   double expectedSellPrice = 0;
   double expectedSellVolume = 0;

   if(largestBuyIndex >= 0)
   {
      expectedBuyPrice  = RoundPrice(originalOrders[largestBuyIndex].originalPrice);
      expectedBuyVolume = RoundVolume(originalOrders[largestBuyIndex].volume);
   }

   if(smallestSellIndex >= 0)
   {
      expectedSellPrice  = RoundPrice(originalOrders[smallestSellIndex].originalPrice);
      expectedSellVolume = RoundVolume(originalOrders[smallestSellIndex].volume);
   }

   //===== STEP 2: Read the order currently in the book (only 1 after execution!) =====

   ulong existingTicket = 0;
   ENUM_ORDER_TYPE existingType = ORDER_TYPE_BUY_LIMIT;  // Only to avoid compiler warning (used only if foundOrder=true)
   double existingPrice = 0;
   double existingVolume = 0;
   bool foundOrder = false;  // IMPORTANT: existingType is only valid if this flag is true

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            existingTicket = ticket;
            existingType   = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            existingPrice  = NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN), _Digits);
            existingVolume = OrderGetDouble(ORDER_VOLUME_CURRENT);
            foundOrder     = true;

            if(DebugMode)
               Print("Order in book: ", EnumToString(existingType),
                     " @ ", existingPrice, " vol: ", existingVolume, " #", ticket);

            break; // Only one order after execution, can exit
         }
      }
   }

   //===== STEP 3: Check whether it matches one of the calculated ones =====

   bool matchesBuy  = false;
   bool matchesSell = false;

   if(foundOrder)
   {
      if(existingType == ORDER_TYPE_BUY_LIMIT)
      {
         // Compare EXACTLY with the BUY that should exist (no tolerance)
         if(existingPrice == expectedBuyPrice && existingVolume == expectedBuyVolume)
         {
            matchesBuy = true;

            if(DebugMode)
               Print("BUY in book matches EXACTLY the calculated BUY!");
         }
      }
      else if(existingType == ORDER_TYPE_SELL_LIMIT)
      {
         // Compare EXACTLY with the SELL that should exist (no tolerance)
         if(existingPrice == expectedSellPrice && existingVolume == expectedSellVolume)
         {
            matchesSell = true;

            if(DebugMode)
               Print("SELL in book matches EXACTLY the calculated SELL!");
         }
      }
   }

   //===== STEP 4: Decision - Create only 1 or create 2? =====

   // CASE A: Matches -> Create ONLY the missing one
   if(matchesBuy || matchesSell)
   {
      if(DebugMode)
         Print("Order in book is correct. Creating only the missing one...");

      // If BUY matches -> create only SELL (if it exists in array)
      if(matchesBuy && smallestSellIndex >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, expectedSellVolume, 0,
                            expectedSellPrice, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[smallestSellIndex].comment))
         {
            ulong createdTicket = trade.ResultOrder();
            originalOrders[smallestSellIndex].ticket = createdTicket;

            if(DebugMode)
               Print("  SELL created: ", expectedSellPrice, " vol: ", expectedSellVolume, " #", createdTicket);
         }
         else
         {
            Print("  Error creating SELL: ", trade.ResultRetcode());
         }
      }
      // If SELL matches -> create only BUY (if it exists in array)
      else if(matchesSell && largestBuyIndex >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, expectedBuyVolume, 0,
                            expectedBuyPrice, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[largestBuyIndex].comment))
         {
            ulong createdTicket = trade.ResultOrder();
            originalOrders[largestBuyIndex].ticket = createdTicket;

            if(DebugMode)
               Print("  BUY created: ", expectedBuyPrice, " vol: ", expectedBuyVolume, " #", createdTicket);
         }
         else
         {
            Print("  Error creating BUY: ", trade.ResultRetcode());
         }
      }
   }
   // CASE B: Does NOT match -> Cancel EVERYTHING + Create the ones that exist in array
   else
   {
      if(DebugMode)
         Print("Order in book does NOT match. Cancelling ALL and recreating...");

      // Cancel ALL EA orders
      CancelAllEAOrders();

      // v3.18: Wait until orders are effectively cancelled (max 1 second)
      int attempts = 0;
      while(CountEAOrders() > 0 && attempts < 20)
      {
         Sleep(50);
         attempts++;
      }

      if(DebugMode && attempts > 0)
         Print("  Waited ", attempts * 50, "ms for cancellations");

      // Create BUY (only if exists in array)
      if(largestBuyIndex >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, expectedBuyVolume, 0,
                            expectedBuyPrice, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[largestBuyIndex].comment))
         {
            ulong createdTicket = trade.ResultOrder();
            originalOrders[largestBuyIndex].ticket = createdTicket;

            if(DebugMode)
               Print("  BUY created: ", expectedBuyPrice, " vol: ", expectedBuyVolume, " #", createdTicket);
         }
         else
         {
            Print("  Error creating BUY: ", trade.ResultRetcode());
         }
      }

      // Create SELL (only if exists in array)
      if(smallestSellIndex >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, expectedSellVolume, 0,
                            expectedSellPrice, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[smallestSellIndex].comment))
         {
            ulong createdTicket = trade.ResultOrder();
            originalOrders[smallestSellIndex].ticket = createdTicket;

            if(DebugMode)
               Print("  SELL created: ", expectedSellPrice, " vol: ", expectedSellVolume, " #", createdTicket);
         }
         else
         {
            Print("  Error creating SELL: ", trade.ResultRetcode());
         }
      }
   }

   if(DebugMode)
      Print("Update finished");
}

//+------------------------------------------------------------------+
//| Cancel all EA orders in MT5                                      |
//+------------------------------------------------------------------+
void CancelAllEAOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            trade.OrderDelete(ticket);

            if(DebugMode)
               Print("  Order #", ticket, " cancelled");
         }
      }
   }

}

//+------------------------------------------------------------------+
//| v3.18: Count EA orders in the book                               |
//+------------------------------------------------------------------+
int CountEAOrders()
{
   int counter = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            counter++;
         }
      }
   }

   return counter;
}

//+------------------------------------------------------------------+
//| v3.28: Count open EA positions (HEDGE and NETTING)               |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int counter = 0;

   if(isHedge)
   {
      // HEDGE: Counts positions filtered by MagicNumber
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               counter++;
            }
         }
      }
   }
   else
   {
      // NETTING: Consolidated position - counts volume in lots
      if(PositionSelect(_Symbol))
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

         if(volume > 0 && volumeMin > 0)
            counter = (int)MathRound(volume / volumeMin);
      }
   }

   return counter;
}

//+------------------------------------------------------------------+
//| v3.28: Get ticket of oldest position (HEDGE)                     |
//+------------------------------------------------------------------+
ulong GetOldestPosition()
{
   ulong oldestTicket = 0;
   datetime oldestTime = D'2099.01.01';

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime < oldestTime)
            {
               oldestTime   = openTime;
               oldestTicket = ticket;
            }
         }
      }
   }

   return oldestTicket;
}

//+------------------------------------------------------------------+
//| v3.29 (revised): Enforce Max Inventory via market order          |
//| - When positions > MaxInventory, sends an opposite market order   |
//|   with volume = k * volumeMin + nextGridOrderVolume (hysteresis)  |
//| - HEDGE: closes the k oldest positions + buffer market order     |
//| - NETTING: reduces the consolidated position                     |
//+------------------------------------------------------------------+
void EnforceMaxInventory(double lastExecutedPrice, ENUM_ORDER_TYPE lastExecutedType)
{
   if(MaxInventory <= 0)
      return;

   int positions = CountOpenPositions();

   if(positions <= MaxInventory)
      return;  // within the limit - nothing to do

   int k = positions - MaxInventory;  // excess in "positions"

   //===== IDENTIFY next pending order on the accumulating side (hysteresis) =====
   double nextVolume = 0.0;

   if(lastExecutedType == ORDER_TYPE_BUY_LIMIT)
   {
      // Accumulating long: next BUY LIMIT is the HIGHEST price below last executed
      double maxPrice = 0;
      int nextIndex   = -1;
      for(int i = 0; i < ArraySize(originalOrders); i++)
      {
         if(originalOrders[i].orderType == ORDER_TYPE_BUY_LIMIT &&
            originalOrders[i].originalPrice < lastExecutedPrice)
         {
            if(originalOrders[i].originalPrice > maxPrice)
            {
               maxPrice  = originalOrders[i].originalPrice;
               nextIndex = i;
            }
         }
      }
      if(nextIndex >= 0)
         nextVolume = originalOrders[nextIndex].volume;
   }
   else if(lastExecutedType == ORDER_TYPE_SELL_LIMIT)
   {
      // Accumulating short: next SELL LIMIT is the LOWEST price above last executed
      double minPrice = DBL_MAX;
      int nextIndex   = -1;
      for(int i = 0; i < ArraySize(originalOrders); i++)
      {
         if(originalOrders[i].orderType == ORDER_TYPE_SELL_LIMIT &&
            originalOrders[i].originalPrice > lastExecutedPrice)
         {
            if(originalOrders[i].originalPrice < minPrice)
            {
               minPrice  = originalOrders[i].originalPrice;
               nextIndex = i;
            }
         }
      }
      if(nextIndex >= 0)
         nextVolume = originalOrders[nextIndex].volume;
   }
   else
   {
      return;  // unknown type
   }

   //===== DETERMINE market order direction (opposite of accumulating side) =====
   ENUM_ORDER_TYPE marketType;
   string side;
   if(lastExecutedType == ORDER_TYPE_BUY_LIMIT)
   {
      marketType = ORDER_TYPE_SELL;  // accumulating long -> sell
      side       = "SELL";
   }
   else
   {
      marketType = ORDER_TYPE_BUY;   // accumulating short -> buy
      side       = "BUY";
   }

   string comment = StringFormat("MaxInv:%d", MaxInventory);
   trade.SetExpertMagicNumber(MagicNumber);

   if(isHedge)
   {
      //===== HEDGE: close the k oldest positions (one by one) =====
      Print("========================================");
      Print("MAX INVENTORY EXCEEDED! Enforcing limit (HEDGE)");
      Print("Open positions: ", positions, " / Max: ", MaxInventory, " (excess k = ", k, ")");
      Print("Volume of next grid order: ", DoubleToString(nextVolume, 2));
      Print("Closing side: ", side);
      Print("Strategy: close k=", k, " oldest positions",
            (nextVolume > 0 ? StringFormat(" + market order of %s lots (hysteresis)", DoubleToString(nextVolume, 2)) : ""));

      int closed = 0;
      for(int step = 0; step < k && step < 1000; step++)
      {
         ulong oldestTicket = GetOldestPosition();
         if(oldestTicket == 0)
            break;

         if(trade.PositionClose(oldestTicket))
         {
            closed++;
            if(DebugMode)
               Print("  Position #", oldestTicket, " closed (", closed, "/", k, ")");
         }
         else
         {
            Print("Error closing position #", oldestTicket, ": ",
                  trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
            break;
         }
         Sleep(50);
      }

      // Hysteresis buffer: extra market order with volume of next grid order
      if(nextVolume > 0)
      {
         double bufferVolume = RoundVolume(nextVolume);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         bool ok = false;
         if(marketType == ORDER_TYPE_SELL)
            ok = trade.Sell(bufferVolume, _Symbol, bid, 0, 0, comment);
         else
            ok = trade.Buy(bufferVolume, _Symbol, ask, 0, 0, comment);

         if(ok)
            Print("Hysteresis buffer (HEDGE): ", side, " market order of ",
                  DoubleToString(bufferVolume, 2), " lots sent");
         else
            Print("Error sending hysteresis buffer: ",
                  trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }

      Print("Positions now: ", CountOpenPositions(), " / Max: ", MaxInventory);
      Print("========================================");
   }
   else
   {
      //===== NETTING: single opposite market order =====
      double volumeMin   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double totalVolume = RoundVolume(k * volumeMin + nextVolume);

      if(totalVolume <= 0)
         return;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      Print("========================================");
      Print("MAX INVENTORY EXCEEDED! Enforcing limit (NETTING)");
      Print("Open positions: ", positions, " / Max: ", MaxInventory, " (excess k = ", k, ")");
      Print("Volume of next grid order: ", DoubleToString(nextVolume, 2));
      Print("Market volume: ", DoubleToString(totalVolume, 2),
            " (= k*", DoubleToString(volumeMin, 2), " + v_next)");
      Print("Side: ", side);

      bool ok = false;
      if(marketType == ORDER_TYPE_SELL)
         ok = trade.Sell(totalVolume, _Symbol, bid, 0, 0, comment);
      else
         ok = trade.Buy(totalVolume, _Symbol, ask, 0, 0, comment);

      if(ok)
      {
         Print("Market order sent. Ticket: #", trade.ResultOrder());
         Print("Positions now: ", CountOpenPositions(), " / Max: ", MaxInventory);
      }
      else
      {
         Print("Error sending market order: ",
               trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
      Print("========================================");
   }
}

//+------------------------------------------------------------------+
//| Remove order from array by TICKET                                |
//+------------------------------------------------------------------+
void RemoveOrderByTicket(ulong ticketToRemove)
{
   int index = FindOrderByTicket(ticketToRemove);

   if(index < 0)
   {
      if(DebugMode)
         Print("Ticket #", ticketToRemove, " not found for removal");
      return;
   }

   if(DebugMode)
      Print("Removing order from array: ticket #", ticketToRemove,
            " price: ", DoubleToString(originalOrders[index].originalPrice, _Digits));

   // Shift remaining elements back
   for(int j = index; j < ArraySize(originalOrders) - 1; j++)
   {
      originalOrders[j] = originalOrders[j + 1];
   }

   // Resize array
   ArrayResize(originalOrders, ArraySize(originalOrders) - 1);
}

//+------------------------------------------------------------------+
//| Cancel pending orders                                            |
//+------------------------------------------------------------------+
void CancelPendingOrders()
{
   Sleep(200);

   ulong tickets[];
   ArrayResize(tickets, 0);

   // Collect tickets
   int total = OrdersTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }

   if(DebugMode)
      Print("Cancelling ", ArraySize(tickets), " pending orders");

   // Cancel orders
   for(int i = 0; i < ArraySize(tickets); i++)
   {
      if(!OrderSelect(tickets[i]))
         continue;

      bool success = false;
      for(int attempt = 1; attempt <= 3 && !success; attempt++)
      {
         if(trade.OrderDelete(tickets[i]))
         {
            success = true;
            if(DebugMode)
               Print("Order #", tickets[i], " cancelled");
         }
         else
         {
            Sleep(100);
         }
      }

      Sleep(100);
   }

   if(DebugMode)
      Print("Cancellation finished");
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void ClosePositions()
{
   int total = PositionsTotal();

   Print("Closing positions. Total: ", total);

   ulong tickets[];
   ArrayResize(tickets, 0);

   // Collect tickets
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }

   // Close positions
   for(int i = 0; i < ArraySize(tickets); i++)
   {
      if(!PositionSelectByTicket(tickets[i]))
         continue;

      bool success = false;
      for(int attempt = 1; attempt <= 3 && !success; attempt++)
      {
         if(trade.PositionClose(tickets[i]))
         {
            success = true;
            Print("Position #", tickets[i], " closed");
         }
         else
         {
            Sleep(200);
         }
      }

      Sleep(200);
   }

   Print("Position closing finished");
}

//+------------------------------------------------------------------+
//| Get total profit/loss (HEDGE and NETTING)                        |
//| Includes: Floating profit + closed trades profit of the day      |
//+------------------------------------------------------------------+
double GetTotalProfitLoss()
{
   double floatingProfit = 0;
   double closedProfit   = 0;

   //========== PART 1: FLOATING PROFIT (open positions) ==========
   if(isHedge)
   {
      // HEDGE: Filter by MagicNumber (multiple EAs may run on same symbol)
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               double profit = PositionGetDouble(POSITION_PROFIT);
               double swap   = PositionGetDouble(POSITION_SWAP);

               floatingProfit += (profit + swap);

               if(DebugMode)
                  Print("Position #", ticket, ": Profit=", DoubleToString(profit, 2),
                        ", Swap=", DoubleToString(swap, 2));
            }
         }
      }
   }
   else
   {
      // NETTING: Take profit from consolidated position of the symbol
      if(PositionSelect(_Symbol))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         double swap   = PositionGetDouble(POSITION_SWAP);

         floatingProfit = profit + swap;

         if(DebugMode)
            Print("NETTING floating position: Profit=", DoubleToString(profit, 2),
                  ", Swap=", DoubleToString(swap, 2));
      }
   }

   //========== PART 2: PROFIT FROM CLOSED TRADES OF THE DAY ==========
   MqlDateTime currentTime;
   TimeCurrent(currentTime);

   // Beginning of current day
   MqlDateTime dayStart;
   dayStart.year = currentTime.year;
   dayStart.mon  = currentTime.mon;
   dayStart.day  = currentTime.day;
   dayStart.hour = 0;
   dayStart.min  = 0;
   dayStart.sec  = 0;

   datetime dayStartDate = StructToTime(dayStart);
   datetime endDate      = TimeCurrent() + 3600; // 1 hour margin

   // v3.21: If profit/loss reset happened today, use that timestamp
   // This allows "Close and recreate grid" to reset the counter
   datetime startDate = dayStartDate;
   if(lastProfitLossReset > dayStartDate)
   {
      startDate = lastProfitLossReset;
      if(DebugMode)
         Print("Using reset timestamp: ", TimeToString(startDate));
   }

   // Load history deals for the period
   if(HistorySelect(startDate, endDate))
   {
      int totalDeals = HistoryDealsTotal();

      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > 0)
         {
            string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);

            // Check if symbol matches
            if(dealSymbol != _Symbol)
               continue;

            // In HEDGE, also filter by MagicNumber
            if(isHedge)
            {
               long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               if(dealMagic != MagicNumber)
                  continue;
            }

            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

            // Take profit only from exit operations (closing)
            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               double dealProfit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               double dealSwap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
               double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

               closedProfit += (dealProfit + dealSwap + dealCommission);

               if(DebugMode)
                  Print("Deal #", dealTicket, " (closed): Profit=", DoubleToString(dealProfit, 2),
                        ", Swap=", DoubleToString(dealSwap, 2),
                        ", Commission=", DoubleToString(dealCommission, 2));
            }
         }
      }
   }

   double totalProfit = floatingProfit + closedProfit;

   if(DebugMode)
      Print("Total Profit (", (isHedge ? "HEDGE" : "NETTING"), "): Floating=",
            DoubleToString(floatingProfit, 2), " + Closed=", DoubleToString(closedProfit, 2),
            " = ", DoubleToString(totalProfit, 2));

   return totalProfit;
}

//+------------------------------------------------------------------+
//| v3.29: Enter Cooldown mode after stop loss                       |
//+------------------------------------------------------------------+
void EnterCooldown()
{
   currentAttempt++;

   if(currentAttempt > MaxConsecutiveAttempts)
   {
      // Attempts exhausted -> deactivate EA for the day
      Print("========================================");
      Print("COOLDOWN: ", currentAttempt - 1, " consecutive stops. EA DEACTIVATED for the day.");
      Print("========================================");

      robotActive        = false;
      targetReachedToday = true;
      inCooldown         = false;
      UpdateVisualStatus();

      CancelAllEAOrders(); Sleep(300);
      ClosePositions();    Sleep(500);
      CancelAllEAOrders(); Sleep(300);

      SaveGridState();
      return;
   }

   // Exponential backoff: base * 2^(attempt-1)
   int multiplier = 1;
   for(int i = 1; i < currentAttempt; i++)
      multiplier *= 2;

   cooldownSeconds = InitialPauseMinutes * 60 * multiplier;
   inCooldown      = true;
   cooldownStart   = TimeCurrent();

   Print("========================================");
   Print("COOLDOWN ACTIVATED! Attempt ", currentAttempt, "/", MaxConsecutiveAttempts);
   Print("Pause of ", cooldownSeconds / 60, " minutes");
   Print("Expected return: ", TimeToString(cooldownStart + cooldownSeconds, TIME_DATE|TIME_SECONDS));
   Print("========================================");

   // Close everything and pause
   CancelAllEAOrders(); Sleep(300);
   ClosePositions();    Sleep(500);
   CancelAllEAOrders(); Sleep(300);

   // Third safety pass
   int remainingOrders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         remainingOrders++;
      }
   }
   if(remainingOrders > 0)
   {
      CancelPendingOrders();
      Sleep(500);
   }

   SaveGridState();
   UpdateVisualStatus();
}

//+------------------------------------------------------------------+
//| v3.29: Check whether cooldown expired                            |
//+------------------------------------------------------------------+
void CheckCooldown()
{
   if(!inCooldown) return;

   datetime now = TimeCurrent();
   int elapsedTime = (int)(now - cooldownStart);

   if(elapsedTime < cooldownSeconds)
      return;

   // COOLDOWN EXPIRED -> RESUME OPERATIONS
   Print("========================================");
   Print("COOLDOWN EXPIRED! Resuming operations...");
   Print("Attempt ", currentAttempt, "/", MaxConsecutiveAttempts);
   Print("========================================");

   inCooldown = false;

   // Reset profit/loss control for new cycle
   lastProfitLossReset = TimeCurrent();
   breakEvenActivated  = false;
   dynamicLoss         = 0;
   trailingBaseLevel   = 0;

   // Clear array and recreate grid
   ArrayResize(originalOrders, 0);

   if(ReuseGridAfterPause)
   {
      string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
      if(FileIsExist(fileName, FILE_COMMON))
      {
         Print("Reusing previous grid from CSV");
         LoadPreviousGrid();
      }
      else
      {
         Print("CSV not found, creating new grid");
         CreateInitialGrid();
      }
   }
   else
   {
      CreateInitialGrid();
   }

   UpdateVisualStatus();
}

//+------------------------------------------------------------------+
//| Check profit/loss target                                         |
//+------------------------------------------------------------------+
void CheckProfitLossTarget()
{
   // Works both in HEDGE and NETTING
   if(ProfitTarget <= 0 && MaxLoss >= 0)
      return;

   double currentProfitLoss = GetTotalProfitLoss();

   //========== PROFIT CHECK ==========
   if(ProfitTarget > 0 && currentProfitLoss >= ProfitTarget)
   {
      Print("========================================");
      Print("PROFIT TARGET REACHED!");
      Print("Current profit: $ ", DoubleToString(currentProfitLoss, 2));
      Print("Configured target: $ ", DoubleToString(ProfitTarget, 2));
      Print("========================================");

      // v3.29: Profit reached resets the cooldown attempt counter
      currentAttempt = 0;

      ExecuteTargetAction();
      return;
   }

   //========== v3.24: BREAK EVEN BY VALUE ==========
   // When profit reaches a fixed $ value, loss is reconfigured to zero
   if(UseBreakEven && !breakEvenActivated && BreakEvenValue > 0 && MaxLoss < 0)
   {
      if(currentProfitLoss >= BreakEvenValue)
      {
         breakEvenActivated = true;
         dynamicLoss        = 0;  // Loss reset to zero!
         trailingBaseLevel  = currentProfitLoss;  // Base for trailing

         Print("========================================");
         Print("BREAK EVEN ACTIVATED!");
         Print("Current profit: $ ", DoubleToString(currentProfitLoss, 2));
         Print("Activation level: $ ", DoubleToString(BreakEvenValue, 2));
         Print("Dynamic loss: $ ", DoubleToString(dynamicLoss, 2), " (was $ ", DoubleToString(MaxLoss, 2), ")");
         Print("========================================");
      }
   }

   //========== v3.22: DYNAMIC TRAILING LOSS ==========
   // For each $X profit rise, loss rises by $X
   if(UseTrailingLoss && breakEvenActivated && TrailingLossValue > 0)
   {
      double gainSinceBreakEven = currentProfitLoss - trailingBaseLevel;

      if(gainSinceBreakEven > 0)
      {
         // Compute how many trailing "steps" we have climbed
         int trailingSteps = (int)MathFloor(gainSinceBreakEven / TrailingLossValue);
         double newDynamicLoss = trailingSteps * TrailingLossValue;

         // Only update if it went up (never down)
         if(newDynamicLoss > dynamicLoss)
         {
            double previousLoss = dynamicLoss;
            dynamicLoss = newDynamicLoss;

            Print("TRAILING LOSS UPDATED!");
            Print("Current profit: $ ", DoubleToString(currentProfitLoss, 2));
            Print("Gain since Break Even: $ ", DoubleToString(gainSinceBreakEven, 2));
            Print("Dynamic loss: $ ", DoubleToString(previousLoss, 2), " -> $ ", DoubleToString(dynamicLoss, 2));
         }
      }
   }

   //========== LOSS CHECK ==========
   // v3.22: Logic fixed for Break Even and Trailing Loss
   // - Without Break Even: closes if profit <= MaxLoss (negative, e.g. -50)
   // - With Break Even: closes if profit <= dynamicLoss (positive = guaranteed profit!)

   if(breakEvenActivated)
   {
      // With Break Even active, dynamicLoss is the GUARANTEED MINIMUM PROFIT
      if(currentProfitLoss <= dynamicLoss)
      {
         Print("========================================");
         Print("GUARANTEED MINIMUM PROFIT REACHED!");
         Print("Current profit: $ ", DoubleToString(currentProfitLoss, 2));
         Print("Guaranteed minimum profit: $ ", DoubleToString(dynamicLoss, 2));
         Print("(Original loss was: $ ", DoubleToString(MaxLoss, 2), ")");
         Print("========================================");

         ExecuteTargetAction();
         return;
      }
   }
   else
   {
      // Without Break Even, use original maximum loss
      if(MaxLoss < 0 && currentProfitLoss <= MaxLoss)
      {
         Print("========================================");
         Print("MAXIMUM LOSS LIMIT REACHED!");
         Print("Current loss: $ ", DoubleToString(currentProfitLoss, 2));
         Print("Configured limit: $ ", DoubleToString(MaxLoss, 2));
         Print("========================================");

         // v3.29: Specific action for stop loss (independent of profit)
         if(ActionAfterStopLoss == STOP_ACTION_COOLDOWN)
         {
            Print("Action: Cooldown with exponential backoff");
            EnterCooldown();
         }
         else
         {
            ExecuteStopLossAction();
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Execute action on target reached                                 |
//+------------------------------------------------------------------+
void ExecuteTargetAction()
{
   Print("Executing action: ", EnumToString(ActionOnTarget));

   // v3.15: DEACTIVATE FIRST so that OnTradeTransaction does not create new orders
   if(ActionOnTarget == ACTION_CLOSE_AND_DEACTIVATE)
   {
      robotActive        = false;
      targetReachedToday = true;  // v3.15: Block automatic reactivation
      UpdateVisualStatus();

      if(DebugMode)
         Print("Robot deactivated BEFORE closing positions/orders");
   }

   Print("Cancelling all pending orders (1st pass)...");
   CancelAllEAOrders();  // v3.15: Use more direct function
   Sleep(300);

   Print("Closing all positions...");
   ClosePositions();
   Sleep(500);

   Print("Cancelling all pending orders (2nd pass)...");
   CancelAllEAOrders();  // v3.15: Double cancellation to be safe
   Sleep(300);

   // v3.15: Third safety pass
   int remainingOrders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         remainingOrders++;
      }
   }

   if(remainingOrders > 0)
   {
      Print("Still ", remainingOrders, " orders remaining. Running 3rd pass...");
      CancelPendingOrders();
      Sleep(500);
   }

   if(ActionOnTarget == ACTION_CLOSE_AND_DEACTIVATE)
   {
      SaveGridState();

      Print("EA DEACTIVATED");
      Print("Automatic reactivation BLOCKED for today");
      if(AutoStart)
         Print("Will only be reactivated NEXT DAY at ", StartTime);
      else
         Print("To reactivate, click 'Start Trading'");
   }
   else if(ActionOnTarget == ACTION_CLOSE_AND_RECREATE)
   {
      // v3.21: Reset timestamp to zero out profit/loss calculation
      // This makes the EA ignore deals before this moment
      lastProfitLossReset = TimeCurrent();
      Print("Profit/Loss reset. New period starts at: ", TimeToString(lastProfitLossReset));

      // v3.22: Reset Break Even and Trailing Loss variables
      breakEvenActivated = false;
      dynamicLoss        = 0;
      trailingBaseLevel  = 0;
      Print("Break Even and Trailing Loss reset for new grid");

      Print("Creating new grid...");
      Sleep(1000);
      CreateInitialGrid();

      Print("NEW GRID CREATED");
      Print("EA continues active and operating");
   }

   Print("========================================");
}

//+------------------------------------------------------------------+
//| v3.29: Execute Stop Loss specific action                         |
//| Independent of ActionOnTarget (which controls only profit)       |
//+------------------------------------------------------------------+
void ExecuteStopLossAction()
{
   Print("Executing stop loss action: ", EnumToString(ActionAfterStopLoss));

   // If deactivating, mark BEFORE closing (avoids OnTradeTransaction creating orders)
   if(ActionAfterStopLoss == STOP_ACTION_DEACTIVATE)
   {
      robotActive        = false;
      targetReachedToday = true;
      UpdateVisualStatus();

      if(DebugMode)
         Print("Robot deactivated BEFORE closing positions/orders (stop loss)");
   }

   // Close everything (same logic as ExecuteTargetAction)
   Print("Cancelling all pending orders (1st pass)...");
   CancelAllEAOrders();
   Sleep(300);

   Print("Closing all positions...");
   ClosePositions();
   Sleep(500);

   Print("Cancelling all pending orders (2nd pass)...");
   CancelAllEAOrders();
   Sleep(300);

   // Third safety pass
   int remainingOrders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         remainingOrders++;
      }
   }

   if(remainingOrders > 0)
   {
      Print("Still ", remainingOrders, " orders remaining. Running 3rd pass...");
      CancelPendingOrders();
      Sleep(500);
   }

   if(ActionAfterStopLoss == STOP_ACTION_DEACTIVATE)
   {
      SaveGridState();

      Print("EA DEACTIVATED after stop loss");
      Print("Automatic reactivation BLOCKED for today");
      if(AutoStart)
         Print("Will only be reactivated NEXT DAY at ", StartTime);
      else
         Print("To reactivate, click 'Start Trading'");
   }
   else if(ActionAfterStopLoss == STOP_ACTION_RECREATE)
   {
      lastProfitLossReset = TimeCurrent();
      Print("Profit/Loss reset. New period starts at: ", TimeToString(lastProfitLossReset));

      breakEvenActivated = false;
      dynamicLoss        = 0;
      trailingBaseLevel  = 0;
      Print("Break Even and Trailing Loss reset for new grid");

      Print("Creating new grid after stop loss...");
      Sleep(1000);
      CreateInitialGrid();

      Print("NEW GRID CREATED after stop loss");
      Print("EA continues active and operating");
   }

   Print("========================================");
}

//+------------------------------------------------------------------+
//| v3.23: SYNC WITH SERVER after reconnection                       |
//| Flow: Analyze deals -> Fix array -> Save CSV -> Cancel           |
//|       orders -> Restart with previous grid                       |
//+------------------------------------------------------------------+
void SyncWithServer()
{
   // v3.29: Do not sync during cooldown
   if(inCooldown)
   {
      Print("Sync skipped - EA in cooldown");
      return;
   }

   Print("========================================");
   Print("STARTING SERVER SYNC");
   Print("========================================");

   // v3.23: Use disconnection timestamp as window start
   datetime windowStart = disconnectionTimestamp;

   if(windowStart == 0)
   {
      Print("Disconnection timestamp not set - using 1 hour ago");
      windowStart = TimeCurrent() - 3600;
   }

   datetime now = TimeCurrent();

   Print("Sync window:");
   Print("   From: ", TimeToString(windowStart, TIME_DATE|TIME_SECONDS));
   Print("   To:   ", TimeToString(now, TIME_DATE|TIME_SECONDS));

   if(!HistorySelect(windowStart, now))
   {
      Print("Error loading deals history: ", GetLastError());
      return;
   }

   //========== STEP 1: COLLECT DEALS OF THE PERIOD ==========
   double buyVolumeTotal = 0;
   double sellVolumeTotal = 0;
   double buyExecPrice = 0;
   double sellExecPrice = 0;
   double buyOriginalVolume = 0;
   double sellOriginalVolume = 0;
   int buyIndex  = -1;
   int sellIndex = -1;

   int totalDeals = HistoryDealsTotal();
   Print("Total deals in period: ", totalDeals);

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;

      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != MagicNumber) continue;

      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(dealSymbol != _Symbol) continue;

      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

      double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double dealPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);

      if(dealType == DEAL_TYPE_BUY)
      {
         buyVolumeTotal += dealVolume;
         buyExecPrice = dealPrice;
         Print("   BUY executed: ", DoubleToString(dealVolume, 2), " @ ", DoubleToString(dealPrice, _Digits));
      }
      else
      {
         sellVolumeTotal += dealVolume;
         sellExecPrice = dealPrice;
         Print("   SELL executed: ", DoubleToString(dealVolume, 2), " @ ", DoubleToString(dealPrice, _Digits));
      }
   }

   // If no deals, check book integrity and exit
   if(buyVolumeTotal == 0 && sellVolumeTotal == 0)
   {
      Print("No deals to process");

      // v3.27: Check if extreme orders exist in book
      // The previous grid creation may have failed before disconnect
      int ordersInBook = CountEAOrders();
      Print("Checking book integrity... Orders found: ", ordersInBook);

      if(ordersInBook < 2)
      {
         Print("Incomplete book! Recreating extreme orders...");
         InsertExtremeOrders();
         Print("Extreme orders verified/recreated");
      }
      else
      {
         Print("Book is intact");
      }

      disconnectionTimestamp = 0;  // v3.23: Reset for next disconnection
      return;
   }

   //========== STEP 2: FIND ORDERS IN ARRAY ==========
   if(buyVolumeTotal > 0)
   {
      buyIndex = FindOrderByPriceAndType(buyExecPrice, ORDER_TYPE_BUY_LIMIT);
      if(buyIndex >= 0)
         buyOriginalVolume = originalOrders[buyIndex].volume;
   }

   if(sellVolumeTotal > 0)
   {
      sellIndex = FindOrderByPriceAndType(sellExecPrice, ORDER_TYPE_SELL_LIMIT);
      if(sellIndex >= 0)
         sellOriginalVolume = originalOrders[sellIndex].volume;
   }

   //========== STEP 3: IDENTIFY AND PROCESS CASE ==========
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Print("-------------------------------------");
   Print("Analysis:");
   Print("   BUY executed: ", DoubleToString(buyVolumeTotal, 2), " of ", DoubleToString(buyOriginalVolume, 2));
   Print("   SELL executed: ", DoubleToString(sellVolumeTotal, 2), " of ", DoubleToString(sellOriginalVolume, 2));
   Print("   Current price: ", DoubleToString(currentPrice, _Digits));

   bool buyFull     = (buyVolumeTotal > 0 && buyVolumeTotal >= buyOriginalVolume - 0.001);
   bool sellFull    = (sellVolumeTotal > 0 && sellVolumeTotal >= sellOriginalVolume - 0.001);
   bool buyPartial  = (buyVolumeTotal > 0 && buyVolumeTotal < buyOriginalVolume - 0.001);
   bool sellPartial = (sellVolumeTotal > 0 && sellVolumeTotal < sellOriginalVolume - 0.001);

   //---------- CASE A: One order fully executed ----------
   if((buyFull && sellVolumeTotal == 0) || (sellFull && buyVolumeTotal == 0))
   {
      Print("CASE A: One order fully executed");

      if(buyFull && buyIndex >= 0)
      {
         // Remove BUY from array and insert gain (SELL)
         double gainPrice = buyExecPrice + PipsToPoints(GainPips);
         Print("   Removing BUY @ ", DoubleToString(buyExecPrice, _Digits));
         Print("   Inserting SELL gain @ ", DoubleToString(gainPrice, _Digits));

         originalOrders[buyIndex].volume = 0; // Mark for removal
         AddOrderToArray(ORDER_TYPE_SELL_LIMIT, gainPrice, buyOriginalVolume, "Initial Grid");
      }
      else if(sellFull && sellIndex >= 0)
      {
         // Remove SELL from array and insert gain (BUY)
         double gainPrice = sellExecPrice - PipsToPoints(GainPips);
         Print("   Removing SELL @ ", DoubleToString(sellExecPrice, _Digits));
         Print("   Inserting BUY gain @ ", DoubleToString(gainPrice, _Digits));

         originalOrders[sellIndex].volume = 0; // Mark for removal
         AddOrderToArray(ORDER_TYPE_BUY_LIMIT, gainPrice, sellOriginalVolume, "Initial Grid");
      }
   }
   //---------- CASE B: Two orders fully executed ----------
   // Both executed = complete cycle = position flat = do NOT touch array
   else if(buyFull && sellFull)
   {
      Print("CASE B: Two orders fully executed");
      Print("   Complete cycle - position flat");
      Print("   Keeping both orders in array (no change)");
   }
   //---------- CASE C: One order partially executed ----------
   else if((buyPartial && sellVolumeTotal == 0) || (sellPartial && buyVolumeTotal == 0))
   {
      Print("CASE C: One order partially executed");

      if(buyPartial && buyIndex >= 0)
      {
         double remainingVolume = buyOriginalVolume - buyVolumeTotal;
         double gainPrice = buyExecPrice + PipsToPoints(GainPips);

         Print("   BUY partial: ", DoubleToString(buyVolumeTotal, 2), " of ", DoubleToString(buyOriginalVolume, 2));
         Print("   Updating volume to: ", DoubleToString(remainingVolume, 2));
         Print("   Inserting SELL gain: ", DoubleToString(buyVolumeTotal, 2), " @ ", DoubleToString(gainPrice, _Digits));

         originalOrders[buyIndex].volume = remainingVolume;
         AddOrderToArray(ORDER_TYPE_SELL_LIMIT, gainPrice, buyVolumeTotal, "Initial Grid");
      }
      else if(sellPartial && sellIndex >= 0)
      {
         double remainingVolume = sellOriginalVolume - sellVolumeTotal;
         double gainPrice = sellExecPrice - PipsToPoints(GainPips);

         Print("   SELL partial: ", DoubleToString(sellVolumeTotal, 2), " of ", DoubleToString(sellOriginalVolume, 2));
         Print("   Updating volume to: ", DoubleToString(remainingVolume, 2));
         Print("   Inserting BUY gain: ", DoubleToString(sellVolumeTotal, 2), " @ ", DoubleToString(gainPrice, _Digits));

         originalOrders[sellIndex].volume = remainingVolume;
         AddOrderToArray(ORDER_TYPE_BUY_LIMIT, gainPrice, sellVolumeTotal, "Initial Grid");
      }
   }
   //---------- CASE D: Two orders partially executed ----------
   else if(buyPartial && sellPartial)
   {
      Print("CASE D: Two orders partially executed");

      if(MathAbs(buyVolumeTotal - sellVolumeTotal) < 0.001)
      {
         // Equal quantities: do not touch array
         Print("   Equal quantities - no change to array");
      }
      else
      {
         // Different quantities: compute net
         double net = MathAbs(buyVolumeTotal - sellVolumeTotal);

         if(sellVolumeTotal > buyVolumeTotal)
         {
            // More SELL executed: keep BUY, fix SELL, insert BUY gain
            Print("   Net: ", DoubleToString(net, 2), " SELL");

            if(sellIndex >= 0)
            {
               double newSellVolume = sellOriginalVolume - net;
               double gainPrice = sellExecPrice - PipsToPoints(GainPips);

               Print("   Keeping BUY: ", DoubleToString(buyOriginalVolume, 2));
               Print("   Fixing SELL: ", DoubleToString(sellOriginalVolume, 2), " -> ", DoubleToString(newSellVolume, 2));
               Print("   Inserting BUY gain: ", DoubleToString(net, 2), " @ ", DoubleToString(gainPrice, _Digits));

               originalOrders[sellIndex].volume = newSellVolume;
               AddOrderToArray(ORDER_TYPE_BUY_LIMIT, gainPrice, net, "Initial Grid");
            }
         }
         else
         {
            // More BUY executed: keep SELL, fix BUY, insert SELL gain
            Print("   Net: ", DoubleToString(net, 2), " BUY");

            if(buyIndex >= 0)
            {
               double newBuyVolume = buyOriginalVolume - net;
               double gainPrice = buyExecPrice + PipsToPoints(GainPips);

               Print("   Keeping SELL: ", DoubleToString(sellOriginalVolume, 2));
               Print("   Fixing BUY: ", DoubleToString(buyOriginalVolume, 2), " -> ", DoubleToString(newBuyVolume, 2));
               Print("   Inserting SELL gain: ", DoubleToString(net, 2), " @ ", DoubleToString(gainPrice, _Digits));

               originalOrders[buyIndex].volume = newBuyVolume;
               AddOrderToArray(ORDER_TYPE_SELL_LIMIT, gainPrice, net, "Initial Grid");
            }
         }
      }
   }

   //========== STEP 4: CLEAN UP ZERO-VOLUME ORDERS ==========
   CleanZeroVolumeOrders();

   //========== STEP 5: RESET TICKETS AND COMMENTS, SAVE CSV ==========
   Print("-------------------------------------");
   Print("Resetting tickets and saving CSV...");

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      originalOrders[i].ticket  = 0;
      originalOrders[i].comment = "Initial Grid";
   }

   SaveGridState();

   //========== STEP 6: CANCEL ALL ORDERS ==========
   Print("Cancelling all orders in book...");
   CancelAllEAOrders();
   Sleep(500);

   //========== STEP 7: RESTART WITH PREVIOUS GRID ==========
   Print("Restarting with previous grid...");
   InsertExtremeOrders();

   disconnectionTimestamp = 0;  // v3.23: Reset for next disconnection

   Print("========================================");
   Print("SYNC COMPLETED SUCCESSFULLY");
   Print("Array: ", ArraySize(originalOrders), " orders");
   Print("Book: ", CountEAOrders(), " orders");
   Print("========================================");
}

//+------------------------------------------------------------------+
//| v3.23: Remove orders with zero volume from array                 |
//+------------------------------------------------------------------+
void CleanZeroVolumeOrders()
{
   int i = 0;
   while(i < ArraySize(originalOrders))
   {
      if(originalOrders[i].volume <= 0.001)
      {
         // Remove this element shifting the others
         for(int j = i; j < ArraySize(originalOrders) - 1; j++)
         {
            originalOrders[j] = originalOrders[j + 1];
         }
         ArrayResize(originalOrders, ArraySize(originalOrders) - 1);
         // Do not increment i; next element is now at the current position
      }
      else
      {
         i++;
      }
   }

   if(DebugMode)
      Print("Array cleaned. Remaining orders: ", ArraySize(originalOrders));
}

//+------------------------------------------------------------------+
//| Create control panel                                             |
//+------------------------------------------------------------------+
void CreatePanel()
{
   // Panel background
   ObjectCreate(0, "Panel_Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BGCOLOR, panelColor);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BACK, false);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_HIDDEN, true);

   // Title
   ObjectCreate(0, "Panel_Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_XDISTANCE, panelX + 60);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_YDISTANCE, panelY + 5);
   ObjectSetString(0, "Panel_Title", OBJPROP_TEXT, "Gradient Grid v3.29");
   ObjectSetString(0, "Panel_Title", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "Panel_Title", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_SELECTABLE, false);

   // Start button
   ObjectCreate(0, "Panel_BtnStart", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_YDISTANCE, panelY + 30);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnStart", OBJPROP_TEXT, "Start Trading");
   ObjectSetString(0, "Panel_BtnStart", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, "Panel_BtnStart", OBJPROP_BORDER_COLOR, clrBlack);

   // Activate Without Creating button
   ObjectCreate(0, "Panel_BtnActivateWithoutCreating", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_YDISTANCE, panelY + 70);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnActivateWithoutCreating", OBJPROP_TEXT, "Activate Without Creating");
   ObjectSetString(0, "Panel_BtnActivateWithoutCreating", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, "Panel_BtnActivateWithoutCreating", OBJPROP_BORDER_COLOR, clrBlack);

   // Cancel Orders button
   ObjectCreate(0, "Panel_BtnCancelOrders", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_YDISTANCE, panelY + 110);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnCancelOrders", OBJPROP_TEXT, "Cancel Orders & Deactivate");
   ObjectSetString(0, "Panel_BtnCancelOrders", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, "Panel_BtnCancelOrders", OBJPROP_BORDER_COLOR, clrBlack);

   // Cancel All button
   ObjectCreate(0, "Panel_BtnCancelAll", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_YDISTANCE, panelY + 150);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnCancelAll", OBJPROP_TEXT, "Close All & Deactivate");
   ObjectSetString(0, "Panel_BtnCancelAll", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_BGCOLOR, clrDarkRed);
   ObjectSetInteger(0, "Panel_BtnCancelAll", OBJPROP_BORDER_COLOR, clrBlack);

   // Status label
   ObjectCreate(0, "Panel_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_YDISTANCE, panelY + 190);
   ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, "Status: Inactive");
   ObjectSetString(0, "Panel_Status", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_Status", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_HIDDEN, true);

   // Profit/Loss label (HEDGE and NETTING)
   if(ProfitTarget > 0 || MaxLoss < 0)
   {
      // v3.20: Delete existing object before recreating (MT5 update fix)
      ObjectDelete(0, "Panel_ProfitLoss");
      ObjectCreate(0, "Panel_ProfitLoss", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_YDISTANCE, panelY + 218);
      ObjectSetString(0, "Panel_ProfitLoss", OBJPROP_TEXT, "P/L: $ 0.00");
      ObjectSetString(0, "Panel_ProfitLoss", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_HIDDEN, true);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update visual status                                             |
//+------------------------------------------------------------------+
void UpdateVisualStatus()
{
   // v3.29: Show cooldown state
   if(inCooldown)
   {
      int remainingTime = cooldownSeconds - (int)(TimeCurrent() - cooldownStart);
      if(remainingTime < 0) remainingTime = 0;
      string text = StringFormat("Cooldown %d/%d (%dmin)",
                     currentAttempt, MaxConsecutiveAttempts, remainingTime / 60);
      ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, text);
      ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrOrangeRed);
   }
   else if(robotActive)
   {
      ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, "Status: Active");
      ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrRoyalBlue);
   }
   else
   {
      ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, "Status: Inactive");
      ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrRed);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Profit/Loss panel                                         |
//+------------------------------------------------------------------+
void UpdateProfitLossPanel()
{
   // Works both in HEDGE and NETTING
   if(ProfitTarget <= 0 && MaxLoss >= 0)
      return;

   double currentProfitLoss = GetTotalProfitLoss();
   color labelColor = currentProfitLoss >= 0 ? clrGreen : clrRed;

   // v3.22: Show Break Even and Trailing Loss status
   string text;
   if(breakEvenActivated)
   {
      // dynamicLoss is the GUARANTEED MINIMUM profit (positive value)
      text = StringFormat("P/L: $ %s [Min: $ %s]",
              DoubleToString(currentProfitLoss, 2),
              DoubleToString(dynamicLoss, 2));
      labelColor = clrBlue;  // Blue indicates active protection
   }
   else
   {
      text = StringFormat("P/L: $ %s", DoubleToString(currentProfitLoss, 2));
   }

   ObjectSetString(0, "Panel_ProfitLoss", OBJPROP_TEXT, text);
   ObjectSetInteger(0, "Panel_ProfitLoss", OBJPROP_COLOR, labelColor);
}

//+------------------------------------------------------------------+
//| Check close time                                                 |
//+------------------------------------------------------------------+
void CheckCloseTime()
{
   MqlDateTime time;
   TimeCurrent(time);

   string hourParts[];
   int size = StringSplit(CloseTime, ':', hourParts);

   if(size != 2)
      return;

   int closeHour   = (int)StringToInteger(hourParts[0]);
   int closeMinute = (int)StringToInteger(hourParts[1]);

   bool inWindow = false;

   if(time.hour == closeHour &&
      time.min >= closeMinute &&
      time.min < closeMinute + 15)
   {
      inWindow = true;
   }

   if(inWindow)
   {
      Print("Running scheduled close...");

      // v3.25: Create CSV backup before deactivating
      BackupCSV();

      if(Persistence == PERSISTENCE_CLOSE_ORDERS)
         SaveGridState();

      bool previousStatus = robotActive;
      robotActive = false;
      UpdateVisualStatus();

      if(Persistence == PERSISTENCE_CLOSE_ALL)
      {
         if(DebugMode)
            Print("Closing ALL positions...");

         ClosePositions();
         Sleep(1000);

         if(DebugMode)
            Print("Cancelling ALL pending orders...");

         CancelPendingOrders();
         Sleep(500);
         CancelPendingOrders();
      }
      else if(Persistence == PERSISTENCE_CLOSE_ORDERS)
      {
         if(DebugMode)
            Print("Cancelling pending orders ONLY...");

         SaveGridState();
         CancelPendingOrders();
         Sleep(500);
         CancelPendingOrders();

         robotActive = false;
         UpdateVisualStatus();
         return;
      }
      else if(Persistence == PERSISTENCE_DEACTIVATE)
      {
         robotActive = false;
         UpdateVisualStatus();
         return;
      }

      if(Persistence != PERSISTENCE_CLOSE_ALL)
         robotActive = previousStatus;

      UpdateVisualStatus();

      Print("Close executed at ", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
//| Check start time                                                 |
//+------------------------------------------------------------------+
void CheckStartTime()
{
   if(robotActive)
      return;

   MqlDateTime time;
   TimeCurrent(time);

   // v3.15: Reset target-reached flag when day changes
   // v3.21: Reset also the profit/loss timestamp
   // v3.23: Reset also Break Even and Trailing Loss
   if(lastCheckDay != time.day)
   {
      if(DebugMode)
         Print("New day detected. Resetting target, profit/loss and Break Even/Trailing flags.");

      targetReachedToday  = false;
      lastProfitLossReset = 0;  // v3.21: New day = starts from zero

      // v3.23: Reset Break Even and Trailing Loss for new day
      breakEvenActivated = false;
      dynamicLoss        = 0;
      trailingBaseLevel  = 0;

      // v3.29: Reset cooldown for new day
      inCooldown      = false;
      currentAttempt  = 0;
      cooldownSeconds = 0;

      lastCheckDay = time.day;
   }

   // v3.15: If target was reached today, do NOT reactivate automatically
   if(targetReachedToday)
   {
      if(DebugMode)
         Print("Target already reached today. Automatic reactivation blocked.");
      return;
   }

   string hourParts[];
   int size = StringSplit(StartTime, ':', hourParts);

   if(size != 2)
      return;

   int startHour   = (int)StringToInteger(hourParts[0]);
   int startMinute = (int)StringToInteger(hourParts[1]);

   bool inWindow = false;

   if(time.hour == startHour &&
      time.min >= startMinute &&
      time.min < startMinute + 15)
   {
      inWindow = true;
   }

   if(inWindow)
   {
      Print("Running automatic start...");

      robotActive = true;
      UpdateVisualStatus();

      string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

      if(StartWithPreviousGrid && FileIsExist(fileName, FILE_COMMON))
      {
         LoadPreviousGrid();
      }
      else
      {
         if(DebugMode)
            Print("Previous grid not found. Creating initial grid.");
         CreateInitialGrid();
      }

      Print("Automatic start executed at ", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
//| Button handlers                                                  |
//+------------------------------------------------------------------+
void OnClickBtnStart()
{
   if(robotActive)
      return;

   // v3.15: Manual reset of flag (allows forced reactivation)
   if(targetReachedToday)
   {
      Print("User forced reactivation after target reached");
      targetReachedToday = false;
   }

   // v3.29: Manual cooldown reset
   if(inCooldown)
   {
      Print("User forced reactivation during cooldown");
      inCooldown      = false;
      currentAttempt  = 0;
      cooldownSeconds = 0;
   }

   robotActive = true;
   UpdateVisualStatus();

   string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

   if(StartWithPreviousGrid && FileIsExist(fileName, FILE_COMMON))
   {
      LoadPreviousGrid();
   }
   else
   {
      if(DebugMode)
         Print("Creating initial grid...");
      CreateInitialGrid();
   }

   if(DebugMode)
      Print("Robot activated manually");
}

void OnClickBtnActivateWithoutCreating()
{
   if(robotActive)
      return;

   // v3.19: Load array from CSV to map existing book orders
   string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
   if(FileIsExist(fileName, FILE_COMMON))
   {
      LoadPreviousGrid(false);  // false = do not create orders, only load array
      if(DebugMode)
         Print("Array loaded from CSV (", ArraySize(originalOrders), " orders mapped)");
   }

   robotActive = true;
   UpdateVisualStatus();

   if(DebugMode)
      Print("Robot activated without creating orders");
}

void OnClickBtnCancelOrders()
{
   robotActive = false;

   if(ArraySize(originalOrders) > 0)
      SaveGridState();

   CancelPendingOrders();
   UpdateVisualStatus();

   if(DebugMode)
      Print("Orders cancelled and robot deactivated");
}

void OnClickBtnCancelAll()
{
   robotActive = false;

   CancelPendingOrders();
   ClosePositions();
   UpdateVisualStatus();

   if(DebugMode)
      Print("Orders and positions cancelled");
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetDeviationInPoints(Slippage);
   trade.SetExpertMagicNumber(MagicNumber);

   isHedge = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

   if(DebugMode)
      Print("Account type: ", isHedge ? "HEDGE" : "NETTING");

   if(ProfitTarget > 0 || MaxLoss < 0)
   {
      Print("============================================");
      Print("Profit/Loss control ENABLED");
      Print("Mode: ", isHedge ? "HEDGE (filter by MagicNumber)" : "NETTING (consolidated position)");
      if(ProfitTarget > 0)
         Print("Profit target: $ ", DoubleToString(ProfitTarget, 2));
      if(MaxLoss < 0)
         Print("Loss limit: $ ", DoubleToString(MaxLoss, 2));
      if(!isHedge)
         Print("NETTING: Controls result of the whole symbol");
      Print("============================================");
   }

   // v3.28: Max Inventory log
   if(MaxInventory > 0)
   {
      Print("============================================");
      Print("Max Inventory ENABLED");
      Print("Limit: ", MaxInventory, " positions");
      Print("Protection: opposite market order with hysteresis (k + v_next of grid)");
      Print("Mode: ", isHedge ? "HEDGE (closes oldest positions)" : "NETTING (reduces consolidated)");
      Print("============================================");
   }

   if(BrazilianMode)
   {
      pointsPerPip = Point();
      pipDigits    = _Digits;
   }
   else
   {
      pointsPerPip = _Digits == 3 || _Digits == 5 ? Point() * 10 : Point();
      pipDigits    = _Digits == 3 || _Digits == 5 ? _Digits - 1 : _Digits;
   }

   // Validate lot size
   if(LotSize <= 0)
   {
      Print("Error: Lot size must be greater than zero!");
      return INIT_PARAMETERS_INCORRECT;
   }

   // v3.08: Check minimum lot
   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   if(LotSize < volumeMin)
   {
      Print("============================================");
      Print("ERROR: INVALID LOT SIZE!");
      Print("You configured: ", DoubleToString(LotSize, 2));
      Print("Minimum lot for ", _Symbol, ": ", DoubleToString(volumeMin, 2));
      Print("SOLUTION: Set LotSize >= ", DoubleToString(volumeMin, 2));
      Print("============================================");

      // Show visual alert
      Alert("ERROR: LotSize (", DoubleToString(LotSize, 2),
            ") is less than the allowed minimum (", DoubleToString(volumeMin, 2), ")!");

      return INIT_PARAMETERS_INCORRECT;
   }

   // v3.22: Initialize sync timestamp
   lastSync = TimeCurrent();

   CreatePanel();

   robotActive = (InitialStatus == STATUS_ACTIVE);
   UpdateVisualStatus();

   ArrayResize(originalOrders, 0);

   if(robotActive)
   {
      string fileName = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
      bool csvExists = FileIsExist(fileName, FILE_COMMON);

      if(StartWithPreviousGrid && csvExists)
      {
         if(DebugMode)
            Print("Loading previous grid from CSV...");

         LoadPreviousGrid();
      }
      else
      {
         if(!csvExists && DebugMode)
            Print("CSV not found. Creating initial grid...");
         else if(DebugMode)
            Print("StartWithPreviousGrid = false. Creating new grid...");

         CreateInitialGrid();
      }
   }

   if(DebugMode)
   {
      Print("============================================");
      Print("Linear Gradient Grid v3.29 initialized!");
      Print("v3.29: Cooldown with backoff after stop loss");
      Print("v3.29 (revised): Max Inventory via market order with hysteresis");
      Print("v3.26: Tick size rounding (fixes J/K)");
      Print("v3.20: Fix P/L label (MT5 update)");
      Print("v3.18: Active cancellation verification");
      Print("v3.15: Blocks automatic reactivation after target");
      Print("Handles PARTIAL and COMPLETE fills");
      Print("Points per Pip: ", DoubleToString(pointsPerPip, 8));
      Print("Digits: ", pipDigits);
      Print("Status: ", robotActive ? "Active" : "Inactive");
      Print("============================================");
   }

   // v3.22: Timer to detect disconnect/reconnect
   EventSetTimer(5);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // v3.22: Stop timer
   EventKillTimer();

   if(robotActive || ArraySize(originalOrders) > 0)
   {
      SaveGridState();

      if(DebugMode)
         Print("Grid state saved on EA shutdown");
   }

   ObjectsDeleteAll(0, "Panel_");

   if(DebugMode)
      Print("EA finalized, reason: ", reason);
}

//+------------------------------------------------------------------+
//| v3.22: Timer to detect disconnect/reconnect                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      if(!inDisconnection)
      {
         inDisconnection        = true;
         disconnectionTimestamp = TimeCurrent();  // v3.23: Store exact moment
         Print("DISCONNECT detected via Timer at ", TimeToString(disconnectionTimestamp, TIME_DATE|TIME_SECONDS));
      }
   }
   else
   {
      if(inDisconnection)
      {
         inDisconnection = false;
         Print("========================================");
         Print("RECONNECT detected via Timer!");

         if(robotActive)
         {
            Print("Starting automatic sync...");
            Print("========================================");
            SyncWithServer();
         }
         else
         {
            Print("EA inactive - sync NOT executed");
            Print("========================================");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(AutoStart && !robotActive)
   {
      CheckStartTime();
   }

   if(!robotActive)
   {
      ChartRedraw();
      return;
   }

   if(Persistence != PERSISTENCE_KEEP)
   {
      CheckCloseTime();
   }

   // v3.29: If in cooldown, check whether it expired and skip target check
   if(inCooldown)
   {
      CheckCooldown();
      ChartRedraw();
      return;
   }

   // Check profit/loss target (works in HEDGE and NETTING)
   if(robotActive && (ProfitTarget > 0 || MaxLoss < 0))
   {
      CheckProfitLossTarget();
      UpdateProfitLossPanel();
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "Panel_BtnStart")
         OnClickBtnStart();
      else if(sparam == "Panel_BtnActivateWithoutCreating")
         OnClickBtnActivateWithoutCreating();
      else if(sparam == "Panel_BtnCancelOrders")
         OnClickBtnCancelOrders();
      else if(sparam == "Panel_BtnCancelAll")
         OnClickBtnCancelAll();
   }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - VERSION v3.10 VOLUMES                       |
//| Compares dealVolume vs originalVolume                            |
//| Handles PARTIAL and COMPLETE fills                               |
//| v3.10: Consolidates orders of same type/price                    |
//| v3.10 Item 6: Does not reset ticket (traceability)               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Initial validations
   if(!robotActive)
      return;

   // v3.29: Block deal processing during cooldown
   if(inCooldown)
      return;

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong dealTicket = trans.deal;

   if(dealTicket <= 0)
      return;

   if(!HistoryDealSelect(dealTicket))
      return;

   long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);

   if(dealMagic != MagicNumber)
      return;

   string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);

   if(dealSymbol != _Symbol)
      return;

   // Get deal data
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   ulong orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
   double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);  // EXECUTED VOLUME

   // Ignore deals that are not BUY or SELL
   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
      return;

   if(DebugMode)
   {
      Print("========================================");
      Print("DEAL DETECTED!");
      Print("Deal Ticket: ", dealTicket);
      Print("Order Ticket: #", orderTicket);
      Print("Type: ", EnumToString(dealType));
      Print("Executed volume: ", DoubleToString(dealVolume, 2));
      Print("========================================");
   }

   //===== v3.29 (revised): SKIP deals from Max Inventory enforcement =====
   // Orders sent by EnforceMaxInventory() carry the comment "MaxInv:<N>".
   // Those deals must not trigger gain orders nor re-enter the grid flow.
   string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   if(StringFind(dealComment, "MaxInv:") == 0)
   {
      if(DebugMode)
         Print("Max-inventory enforcement deal (MaxInv) skipped by grid flow.");
      return;
   }

   //===== SEARCH order in array by TICKET =====
   int executedOrderIndex = FindOrderByTicket(orderTicket);

   if(executedOrderIndex < 0)
   {
      if(DebugMode)
      {
         Print("========================================");
         Print("ERROR: Order #", orderTicket, " NOT found in array!");
         Print("========================================");
      }
      return;
   }

   // GET ORIGINAL DATA FROM ARRAY
   double originalPrice  = originalOrders[executedOrderIndex].originalPrice;
   double originalVolume = originalOrders[executedOrderIndex].volume;

   if(DebugMode)
   {
      Print("Order found in array!");
      Print("Original price: ", DoubleToString(originalPrice, _Digits));
      Print("Volume in array: ", DoubleToString(originalVolume, 2));
   }

   //===== NEW LOGIC: COMPARE VOLUMES =====

   // Is this a PARTIAL or COMPLETE fill?
   double tolerance = 0.001; // Tolerance for double comparison

   if(dealVolume < originalVolume - tolerance)
   {
      // PARTIAL FILL!

      Print("========================================");
      Print("PARTIAL FILL DETECTED!");
      Print("Executed volume: ", DoubleToString(dealVolume, 2));
      Print("Original volume: ", DoubleToString(originalVolume, 2));
      Print("Remaining volume: ", DoubleToString(originalVolume - dealVolume, 2));
      Print("========================================");

      // 1) CREATE opposite order with EXECUTED volume
      double newPrice;
      ENUM_ORDER_TYPE newType;
      string newComment;

      if(dealType == DEAL_TYPE_BUY)
      {
         newPrice   = originalPrice + PipsToPoints(GainPips);
         newType    = ORDER_TYPE_SELL_LIMIT;
         newComment = StringFormat("AutoSell:%I64u", dealTicket);
      }
      else
      {
         newPrice   = originalPrice - PipsToPoints(GainPips);
         newType    = ORDER_TYPE_BUY_LIMIT;
         newComment = StringFormat("AutoBuy:%I64u", dealTicket);
      }

      // v3.10: Add opposite order with consolidation
      AddOrderToArray(newType, newPrice, dealVolume, newComment);

      // 2) UPDATE volume in array (DO NOT remove order!)
      originalOrders[executedOrderIndex].volume = originalVolume - dealVolume;
      // v3.10 Item 6: Do NOT reset ticket (keep tracking)

      if(DebugMode)
         Print("Volume updated in array: ", DoubleToString(originalOrders[executedOrderIndex].volume, 2));
   }
   else
   {
      // COMPLETE FILL!

      Print("========================================");
      Print("COMPLETE FILL!");
      Print("Executed volume: ", DoubleToString(dealVolume, 2));
      Print("Original volume: ", DoubleToString(originalVolume, 2));
      Print("========================================");

      // 1) CREATE opposite order with FULL volume
      double newPrice;
      ENUM_ORDER_TYPE newType;
      string newComment;

      if(dealType == DEAL_TYPE_BUY)
      {
         newPrice   = originalPrice + PipsToPoints(GainPips);
         newType    = ORDER_TYPE_SELL_LIMIT;
         newComment = StringFormat("AutoSell:%I64u", dealTicket);
      }
      else
      {
         newPrice   = originalPrice - PipsToPoints(GainPips);
         newType    = ORDER_TYPE_BUY_LIMIT;
         newComment = StringFormat("AutoBuy:%I64u", dealTicket);
      }

      // v3.10: Add opposite order with consolidation
      AddOrderToArray(newType, newPrice, originalVolume, newComment);

      // 2) REMOVE executed order from array
      RemoveOrderByTicket(orderTicket);

      if(DebugMode)
         Print("Original order removed from array");
   }

   //===== UPDATE the 2 extremes in MT5 =====
   InsertExtremeOrders();

   //===== v3.28: CHECK MAX INVENTORY =====
   // Determine type of the executed order to know market direction
   ENUM_ORDER_TYPE executedOrderType;
   if(dealType == DEAL_TYPE_BUY)
      executedOrderType = ORDER_TYPE_BUY_LIMIT;
   else
      executedOrderType = ORDER_TYPE_SELL_LIMIT;

   EnforceMaxInventory(originalPrice, executedOrderType);

   //===== SAVE state =====
   SaveGridState();

   if(DebugMode)
   {
      Print("========================================");
      Print("PROCESSING COMPLETE!");
      Print("Total orders in array: ", ArraySize(originalOrders));
      if(MaxInventory > 0)
         Print("Open positions: ", CountOpenPositions(), " / Max: ", MaxInventory);
      Print("========================================");
   }
}
