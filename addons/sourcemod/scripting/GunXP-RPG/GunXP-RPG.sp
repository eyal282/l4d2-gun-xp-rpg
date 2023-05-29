#include <GunXP-RPG>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <left4dhooks>
#include <smlib>
#include <ps_api>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <autoexecconfig>
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

#pragma newdecls required
#pragma semicolon 1

//#define UNKNOWN_ERROR "\x01An unknown error has occured, action was aborted."

#define ADMFLAG_VIP ADMFLAG_CUSTOM2

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name = "Gun XP - RPG",
	author = "Eyal282",
	description = "Earn experience points to permanently unlock perks and weapons.",
	version = PLUGIN_VERSION,
	url = "NULL"
};



char g_sAllowedDropWeapons[][] =
{
	"weapon_adrenaline",
	"weapon_cola_bottles",
	"weapon_defibrillator",
	"weapon_fireworkcrate",
	"weapon_gascan",
	"weapon_gnome",
	"weapon_molotov",
	"weapon_oxygentank",
	"weapon_pain_pills",
	"weapon_pipe_bomb",
	"weapon_propanetank",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary",
	"weapon_vomitjar"
};

char g_sForbiddenMapWeapons[][] =
{
	"weapon_autoshotgun_spawn",
	"weapon_chainsaw_spawn",
	"weapon_hunting_rifle_spawn",
	"weapon_item_spawn",
	"weapon_melee_spawn",
	"weapon_pistol_magnum_spawn",
	"weapon_pistol_spawn",
	"weapon_pumpshotgun_spawn",
	"weapon_rifle_ak47_spawn",
	"weapon_rifle_desert_spawn",
	"weapon_rifle_m60_spawn",
	"weapon_rifle_sg552_spawn",
	"weapon_rifle_spawn",
	"weapon_shotgun_chrome_spawn",
	"weapon_shotgun_spas_spawn",
	"weapon_smg_mp5_spawn",
	"weapon_smg_silenced_spawn",
	"weapon_smg_spawn",
	"weapon_sniper_awp_spawn",
	"weapon_sniper_military_spawn",
	"weapon_sniper_scout_spawn",
	"weapon_spawn"
};

bool SaveLastGuns[MAXPLAYERS+1];

ConVar hcv_xpSIKill;
ConVar hcv_xpSIHS;


ConVar hcv_xpKillingSpree;
ConVar hcv_xpKillingSpreeNumber;

ConVar hcv_xpHeadshotSpree;
ConVar hcv_xpHeadshotSpreeNumber;


ConVar hcv_xpHeal;
ConVar hcv_xpDefib;
ConVar hcv_xpRevive;
ConVar hcv_xpLedge;

ConVar hcv_VIPMultiplier;

int KillStreak[MAXPLAYERS+1];

int g_iLevel[MAXPLAYERS+1], g_iXP[MAXPLAYERS+1], g_iXPCurrency[MAXPLAYERS+1];
bool g_bLoadedFromDB[MAXPLAYERS+1];

Database dbGunXP;

bool dbFullConnected;

Handle cpLastSecondary, cpLastPrimary, cpAutoRPG;

bool g_bTookWeapons[MAXPLAYERS+1];

int StartOfPrimary = 14; // Change to the beginning of rifles in the levels, remember to count [0]

#define MAX_LEVEL 29

#define PERK_TREE_NOT_UNLOCKED -1

enum struct enSkill
{
	// Database entry of the skill. Never change this.
	char identifier[32];

	char name[64];
	char description[512];

	// Cost in XP.
	int cost;

	// level requirement.
	int levelReq;

	// ArrayList of skill / perk tree identifiers required to go into this skill.
	// A perk tree requires any level unlocked to count.
	ArrayList reqIdentifiers;
}

enum struct enPerkTree
{
	// Database entry of the perk tree. Never change this.
	char identifier[32];
	char name[64];

	// descriptions, costs and levelReqs are arrays that should be identical length to indicate what the perk does at each level, cost at each level, and level requirement at each level.
	ArrayList descriptions;
	ArrayList costs;
	ArrayList levelReqs;
	// level requirement.


	// ArrayList of skill / perk tree identifiers required to go into this perk tree.
	// A perk tree requires any level unlocked to count.
	ArrayList reqIdentifiers;
}

//ArrayList g_aUnlockItems;
ArrayList g_aSkills;
ArrayList g_aPerkTrees;

#define MAX_ITEMS 128

bool g_bUnlockedProducts[MAXPLAYERS+1][MAX_ITEMS];
bool g_bUnlockedSkills[MAXPLAYERS+1][MAX_ITEMS];
int g_iUnlockedPerkTrees[MAXPLAYERS+1][MAX_ITEMS];

int g_iCommonKills[MAXPLAYERS+1];
int g_iCommonHeadshots[MAXPLAYERS+1];

//GlobalForward g_fwOnUnlockShopBuy;
GlobalForward g_fwOnSkillBuy;
GlobalForward g_fwOnPerkTreeBuy;
GlobalForward g_fwOnSpawned;

/*
new const String:FORBIDDEN_WEAPONS[][] =
{
	"weapon_sawedoff"
}

*/
int LEVELS[MAX_LEVEL+1] =
{
	90, // needed for level 1
	180, // needed for level 2 
	300, // needed for level 3 
	450, // needed for level 4 
	650, // needed for level 5
	850, // needed for level 6
	1000, // needed for level 7
	1200, // needed for level 8
	1500, // needed for level 9 
	1750, // needed for level 10
	2000, // needed for level 11 
	2250, // needed for level 12 
	2500, // needed for level 13 
	2750, // needed for level 14 
	3000, // needed for level 15, the first rifle
	3500, // needed for level 16 
	4000, // needed for level 17 
	4500, // needed for level 18 
	5000, // needed for level 19 
	6000, // needed for level 20 
	10000, // needed for level 21
	14000, // needed for level 22 
	18000, // needed for level 23 
	25000, // needed for level 24 
	35000,  // needed for level 25
	50000,  // needed for level 26
	100000,  // needed for level 27
	200000,  // needed for level 28
	400000,  // needed for level 29
	2147483647 // This shall never change, NEVERRRRR
};
char GUNS_CLASSNAMES[MAX_LEVEL+1][] =
{
	"pistol",
	"pitchfork",
	"shovel",
	"frying_pan",
	"tonfa",
	"knife",
	"golfclub",
	"crowbar",
	"cricket_bat",
	"machete",
	"katana",
	"fireaxe",
	"pistol_magnum",
	"chainsaw",
	"sniper_scout",
	"sniper_awp",
	"hunting_rifle",
	"smg",
	"smg_silenced",
	"smg_mp5",
	"sniper_military",
	"pumpshotgun",
	"shotgun_chrome",
	"autoshotgun",
	"shotgun_spas",
	"rifle_desert",
	"rifle_sg552",
	"rifle",
	"rifle_ak47",
	"null"
};

char GUNS_NAMES[MAX_LEVEL+1][] =
{

	"Pistol",
	"Pitchfork",
	"Shovel",
	"Frying Pan",
	"Tonfa",
	"Knife",
	"Golf Club",
	"Crowbar",
	"Bat",
	"Machete",
	"Katana",
	"Fireaxe",
	"Magnum",
	"Chainsaw",
	"Scout", // The first rifle
	"AWP",
	"Hunting Rifle",
	"SMG",
	"Silenced SMG",	
	"MP5",
	"Military Sniper",
	"Pump Shotgun",
	"Chrome Shotgun",	
	"Auto Shotgun",
	"Spas",
	"Desert Rifle",
	"SG552",
	"M-16",
	"AK-47",
	"NULL"
};

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		SetEntityMaxHealth(i, 100);

		Call_StartForward(g_fwOnSpawned);

		Call_PushCell(i);

		Call_Finish();

		SetEntityHealth(i, GetEntityMaxHealth(i));
	}
}

