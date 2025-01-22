#if defined _PSAPI_API_included
 #endinput
#endif
#define _PSAPI_API_included

#include <autoexecconfig>
#include <left4dhooks>

#define MIN_FLOAT   -2147483647.0    // I think -2147483648 is lowest but meh, same thing.

#define PSAPI_NOT_ENOUGH_POINTS "Failed! You need \x05%d\x03 more points to buy it! (Σ: \x05%d\x03)"

stock char g_sSINames[][]={"","Smoker","Boomer","Hunter","Spitter","Jockey","Charger"};
stock char g_sSIClassnames[][]={"","smoker","boomer","hunter","spitter","jockey","charger"};

stock char g_sBossNames[][]={"","Smoker","Boomer","Hunter","Spitter","Jockey","Charger","Witch","Tank","Survivor"};
stock char g_sBossClassnames[][]={"","smoker","boomer","hunter","spitter","jockey","charger","witch","tank","survivor"};

enum struct enCategory
{
	int iCategory; // Category number this category belongs to, or -1 for main buy menu.
	char sID[256]; // Identifier between plugins, players cannot see this.
	char sName[64]; // Category Name
	int iBuyFlags; // Must use variable that determines flags that specify when you can buy. BUYFLAG_* in PSAPI_api.inc
}

enum struct enProduct
{
	int iCategory; // Category number this product belongs to, or -1 for main buy menu.
	float fCost; // Cost of this product rounded down.
	int iBuyFlags; // Must use variable that determines flags that specify when you can buy. BUYFLAG_* in PSAPI_api.inc
	char sName[64]; // Product Name
	char sDescription[512]; // Optional Description
	char sAliases[256]; // Aliases, seperated by spaces, to buy directly with !buy <alias>
	char sInfo[256]; // Info that only devs can see.

	float fDelay; // Delay between purchase to obtaining the product.
	float fCooldown; // Cooldown between purchases.
	
	float fNextBuyProduct[MAXPLAYERS + 1]; // Next time each player can buy this product.
}


enum struct enDelayedProduct
{
	Handle timer;
	float fCost;
	int buyerUserId; // Buyer's user ID.
	int targetUserId; // victim of purchase, but his user ID.
	char sAlias[32]; // Alias of product
	char sInfo[256]; // Info that only devs can see.
}


#define NO_DESCRIPTION "" // Simple way to understand the empty space is a description



#define BUYFLAG_NO_DEAD_SURVIVORS	(BUYFLAG_ALIVE|BUYFLAG_INCAP|BUYFLAG_DEAD_INFECTED|BUYFLAG_GHOST)
#define BUYFLAG_ALL_LIFESTATES		(BUYFLAG_ALIVE|BUYFLAG_INCAP|BUYFLAG_DEAD|BUYFLAG_GHOST)
#define BUYFLAG_ANY_ALIVE			(BUYFLAG_ALIVE|BUYFLAG_GHOST|BUYFLAG_INCAP) // Can this product be bought when a player has m_isAlive?
#define BUYFLAG_ALIVE_NO_INCAP			BUYFLAG_ALIVE|BUYFLAG_GHOST // Can this product be bought when a player has m_isAlive?
#define BUYFLAG_ALIVE				(1<<0) // Can this product be bought while you're alive? Ghosts are a third life state for PSAPI
#define BUYFLAG_INCAP				(1<<10) // Can this product be bought while you're incapacitated?
#define BUYFLAG_DEAD				(BUYFLAG_DEAD_SURVIVORS|BUYFLAG_DEAD_INFECTED)
#define BUYFLAG_DEAD_SURVIVORS (1<<20) // Can this product be bought while you're a dead survivor?
#define BUYFLAG_DEAD_INFECTED				(1<<21) // Can this product be bought while you're a dead infected?
#define BUYFLAG_GHOST				(1<<22) // Can this product be bought while you're a ghost? 
#define BUYFLAG_ONLY_INCAP				(1<<23) // Can this product be bought ONLY if you're incapacitated?

