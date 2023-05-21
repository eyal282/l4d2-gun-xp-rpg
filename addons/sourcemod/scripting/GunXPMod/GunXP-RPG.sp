#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <smlib>

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

bool SaveLastGuns[MAXPLAYERS+1];

Handle hcv_xpKill = INVALID_HANDLE;
Handle hcv_xpHS = INVALID_HANDLE;
Handle hcv_MinPlayers = INVALID_HANDLE;
Handle hcv_MaxLevelBypass = INVALID_HANDLE;
Handle hcv_VIPMultiplier = INVALID_HANDLE;
Handle hcv_Zeus = INVALID_HANDLE;

Handle hcv_FriendlyFire = INVALID_HANDLE;
Handle hcv_spawnProtectTime = INVALID_HANDLE;

Handle hcv_IgnoreRoundWinConditions = INVALID_HANDLE;
Handle hcv_autoRespawn = INVALID_HANDLE;

int KillStreak[MAXPLAYERS+1];

int Level[MAXPLAYERS+1], XP[MAXPLAYERS+1], XPCurrency[MAXPLAYERS+1];

Database dbGunXP;

bool dbFullConnected;

Handle cpLastSecondary, cpLastPrimary;

bool TookWeapons[MAXPLAYERS+1];

int StartOfPrimary = 13; // Change to the beginning of rifles in the levels, remember to count [0]

int HUD_INFO_CHANNEL = 25;
int HUD_KILL_CHANNEL = 82;

#define MAX_LEVEL 28

enum struct enProduct
{
	char name[64];
	char description[512];

	// cost in XP.
	int cost;
	// min level to use.
	int minLevel;
}

enum struct enSkill
{
	// Database entry of the skill. Never change this.
	char identifier[32];

	char name[64];
	char description[512];

	// Cost in XP.
	int cost;

	// ArrayList of skill identifiers required to go into this skill.
	ArrayList reqIdentifiers;
}

enum struct enPerkTree
{
	// Database entry of the perk tree. Never change this.
	char identifier[32];
	char name[64];

	// descriptions and costs are arrays that should be identical length to indicate what the perk does at each level, and cost at each level.
	ArrayList descriptions[512];
	ArrayList costs;

	// ArrayList of skill identifiers required to go into this skill.
	ArrayList reqIdentifiers;
}

ArrayList g_aUnlockItems;
ArrayList g_aSkills;
ArrayList g_aPerkTrees;

#define MAX_ITEMS 128

bool g_bUnlockedProducts[MAXPLAYERS+1][MAX_ITEMS];
bool g_bUnlockedSkills[MAXPLAYERS+1][MAX_ITEMS];
bool g_bUnlockedPerkTrees[MAXPLAYERS+1][MAX_ITEMS];

GlobalForward g_fwOnUnlockShopBuy;
GlobalForward g_fwOnSkillBuy;
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
	700, // needed for level 5
	1200, // needed for level 6
	1800, // needed for level 7
	2800, // needed for level 8
	4100, // needed for level 9 
	5200, // needed for level 10 
	6000, // needed for level 11 
	6800, // needed for level 12 
	8200, // needed for level 13 
	10200, // needed for level 14, the first rifle
	12000, // needed for level 15 
	15000, // needed for level 16 
	17500, // needed for level 17 
	20500, // needed for level 18 
	25500, // needed for level 19 
	29000, // needed for level 20 
	35000, // needed for level 21 
	46000, // needed for level 22 
	58000, // needed for level 23 
	71000,  // needed for level 24 
	85000,  // needed for level 25 
	100000,  // needed for level 26
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
	"fireaxe",
	"magnum",
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