public Action PointSystemAPI_OnTryBuyProduct(int buyer, const char[] sInfo, const char[] sAliases, const char[] sName, int target, float fCost, float fDelay, float fCooldown)
{
	if(!L4D_IsPlayerIncapacitated(target))
		return Plugin_Continue;

	else if(StrEqual(sInfo, "give pistol") || StrEqual(sInfo, "give pistol_magnum"))
	{
		PSAPI_SetErrorByPriority(50, "\x04[Gun-XP]\x03 Error:\x01 Pistols cannot be bought when incapacitated");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action PointSystemAPI_OnGetParametersProduct(int buyer, const char[] sAliases, char[] sInfo, char[] sName, char[] sDescription, int target, float& fCost, float& fDelay, float& fCooldown)
{
	if(strncmp(sInfo, "give ", 5) != 0)
		return Plugin_Continue;

	char sClass[32];
	FormatEx(sClass, sizeof(sClass), sInfo);

	ReplaceStringEx(sClass, sizeof(sClass), "give ", "");

	for(int i=0;i < sizeof(GUNS_CLASSNAMES);i++)
	{
		if(StrEqual(sClass, GUNS_CLASSNAMES[i]))
		{
			if(i <= GetClientLevel(target))
			{
				fCost = 0.0;
				return Plugin_Changed;
			}

			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{	

	CreateNative("GunXP_RPG_GetClientLevel", Native_GetClientLevel);

	CreateNative("GunXP_RPG_AddClientXP", Native_AddClientXP);

	CreateNative("GunXP_RPGShop_RegisterSkill", Native_RegisterSkill);
	CreateNative("GunXP_RPGShop_IsSkillUnlocked", Native_IsSkillUnlocked);
	CreateNative("GunXP_RPGShop_RegisterPerkTree", Native_RegisterPerkTree);
	CreateNative("GunXP_RPGShop_IsPerkTreeUnlocked", Native_IsPerkTreeUnlocked);

//	CreateNative("GunXP_UnlockShop_RegisterProduct", Native_RegisterProduct);
//	CreateNative("GunXP_UnlockShop_ReplenishProducts", Native_ReplenishProducts);
//	CreateNative("GunXP_UnlockShop_IsProductUnlocked", Native_IsProductUnlocked);

	RegPluginLibrary("GunXPMod");
	RegPluginLibrary("GunXP_UnlockShop");
	RegPluginLibrary("GunXP_SkillShop");

	return APLRes_Success;
}

// GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null)

public int Native_GetClientLevel(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	return GetClientLevel(client);
}

public int Native_AddClientXP(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	bool bPremiumMultiplier = GetNativeCell(3);

	AddClientXP(client, amount, bPremiumMultiplier);

	return 0;
}
public int Native_RegisterSkill(Handle caller, int numParams)
{
	enSkill skill;

	if(g_aSkills == null)
		g_aSkills = CreateArray(sizeof(enSkill));

	char identifier[32];
	GetNativeString(1, identifier, sizeof(identifier));

	char name[64];
	GetNativeString(2, name, sizeof(name));

	char description[512];
	GetNativeString(3, description, sizeof(description));

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill iSkill;
		g_aSkills.GetArray(i, iSkill);
		
		if(StrEqual(identifier, iSkill.identifier))
			return i;
	}

	int cost = GetNativeCell(4);

	int levelReq = GetClosestLevelToXP(GetNativeCell(5));

	ArrayList reqIdentifiers = GetNativeCell(6);

	skill.identifier = identifier;
	skill.name = name;
	skill.description = description;
	skill.cost = cost;
	skill.levelReq = levelReq;

	if(reqIdentifiers == null)
	{
		skill.reqIdentifiers = null;
	}
	else
	{
		skill.reqIdentifiers = reqIdentifiers.Clone();
	}

	delete reqIdentifiers;

	return g_aSkills.PushArray(skill);
}


public any Native_IsSkillUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int skillIndex = GetNativeCell(2);

	if(!IsFakeClient(client))
		return view_as<bool>(g_bUnlockedSkills[client][skillIndex]);

	// Check if average of humans have the skill unlocked.
	else
	{
		int count = 0;
		int unlockedCount = 0;

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(IsFakeClient(i))
				continue;

			count++;

			if(g_bUnlockedSkills[i][skillIndex])
			{
				unlockedCount++;
			}
		}

		if(float(unlockedCount) / float(count) >= 0.5)
		{
			return true;
		}
		
		return false;
	}
}

// GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null)
public int Native_RegisterPerkTree(Handle caller, int numParams)
{
	enPerkTree perkTree;

	if(g_aPerkTrees == null)
		g_aPerkTrees = CreateArray(sizeof(enPerkTree));

	char identifier[32];
	GetNativeString(1, identifier, sizeof(identifier));

	char name[64];
	GetNativeString(2, name, sizeof(name));

	ArrayList descriptions = GetNativeCell(3);
	ArrayList costs = GetNativeCell(4);
	ArrayList levelReqs = GetNativeCell(5);

	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree iPerkTree;
		g_aPerkTrees.GetArray(i, iPerkTree);
		
		if(StrEqual(identifier, iPerkTree.identifier))
			return i;
	}

	ArrayList reqIdentifiers = GetNativeCell(6);

	perkTree.identifier = identifier;
	perkTree.name = name;
	perkTree.descriptions = descriptions.Clone();
	perkTree.costs = costs.Clone();
	perkTree.levelReqs = levelReqs.Clone();

	for(int i=0;i < perkTree.levelReqs.Length;i++)
	{
		int levelReq = GetClosestLevelToXP(perkTree.levelReqs.Get(i));

		perkTree.levelReqs.Set(i, levelReq);
	}

	if(reqIdentifiers == null)
	{
		perkTree.reqIdentifiers = null;
	}
	else
	{
		perkTree.reqIdentifiers = reqIdentifiers.Clone();
	}

	delete reqIdentifiers;
	delete descriptions;
	delete costs;
	delete levelReqs;

	return g_aPerkTrees.PushArray(perkTree);
}


public any Native_IsPerkTreeUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int perkIndex = GetNativeCell(2);

	if(!IsFakeClient(client))
		return g_iUnlockedPerkTrees[client][perkIndex];

	// Get average level divided by 2, rounded down.
	else
	{
		int averageLevel = 0;
		int count = 0;
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(IsFakeClient(i))
				continue;

			count++;

			averageLevel += g_iUnlockedPerkTrees[i][perkIndex] + 1;
		}

		return RoundToCeil((float(averageLevel) / float(count)) / 2.0) - 1;
	}
}
/*
public int Native_RegisterProduct(Handle caller, int numParams)
{
	enProduct product;

	if(g_aUnlockItems == null)
		g_aUnlockItems = CreateArray(sizeof(enProduct));

	char name[64];
	GetNativeString(1, name, sizeof(name));

	char description[256];
	GetNativeString(2, description, sizeof(description));

	for(int i=0;i < g_aUnlockItems.Length;i++)
	{
		enProduct iProduct;
		g_aUnlockItems.GetArray(i, iProduct);
		
		if(StrEqual(name, iProduct.name))
			return i;
	}

	int cost = GetNativeCell(3);
	int minLevel = GetNativeCell(4);

	char sClassname[64];
	GetNativeString(5, sClassname, sizeof(sClassname));
	
	// Weapon requirements cannot reduce min level.
	for(int i=minLevel;i < MAX_LEVEL;i++)
	{
		if(StrEqual(sClassname, GUNS_CLASSNAMES[i]))
		{
			minLevel = i;
			break;
		}
	}

	product.name = name;
	product.description = description;
	product.cost = cost;
	product.minLevel = minLevel;

	return g_aUnlockItems.PushArray(product);
}

public any Native_IsProductUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int productIndex = GetNativeCell(2);


	return g_bUnlockedProducts[client][productIndex];
}
*/
/*public any Native_IsFFA(Handle caller, int numParams)
{
	return GetConVarBool(FindConVar("mp_teammates_are_enemies"));
}
*/

// This basically means "Treat the situation as if we bought every product again"