// On purpose that BUYFLAG_INFECTED_SMOKER == (1<<L4D2ZombieClass_Smoker) and all the others including survivor have this property in common.
#define BUYFLAG_ALL_TEAMS				(BUYFLAG_SURVIVOR|BUYFLAG_INFECTED)
#define BUYFLAG_INFECTED_SMOKER			(1<<1) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_BOOMER			(1<<2) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_HUNTER			(1<<3) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_SPITTER			(1<<4) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_JOCKEY			(1<<5) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_CHARGER			(1<<6) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_TANK			(1<<8) // Can this product be bought while you're a Charger?
#define BUYFLAG_INFECTED_NO_TANK		(BUYFLAG_INFECTED_SMOKER|BUYFLAG_INFECTED_BOOMER|BUYFLAG_INFECTED_HUNTER|BUYFLAG_INFECTED_SPITTER|BUYFLAG_INFECTED_JOCKEY|BUYFLAG_INFECTED_CHARGER) // Can this product be bought while you're a non-tank infected?
#define BUYFLAG_INFECTED			(BUYFLAG_INFECTED_NO_TANK|BUYFLAG_INFECTED_TANK) // Can this product be bought while you're an Infected?
#define BUYFLAG_SURVIVOR			(1<<9) // Can this product be bought while you're a Survivor?


// On purpose that BUYFLAG_INFECTED_SMOKER == (1<<(10+L4D2ZombieClass_Smoker)) and all the others have this property in common.
#define BUYFLAG_PINNED_SMOKER		(1<<11) // Can this product be bought while you're pinned by a Smoker?
#define BUYFLAG_PINNED_HUNTER				(1<<13) // Can this product be bought while you're pinned by any Special Infected?
#define BUYFLAG_PINNED_JOCKEY				(1<<15) // Can this product be bought while you're pinned by any Special Infected?
#define BUYFLAG_PINNED_CHARGER				(1<<16) // Can this product be bought while you're pinned by any Special Infected?

#define BUYFLAG_ONLY_PINNED (1<<17)					// Can this product be bought ONLY if you're pinned? Must activate a BUYFLAG_PINNED* flag for this. 
#define BUYFLAG_PINNED				(BUYFLAG_PINNED_SMOKER|BUYFLAG_PINNED_HUNTER|BUYFLAG_PINNED_JOCKEY|BUYFLAG_PINNED_CHARGER)
#define BUYFLAG_PINNED_NO_SMOKER	(BUYFLAG_PINNED_HUNTER|BUYFLAG_PINNED_JOCKEY|BUYFLAG_PINNED_CHARGER)
#define BUYFLAG_PINNED_NO_HUNTER	(BUYFLAG_PINNED_SMOKER|BUYFLAG_PINNED_JOCKEY|BUYFLAG_PINNED_CHARGER)
#define BUYFLAG_PINNED_NO_JOCKEY	(BUYFLAG_PINNED_SMOKER|BUYFLAG_PINNED_HUNTER|BUYFLAG_PINNED_CHARGER)
#define BUYFLAG_PINNED_NO_CHARGER	(BUYFLAG_PINNED_SMOKER|BUYFLAG_PINNED_HUNTER|BUYFLAG_PINNED_JOCKEY)

// Below this line is only for products and not for categories
#define BUYFLAG_HUMANTEAM			(1<<18) // Can this product be bought to non-bot teammates?
#define BUYFLAG_BOTTEAM				(1<<19) // Can this product be bought for your bot teammates?
#define BUYFLAG_TEAM			(BUYFLAG_BOTTEAM|BUYFLAG_HUMANTEAM) // Can this product be bought for your teammates?

#define BUYFLAG_CUSTOMNAME			(1<<30) // Ask for this product's name when opening !buy menu
#define BUYFLAG_REALTIME_REFUNDS			(1<<31) // Check for the ability to refund this product in real-time. 

/*
Clarification: If BUYFLAG_TEAM is present and BUYFLAG_HUMANTEAM is not present,
you can basically help your bots, buying them products without disturbing any players. 
*/

// Natives


// Clone of list of products. Must be closed with delete.
// Editing this array doesn't do anything. Go wild.
native ArrayList PSAPI_GetProducts();

// Sets global error for the forward you're inside. Highest priority number wins. Refunds and death buys have a priority of 50.
// Returns Plugin_Handled always. This means you can return PSAPI_SetErrorByPriority as an easy method.
// Using a negative priority will not set the error, so cvars that deal with priority have an easy way to delete the error.
native Action PSAPI_SetErrorByPriority(int priority, char[] error, any ...);

// Creates or edits a category ( edits by sID).
// If a category is unavailable to us, but it has available products, they will go to main menu.
// iCategory is parent category, or -1 if this category is child of main buy menu.
// Not all buy flags work with categories, check BUYFLAG_* for more info.
// sID is an identifier that is not shared to the player.
native int PSAPI_CreateCategory(int iCategory, char[] sID, char[] sName, int iBuyFlags);