public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{	
	CreateNative("GunXP_SkillShop_RegisterSkill", Native_RegisterSkill);
	CreateNative("GunXP_SkillShop_IsSkillUnlocked", Native_IsSkillUnlocked);
	CreateNative("GunXP_SkillShop_RegisterPerkTree", Native_RegisterPerkTree);
	CreateNative("GunXP_SkillShop_IsPerkTreeUnlocked", Native_IsPerkTreeUnlocked);

	CreateNative("GunXP_UnlockShop_RegisterProduct", Native_RegisterProduct);
	CreateNative("GunXP_UnlockShop_ReplenishProducts", Native_ReplenishProducts);
	CreateNative("GunXP_UnlockShop_IsProductUnlocked", Native_IsProductUnlocked);

	//CreateNative("GunXP_IsFFA", Native_IsFFA);

	RegPluginLibrary("GunXPMod");
	RegPluginLibrary("GunXP_UnlockShop");
	RegPluginLibrary("GunXP_SkillShop");

	return APLRes_Success;
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

	ArrayList reqIdentifiers = GetNativeCell(5);

	skill.reqIdentifiers = reqIdentifiers.Clone();
	skill.identifier = identifier;
	skill.name = name;
	skill.description = description;
	skill.cost = cost;

	delete reqIdentifiers;

	return g_aSkills.PushArray(skill);
}


public any Native_IsSkillUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int skillIndex = GetNativeCell(2);

	return view_as<bool>(g_bUnlockedSkills[client][skillIndex]);
}

public int Native_RegisterPerkTree(Handle caller, int numParams)
{
	enPerkTree perkTree;

	if(g_aPerkTrees == null)
		g_aPerkTrees = CreateArray(sizeof(g_aPerkTrees));

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

	ArrayList reqIdentifiers = GetNativeCell(5);

	skill.reqIdentifiers = reqIdentifiers.Clone();
	skill.identifier = identifier;
	skill.name = name;
	skill.description = description;
	skill.cost = cost;

	delete reqIdentifiers;

	return g_aSkills.PushArray(skill);
}


public any Native_IsSkillUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int skillIndex = GetNativeCell(2);

	return view_as<bool>(g_bUnlockedSkills[client][skillIndex]);
}