// If you got a teleport grenade bought, and this plugin is called, you will get a free smoke.
/*
public int Native_ReplenishProducts(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	for(int i=0;i < g_aUnlockItems.Length;i++)
	{
		enProduct iProduct;
		g_aUnlockItems.GetArray(i, iProduct);
		
		if(g_bUnlockedProducts[client][i])
		{

			Call_StartForward(g_fwOnUnlockShopBuy);

			Call_PushCell(client);
			Call_PushCell(i);

			Call_Finish();
		}
	}

	return 0;
}
*/
public void OnPluginStart()
{
	//g_fwOnUnlockShopBuy = CreateGlobalForward("GunXP_UnlockShop_OnProductBuy", ET_Ignore, Param_Cell, Param_Cell);
	g_fwOnSkillBuy = CreateGlobalForward("GunXP_RPGShop_OnSkillBuy", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnPerkTreeBuy = CreateGlobalForward("GunXP_RPGShop_OnPerkTreeBuy", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnSpawned = CreateGlobalForward("GunXP_RPG_OnPlayerSpawned", ET_Ignore, Param_Cell);

	//g_aUnlockItems = CreateArray(sizeof(enProduct));
	g_aSkills = CreateArray(sizeof(enSkill));
	g_aPerkTrees = CreateArray(sizeof(enPerkTree));

	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("GunXP-RPG");
	
	#endif
	
	RegConsoleCmd("sm_xp", Command_XP);
	RegConsoleCmd("sm_guns", Command_Guns);
	//RegConsoleCmd("sm_ul", Command_UnlockShop);
	RegAdminCmd("sm_givexp", Command_GiveXP, ADMFLAG_ROOT);
	RegConsoleCmd("sm_rpg", Command_RPG);
	RegConsoleCmd("sm_skills", Command_Skills);
	RegConsoleCmd("sm_skill", Command_Skills);
	RegConsoleCmd("sm_perk", Command_PerkTrees);
	RegConsoleCmd("sm_perks", Command_PerkTrees);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("infected_death", Event_CommonDeath, EventHookMode_Pre);

	// I want tanks and witches to have special "tiers".
	//HookEvent("tank_killed", Event_TankDeath, EventHookMode_Pre);
	//HookEvent("witch_killed", Event_WitchDeath);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("defibrillator_used", Event_DefibSuccess);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	
	SetConVarString(UC_CreateConVar("gun_xp_version", PLUGIN_VERSION), PLUGIN_VERSION);

	hcv_xpSIKill = UC_CreateConVar("gun_xp_si_kill", "15", "Amount of xp you get per SI kill");
	hcv_xpSIHS = UC_CreateConVar("gun_xp_si_kill_bonus_hs", "5", "Amount of bonus xp you get per SI headshot kill");


	hcv_xpKillingSpree = UC_CreateConVar("gun_xp_killing_spree", "10", "Amount of XP you get per killing spree");
	hcv_xpKillingSpreeNumber = UC_CreateConVar("gun_xp_killing_spree_number", "20", "Amount of commons to kill for a killing spree");

	hcv_xpHeadshotSpree = UC_CreateConVar("gun_xp_headshot_spree", "30", "Amount of xp you get per headshot spree");
	hcv_xpHeadshotSpreeNumber = UC_CreateConVar("gun_xp_headshot_spree_number", "20", "Amount of common headshots for a headshot spree");

	hcv_xpHeal = UC_CreateConVar("gun_xp_heal", "20", "Amount of XP gained for healing, including medkit spam");
	hcv_xpDefib = UC_CreateConVar("gun_xp_defib", "30", "Amount of XP gained for defibrillating a survivor");
	hcv_xpRevive = UC_CreateConVar("gun_xp_revive", "12", "Amount of XP gained for reviving an incapped survivor");
	hcv_xpLedge = UC_CreateConVar("gun_xp_ledge", "0", "Amount of XP gained for reviving a survivor from a ledge. This can be farmed easily.");

	hcv_VIPMultiplier = UC_CreateConVar("gun_xp_vip_multiplier", "1.0", "How much to mulitply rewards for VIP players. 1 to disable.");
	
	cpLastSecondary = RegClientCookie("GunXP_LastSecondary", "Last Chosen Secondary Weapon", CookieAccess_Private);
	cpLastPrimary = RegClientCookie("GunXP_LastPrimary", "Last Chosen Primary Weapon", CookieAccess_Private);
	cpAutoRPG = RegClientCookie("GunXP_AutoRPG", "Are we playing auto RPG?", CookieAccess_Private);
	
	#if defined _autoexecconfig_included
	
	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();
	
	#endif

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsClientAuthorized(i))
			continue;

		// Prevent issues of late load...
		g_bTookWeapons[i] = true;
	}

	RegPluginLibrary("GunXP_PerkTreeShop");
	RegPluginLibrary("GunXP_SkillShop");

	ConnectDatabase();
}


public void ConnectDatabase()
{
	char     error[256];
	Database hndl;
	if ((hndl = SQLite_UseDatabase("GunXP-RPG", error, sizeof(error))) == null)
		SetFailState(error);

	else
	{
		dbGunXP = hndl;

		dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_Players (AuthId VARCHAR(32) NOT NULL UNIQUE, LastName VARCHAR(64) NOT NULL, XP INT(11) NOT NULL, XPCurrency INT(11) NOT NULL, LastSecondary INT(11) NOT NULL, LastPrimary INT(11) NOT NULL)", 2, DBPrio_High);
		dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_PerkTrees (AuthId VARCHAR(32) NOT NULL, PerkTreeIdentifier VARCHAR(32) NOT NULL, PerkTreeLevel INT(11) NOT NULL, UNIQUE(AuthId, PerkTreeIdentifier))", 2, DBPrio_High);
		dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_Skills (AuthId VARCHAR(32) NOT NULL, SkillIdentifier VARCHAR(32) NOT NULL, UNIQUE(AuthId, SkillIdentifier))", 2, DBPrio_High);

		dbFullConnected = true;

		for (int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			OnClientPutInServer(i);
			
			if(IsClientAuthorized(i))
				FetchStats(i);
		}
	}
}