// Creates or edits a product.
// The first alias is documented in the buy menu.
// fCost is rounded to an integer.
// Each alias is maxed at 32 characters.
// Each product is maxed at 8 aliases.
// bNoHooks determines if PSAPI_OnProductCreated should be called. Careful with infinite loops
native bool PSAPI_CreateProduct(int iCategory, float fCost, char[] sName, char[] sDescription, char[] sAliases, char[] sInfo, float fDelay, float fCooldown, int iBuyFlags, bool bNoHooks = false);

// Finds a category by sID
// To invoke:
// enCategory cat;
// PSAPI_FindCategoryByIdentifier(sID, cat);
native bool PSAPI_FindCategoryByIdentifier(const char[] sID, any[] aCat);

// Given an alias, triggers every condition and every global forward except OnShouldGiveProduct to determine if the product is possible to buy.
// If target == 0, we treat target as buyer and ignore price as a factor if product can be bought.
// To do the same with a real target, set target to -1 * target
native bool PSAPI_CanProductBeBought(const char[] sAlias, int buyer, int target);

// Feed a list of aliases seperated by spaces to refund every delayed instance of them for the buyer target duo:
native void PSAPI_RefundProducts(const char[] sAliases, int buyer, int target);

// Finds a product by one of their aliases.
// To invoke:
// enProduct product;
// PSAPI_FindProductByAlias(sAlias, product);
native bool PSAPI_FindProductByAlias(const char[] sAlias, any[] aProduct);

// Returns negative for disabled or non-existent product, returns 0.0 for free product, returns positive for the cost.
native float PSAPI_FetchProductCostByAlias(const char[] sAlias, int buyer, int targetclient);

// Gets the current version of Point System API.
native float PSAPI_GetVersion();

// Gets a client's points in his current team.
// Points are always displayed as integers by rounding down
native float PSAPI_GetPoints(int client);

// Sets a client's point for every team. You should almost always use PSAPI_SetPoints for setting points.
native void PSAPI_HardSetPoints(int client, float fPoints);

// Sets a client's points for his current team.
native void PSAPI_SetPoints(int client, float fPoints);

stock void PSAPI_GivePoints(int client,  float fPoints)
{
	PSAPI_SetPoints(client, PSAPI_GetPoints(client) + fPoints);
}

stock void PSAPI_RemovePoints(int client, float fPoints)
{
	PSAPI_SetPoints(client, PSAPI_GetPoints(client) - fPoints);
}

// Uses my own algorithm to fully heal a player, fixing the bug where you get to 100 hp when incapped and pinned.
native void PSAPI_FullHeal(int client);

// Checks how many times a tank has healed, don't use for non-tanks
// Also checks the maximum amount of heals within the cvar.
native void PSAPI_GetTankHealCount(int client, int &maxHeals);

// Adds amount of tank heal counts, also useful for special tanks that shouldn't be able to heal.
native void PSAPI_AddTankHealCount(int client, int amount);


// Forwards


// team is the team relative to start points, and is NOT necessarily the team of client.
// fAveragePrice is the average product price of the team.
// You should utilize fAveragePrice to increase start points, as some servers may make start points as 0.
forward void PointSystemAPI_OnSetStartPoints(int client, L4DTeam team, float &fStartPoints, float fAveragePrice);

forward void PointSystemAPI_OnGainPoints(int client, float &fPoints, const char[] reason);

// product is a copyback value.
// Return Plugin_Handled to prevent the product from creation.
// Does not fire if a product is created with bNoHooks = true
forward Action PointSystemAPI_OnProductCreated(enProduct product);

// return Plugin_Handled to prevent the user from buying anything. Supports PSAPI_SetErrorByPriority
forward Action PointSystemAPI_OnCanBuyProducts(int buyer, int target);

// return Plugin_Handled to hide the category, must have BUYFLAGS_CUSTOMNAME to fire this.
forward Action PointSystemAPI_OnGetParametersCategory(int buyer, const char[] sID, char[] sName);