public int Native_RegisterProduct(Handle caller, int numParams)
{
	enProduct product;

	if(g_aUnlockItems == null)
		g_aUnlockItems = CreateArray(sizeof(enProduct));

	char name[64];
	GetNativeString(1, name, sizeof(name));

	char description[512];
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

/*public any Native_IsFFA(Handle caller, int numParams)
{
	return GetConVarBool(FindConVar("mp_teammates_are_enemies"));
}
*/

// This basically means "Treat the situation as if we bought every product again"

// If you got a teleport grenade bought, and this plugin is called, you will get a free smoke.
public int Native_ReplenishProducts(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	bool bOnlyUL = GetNativeCell(2);

	if(!bOnlyUL && IsPlayerAlive(client))
	{
		if(GetConVarBool(hcv_Zeus))
			GivePlayerItem(client, "weapon_taser");
	}
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


int prevButtons[MAXPLAYERS+1], prevMouse[MAXPLAYERS+1][2];

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	prevButtons[client] = buttons;
	prevMouse[client] = mouse;
}
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!GetConVarBool(hcv_autoRespawn))
	{
		float fTimeLeft = GetEntPropFloat(client, Prop_Send, "m_fImmuneToGunGameDamageTime") - GetGameTime();

		if(fTimeLeft >= 1000000.0)
		{
			SetEntPropFloat(client, Prop_Send, "m_fImmuneToGunGameDamageTime", GetGameTime() + GetConVarFloat(hcv_spawnProtectTime));
		}

		return Plugin_Continue;
	}

	Action rtn = Plugin_Continue;

	float fTimeLeft = GetEntPropFloat(client, Prop_Send, "m_fImmuneToGunGameDamageTime") - GetGameTime();

	if(fTimeLeft <= 0.0)
		return Plugin_Continue;

	if(prevButtons[client] == buttons && Abs(prevMouse[client][0] - mouse[0]) < 8 && Abs(prevMouse[client][1] - mouse[1]) < 8) // AFK?
	{
		// AFK with infinite spawn protection. Make sure to prevent movement...
		if(fTimeLeft >= 1000000.0)
		{
			vel[0] = 0.0;
			vel[1] = 0.0;
			rtn = Plugin_Continue;
		}
	}
	else
	{
		// Not AFK? Limit spawn protection to 4 seconds.
		if(fTimeLeft >= 1000000.0)
		{
			SetEntPropFloat(client, Prop_Send, "m_fImmuneToGunGameDamageTime", GetGameTime() + GetConVarFloat(hcv_spawnProtectTime));
		}
	}

	return rtn;
}
public void OnPluginStart()
{
	g_fwOnUnlockShopBuy = CreateGlobalForward("GunXP_UnlockShop_OnProductBuy", ET_Ignore, Param_Cell, Param_Cell);
	g_fwOnSkillBuy = CreateGlobalForward("GunXP_SkillShop_OnSkillBuy", ET_Ignore, Param_Cell, Param_Cell);
	g_fwOnSpawned = CreateGlobalForward("GunXP_OnPlayerSpawned", ET_Ignore, Param_Cell);

	g_aUnlockItems = CreateArray(sizeof(enProduct));
	g_aSkills = CreateArray(sizeof(enSkill));

	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("GunXPMod");
	
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
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	
	HookUserMessage(GetUserMessageId("TextMsg"), Message_TextMsg, true); 
	
	hcv_FriendlyFire = FindConVar("mp_friendlyfire");
	SetConVarString(UC_CreateConVar("gun_xp_version", PLUGIN_VERSION), PLUGIN_VERSION);
	hcv_autoRespawn = UC_CreateConVar("gun_xp_auto_respawn", "0", "Should we auto respawn players?");
	hcv_spawnProtectTime = UC_CreateConVar("gun_xp_respawn_immunitytime", "3", "From the moment the player moves, how long to spawn protect? AFK players are always spawn protected if there is auto respawn.");

	hcv_IgnoreRoundWinConditions = UC_CreateConVar("gun_xp_ignore_round_win_conditions", "0", "0 - Disabled. 1 - Rounds are infinite. 2 - Rounds are infinite except for bomb events.");
	hcv_xpKill = UC_CreateConVar("gun_xp_kill", "15", "Amount of xp you get per kill");
	hcv_xpHS = UC_CreateConVar("gun_xp_bonus_hs", "5", "Amount of bonus xp you get per headshot kill");
	hcv_MinPlayers = UC_CreateConVar("gun_xp_min_players", "4", "XP Gain is only possible if players count is equal or greater than this");
	hcv_MaxLevelBypass = UC_CreateConVar("gun_xp_max_players", "0", "Players equal or below this can gain EXP while bypassing hcv_MinPlayers. -1 to disable");
	hcv_VIPMultiplier = UC_CreateConVar("gun_xp_vip_multiplier", "2.0", "How much to mulitply rewards for VIP players. 1 to disable.");
	hcv_Zeus = UC_CreateConVar("gun_xp_zeus", "1", "Give zeus on spawn?"); // Note to self: level 10 gives you he, level 20 gives you flash in addition to he, level 30 gives you extra flash in addition to other.
	
	cpLastSecondary = RegClientCookie("GunXP_LastSecondary", "Last Chosen Secondary Weapon", CookieAccess_Private);
	cpLastPrimary = RegClientCookie("GunXP_LastPrimary", "Last Chosen Primary Weapon", CookieAccess_Private);
	
	#if defined _autoexecconfig_included
	
	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();
	
	#endif
	/*
	new String:ServerIP[50];
	
	GetServerIP(ServerIP, sizeof(ServerIP));
	
	if(!StrEqual(ServerIP, "93.186.198.117:30415"))
		SetFailState("Only Spectre Gaming can use this plugin.");
		
	*/

	RegPluginLibrary("GunXP_UnlockShop");

	ConnectDatabase();
}