public void OnClientConnected(int client)
{
	SaveLastGuns[client] = false;

	CalculateStats(client);
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_HudMessageXP, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	CreateTimer(1.0, Timer_AutoRPG, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		
	CreateTimer(150.0, Timer_TellAboutShop,_, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_AutoRPG(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;

		else if(!g_bLoadedFromDB[i])
			continue;

		else if(!IsClientAutoRPG(i))
			continue;
		
		int iPosPerkTree;
		int iCostPerkTree;
		bool bFoundPerkTree = AutoRPG_FindCheapestPerkTree(i, iPosPerkTree, iCostPerkTree);

		int iPosSkill;
		int iCostSkill;
		bool bFoundSkill = AutoRPG_FindCheapestSkill(i, iPosSkill, iCostSkill);

		// Only need to check both, as the unfound will have infinite cost.
		if(!bFoundPerkTree && !bFoundSkill)
			continue;

		if(iCostPerkTree < iCostSkill)
		{
			enPerkTree perkTree;
			g_aPerkTrees.GetArray(iPosPerkTree, perkTree);

			PurchasePerkTreeLevel(i, iPosPerkTree, perkTree, true);

			PrintToChat(i, "Successfully unlocked Perk Tree %s level %i!", perkTree.name, g_iUnlockedPerkTrees[i][iPosPerkTree] + 1);

			Call_StartForward(g_fwOnPerkTreeBuy);

			Call_PushCell(i);
			Call_PushCell(iPosPerkTree);

			// Auto RPG?
			Call_PushCell(true);

			Call_Finish();
		}
		else
		{
			enSkill skill;
			g_aSkills.GetArray(iPosSkill, skill);

			PurchaseSkill(i, iPosSkill, skill, true);

			PrintToChat(i, "Successfully unlocked the Skill %s!", skill.name);

			Call_StartForward(g_fwOnSkillBuy);

			Call_PushCell(i);
			Call_PushCell(iPosSkill);

			// Auto RPG?
			Call_PushCell(true);

			Call_Finish();
		}


	}
	return Plugin_Continue;
}
public Action Timer_HudMessageXP(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		
		char adrenalineFormat[64];

		if(IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(i) > 0.0)
		{
			FormatEx(adrenalineFormat, sizeof(adrenalineFormat), "\n[Adrenaline : %i sec]", RoundFloat(Terror_GetAdrenalineTime(i)));
		}

		if(LEVELS[g_iLevel[i]] != 2147483647)
			PrintHintText(i, "[Level : %i] | [XP : %i/%i]\n[XP Currency : %i] | [Weapon : %s]%s", g_iLevel[i], g_iXP[i], LEVELS[g_iLevel[i]], g_iXPCurrency[i], GUNS_NAMES[g_iLevel[i]], adrenalineFormat);
			
		else 
			PrintHintText(i, "[Level : %i] | [XP : %i/∞]\n[XP Currency : %i] | [Weapon : %s]%s", g_iLevel[i], g_iXP[i], g_iXPCurrency[i], GUNS_NAMES[g_iLevel[i]], adrenalineFormat);
	}

	return Plugin_Continue;
}


public Action Timer_TellAboutShop(Handle hTimer)
{

	PrintToChatAll("\x01Type\x03 !rpg\x01 to buy permanent perks!");
	
	return Plugin_Continue;
}

public void OnClientAuthorized(int client)
{
	if(!dbFullConnected)
		return;

	g_iCommonKills[client]     = 0;
	g_iCommonHeadshots[client] = 0;

	FetchStats(client);
}
public void OnClientPutInServer(int client)
{
	//SDKHook(client, SDKHook_WeaponEquip, SDKEvent_WeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, SDKEvent_WeaponDropPost);
}

public void SDKEvent_WeaponDropPost(int client, int weapon)
{
	if(weapon == -1)
		return;

	char sClassname[64];
	GetEdictClassname(weapon, sClassname, sizeof(sClassname)); 

	for(int i=0;i < sizeof(g_sAllowedDropWeapons);i++)
	{
		if(StrEqual(sClassname, g_sAllowedDropWeapons[i]))
		{
			return;
		}
	}

	AcceptEntityInput(weapon, "Kill");
}

/*
public Action SDKEvent_WeaponEquip(int client, int weapon) 
{
	char Classname[64]; 
	GetEdictClassname(weapon, Classname, sizeof(Classname)); 
	
	if(strncmp(Classname, "weapon_knife", 12) == 0)
		return Plugin_Continue;

	int i;
	bool Found = false;


	for(i=0;i < MAX_LEVEL;i++)
	{
		if(StrEqual(GUNS_CLASSNAMES[i], Classname))
		{
			Found = true;
			break;
		}
	}
    
	if(g_iLevel[client] < i && Found)
	{
		AcceptEntityInput(weapon, "Kill");
		return Plugin_Handled;
	}
	
	return Plugin_Continue; 
}  */
/*public Action Command_UnlockShop(int client, int args)
{
	Handle hMenu = CreateMenu(UnlockShop_MenuHandler);

	char TempFormat[200];

	int gamemode = GetConVarInt(hcv_gameMode);

	for(int i=0;i < g_aUnlockItems.Length;i++)
	{
		enProduct product;
		g_aUnlockItems.GetArray(i, product);

		if(!(gamemode & product.gamemode))
			continue;
			
		if(g_iLevel[client] < product.minLevel)
		{
			FormatEx(TempFormat, sizeof(TempFormat), "%s - (%i XP) - (Level: %i)", product.name, product.cost, product.minLevel);
			AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DISABLED);
		}
		else
		{

			FormatEx(TempFormat, sizeof(TempFormat), "%s - (%i XP) - (%s)", product.name, product.cost, g_bUnlockedProducts[client][i] ? "Bought" : "Not Bought");
			AddMenuItem(hMenu, "", TempFormat, !g_bUnlockedProducts[client][i] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	SetMenuTitle(hMenu, "Choose perks to unlock:\nThe perks stay until until you disconnect.");
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int UnlockShop_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if(action == MenuAction_Select)
	{		
		enProduct product;
		g_aUnlockItems.GetArray(item, product);

		if(product.cost > g_iXP[client])
		{
			PrintToChat(client, "You need %i more XP to unlock this item!", product.cost - g_iXP[client]);
			return 0;
		}
		else
		{
			g_bUnlockedProducts[client][item] = true;

			AddClientXP(client, -1 * product.cost);

			PrintToChat(client, "Successfully unlocked %s!", product.name);

			Call_StartForward(g_fwOnUnlockShopBuy);

			Call_PushCell(client);
			Call_PushCell(item);

			Call_Finish();
		}

		//Command_UnlockShop(client, 0);
	}	

	return 0;
}
*/


public Action Command_Guns(int client, int args)
{
	ShowChoiceMenu(client);
	
	if(SaveLastGuns[client])
	{
		SaveLastGuns[client] = false;
		PrintToChat(client, "\x05Last guns save\x01 is now disabled.");
		
		if(g_bTookWeapons[client])
			return Plugin_Handled;
	}
	/*if(g_bTookWeapons[client])
		PrintToChat(client, "\01You have already taken weapons this round.");*/
		
	return Plugin_Handled;
}

public Action Command_GiveXP(int client, int args)
{	
	if (args < 1 || args > 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_givexp <#userid|name> [number of xp]");
		return Plugin_Handled;
	}
	char arg[MAX_NAME_LENGTH], arg2[10];
	GetCmdArg(1, arg, sizeof(arg));

	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		char Path[256], LogFormat[100];
		BuildPath(Path_SM, Path, sizeof(Path), "logs/gunxp.txt");
		
		Format(LogFormat, sizeof(LogFormat), "Admin %N has given %i EXP to %s.", client, StringToInt(arg2), arg);
		LogToFile(Path, LogFormat);
		
		AddClientXP(target_list[0], StringToInt(arg2), false);
		
		PrintToChatAll("\x01Admin\x03 %N\x01 has given\x04 %i\x01 XP to \x05%N", client, StringToInt(arg2), target_list[0]);
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	return Plugin_Handled;
}

public Action Command_RPG(int client, int args)
{
	Handle hMenu = CreateMenu(RPG_MenuHandler);

	char TempFormat[200];

	AddMenuItem(hMenu, "", "Reset choices [FREE]");

	if(IsClientAutoRPG(client))
	{
		AddMenuItem(hMenu, "", "Auto RPG [ON]");
	}
	else
	{
		AddMenuItem(hMenu, "", "Auto RPG [OFF]");
	}

	AddMenuItem(hMenu, "", "Perk Trees");
	AddMenuItem(hMenu, "", "Skills");

	FormatEx(TempFormat, sizeof(TempFormat), "Perk Trees are upgradable abilities.\nSkills are singular abilities.\nLevel : %i | XP : %i | XP Curency : %i", GetClientLevel(client), GetClientXP(client), GetClientXPCurrency(client));
	SetMenuTitle(hMenu, TempFormat);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int RPG_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if(action == MenuAction_Select)
	{		
		switch(item)
		{
			case 0:
			{
				ResetPerkTreesAndSkills(client);

				PrintToChat(client, "\x01You have successfully reset all your\x03 Perk Trees and Skills\x01.");
			}

			case 1:
			{
				SetClientAutoRPG(client, !IsClientAutoRPG(client));

				PrintToChat(client, "\x01Auto RPG mode is now\x03 %s", IsClientAutoRPG(client) ? "Enabled" : "Disabled");
			}
			case 2:
			{
				Command_PerkTrees(client, 0);
			}

			case 3:
			{
				Command_Skills(client, 0);
			}
		}
	}	

	return 0;
}	

public Action Command_PerkTrees(int client, int args)
{
	Handle hMenu = CreateMenu(PerkTreesShop_MenuHandler);

	char TempFormat[200];

	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree perkTree;
		g_aPerkTrees.GetArray(i, perkTree);

		if(g_iUnlockedPerkTrees[client][i] >= perkTree.costs.Length - 1)
		{
			Format(TempFormat, sizeof(TempFormat), "%s (0 XP) - (Lv. MAX)", perkTree.name);
			AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DEFAULT);
		}
		else
		{
			int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1);

			Format(TempFormat, sizeof(TempFormat), "%s (%i XP) - (Lv. %i)", perkTree.name, cost, g_iUnlockedPerkTrees[client][i] + 1);
			AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DEFAULT);
		}
	}


	FormatEx(TempFormat, sizeof(TempFormat), "Choose your Perk Trees:\nLevel : %i | XP : %i | XP Curency : %i", GetClientLevel(client), GetClientXP(client), GetClientXPCurrency(client));
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int PerkTreesShop_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Command_RPG(client, 0);
	}
	else if(action == MenuAction_Select)
	{		
		ShowPerkTreeInfo(client, item);
	}	

	return 0;
}	

public void ShowPerkTreeInfo(int client, int item)
{
	Handle hMenu = CreateMenu(PerkTreeInfo_MenuHandler);

	char TempFormat[1024];

	enPerkTree perkTree;
	g_aPerkTrees.GetArray(item, perkTree);

	char sInfo[11];
	IntToString(item, sInfo, sizeof(sInfo));

	AddMenuItem(hMenu, sInfo, "Upgrade Perk Tree", g_iUnlockedPerkTrees[client][item] >= perkTree.costs.Length - 1 || perkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][item] + 1) > GetClientLevel(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	if(g_iUnlockedPerkTrees[client][item] >= perkTree.costs.Length - 1)
	{
		char sCurrentUpgrade[128];
		perkTree.descriptions.GetString(g_iUnlockedPerkTrees[client][item], sCurrentUpgrade, sizeof(sCurrentUpgrade));
		
		FormatEx(TempFormat, sizeof(TempFormat), "%s (0 XP) - (Lv. MAX)\nCurrent Upgrade: %s", perkTree.name, sCurrentUpgrade);
		SetMenuTitle(hMenu, TempFormat);
	}
	else
	{
		int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][item] + 1);

		char sCurrentUpgrade[128];
		char sNextUpgrade[128];

		if(g_iUnlockedPerkTrees[client][item] == -1)
		{
			FormatEx(sCurrentUpgrade, sizeof(sCurrentUpgrade), "Nothing");
		}
		else
		{
			perkTree.descriptions.GetString(g_iUnlockedPerkTrees[client][item], sCurrentUpgrade, sizeof(sCurrentUpgrade));
		}
		perkTree.descriptions.GetString(g_iUnlockedPerkTrees[client][item] + 1, sNextUpgrade, sizeof(sNextUpgrade));
		FormatEx(TempFormat, sizeof(TempFormat), "Level: %i | XP Currency: %i\nRequired Level: %i\n%s (%i XP) - (Lv. %i)\nCurrent Upgrade: %s\nNext Upgrade: %s", GetClientLevel(client), GetClientXPCurrency(client), perkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][item] + 1), perkTree.name, cost, g_iUnlockedPerkTrees[client][item] + 1, sCurrentUpgrade, sNextUpgrade);
		SetMenuTitle(hMenu, TempFormat);
	}

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}