// Called even if you cannot afford the product, and even if you didn't try to buy the product'.
// sAliases contain the original alias list, to compare your own alias as an identifier.
// If the cost drops below 0, the product is disabled!!!
// Every cost of a product will always be treated as a whole number.
// return Plugin_Handled to disable & hide this product.
forward Action PointSystemAPI_OnGetParametersProduct(int buyer, const char[] sAliases, char[] sInfo, char[] sName, char[] sDescription, int target, float &fCost, float &fDelay, float &fCooldown);

// sAliases contain the original alias list, to compare your own alias as an identifier.
// This forward is triggered by PSAPI_CanProductBeBought so always use PSAPI_SetErrorByPriority
// Return Plugin_Handled to block purchase
forward Action PointSystemAPI_OnTryBuyProduct(int buyer, const char[] sInfo, const char[] sAliases, const char[] sName, int target, float fCost, float fDelay, float fCooldown);

// sAliases contain the original alias list, to compare your own alias as an identifier.
// Called every 0.1 seconds during the delay of arrival.
// Product must have BUYFLAG_REALTIME_REFUNDS.
// fTimeleft can be 0.0, and in this case, in the same frame PointSystemAPI_OnBuyProductPost will be called, so you don't need PointSystemAPI_OnBuyProductPost if you have this.
// This forward is triggered by PSAPI_CanProductBeBought so always use PSAPI_SetErrorByPriority
// Return Plugin_Handled to refund purchase
forward Action PointSystemAPI_OnRealTimeRefundProduct(int buyer, const char[] sInfo, const char[] sAliases, const char[] sName, int target, float fCost, float fTimeleft);
	
	
// If a delay exists, called several seconds after PointSystemAPI_OnTryBuyProduct. Otherwise this is called instantly. 
// sAliases contain the original alias list, to compare your own alias as an identifier.

// This forward is triggered by PSAPI_CanProductBeBought so always use PSAPI_SetErrorByPriority.
// Return Plugin_Handled to refund.
forward Action PointSystemAPI_OnBuyProductPost(int buyer, const char[] sInfo, const char[] sAliases, const char[] sName, int target, float fCost, float fDelay, float fCooldown);
	
// This forward should be used to give the product to a target player. This is after the delay, and after not refunding the product. Called instantly after PointSystemAPI_OnBuyProductPost
// sAliases contain the original alias list, to compare your own alias as an identifier.

// Return Plugin_Handled to refund if you cannot give the product, which should be rare and may interfere with PSAPI_CanProductBeBought which won't trigger this forward.
forward Action PointSystemAPI_OnShouldGiveProduct(int buyer, const char[] info, const char[] sAliases, const char[] sName, int target, float fCost, float fDelay, float fCooldown);





// Stocks


char PS_Colors[][] = 
{
	"{NORMAL}", "{RED}", "{GREEN}", "{LIGHTGREEN}", "{OLIVE}", "{LIGHTRED}", "{GRAY}", "{YELLOW}", "{ORANGE}", "{BLUE}", "{PINK}"
};

char PS_ColorEquivalents[][] =
{
	"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0C", "\x0E"
};



stock void PS_ReplyToCommand(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[256];

	VFormat(buffer, sizeof(buffer), format, 3);

	char sReplaceFrom[2], sReplaceTo[32];

	sReplaceFrom[0] = buffer[0]
	sReplaceFrom[1] = EOS;
	FormatEx(sReplaceTo, sizeof(sReplaceTo), "{GREEN}{NORMAL}%s", sReplaceFrom);
	
	ReplaceStringEx(buffer, sizeof(buffer), sReplaceFrom, sReplaceTo);

	for(int i=0;i < sizeof(PS_Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), PS_Colors[i], PS_ColorEquivalents[i]);
	}
	
	ReplaceString(buffer, sizeof(buffer), "{PERCENT}", "%%");
	
	ReplyToCommand(client, buffer);
}