public void ConnectDatabase()
{
	char     error[256];
	Database hndl;
	if ((hndl = SQLite_UseDatabase("GunXPMod", error, sizeof(error))) == null)
		SetFailState(error);

	else
	{
		dbGunXP = hndl;

		dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_Players (AuthId VARCHAR(32) NOT NULL UNIQUE, LastName VARCHAR(64) NOT NULL, XP INT(11) NOT NULL, XPCurrency INT(11) NOT NULL, LastSecondary INT(11) NOT NULL, LastPrimary INT(11) NOT NULL)", 2, DBPrio_High);
		dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_PerkTrees (AuthId VARCHAR(32) NOT NULL, PerkTreeIdentifier VARCHAR(32) NOT NULL, PerkTreeLevel INT(11) NOT NULL, UNIQUE(AuthId, SkillIdentifier))", 2, DBPrio_High);
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

public Action Message_TextMsg(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init) 
{ 
    char buffer[64]; 
    PbReadString(msg, "params", buffer, sizeof(buffer), 0); 

    if(StrContains(buffer, "Cash_Award") != -1) 
        return Plugin_Handled; 

	else if(StrContains(buffer, "teammate_attack") != -1 && !GetConVarBool(hcv_FriendlyFire))
		return Plugin_Handled;

    return Plugin_Continue; 
} 

public void OnClientConnected(int client)
{
	SaveLastGuns[client] = false;

	CalculateStats(client);
}

public void OnMapStart()
{
	CreateTimer(2.5, HudMessageXP, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		
	CreateTimer(150.0, TellAboutShop,_, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public Action HudMessageXP(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsValidPlayer(i))
			continue;
			
		SetHudMessage(0.2, 0.1, 2.5, 232, 61, 22);
		if(LEVELS[Level[i]] != 2147483647)
			ShowHudMessage(i, HUD_INFO_CHANNEL, "[Level : %i]\n[XP : %i/%i]\n[XP Currency : %i]\n[Weapon : %s]", Level[i], XP[i], LEVELS[Level[i]], XPCurrency[i], GUNS_NAMES[Level[i]]);
			
		else 
			ShowHudMessage(i, HUD_INFO_CHANNEL, "[Level : %i]\n[XP : %i/∞]\n[XP Currency : %i]\n[Weapon : %s]", Level[i], XP[i], XPCurrency[i], GUNS_NAMES[Level[i]]);
	}

	return Plugin_Continue;
}


public Action TellAboutShop(Handle hTimer)
{

	PrintToChatAll("\x01Type\x03 !rpg\x01 to buy permanent perks!");
	
	return Plugin_Continue;
}

public void OnClientAuthorized(int client)
{
	if(!dbFullConnected)
		return;

	FetchStats(client);
}
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquip, SDKEvent_WeaponEquip);
}


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
    
	if(Level[client] < i && Found)
	{
		AcceptEntityInput(weapon, "Kill");
		return Plugin_Handled;
	}
	
	return Plugin_Continue; 
}  
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
			
		if(Level[client] < product.minLevel)
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

		if(product.cost > XP[client])
		{
			PrintToChat(client, "You need %i more XP to unlock this item!", product.cost - XP[client]);
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
		
		if(TookWeapons[client])
			return Plugin_Handled;
	}
	/*if(TookWeapons[client])
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
		
		AddClientXP(target_list[0], StringToInt(arg2));
		
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

	AddMenuItem(hMenu, "", "Perk Trees");
	AddMenuItem(hMenu, "", "Skills");


	FormatEx(TempFormat, sizeof(TempFormat), "Perk Trees are upgradable abilities.\nSkills are singular abilities.:\nYou have %i XP and %i XP Currency.", GetClientXP(client), GetClientXPCurrency(client));
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
				Command_PerkTrees(client, 0);
			}

			case 2:
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

		if(g_iUnlockedPerkTrees[client][i] == perkTree.costs.Length)
		{
			Format(TempFormat, sizeof(TempFormat), "%s (0 XP) - (Lv. MAX)", perkTree.name, perkTree.cost);
			AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DEFAULT);
		}
		else
		{
			int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1);

			Format(TempFormat, sizeof(TempFormat), "%s (%i XP) - (Lv. %i)", perkTree.name, cost, g_iUnlockedPerkTrees[client][i]);
			AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DEFAULT);
		}
	}


	FormatEx(TempFormat, sizeof(TempFormat), "Choose your Perk Trees:\nYou have %i XP and %i XP Currency.", GetClientXP(client), GetClientXPCurrency(client));
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
		enperkTree perkTree;

		g_aPerkTrees.GetArray(item, perkTree);

		int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1);

		if(cost > GetClientXPCurrency(client))
		{
			PrintToChat(client, "You need %i more XP Currency to unlock this Perk Tree level!", cost - GetClientXPCurrency(client));
			return 0;
		}
		else
		{
			PurchasePerkTreeLevel(client, item, perkTree);

			PrintToChat(client, "Successfully unlocked Perk Tree %s level %i!", perkTree.name, item + 1);

			Call_StartForward(g_fwOnPerkTreeBuy);

			Call_PushCell(client);
			Call_PushCell(item);

			Call_Finish();
		}

		Command_Skills(client, 0);
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
		AddMenuItem(hMenu, "", TempFormat, g_bUnlockedSkills[client][i] || GetClientXPCurrency(client) < skill.cost ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
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
		enSkill skill;

		g_aSkills.GetArray(item, skill);

		if(skill.cost > GetClientXPCurrency(client))
		{
			PrintToChat(client, "You need %i more XP Currency to unlock this skill!", skill.cost - GetClientXPCurrency(client));
			return 0;
		}
		else
		{
			PurchaseSkill(client, item , skill);

			PrintToChat(client, "Successfully unlocked the skill %s!", skill.name);

			Call_StartForward(g_fwOnSkillBuy);

			Call_PushCell(client);
			Call_PushCell(item);

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
	
	if(Level[client] >= StartOfPrimary)
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
		if(IsValidPlayer(client))
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
		AddMenuItem(hMenu, "", TempFormat, Level[client] >= i ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
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
		if(!IsValidPlayer(client)) // Don't ask, I got an error :/
			return 0;
			
		SetClientLastSecondary(client, item);
		
		if(Level[client] >= StartOfPrimary)
			ChoosePrimaryMenu(client);
			
		else
			GiveGuns(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(IsValidPlayer(client))
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
		AddMenuItem(hMenu, "", TempFormat, Level[client] >= i ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
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
		if(!IsValidPlayer(client)) // Don't ask, I got an error :/
			return 0;
			
		SetClientLastPrimary(client, StartOfPrimary + item);
		
		GiveGuns(client);
	}	
	else if(action == MenuAction_Cancel)
	{
		if(IsValidPlayer(client))
			PrintToChat(client, "Type\x05 !guns\x01 to re-open this menu.");
	}

	return 0;
}

public void GiveGuns(int client)
{
	if(TookWeapons[client])
		return;
		
	else if(!IsPlayerAlive(client))
		return;

	int LastSecondary, LastPrimary;
	LastSecondary = GetClientLastSecondary(client);
	LastPrimary = GetClientLastPrimary(client);
	
	if(LastPrimary > Level[client] || LastPrimary < StartOfPrimary)
		LastPrimary = StartOfPrimary;
		
	if(LastSecondary > Level[client] || LastSecondary >= StartOfPrimary)
		LastSecondary = 0;
		
	StripWeaponFromPlayer(client, GUNS_CLASSNAMES[LastSecondary]);
	GivePlayerItem(client, GUNS_CLASSNAMES[LastSecondary]);
	
	if(Level[client] >= StartOfPrimary)
	{
		StripWeaponFromPlayer(client, GUNS_CLASSNAMES[LastPrimary]);
		GivePlayerItem(client, GUNS_CLASSNAMES[LastPrimary]);
	}
		
	TookWeapons[client] = true;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	// This is gun_xp_ignore_round_win_conditions
	switch(GetConVarInt(hcv_IgnoreRoundWinConditions))
	{
		case 1: return Plugin_Handled;
		case 2:
		{
			if(reason == CSRoundEnd_BombDefused || reason == CSRoundEnd_TargetBombed)
				return Plugin_Continue;
			
			else if(reason == CSRoundEnd_TargetSaved)
			{
				GameRules_SetPropFloat("m_flGameStartTime", GetGameTime());
				GameRules_SetPropFloat("m_fRoundStartTime", GetGameTime());
				GameRules_SetProp("m_iRoundTime", 60);

				return Plugin_Handled;
			}
			return Plugin_Handled;
		}
		default: return Plugin_Continue;
	}
}

public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsValidPlayer(victim))
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == victim || !IsValidPlayer(attacker))
		return Plugin_Continue;
	
	int players = 0;
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsValidPlayer(i))
			continue;
		
		else if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
			continue;
		
		players++;
	}
	
	int MinPlayers = GetConVarInt(hcv_MinPlayers);
	int BypassLevel = GetConVarInt(hcv_MaxLevelBypass);
	
	if(players < MinPlayers && BypassLevel < Level[attacker])
	{
		PrintToChat(attacker, "\x01There aren't enough players to gain XP, minimum\x03 %i\x01.", MinPlayers);
		return Plugin_Continue;
	}	

	bool headshot = GetEventBool(hEvent, "headshot");

	
	char HudFormat[100];
	int xpToAdd = GetConVarInt(hcv_xpKill);
	int hsXP = GetConVarInt(hcv_xpHS);
	int Colors[3];
	
	KillStreak[victim] = 0;	
	KillStreak[attacker]++;
	
	Colors = {0, 255, 0};
	// xpToAdd already equal to getconvarint(hcv_xpHs);
	Format(HudFormat, sizeof(HudFormat), "+ %i XP ( Kill )\n", xpToAdd);

	if(headshot && hsXP > 0)
	{
		xpToAdd += hsXP;
		Format(HudFormat, sizeof(HudFormat), "%s+ %i XP ( Headshot )\n", HudFormat, hsXP);
	}
	
	float PremiumMultiplier = GetConVarFloat(hcv_VIPMultiplier);
	if(CheckCommandAccess(attacker, "sm_checkcommandaccess_custom4", ADMFLAG_VIP) && PremiumMultiplier != 1.0)
	{
		float xp = float(xpToAdd);
		
		xp *= PremiumMultiplier;
		
		xpToAdd = RoundFloat(xp);
		
		Format(HudFormat, sizeof(HudFormat), "%sx %.1f XP ( VIP )\n", HudFormat, PremiumMultiplier);
	}
	if(HudFormat[0] != EOS)
	{
		SetHudMessage(0.05, 0.7, 6.0, Colors[0], Colors[1], Colors[2], 255, 1, 5.0);
		ShowHudMessage(attacker, HUD_KILL_CHANNEL, HudFormat);
	}
	AddClientXP(attacker, xpToAdd);
	SetEntProp(attacker, Prop_Send, "m_iAccount", 0);
	
	int LastLevel = Level[attacker];
	
	if(Level[attacker] > LastLevel)
	{
		SaveLastGuns[attacker] = false;
		ClientCommand(attacker, "play ui/xp_levelup.wav");
		PrintToChatAll("\x01Congratulations!\x03 %N\x01 has\x05 leveled up\x01 to\x04 %i", attacker, Level[attacker]);
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
	
	StripPlayerWeapons(client);
	
	CalculateStats(client);	
	
	TookWeapons[client] = false;
	KillStreak[client] = 0;
	SetEntProp(client, Prop_Send, "m_iAccount", 0);
	
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
	if(StrEqual(classname, "game_player_equip"))
		SDKHook(entity, SDKHook_Spawn, OnShouldSpawn_NeverSpawn);

	if(StrEqual(classname, "game_weapon_manager") || strncmp(classname, "weapon_knife", 12) == 0)
		return;
		
	if(StrContains(classname, "weapon_") != -1 && !StrEqual(classname, "weapon_hegrenade") && !StrEqual(classname, "weapon_flashbang") && !StrEqual(classname, "weapon_smokegrenade") && !StrEqual(classname, "weapon_molotov") && !StrEqual(classname, "weapon_incgrenade") && !StrEqual(classname, "weapon_decoy"))
		SDKHook(entity, SDKHook_ReloadPost, OnWeaponReload);

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
		PrintToChat(client, "\x01You have\x03 %i\x01 xp. [Level:\x03 %i\x01]. [XP Currency:\x03 %i\x01].", XP[client], Level[client], GetClientXPCurrency(client));
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
		PrintToChat(client, "\x01%N has\x03 %i\x01 xp. [Level:\x03 %i\x01]. [XP Currency:\x03 %i\x01].", target_list[0], XP[target_list[0]], Level[target_list[0]], GetClientXPCurrency(target_list[0]));
	}
	return Plugin_Handled;
}


stock void FetchStats(int client)
{
	for(int i=0;i < MAX_ITEMS;i++)
	{
		g_bUnlockedSkills[client][i] = false;
	}

	Transaction transaction = SQL_CreateTransaction();

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_Players WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_Skills WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	Handle DP = CreateDataPack();

	WritePackCell(DP, GetClientUserId(client));

	dbGunXP.Execute(transaction, SQLTrans_PlayerLoaded, SQLTrans_SetFailState, DP);
}

stock void CalculateStats(int client)
{
	if(!IsClientInGame(client))
		return;
		
	Level[client] = 0;
	XP[client] = GetClientXP(client);

	for(int i=0;i < MAX_LEVEL;i++)
	{
		if(XP[client] >= LEVELS[i])
			Level[client]++;
	}
	
	CS_SetMVPCount(client, Level[client]);
}

stock void AddClientXP(int client, int amount)
{	
	CalculateStats(client);
	
	int preCalculatedLevel = Level[client];
	
	XP[client] += amount;

	for(int i=preCalculatedLevel;i < MAX_LEVEL;i++)
	{
		if(XP[client] >= LEVELS[i])
		{
			PrintToChatAll("\x03%N\x01 has\x04 leveled up\x01 to level\x05 %i\x01!", client, i + 1);
			SaveLastGuns[client] = false;
		}
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XP = XP + %i WHERE AuthId = '%s'", amount, AuthId);

	dbGunXP.Query(SQLCB_Error, sQuery);	

	CalculateStats(client);
}

stock int GetClientXP(int client)
{	
	return XP[client];
}

stock int GetClientXPCurrency(int client)
{	
	return XPCurrency[client];
}


stock void ResetPerkTreesAndSkills(int client)
{
	for(int i=0;i < MAX_ITEMS;i++)
	{
		g_bUnlockedSkills[client][i] = false;
	}

	XPCurrency[client] = XP[client];

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

stock void PurchaseSkill(int client, int skillIndex, enSkill skill)
{
	g_bUnlockedSkills[client][skillIndex] = true;

	XPCurrency[client] -= skill.cost;

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
		XP[client] = 0;
		XPCurrency[client] = 0;

		char AuthId[35];
		GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

		char Name[64];
		GetClientName(client, Name, sizeof(Name));

		char sQuery[512];
		dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT INTO GunXP_Players (AuthId, LastName, XP, XPCurrency, LastSecondary, LastPrimary) VALUES ('%s', '%s', 0, 0, 0, 0)", AuthId, Name);

		// We just loaded the client, and this is the first query made after authentication. We need to skip any queued queries to increase XP.
		dbGunXP.Query(SQLCB_Error, sQuery, _, DBPrio_High);	

		return;
	}

	XP[client] = SQL_FetchIntByName(results[0], "XP");
	XPCurrency[client] = SQL_FetchIntByName(results[0], "XPCurrency");

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


stock bool IsValidPlayer(int client)
{
	if(client <= 0)
		return false;
		
	else if(client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}

stock void StripPlayerWeapons(int client)
{
	if(!IsValidPlayer(client))
		return;
	
	// <= 4 removes bomb
	for(int i=0;i < 4;i++)
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

stock void ShowHudMessage(int client, int channel = -1, char[] Message, any ...)
{
	char VMessage[300];
	VFormat(VMessage, sizeof(VMessage), Message, 4);
	
	if(client != 0)
		ShowHudText(client, channel, VMessage);
	
	else
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(IsValidPlayer(i))
				ShowHudText(i, channel, VMessage);
		}
	}
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
#if defined _autoexecconfig_included

stock ConVar UC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	return AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}

#else

stock ConVar UC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	return CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}
 
#endif



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


stock void SetEntityMaxHealth(int entity, int amount)
{
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", amount);
}

stock int GetEntityMaxHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

stock int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}