public int PerkTreeInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Command_PerkTrees(client, 0);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int perkIndex = StringToInt(sInfo);

		enPerkTree perkTree;

		g_aPerkTrees.GetArray(perkIndex, perkTree);

		int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][perkIndex] + 1);
		int levelReq = perkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][perkIndex] + 1);

		if(levelReq > GetClientLevel(client))
		{
			PrintToChat(client, "You need to reach Level %i to unlock this Perk Tree Level!", levelReq);
			return 0;
		}
		else if(cost > GetClientXPCurrency(client))
		{
			PrintToChat(client, "You need %i more XP Currency to unlock this Perk Tree level!", cost - GetClientXPCurrency(client));
			return 0;
		}
		else if(IsClientAutoRPG(client))
		{
			PrintToChat(client, "You must have auto RPG disabled to purhcase Perk Trees!");
			return 0;
		}
		else
		{
			PurchasePerkTreeLevel(client, perkIndex, perkTree, false);

			PrintToChat(client, "Successfully unlocked Perk Tree %s level %i!", perkTree.name, g_iUnlockedPerkTrees[client][perkIndex] + 1);

			Call_StartForward(g_fwOnPerkTreeBuy);

			Call_PushCell(client);
			Call_PushCell(perkIndex);

			// Auto RPG?
			Call_PushCell(false);

			Call_Finish();
		}
	}

	return 0;
}

public Action Command_Skills(int client, int args)
{
	Handle hMenu = CreateMenu(SkillShop_MenuHandler);

	char TempFormat[200];

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill skill;
		g_aSkills.GetArray(i, skill);

		Format(TempFormat, sizeof(TempFormat), "%s (%i XP) - (%s)", skill.name, skill.cost, g_bUnlockedSkills[client][i] ? "Bought" : "Not Bought");
		AddMenuItem(hMenu, "", TempFormat);
	}



	FormatEx(TempFormat, sizeof(TempFormat), "Choose your skills:\nYou have %i XP and %i XP Currency.", GetClientXP(client), GetClientXPCurrency(client));
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int SkillShop_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Command_RPG(client, 0);
	}
	else if(action == MenuAction_Select)
	{	
		ShowSkillInfo(client, item);
	}	

	return 0;
}	

public void ShowSkillInfo(int client, int item)
{
	Handle hMenu = CreateMenu(SkillInfo_MenuHandler);

	char TempFormat[1024];

	enSkill skill;
	g_aSkills.GetArray(item, skill);

	char sInfo[11];
	IntToString(item, sInfo, sizeof(sInfo));

	AddMenuItem(hMenu, sInfo, "Purchase Skill", g_bUnlockedSkills[client][item] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	FormatEx(TempFormat, sizeof(TempFormat), "Level: %i | XP Currency: %i\nRequired Level: %i\n%s (%i XP) - (%s)\nDescription: %s", GetClientLevel(client), GetClientXPCurrency(client), skill.levelReq, skill.name, skill.cost, g_bUnlockedSkills[client][item] ? "Bought" : "Not Bought", skill.description);
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}


public int SkillInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Command_Skills(client, 0);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int skillIndex = StringToInt(sInfo);

		enSkill skill;

		g_aSkills.GetArray(skillIndex, skill);

		if(skill.levelReq > GetClientLevel(client))
		{
			PrintToChat(client, "You need to reach Level %i to unlock this Perk Tree Level!", skill.levelReq);
			return 0;
		}
		else if(skill.cost > GetClientXPCurrency(client))
		{
			PrintToChat(client, "You need %i more XP Currency to unlock this skill!", skill.cost - GetClientXPCurrency(client));
			return 0;
		}
		else if(IsClientAutoRPG(client))
		{
			PrintToChat(client, "You must have auto RPG disabled to purhcase Perk Trees!");
			return 0;
		}
		else
		{
			PurchaseSkill(client, skillIndex, skill, false);

			PrintToChat(client, "Successfully unlocked the Skill %s!", skill.name);

			Call_StartForward(g_fwOnSkillBuy);

			Call_PushCell(client);
			Call_PushCell(skillIndex);

			// Auto RPG?
			Call_PushCell(false);

			Call_Finish();
		}

		Command_Skills(client, 0);
	}	

	return 0;
}	


public Action ShowChoiceMenu(int client)
{	
	CalculateStats(client);
	
	Handle hMenu = CreateMenu(Choice_MenuHandler);
	
	//MessageMenu[client] = hMenu;
	AddMenuItem(hMenu, "", "Choose Guns");
	AddMenuItem(hMenu, "", "Last Guns");
	AddMenuItem(hMenu, "", "Last Guns + Save");
	
	char TempFormat[100];
	
	if(g_iLevel[client] >= StartOfPrimary)
		Format(TempFormat, sizeof(TempFormat), "Choose your guns:\n \nLast Secondary: %s\nLast Primary: %s \n ", GUNS_NAMES[GetClientLastSecondary(client)], GUNS_NAMES[GetClientLastPrimary(client)]);
		
	else
		Format(TempFormat, sizeof(TempFormat), "Choose your guns:\n \nLast Secondary: %s\nLast Primary: NULL \n ", GUNS_NAMES[GetClientLastSecondary(client)]);
		
	SetMenuTitle(hMenu, TempFormat);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int Choice_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	
	else if(action == MenuAction_Select)
	{		
		switch(item)
		{
			case 0:	ChooseSecondaryMenu(client);
			case 1:
			{
				GiveGuns(client);
			}
			case 2:
			{
				GiveGuns(client);
				SaveLastGuns[client] = true;
				PrintToChat(client, "Last Guns save is now enabled. Type \x05!guns\x01 to disable it.");
			}
		}
	}	
	else if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(client))
			PrintToChat(client, "Type\x05 !guns\x01 to re-open this menu.");
	}

	return 0;
}

public void ChooseSecondaryMenu(int client)
{
	char TempFormat[200];
	CalculateStats(client);
	Handle hMenu = CreateMenu(Secondary_MenuHandler);

	for(int i=0;i < StartOfPrimary;i++)
	{
		Format(TempFormat, sizeof(TempFormat), "%s (Level: %i)", GUNS_NAMES[i], i);
		AddMenuItem(hMenu, "", TempFormat, g_iLevel[client] >= i ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	//MessageMenu[client] = hMenu;
	SetMenuTitle(hMenu, "Choose your Secondary Weapon:");
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int Secondary_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if(action == MenuAction_Select)
	{
		if(!IsClientInGame(client)) // Don't ask, I got an error :/
			return 0;
			
		SetClientLastSecondary(client, item);
		
		if(g_iLevel[client] >= StartOfPrimary)
			ChoosePrimaryMenu(client);
			
		else
			GiveGuns(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(client))
			PrintToChat(client, "Type\x05 !guns\x01 to re-open this menu.");
	}
	
	return 0;
}

void ChoosePrimaryMenu(int client)
{
	char TempFormat[200];
	CalculateStats(client);
	Handle hMenu = CreateMenu(Primary_MenuHandler);

	for(int i=StartOfPrimary;i < MAX_LEVEL;i++)
	{
		Format(TempFormat, sizeof(TempFormat), "%s (Level: %i)", GUNS_NAMES[i], i);
		AddMenuItem(hMenu, "", TempFormat, g_iLevel[client] >= i ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	//MessageMenu[client] = hMenu;
	SetMenuTitle(hMenu, "Choose your Primary Weapon:");
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int Primary_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if(action == MenuAction_Select)
	{
		if(!IsClientInGame(client)) // Don't ask, I got an error :/
			return 0;
			
		SetClientLastPrimary(client, StartOfPrimary + item);
		
		GiveGuns(client);
	}	
	else if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(client))
			PrintToChat(client, "Type\x05 !guns\x01 to re-open this menu.");
	}

	return 0;
}

public void GiveGuns(int client)
{
	if(!IsPlayerAlive(client))
		return;

	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return;

	else if(L4D_IsPlayerIncapacitated(client))
	{
		return;
	}

	StripPlayerWeapons(client);

	if(IsFakeClient(client))
	{
		GivePlayerItem(client, "weapon_rifle");
		GivePlayerItem(client, "weapon_pistol_magnum");

		return;
	}
	int LastSecondary, LastPrimary;
	LastSecondary = GetClientLastSecondary(client);
	LastPrimary = GetClientLastPrimary(client);
	
	if(LastPrimary > g_iLevel[client] || LastPrimary < StartOfPrimary)
		LastPrimary = StartOfPrimary;
		
	if(LastSecondary > g_iLevel[client] || LastSecondary >= StartOfPrimary)
		LastSecondary = 0;

	char sClassname[64];
	FormatEx(sClassname, sizeof(sClassname), "weapon_%s", GUNS_CLASSNAMES[LastSecondary]);	

	// No double pistols, but may be redundant with the above StripPlayerWeapons
	StripWeaponFromPlayer(client, sClassname);
	GivePlayerItem(client, GUNS_CLASSNAMES[LastSecondary]);

	if(g_iLevel[client] > 3 && StrEqual(GUNS_CLASSNAMES[LastSecondary], "pistol"))
	{
		GivePlayerItem(client, GUNS_CLASSNAMES[LastSecondary]);
	}
	
	if(g_iLevel[client] >= StartOfPrimary)
	{
		FormatEx(sClassname, sizeof(sClassname), "weapon_%s", GUNS_CLASSNAMES[LastPrimary]);	
		StripWeaponFromPlayer(client, sClassname);
		GivePlayerItem(client, GUNS_CLASSNAMES[LastPrimary]);
	}
		
	g_bTookWeapons[client] = true;
}

public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsClientInGame(victim))
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == victim || attacker == 0)
		return Plugin_Continue;

	bool headshot = GetEventBool(hEvent, "headshot");

	int xpToAdd = GetConVarInt(hcv_xpSIKill);
	int hsXP = GetConVarInt(hcv_xpSIHS);

	if(headshot)
	{
		xpToAdd += hsXP;
	}
	
	AddClientXP(attacker, xpToAdd);

	return Plugin_Continue;
}