stock void PS_PrintToChat(int client, const char[] format, any ...)
{
	ConVar prefixCvar = FindConVar("l4d2_points_prefix");
	
	if(prefixCvar == null)
	{
		prefixCvar = PS_CreateConVar("l4d2_points_prefix", "{LIGHTGREEN}[PS] {GREEN}");
	}

	SetGlobalTransTarget(client);
	
	char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 3);
	
	// This line may do more harm than good.
	if(buffer[0] == EOS)
		return;

	char sReplaceFrom[2], sReplaceTo[256], sPrefix[128];

	sReplaceFrom[0] = buffer[0]
	sReplaceFrom[1] = EOS;
	prefixCvar.GetString(sPrefix, sizeof(sPrefix));

	FormatEx(sReplaceTo, sizeof(sReplaceTo), "{GREEN}{NORMAL}%s%s", sPrefix, sReplaceFrom);
	
	ReplaceStringEx(buffer, sizeof(buffer), sReplaceFrom, sReplaceTo);

	for(int i=0;i < sizeof(PS_Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), PS_Colors[i], PS_ColorEquivalents[i]);
	}
	
	ReplaceString(buffer, sizeof(buffer), "{PERCENT}", "%%");

	int pos = StrContains(buffer, "Σ");

	ConVar Simplified = FindConVar("l4d2_points_simplified_edition");

	if(pos != -1 && Simplified != null && Simplified.BoolValue)
	{
		buffer[pos - 2] = EOS;
	}
	
	PrintToChat(client, buffer);
}

stock void PS_PrintToChatAll(const char[] format, any ...)
{	
	char buffer[256];
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		
		PS_PrintToChat(i, buffer);
	}
}

stock void PS_StringToUpper(char[] buffer)
{
	int length = strlen(buffer);
	for(int i=0;i < length;i++)
		buffer[i] = CharToUpper(buffer[i]);
}

stock void PS_PrintToChatEyal(const char[] format, any...)
{
	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (IsFakeClient(i))
			continue;

		char steamid[64];
		GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));

		if (StrEqual(steamid, "STEAM_1:0:49508144"))
			PS_PrintToChat(i, buffer);
	}
}

stock ConVar PS_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	ConVar hndl = AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);

	if (flags & FCVAR_PROTECTED)
		ServerCommand("sm_cvar protect %s", name);

	return hndl;
}

// This float is pretty much meant for RPG servers to increase starting points when the starting points default is 0.
stock float PSAPI_GetAverageProductPrice(L4DTeam team)
{
	ArrayList aProducts = PSAPI_GetProducts();

	int iProductsSize = aProducts.Length;

	float fCount = 0.0;
	float totalPrice = 0.0;

	for (int i = 0; i < iProductsSize; i++)
	{
		enProduct product;
		GetArrayArray(aProducts, i, product);

		if(product.fCost <= 0.0)
			continue;

		if ((product.iBuyFlags & BUYFLAG_SURVIVOR && team == L4DTeam_Survivor) || (product.iBuyFlags & BUYFLAG_INFECTED && team == L4DTeam_Infected))
		{
			totalPrice += product.fCost;
			fCount++;
		}
	}

	delete aProducts;

	return totalPrice / fCount;
}

stock int PSAPI_GetTeamHumansCount(L4DTeam team, bool bAliveOnly)
{
	int iCount;
	
	for (int i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;
			
		else if(GetClientTeam(i) != view_as<int>(team))
			continue;
			
		else if(bAliveOnly && !IsPlayerAlive(i))
			continue;
			
		iCount++;
	}
	
	return iCount;
}

// Gets the combined number of points a team has.
stock float PSAPI_GetTeamPoints(L4DTeam team, bool bAliveOnly)
{	
	float fTotalPoints = 0.0;
	for (int i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;
			
		else if(GetClientTeam(i) != view_as<int>(team))
			continue;
			
		else if(bAliveOnly && !IsPlayerAlive(i))
			continue;
			
		fTotalPoints += PSAPI_GetPoints(i);
	}
	
	return fTotalPoints;	
}
stock void PSAPI_ExecuteCheatCommand(int client, const char[] command, any ...)
{
	char formattedCommand[256];
	
	VFormat(formattedCommand, sizeof(formattedCommand), command, 3);

	char sFirstArg[64];
	
	BreakString(formattedCommand, sFirstArg, sizeof(sFirstArg));
	
	int flags = GetCommandFlags(sFirstArg);

	SetCommandFlags(sFirstArg, flags & ~FCVAR_CHEAT);
	
	FakeClientCommand(client, formattedCommand);
	
	SetCommandFlags(sFirstArg, flags);
}


// Target == 0 for buyer
// Sneaking in a fake product requires to populate: iBuyFlags, fNextBuyProduct[MAXPLAYERS+1]
stock bool PSAPI_GetErrorFromBuyflags(int buyer, char[] sFirstArg, enProduct alteredProduct, int target=0, char[] sError="", int iLength=0, bool &bShouldReturn=false)
{
	if(target == 0)
		target = buyer;
		
	int iBuyFlags = alteredProduct.iBuyFlags;
	L4DTeam iTeam = view_as<L4DTeam>(GetClientTeam(buyer));
	
	if(alteredProduct.fCost < 0.0)
	{
		FormatEx(sError, iLength, "Error: This product is disabled!");
		bShouldReturn = true;
		return true;
	}
	else if( (iBuyFlags & BUYFLAG_INFECTED != BUYFLAG_INFECTED && iTeam == L4DTeam_Infected) || (!(iBuyFlags & BUYFLAG_SURVIVOR) && iTeam == L4DTeam_Survivor))
	{
		FormatEx(sError, iLength, "Error: Only %s can buy this!", iBuyFlags & BUYFLAG_SURVIVOR ? "Survivors" : "Infected");
		bShouldReturn = true;
		return true;
	}
	else if(!(iBuyFlags & BUYFLAG_TEAM) && target != buyer)
	{
		FormatEx(sError, iLength, "Cannot buy %s for teammates", alteredProduct.sName);
		return true;
	}
	else if(PSAPI_GetPoints(buyer) < alteredProduct.fCost)
	{
		FormatEx(sError, iLength, PSAPI_NOT_ENOUGH_POINTS, RoundToFloor(alteredProduct.fCost) - RoundToFloor(PSAPI_GetPoints(buyer)), RoundToFloor(PSAPI_GetPoints(buyer)));

		return true;
	}
	
	char sName[64];
	GetClientName(target, sName, sizeof(sName));
	bool bBot = IsFakeClient(target);
	bool bAlive = IsPlayerAlive(target);
	bool bGhost = L4D_IsPlayerGhost(target);
	bool bPinned = L4D_IsPlayerPinned(target);
	bool bIncap = L4D_IsPlayerIncapacitated(target);
	int pinningClient = L4D_GetPinnedInfected(target);
	int pinningClass = view_as<int>(L4D2ZombieClass_NotInfected);
	bool bProperClass = PSAPI_IsProperZombieClassForProduct(target, alteredProduct);
	
	if(pinningClient > 0)
		pinningClass = view_as<int>(L4D2_GetPlayerZombieClass(pinningClient));
	
	
	if(!(iBuyFlags & BUYFLAG_HUMANTEAM) && target != buyer && !bBot)
	{
		FormatEx(sError, iLength, "Cannot buy\x04 %s\x03 for non-bot teammates", alteredProduct.sName);
		return true;
	}
	
	else if(!(iBuyFlags & BUYFLAG_BOTTEAM) && target != buyer && bBot)
	{
		FormatEx(sError, iLength, "Cannot buy\x04 %s\x03 for bot teammates", alteredProduct.sName);
		return true;
	}
	

	else if(!(iBuyFlags & BUYFLAG_INCAP) && bIncap)
	{
		FormatEx(sError, iLength, "%s mustn't be incapped to buy\x04 %s", target == buyer ? "You" : sName, alteredProduct.sName);
		return true;
	}
	
	else if(iBuyFlags & BUYFLAG_ONLY_INCAP && !bIncap)
	{
		FormatEx(sError, iLength, "%s must be incapped to buy\x04 %s", target == buyer ? "You" : sName, alteredProduct.sName);
		return true;
	}
	else if(!(iBuyFlags & BUYFLAG_GHOST) && bGhost)
	{
		FormatEx(sError, iLength, "%s must be %s to buy\x04 %s", target == buyer ? "You" : sName, iBuyFlags & BUYFLAG_ALIVE ? "alive" : "dead", alteredProduct.sName);
		return true;
	}
	else if( ( !(iBuyFlags & BUYFLAG_DEAD_SURVIVORS) && !bAlive && iTeam == L4DTeam_Survivor ) || ( !(iBuyFlags & BUYFLAG_DEAD_INFECTED) && !bAlive && iTeam == L4DTeam_Infected ))
	{
		FormatEx(sError, iLength, "%s must be alive to buy\x04 %s", target == buyer ? "You" : sName, alteredProduct.sName);
		return true;
	}
	
	else if(!(iBuyFlags & BUYFLAG_ALIVE) && bAlive)
	{
		FormatEx(sError, iLength, "%s must be dead to buy\x04 %s", target == buyer ? "You" : sName, alteredProduct.sName);
		return true;
	}
	
	else if(!(iBuyFlags & BUYFLAG_PINNED) && bPinned)
	{
		FormatEx(sError, iLength, "%s mustn't be pinned to buy\x04 %s", target == buyer ? "You" : sName, alteredProduct.sName);
		return true;
	}
	
	else if(iBuyFlags & BUYFLAG_ONLY_PINNED && !bPinned)
	{
		FormatEx(sError, iLength, "%s must be pinned to buy\x04 %s", target == buyer ? "You" : sName, alteredProduct.sName);
		return true;
	}
	
	// 10 is a constant created by the fact that BUYFLAG_PINNED_SMOKER = (1<< (L4D2ZombieClass_Smoker + 10))
	else if(pinningClass != view_as<int>(L4D2ZombieClass_NotInfected) && iBuyFlags & (1<< (10 + pinningClass)) != (1<< (10 + pinningClass)))
	{
		FormatEx(sError, iLength, "%s mustn't be pinned by a\x05 %s\x03 to buy\x04 %s", target == buyer ? "You" : sName, g_sBossNames[pinningClass], alteredProduct.sName);
		return true;		
	}
	else if(!bProperClass)
	{
		L4D2ZombieClassType class = L4D2_GetPlayerZombieClass(target);
		
		FormatEx(sError, iLength, "%s mustn't be a %s to buy\x04 %s", target == buyer ? "You" : sName, g_sBossNames[class], alteredProduct.sName);
		return true;
	}
	
	else if(alteredProduct.fNextBuyProduct[target] > GetGameTime())
	{
		FormatEx(sError, iLength, "%s\x03 is in %.2fsec cooldown for %s", alteredProduct.sName, alteredProduct.fNextBuyProduct[target] - GetGameTime(), target == buyer ? "You" : sName);
		return true;
	}
	
	return false;
}