public Action Event_CommonDeath(Handle hEvent, const char[] name, bool dontBroadcast)
{
	bool headshot = GetEventBool(hEvent, "headshot");

	int infected_id = GetEventInt(hEvent, "infected_id");
	int R           = 0;
	int G           = 0;
	int B           = 0;

	if (infected_id > 0)
	{
		SetEntProp(infected_id, Prop_Send, "m_glowColorOverride", R + (G * 256) + (B * 65536));
		SetEntProp(infected_id, Prop_Send, "m_iGlowType", 0);
		SetEntPropFloat(infected_id, Prop_Data, "m_flModelScale", 1.0);
		AcceptEntityInput(GetEntPropEnt(infected_id, Prop_Send, "m_hRagdoll"), "Kill");
	}

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if(attacker > 0 && L4D_GetClientTeam(attacker) == L4DTeam_Survivor && !IsFakeClient(attacker))
	{
		if (headshot)
		{
			g_iCommonHeadshots[attacker]++;
		}
		if (g_iCommonHeadshots[attacker] == GetConVarInt(hcv_xpHeadshotSpreeNumber) && GetConVarInt(hcv_xpHeadshotSpree) > 0)
		{
			if (GetConVarInt(hcv_xpHeadshotSpree) <= 0) return Plugin_Continue;

			g_iCommonHeadshots[attacker] = 0;
			
			int xpToAdd = GetConVarInt(hcv_xpHeadshotSpree);

			AddClientXP(attacker, xpToAdd);

		}

		g_iCommonKills[attacker]++;

		if (g_iCommonKills[attacker] == GetConVarInt(hcv_xpKillingSpreeNumber) && GetConVarInt(hcv_xpKillingSpree) > 0)
		{
			if (GetConVarInt(hcv_xpKillingSpree) <= 0) return Plugin_Continue;

			g_iCommonKills[attacker] = 0;
			int xpToAdd = GetConVarInt(hcv_xpKillingSpree);

			AddClientXP(attacker, xpToAdd);
		}
	}

	return Plugin_Continue;
}

public Action Event_HealSuccess(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "subject"));
	int subject = GetClientOfUserId(GetEventInt(hEvent, "subject"));

	if (subject != 0 && client != 0 && !IsFakeClient(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor)
	{
		if (client == subject) return Plugin_Continue;

		if (GetConVarInt(hcv_xpHeal) <= 0) return Plugin_Continue;

		int xpToAdd = GetConVarInt(hcv_xpHeal);

		AddClientXP(client, xpToAdd);
	}

	return Plugin_Continue;
}

public Action Event_ReviveSuccess(Handle hEvent, const char[] name, bool dontBroadcast)
{
	bool ledge = GetEventBool(hEvent, "ledge_hang");
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int subject = GetClientOfUserId(GetEventInt(hEvent, "subject"));

	if(!g_bTookWeapons[subject])
	{
		StripPlayerWeapons(subject);
		GiveGuns(subject);
	}
	
	if (client > 0 && !IsFakeClient(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor)
	{
		if (subject == client) return Plugin_Continue;
		if (!ledge && GetConVarInt(hcv_xpRevive) > 0)
		{
			if (GetConVarInt(hcv_xpRevive) <= 0) return Plugin_Continue;

			int xpToAdd = GetConVarInt(hcv_xpRevive);
			AddClientXP(client, xpToAdd);
		}
		if (ledge && GetConVarInt(hcv_xpLedge) > 0)
		{			
			if (GetConVarInt(hcv_xpLedge) <= 0) return Plugin_Continue;

			int xpToAdd = GetConVarInt(hcv_xpLedge);
			AddClientXP(client, xpToAdd);
		}
	}

	return Plugin_Continue;
}

public Action Event_DefibSuccess(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (client > 0 && !IsFakeClient(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor)
	{
		if (GetConVarInt(hcv_xpDefib) <= 0) return Plugin_Continue;

		int xpToAdd = GetConVarInt(hcv_xpDefib);

		AddClientXP(client, xpToAdd);
	}

	return Plugin_Continue;
}


public Action Event_PlayerSpawn(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return Plugin_Continue;

	int UserId = GetEventInt(hEvent, "userid");
	
	RequestFrame(Event_PlayerSpawnFrame, UserId);

	return Plugin_Continue;
}

public void Event_PlayerSpawnFrame(int UserId)
{
	int client = GetClientOfUserId(UserId);

	if(client == 0)
		return;

	else if(!IsPlayerAlive(client))
		return;
	
	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return;

	StripPlayerWeapons(client);
	GivePlayerItem(client, "weapon_pistol");
	
	CalculateStats(client);	
	
	g_bTookWeapons[client] = false;
	KillStreak[client] = 0;
	
	if(SaveLastGuns[client])
	{
		PrintToChat(client, "\x01Type\x05 !guns\x01 to disable\x05 auto gun save\x01.");
		GiveGuns(client);
	}
	else
		ShowChoiceMenu(client);

	SetEntityMaxHealth(client, 100);

	Call_StartForward(g_fwOnSpawned);

	Call_PushCell(client);

	Call_Finish();

	if(L4D_IsInFirstCheckpoint(client) || L4D_IsInLastCheckpoint(client))
	{
		SetEntityHealth(client, GetEntityMaxHealth(client));
	}
}


public Action Event_PlayerDisconnect(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	for(int i=0;i < MAX_ITEMS;i++)
		g_bUnlockedProducts[client][i] = false;

	return Plugin_Continue;
}
/*
public Action Event_WeaponOutOfAmmo(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return;
		
	GivePlayerAmmo(client, 999, GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"), true);
}
*/

public void OnEntityCreated(int entity, const char[] classname)
{
	// Sometimes a map will want to give RPG to continue progress.
	//if(StrEqual(classname, "game_player_equip"))
	//	SDKHook(entity, SDKHook_Spawn, OnShouldSpawn_NeverSpawn);

	for(int i=0;i < sizeof(g_sForbiddenMapWeapons);i++)
	{
		if(StrEqual(classname, g_sForbiddenMapWeapons[i]))
		{
			SDKHook(entity, SDKHook_Spawn, OnShouldSpawn_NeverSpawn);
		}
	}
}

public Action OnShouldSpawn_NeverSpawn(int entity)
{
	return Plugin_Handled;
}
public void OnWeaponReload(int weapon, bool bSuccessful)
{
	if(!bSuccessful)
		return;
		
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if(owner == -1)
		return;
		
	GivePlayerAmmo(owner, 999, GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"), true);
}

public Action Command_XP(int client, int args)
{
	CalculateStats(client);
	if(args == 0)
	{
		PrintToChat(client, "\x01You have\x03 %i\x01 xp. [Level:\x03 %i\x01]. [XP Currency:\x03 %i\x01].", g_iXP[client], g_iLevel[client], GetClientXPCurrency(client));
	}
	else
	{
		char arg1[MAX_TARGET_LENGTH];
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;
		
		GetCmdArg(1, arg1, sizeof(arg1));
	
		if ((target_count = ProcessTargetString(
				arg1,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_NO_MULTI	,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
	
		CalculateStats(target_list[0]);
		PrintToChat(client, "\x01%N has\x03 %i\x01 xp. [Level:\x03 %i\x01]. [XP Currency:\x03 %i\x01].", target_list[0], g_iXP[target_list[0]], g_iLevel[target_list[0]], GetClientXPCurrency(target_list[0]));
	}
	return Plugin_Handled;
}


stock void FetchStats(int client)
{
	g_iXP[client] = 0;
	g_iLevel[client] = 0;
	g_iXPCurrency[client] = 0;

	g_bLoadedFromDB[client] = false;

	for(int i=0;i < MAX_ITEMS;i++)
	{
		g_bUnlockedSkills[client][i] = false;
		g_iUnlockedPerkTrees[client][i] = PERK_TREE_NOT_UNLOCKED;
	}

	Transaction transaction = SQL_CreateTransaction();

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_Players WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_Skills WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_PerkTrees WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	Handle DP = CreateDataPack();

	WritePackCell(DP, GetClientUserId(client));

	dbGunXP.Execute(transaction, SQLTrans_PlayerLoaded, SQLTrans_SetFailState, DP);
}

stock void CalculateStats(int client)
{
	if(!IsClientInGame(client))
		return;
		
	g_iLevel[client] = 0;
	g_iXP[client] = GetClientXP(client);

	for(int i=0;i < MAX_LEVEL;i++)
	{
		if(g_iXP[client] >= LEVELS[i])
			g_iLevel[client]++;
	}
}

stock void AddClientXP(int client, int amount, bool bPremiumMultiplier = true)
{	
	float PremiumMultiplier = GetConVarFloat(hcv_VIPMultiplier);
	
	if(CheckCommandAccess(client, "sm_vip_cca", ADMFLAG_VIP) && PremiumMultiplier != 1.0 && bPremiumMultiplier)
	{
		float xp = float(amount);
		
		xp *= PremiumMultiplier;
		
		amount = RoundFloat(xp);
	}

	CalculateStats(client);
	
	int preCalculatedLevel = g_iLevel[client];
	
	g_iXP[client] += amount;
	g_iXPCurrency[client] += amount;

	for(int i=preCalculatedLevel;i < MAX_LEVEL;i++)
	{
		if(g_iXP[client] >= LEVELS[i])
		{
			PrintToChatAll("\x03%N\x01 has\x04 leveled up\x01 to level\x05 %i\x01!", client, i + 1);
			SaveLastGuns[client] = false;
		}
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XP = XP + %i, XPCurrency = XPCurrency + %i WHERE AuthId = '%s'", amount, amount, AuthId);

	dbGunXP.Query(SQLCB_Error, sQuery);	

	CalculateStats(client);
}

stock int GetClientXP(int client)
{	
	return g_iXP[client];
}

stock int GetClientXPCurrency(int client)
{	
	return g_iXPCurrency[client];
}

stock int GetClientLevel(int client)
{	
	return g_iLevel[client];
}

stock void ResetPerkTreesAndSkills(int client)
{
	for(int i=0;i < MAX_ITEMS;i++)
	{
		g_bUnlockedSkills[client][i] = false;
		g_iUnlockedPerkTrees[client][i] = -1;
	}

	g_iXPCurrency[client] = g_iXP[client];

	Transaction transaction = SQL_CreateTransaction();

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XP WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_Skills WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_PerkTrees WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
}


stock void PurchasePerkTreeLevel(int client, int perkIndex, enPerkTree perkTree, bool bAuto)
{
	g_iUnlockedPerkTrees[client][perkIndex]++;

	int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][perkIndex]);
	g_iXPCurrency[client] -= cost;

	Transaction transaction = SQL_CreateTransaction();

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency - %i WHERE AuthId = '%s'", cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// PerkTreeLevel to -1 to immediately increment it.
	dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT OR IGNORE INTO GunXP_PerkTrees (AuthId, PerkTreeIdentifier, PerkTreeLevel) VALUES ('%s', '%s', -1)", AuthId, perkTree.identifier);
	SQL_AddQuery(transaction, sQuery);
	
	dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_PerkTrees SET PerkTreeLevel = PerkTreeLevel + 1 WHERE AuthId = '%s' AND PerkTreeIdentifier = '%s'", AuthId, perkTree.identifier);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);

	if(!bAuto)
		ShowPerkTreeInfo(client, perkIndex);
}

stock void PurchaseSkill(int client, int skillIndex, enSkill skill, bool bAuto)
{
	g_bUnlockedSkills[client][skillIndex] = true;

	g_iXPCurrency[client] -= skill.cost;

	Transaction transaction = SQL_CreateTransaction();

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency - %i WHERE AuthId = '%s'", skill.cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// INSERT INTO will guarantee an error if we give someone the same skill twice.
	dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT INTO GunXP_Skills (AuthId, SkillIdentifier) VALUES ('%s', '%s')", AuthId, skill.identifier);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);

	if(!bAuto)
		ShowSkillInfo(client, skillIndex);
}

public void SQLTrans_PlayerLoaded(Database db, any DP, int numQueries, DBResultSet[] results, any[] queryData)
{
	ResetPack(DP);

	int userId = ReadPackCell(DP);

	CloseHandle(DP);

	int client = GetClientOfUserId(userId);

	if(client == 0)
		return;
	
	if(!SQL_FetchRow(results[0]))
	{
		g_iXP[client] = 0;
		g_iXPCurrency[client] = 0;

		g_bLoadedFromDB[client] = true;

		char AuthId[35];
		GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

		char Name[64];
		GetClientName(client, Name, sizeof(Name));

		char sQuery[512];
		dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT OR IGNORE INTO GunXP_Players (AuthId, LastName, XP, XPCurrency, LastSecondary, LastPrimary) VALUES ('%s', '%s', 0, 0, 0, 0)", AuthId, Name);

		// We just loaded the client, and this is the first query made after authentication. We need to skip any queued queries to increase XP.
		dbGunXP.Query(SQLCB_Error, sQuery, _, DBPrio_High);	

		return;
	}

	g_iXP[client] = SQL_FetchIntByName(results[0], "XP");
	g_iXPCurrency[client] = SQL_FetchIntByName(results[0], "XPCurrency");

	while (SQL_FetchRow(results[1]))
	{
		char SkillIdentifier[32];
		SQL_FetchStringByName(results[1], "SkillIdentifier", SkillIdentifier, sizeof(SkillIdentifier));

		for(int i=0;i < g_aSkills.Length;i++)
		{
			enSkill iSkill;
			g_aSkills.GetArray(i, iSkill);
			
			if(StrEqual(SkillIdentifier, iSkill.identifier))
			{
				g_bUnlockedSkills[client][i] = true;

				// I don't like breaking in two for loops...
				i = g_aSkills.Length;
			}
		}
	}

	while (SQL_FetchRow(results[2]))
	{
		char PerkTreeIdentifier[32];
		SQL_FetchStringByName(results[2], "PerkTreeIdentifier", PerkTreeIdentifier, sizeof(PerkTreeIdentifier));

		for(int i=0;i < g_aPerkTrees.Length;i++)
		{
			enSkill iPerkTree;
			g_aPerkTrees.GetArray(i, iPerkTree);
			
			if(StrEqual(PerkTreeIdentifier, iPerkTree.identifier))
			{
				g_iUnlockedPerkTrees[client][i] = SQL_FetchIntByName(results[2], "PerkTreeLevel");

				// I don't like breaking in two for loops...
				i = g_aPerkTrees.Length;
			}
		}
	}

	g_bLoadedFromDB[client] = true;

	CalculateStats(client);
}

public void SQLTrans_SetFailState(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState("Transaction at index %i failed:\n%s", failIndex, error);
}


public void SQLCB_Error(Handle owner, DBResultSet hndl, const char[] Error, int QueryUniqueID)
{
	/* If something fucked up. */
	if (hndl == null)
		SetFailState("%s --> %i", Error, QueryUniqueID);
}

public void SQLCB_ErrorIgnore(Handle owner, DBResultSet hndl, const char[] Error, int Data)
{
}


stock void StripPlayerWeapons(int client)
{
	for(int i=0;i < 2;i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);
		
		if(weapon != -1)
		{
			if(!RemovePlayerItem(client, weapon))
				AcceptEntityInput(weapon, "Kill");
		}
	}
}

stock void SetClientLastSecondary(int client, int amount)
{
	char strAmount[30];
	
	IntToString(amount, strAmount, sizeof(strAmount));
	
	SetClientCookie(client, cpLastSecondary, strAmount);
	
}

stock int GetClientLastSecondary(int client)
{
	char strAmount[30];
	
	GetClientCookie(client, cpLastSecondary, strAmount, sizeof(strAmount));
	
	int amount = StringToInt(strAmount);
	
	return amount;
}


stock void SetClientLastPrimary(int client, int amount)
{
	char strAmount[30];
	
	IntToString(amount, strAmount, sizeof(strAmount));
	
	SetClientCookie(client, cpLastPrimary, strAmount);
	
}

stock bool IsClientAutoRPG(int client)
{
	char strAutoRPG[3];
	
	GetClientCookie(client, cpAutoRPG, strAutoRPG, sizeof(strAutoRPG));
	
	if(strAutoRPG[0] == EOS)
	{
		return true;
	}
	bool bAutoRPG = view_as<bool>(StringToInt(strAutoRPG));
	
	return bAutoRPG;
}

stock void SetClientAutoRPG(int client, bool bAutoRPG)
{
	char strAutoRPG[30];
	
	IntToString(view_as<int>(bAutoRPG), strAutoRPG, sizeof(strAutoRPG));
	
	SetClientCookie(client, cpAutoRPG, strAutoRPG);
	
}

stock int GetClientLastPrimary(int client)
{
	char strAmount[30];
	
	GetClientCookie(client, cpLastPrimary, strAmount, sizeof(strAmount));
	
	int amount = StringToInt(strAmount);
	
	return amount;
}

stock void SetHudMessage(float x = -1.0, float y = -1.0, float HoldTime = 6.0, int r = 255, int g = 0, int b = 0, int a = 255, int effects = 0, float fxTime = 12.0, float fadeIn = 0.0, float fadeOut = 0.0)
{
	SetHudTextParams(x, y, HoldTime, r, g, b, a, effects, fxTime, fadeIn, fadeOut);
}

stock bool IsStringNumber(char[] source)
{
	for(int i=0;i < strlen(source);i++)
	{
		if(!IsCharNumeric(source[i]))
		{
			if(i == 0 && source[i] == '-')
				continue;
			
			return false;
		}
	}
	
	return true;
}

stock void GetServerIP(char[] IPAddress, int length)
{
	int pieces[4];
	int longip = GetConVarInt(FindConVar("hostip"));
	
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;
	
	Format(IPAddress, length, "%d.%d.%d.%d:%i", pieces[0], pieces[1], pieces[2], pieces[3], GetConVarInt(FindConVar("hostport")));
}

// Returns -1 if not found, entity index if found
stock int PlayerHasWeapon(int client, const char[] Classname)
{
	int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	
	for(int i=0;i < size;i++)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		
		if(weapon == -1)
			continue;
			
		char iClassname[64];
		GetEdictClassname(weapon, iClassname, sizeof(iClassname));
		
		if(StrEqual(Classname, iClassname))
			return weapon;
	}
	
	return -1;
}

stock int GivePlayerItemIfNotExists(int client, const char[] Classname)
{
	int weapon = PlayerHasWeapon(client, Classname);

	if(weapon != -1)
		return weapon;
		
	weapon = GivePlayerItem(client, Classname);
	
	return weapon;
}

stock bool StripWeaponFromPlayer(int client, const char[] Classname)
{
	int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	
	for(int i=0;i < size;i++)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		
		if(weapon == -1)
			continue;
			
		char iClassname[64];
		GetEdictClassname(weapon, iClassname, sizeof(iClassname));
		
		if(StrEqual(Classname, iClassname))
		{
			if(!RemovePlayerItem(client, weapon))
				AcceptEntityInput(weapon, "Kill");
				
			return true;
		}
	}
	
	return false;
}

stock void PrintToChatEyal(const char[] format, any ...)
{
	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;

		char steamid[64];
		GetClientAuthId(i, AuthId_Engine, steamid, sizeof(steamid));
		
		if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
			PrintToChat(i, buffer);
	}
}

/**
 * Adds an informational string to the server's public "tags".
 * This string should be a short, unique identifier.
 *
 *
 * @param tag            Tag string to append.
 * @noreturn
 */
stock void AddServerTag2(const char[] tag)
{
	Handle hTags = INVALID_HANDLE;
	hTags        = FindConVar("sv_tags");

	if (hTags != INVALID_HANDLE)
	{
		int flags = GetConVarFlags(hTags);

		SetConVarFlags(hTags, flags & ~FCVAR_NOTIFY);

		char tags[50];    // max size of sv_tags cvar
		GetConVarString(hTags, tags, sizeof(tags));
		if (StrContains(tags, tag, true) > 0) return;
		if (strlen(tags) == 0)
		{
			Format(tags, sizeof(tags), tag);
		}
		else
		{
			Format(tags, sizeof(tags), "%s,%s", tags, tag);
		}
		SetConVarString(hTags, tags, true);

		SetConVarFlags(hTags, flags);
	}
}

/**
 * Removes a tag previously added by the calling plugin.
 *
 * @param tag            Tag string to remove.
 * @noreturn
 */
stock void RemoveServerTag2(const char[] tag)
{
	Handle hTags = INVALID_HANDLE;
	hTags        = FindConVar("sv_tags");

	if (hTags != INVALID_HANDLE)
	{
		int flags = GetConVarFlags(hTags);

		SetConVarFlags(hTags, flags & ~FCVAR_NOTIFY);

		char tags[50];    // max size of sv_tags cvar
		GetConVarString(hTags, tags, sizeof(tags));
		if (StrEqual(tags, tag, true))
		{
			Format(tags, sizeof(tags), "");
			SetConVarString(hTags, tags, true);
			return;
		}

		int pos = StrContains(tags, tag, true);
		int len = strlen(tags);
		if (len > 0 && pos > -1)
		{
			bool found;
			char taglist[50][50];
			ExplodeString(tags, ",", taglist, sizeof(taglist[]), sizeof(taglist));
			for (int i = 0; i < sizeof(taglist[]); i++)
			{
				if (StrEqual(taglist[i], tag, true))
				{
					Format(taglist[i], sizeof(taglist), "");
					found = true;
					break;
				}
			}
			if (!found) return;
			ImplodeStrings(taglist, sizeof(taglist[]), ",", tags, sizeof(tags));
			if (pos == 0)
			{
				tags[0] = 0x20;
			}
			else if (pos == len - 1)
			{
				Format(tags[strlen(tags) - 1], sizeof(tags), "");
			}
			else
			{
				ReplaceString(tags, sizeof(tags), ",,", ",");
			}

			SetConVarString(hTags, tags, true);

			SetConVarFlags(hTags, flags);
		}
	}
}

stock int Abs(int value)
{
	if(value >= 0)
		return value;

	return -1 * value;
}



// AUTO RPG

stock bool AutoRPG_FindCheapestPerkTree(int client, int &position, int &cost)
{
	CalculateStats(client);

	position = -1;

	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree iPerkTree;
		g_aPerkTrees.GetArray(i, iPerkTree);

		// This also safely enables checking for next level without leaving array bounds.
		if(g_iUnlockedPerkTrees[client][i] >= iPerkTree.costs.Length - 1)
			continue;

		else if(GetClientLevel(client) < iPerkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][i] + 1))
			continue;

		else if(GetClientXPCurrency(client) < iPerkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1))
			continue;

		if(position == -1 || iPerkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1) < cost)
		{
			position = i;
			cost = iPerkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1);
		}
	}

	if(position == -1)
	{
		cost = 2147483647;
		return false;
	}

	return true;
}

stock bool AutoRPG_FindCheapestSkill(int client, int &position, int &cost)
{
	CalculateStats(client);

	position = -1;

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill iSkill;
		g_aSkills.GetArray(i, iSkill);

		if(GetClientLevel(client) < iSkill.levelReq)
			continue;

		else if(GetClientXPCurrency(client) < iSkill.cost)
			continue;

		if(position == -1 || iSkill.cost < cost)
		{
			position = i;
			cost = iSkill.cost;
		}
	}

	if(position == -1)
	{
		cost = 2147483647;
		return false;
	}

	return true;
}

stock int GetClosestLevelToXP(int xp)
{
	int level = 0;

	for(int i=0;i < MAX_LEVEL;i++)
	{
		if(xp >= LEVELS[i])
			level++;
	}

	return level;
}