stock bool PSAPI_IsProperZombieClassForProduct(int client, enProduct product)
{
	if(!IsPlayerAlive(client))
		return true;
		
	else if(GetClientTeam(client) == view_as<int>(L4DTeam_Survivor))
		return true;
		
	return view_as<bool>(product.iBuyFlags & view_as<int>(L4D2_GetPlayerZombieClass(client)));
}

// bNoPick = cannot press mouse2 to change to another SI in a ghost spawn by the plugin l4d2_zcs.smx

stock bool PSAPI_SpawnInfectedBossByClassname(int client, const char[] name, bool bGhost=false, bool bNoPick = false)
{	
	if(StrEqual(name, "survivor") || StrEqual(name, "witch"))
		return false;
	
	// Multi tanks will create utter chaos if we don't first swap to a non-tank class prior to spawning the player.
	
	L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
	L4D2_SetPlayerZombieClass(client, L4D2ZombieClass_Charger);

	// Safety measurements.
	L4D_State_Transition(client, STATE_DEATH_WAIT_FOR_KEY);

	float fOrigin[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", fOrigin);

	// Regardless of bGhost, we switch to ghost. If not ghost, we materialize.
	// We must become ghost prior to sending the event or zcs will wait another 0.1 seconds until we're alive.
	L4D_State_Transition(client, STATE_GHOST);



	// isRelocating and isCulling are not a solution to make a no pick, you can only respawn yourself and then swap to ghost as the only solution.
	// isRelocating is not 100% grasped by me, but isCulling checks if a living player can teleport and become ghost for being too far away from survivors.
	// isCulling is not a player that already pressed E to teleport as a living player.
	//SetEntProp(client, Prop_Send, "m_isCulling", bNoPick);
	//SetEntProp(client, Prop_Send, "m_isRelocating", bNoPick);

	if(bNoPick)
	{
		// Respawn is required to make ZCS think we relocated. Must put state transition above to ensure spec2ghost take the OnEnterGhostState
		L4D_RespawnPlayer(client);

		// Since we must switch to ghost again, we must recreate the spectator origin to activate spec2ghost
		TeleportEntity(client, fOrigin);

		// On top of state transition required to negate RespawnPlayer, you must switch state twice to remove a fake message of "You are too far away from survivors" caused by either isRelocating or isCulling
		L4D_State_Transition(client, STATE_GHOST);
	}

	for (int i = 0; i < sizeof(g_sBossClassnames);i++)
	{
		if(StrEqual(g_sBossClassnames[i], name))
		{
			L4D_SetClass(client, i);
			L4D2_SetPlayerZombieClass(client, view_as<L4D2ZombieClassType>(i));
		}
	}
	
	PSAPI_FullHeal(client); // I don't know how, but I once spawned as a tank health smoker.
	
	if(!bGhost)
		L4D_MaterializeFromGhost(client);

	return true;
}

stock void PSAPI_SetGasolineGlow(int iWeapon)
{
	L4D2_SetEntityGlow(iWeapon, L4D2Glow_Constant, 0, 0, { 0, 200, 0 }, false);
}

stock int PSAPI_GetEntityMaxHealth(int entity)
{
	if(PSAPI_IsEntityPlayer(entity))
	{
		if(L4D_GetClientTeam(entity) == L4DTeam_Survivor && L4D_IsPlayerIncapacitated(entity))
		{
			static ConVar convar;
			
			if(convar == null)
				convar = FindConVar("survivor_incap_health");

			return convar.IntValue;
		}
		else
			return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
	}
	else
		return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

stock bool PSAPI_IsEntityPlayer(int entity)
{
	if (entity <= 0)
		return false;

	else if (entity > MaxClients)
		return false;

	return true;
}


// This function is perfect but I need to conduct tests to ensure no bugs occur.
stock bool PS_GetAimPositionBySize(int client, int target, float outputOrigin[3])
{
	float BrokenOrigin[3];
	float vecMin[3], vecMax[3], eyeOrigin[3], eyeAngles[3], Result[3], FakeOrigin[3], clientOrigin[3];

	GetClientMins(target, vecMin);
	GetClientMaxs(target, vecMax);

	GetEntPropVector(target, Prop_Data, "m_vecOrigin", BrokenOrigin);

	GetClientEyePosition(client, eyeOrigin);
	GetClientEyeAngles(client, eyeAngles);

	GetEntPropVector(client, Prop_Data, "m_vecOrigin", clientOrigin);

	TR_TraceRayFilter(eyeOrigin, eyeAngles, MASK_SHOT, RayType_Infinite, PS_TraceRayDontHitPlayers);

	TR_GetEndPosition(FakeOrigin);

	Result = FakeOrigin;

	if (TR_PointOutsideWorld(Result))
		return false;

	float fwd[3];

	GetAngleVectors(eyeAngles, fwd, NULL_VECTOR, NULL_VECTOR);

	NegateVector(fwd);

	float clientHeight = eyeOrigin[2] - clientOrigin[2];
	float OffsetFix    = eyeOrigin[2] - Result[2];

	if (OffsetFix < 0.0)
		OffsetFix = 0.0;

	else if (OffsetFix > clientHeight + 1.3)
		OffsetFix = clientHeight + 1.3;

	ScaleVector(fwd, 1.3);

	int Timeout = 0;

	while (IsPlayerStuck(target, Result, (-1 * clientHeight) + OffsetFix))
	{
		AddVectors(Result, fwd, Result);

		Timeout++;

		if (Timeout > 8192)
			return false;
	}

	Result[2] += (-1 * clientHeight) + OffsetFix;

	outputOrigin = Result;

	return true;
}

stock bool IsPlayerStuck(int client, const float Origin[3] = NULL_VECTOR, float HeightOffset = 0.0)
{
	float vecMin[3], vecMax[3], vecOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	if (PS_IsNullVector(Origin))
	{
		GetClientAbsOrigin(client, vecOrigin);

		vecOrigin[2] += HeightOffset;
	}
	else
	{
		vecOrigin = Origin;

		vecOrigin[2] += HeightOffset;
	}

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, PS_TraceRayDontHitPlayers);
	return TR_DidHit();
}

stock void TeleportToGround(int client)
{
	float vecMin[3], vecMax[3], vecOrigin[3], vecFakeOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	GetClientAbsOrigin(client, vecOrigin);
	vecFakeOrigin = vecOrigin;

	vecFakeOrigin[2] = MIN_FLOAT;

	TR_TraceHullFilter(vecOrigin, vecFakeOrigin, vecMin, vecMax, MASK_PLAYERSOLID, PS_TraceRayDontHitPlayers);

	TR_GetEndPosition(vecOrigin);

	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);
}

public bool PS_TraceRayDontHitPlayers(int entityhit, int mask)
{
	return (entityhit > MaxClients || entityhit == 0);
}

stock bool PS_IsNullVector(const float Vector[3])
{
	return (Vector[0] == NULL_VECTOR[0] && Vector[0] == NULL_VECTOR[1] && Vector[2] == NULL_VECTOR[2]);
}