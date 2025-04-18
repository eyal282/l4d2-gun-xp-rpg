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

#define SOUND_CHANNEL SNDCHAN_STATIC

#define QUEST_COMPLETED_SOUND "music/safe/themonsterswithout.wav"

// How much times to play the sound?
#define QUEST_COMPLETED_SOUND_MULTIPLIER 3

#define LEVEL_UP_SOUND "music/safe/themonsterswithout_l4d1.wav"

// How much times to play the sound?
#define LEVEL_UP_SOUND_MULTIPLIER 3

//#define UNKNOWN_ERROR "\x01An unknown error has occured, action was aborted."

#define ADMFLAG_VIP ADMFLAG_CUSTOM2

#define PLUGIN_VERSION "1.0"

char INSERT_OR_IGNORE_INTO[64];

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
	"weapon_first_aid_kit",
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
	"weapon_sniper_awp_spawn",
	"weapon_sniper_military_spawn",
	"weapon_sniper_scout_spawn",
	"weapon_spawn"
};

bool g_bLate = false;
bool g_bMapStarted = false;
bool g_bDebug = false;
bool g_bMask[MAXPLAYERS+1];

int g_iSpawnsState;

ConVar hcv_Gamemode;

ConVar hcv_xpDisplayMode;
ConVar hcv_priorityGiveGuns;

ConVar hcv_xpDifficultyMultiplier;
ConVar hcv_xpVIPMultiplier;

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

int KillStreak[MAXPLAYERS+1];

bool g_bIronman[MAXPLAYERS+1];

int g_iLevel[MAXPLAYERS+1], g_iXP[MAXPLAYERS+1], g_iXPCurrency[MAXPLAYERS+1];
bool g_bLoadedFromDB[MAXPLAYERS+1];

int g_iRPGTarget[MAXPLAYERS+1];

int g_iMenuPosPerks[MAXPLAYERS+1], g_iMenuPosSkills[MAXPLAYERS+1], g_iMenuPosBuffs[MAXPLAYERS+1];

int g_iMidSell[MAXPLAYERS+1] = { -1, ... };


Database g_dbGunXP;

bool dbFullConnected;

Handle cpLastSecondary, cpLastPrimary, cpSaveGuns, cpAutoRPG;

bool g_bTookWeapons[MAXPLAYERS+1];

int StartOfPrimary = 14; // Change to the beginning of rifles in the levels, remember to count [0]

#define MAX_LEVEL 85

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

	// Exclude from auto RPG, as this skill has downsides.
	bool doubleEdged;

	// ArrayList of skill / perk tree identifiers required to go into this skill.
	// A perk tree requires any level unlocked to count.
	ArrayList reqIdentifiers;

	int skillIndex;

	// If a buff, how many slots does it take.
	int buffWeight;
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

	// Exclude from auto RPG, as this perk tree has downsides.
	bool doubleEdged;

	// ArrayList of skill / perk tree identifiers required to go into this perk tree.
	// A perk tree requires any level unlocked to count.
	ArrayList reqIdentifiers;

	char globalDescription[256];

	// Used for sorting sheneneagans.
	int perkIndex;
}

enum struct enNavigationRef
{
	// What kind of "thing" this is? Example: (type of) Tank, (type of) Mutant SI, Perk Tree, Skill, Buff, Setting, etc...
	char classification[16];
	// Name is compared before description. Two navRefs should not have the same name. If two navRefs trigger a match, one for name and one for description, disambiguation will not occur, and the name supercedes the description.
	char name[64];
	char description[512];

	// If you want to use a serial that is not the navigation itself, use this.
	int serial;
}

//ArrayList g_aUnlockItems;
ArrayList g_aSkills;
ArrayList g_aPerkTrees;
ArrayList g_aNavigationRefs;

#define MAX_ITEMS 128

bool g_bUnlockedProducts[MAXPLAYERS+1][MAX_ITEMS];
bool g_bUnlockedSkills[MAXPLAYERS+1][MAX_ITEMS];
int g_iUnlockedPerkTrees[MAXPLAYERS+1][MAX_ITEMS];

int g_iCommonKills[MAXPLAYERS+1];
int g_iCommonHeadshots[MAXPLAYERS+1];

//GlobalForward g_fwOnUnlockShopBuy;
GlobalForward g_fwOnTriggerNavigationRef;
GlobalForward g_fwOnGetPlayerIronman;
GlobalForward g_fwOnReloadRPGPlugins;
GlobalForward g_fwOnPlayerLoaded;
GlobalForward g_fwOnTryReloadRPGPlugins;
GlobalForward g_fwOnResetRPG;
GlobalForward g_fwOnPerkTreeBuy;
GlobalForward g_fwOnSkillBuy;
GlobalForward g_fwOnBuffBuy;
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
	60000, // needed for level 27
	70000, // needed for level 28
	80000, // needed for level 29
	90000, // needed for level 30
	100000,  // needed for level 31
	125000,  // needed for level 32
	150000,  // needed for level 33
	175000,  // needed for level 34
	200000,  // needed for level 35
	225000,  // needed for level 36
	250000,  // needed for level 37
	275000,  // needed for level 38
	300000,  // needed for level 39
	325000,  // needed for level 40
	350000,  // needed for level 41
	375000,  // needed for level 42
	400000,  // needed for level 43
	450000,  // needed for level 44
	500000,  // needed for level 45
	600000,  // needed for level 46
	700000,  // needed for level 47
	800000,  // needed for level 48
	900000,  // needed for level 49
	1000000,  // needed for level 50
	1200000,  // needed for level 51
	1400000,  // needed for level 52
	1600000,  // needed for level 53
	1800000,  // needed for level 54
	2000000,  // needed for level 55
	2200000,  // needed for level 56
	2400000,  // needed for level 57
	2600000,  // needed for level 58
	2800000,  // needed for level 59
	3000000,  // needed for level 60
	3400000,  // needed for level 61
	3800000,  // needed for level 62
	4200000,  // needed for level 63
	4600000,  // needed for level 64
	5000000, // needed for level 65
	5500000,  // needed for level 66
	6000000,  // needed for level 67
	6500000,  // needed for level 68
	7000000,  // needed for level 69
	7500000,  // needed for level 70
	8000000,  // needed for level 71
	8500000,  // needed for level 72
	9000000,  // needed for level 73
	9500000,  // needed for level 74
	10000000, // needed for level 75
	12000000,  // needed for level 76
	14000000,  // needed for level 77
	16000000,  // needed for level 78
	18000000,  // needed for level 79
	20000000,  // needed for level 80
	22500000,  // needed for level 81
	25000000,  // needed for level 82
	27500000,  // needed for level 83
	30000000,  // needed for level 84
	50000000, // needed for level 85
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
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
	"null",
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
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL",
	"NULL"
};

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsFakeClient(i))
			continue;

		ShowChoiceMenu(i);
	}
}

public void GunXP_OnTriggerNavigationRef(int client, int navSerial, int serial, char[] classification, char[] name, char[] description)
{
	if(StrEqual(classification, "Perk Tree"))
	{
		ShowPerkTreeInfo(client, serial);
	}
	else if(StrEqual(classification, "Skill"))
	{
		ShowSkillInfo(client, serial);
	}
	else if(StrEqual(classification, "Buff"))
	{
		ShowBuffInfo(client, serial);
	}
}
public void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward)
{
	if(XPReward < 0)
		return;

	AddClientXP(attacker, XPReward);
}

public void RPG_Perks_OnTimedAttributeStart(int entity, char attributeName[64], float fDuration)
{
	if(!StrEqual(attributeName, "Mutated"))
		return;

	else if(RPG_Perks_GetZombieType(entity) != ZombieType_NotInfected)
		return;

	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(entity);

	Call_Finish();

	if(IsPlayerAlive(entity))
	{
		RPG_Perks_RecalculateMaxHP(entity);

		RecalculateBotMaxHP();
	}
}

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
	if(StrEqual(attributeName, "Ignore All Sounds"))
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(entity == i)
				continue;

			else if(!RPG_Perks_IsEntityTimedAttribute(i, "Ignore All Sounds"))
				continue;

			// Break the whole function to avoid RemoveNormalSoundHook.
			return;
		}

		RemoveNormalSoundHook(SoundHook_NeverOnLevelUp);
		return;
	}
	if(!StrEqual(attributeName, "Mutated"))
		return;

	else if(RPG_Perks_GetZombieType(entity) != ZombieType_NotInfected)
		return;

	for(int i=0;i < MAX_ITEMS;i++)
	{
		if(g_bUnlockedSkills[entity][i])
		{
			// Make sure you don't put this above this line, because it'll throw an error because the initial loop does not check the array's size.
			enSkill skill;
			g_aSkills.GetArray(i, skill);

			if(skill.buffWeight > 0)
			{
				Call_StartForward(g_fwOnBuffBuy);

				Call_PushCell(entity);
				Call_PushCell(i);

				// Auto RPG?
				Call_PushCell(true);

				Call_Finish();
			}
			else
			{
				Call_StartForward(g_fwOnSkillBuy);

				Call_PushCell(entity);
				Call_PushCell(i);

				// Auto RPG?
				Call_PushCell(true);

				Call_Finish();
			}
		}
		if(g_iUnlockedPerkTrees[entity][i] != PERK_TREE_NOT_UNLOCKED)
		{
			for(int level=0;level < g_iUnlockedPerkTrees[entity][i];level++)
			{
				Call_StartForward(g_fwOnPerkTreeBuy);

				Call_PushCell(entity);
				Call_PushCell(i);
				Call_PushCell(level);

				// Auto RPG?
				Call_PushCell(true);

				Call_Finish();
			}
		}	
	}

	if(IsPlayerAlive(entity))
	{
		RPG_Perks_RecalculateMaxHP(entity);

		RecalculateBotMaxHP();
	}
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
	if(!StrEqual(attributeName, "Mutated"))
		return;

	else if(oldClient == newClient)
		return;

	// Not possible to transfer to common or witch...
	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(newClient);

	Call_Finish();

	if(IsPlayerAlive(newClient))
	{
		RPG_Perks_RecalculateMaxHP(newClient);

		RecalculateBotMaxHP();
	}
}

public void RPG_Perks_OnGetZombieMaxHP(int priority, int entity, int &maxHP)
{
	if(priority != -10)
		return;

	int state = g_iSpawnsState;

	switch(RPG_Perks_GetZombieType(entity))
	{
		case ZombieType_CommonInfected:
		{
			if(state == 0 || state == 3)
				return;

			AcceptEntityInput(entity, "Kill");
		}
		case ZombieType_Witch:
		{
			if(state == 0 || state == 5)
				return;

			AcceptEntityInput(entity, "Kill");
		}

		case ZombieType_Tank:
		{
			if(state == 0 || state == 1 || state == 4)
				return;

			if(IsFakeClient(entity))
			{
				L4D_SetClass(entity, view_as<int>(L4D2ZombieClass_Charger));
				KickClient(entity);
			}			
		}
		
		// Just in case...
		case ZombieType_Invalid:
		{

		}
		// SI, or survivors (not possible on this forward)
		default:
		{
			if(state == 0 || state == 2 || state == 4)
				return;

			if(IsFakeClient(entity))
			{
				KickClient(entity);
			}
		}
	}
}

public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
	if(priority != hcv_priorityGiveGuns.IntValue)
		return;

	ConVar convar = FindConVar("l4d2_points_reset_mapchange");

	if(convar != null)
	{
		convar.SetString("coop");
	}

	StripPlayerWeapons(client);

	if(IsFakeClient(client))
	{
		GiveGuns(client);
		return;
	}

	GivePlayerItem(client, "weapon_pistol");
	
	CalculateStats(client);	
	
	g_bTookWeapons[client] = false;
	KillStreak[client] = 0;
	
	if(IsClientSaveGuns(client))
	{
		PrintToChat(client, "\x04[Gun-XP] \x01Type\x05 !guns\x01 to disable\x05 auto gun save\x01.");
		GiveGuns(client);
	}
	else
		ShowChoiceMenu(client);
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


// product is a copyback value.
public Action PointSystemAPI_OnProductCreated(enProduct product)
{
	if (StrEqual(product.sInfo, "upgrade_add 2") || StrEqual(product.sInfo, "give shotgun_spas"))
	{
		product.iBuyFlags |= BUYFLAG_HUMANTEAM;

		return Plugin_Changed;
	}

	return Plugin_Continue;
}


public Action PointSystemAPI_OnTryBuyProduct(int buyer, const char[] sInfo, const char[] sAliases, const char[] sName, int target, float fCost, float fDelay, float fCooldown)
{
	if(L4D_IsPlayerIncapacitated(target))
	{
		if(StrEqual(sInfo, "give pistol") || StrEqual(sInfo, "give pistol_magnum"))
		{
			PSAPI_SetErrorByPriority(50, "Error:\x01 Pistols cannot be bought when incapacitated");
			return Plugin_Stop;
		}
	}
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
				PSAPI_SetErrorByPriority(50, "Gun is already unlocked, equipped for free instead.");

				char sClassname[64];
				FormatEx(sClassname, sizeof(sClassname), "weapon_%s", sClass);	

				StripWeaponFromPlayer(target, sClassname);

				int weapon = GivePlayerItem(target, sClass);

				if(!L4D_IsInFirstCheckpoint(target) && !StrEqual(sClass, "chainsaw") && HasEntProp(weapon, Prop_Data, "m_iClip1"))
				{
					SetEntProp(weapon, Prop_Data, "m_iClip1", 0);
				}
				
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{	
	CreateNative("GunXP_RPG_EmitQuestCompletedSound", Native_EmitQuestCompletedSound);

	CreateNative("GunXP_RPG_RegisterNavigationRef", Native_RegisterNavigationRef);
	CreateNative("GunXP_RPG_IsValidNavigationRef", Native_IsValidNavigationRef);
//	CreateNative("GunXP_RPG_PopulateMenuNavigationRef", Native_PopulateMenuNavigationRef);
	CreateNative("GunXP_RPG_TriggerNavigationRef", Native_TriggerNavigationRef);

	CreateNative("GunXP_RPG_IsClientLoaded", Native_IsClientLoaded);
	CreateNative("GunXP_RPG_GetXPForLevel", Native_GetXPForLevel);
	CreateNative("GunXP_RPG_GetClientLevel", Native_GetClientLevel);
	CreateNative("GunXP_RPG_GetClientRealLevel", Native_GetClientRealLevel);

	CreateNative("GunXP_RPG_IsDebugActive", Native_IsDebugActive);

	CreateNative("GunXP_RPG_AddClientXP", Native_AddClientXP);
	CreateNative("GunXP_RPG_AddClientXPTransaction", Native_AddClientXPTransaction);


	CreateNative("GunXP_RPGShop_RegisterPerkTree", Native_RegisterPerkTree);
	CreateNative("GunXP_RPGShop_IsPerkTreeUnlocked", Native_IsPerkTreeUnlocked);

	CreateNative("GunXP_RPGShop_RegisterSkill", Native_RegisterSkill);
	CreateNative("GunXP_RPGShop_IsSkillUnlocked", Native_IsSkillUnlocked);

	CreateNative("GunXP_RPGShop_RegisterBuff", Native_RegisterBuff);
	CreateNative("GunXP_RPGShop_IsBuffUnlocked", Native_IsBuffUnlocked);


	// Do not check for this library!!!
	RegPluginLibrary("Gun XP - RPG");
//	CreateNative("GunXP_UnlockShop_RegisterProduct", Native_RegisterProduct);
//	CreateNative("GunXP_UnlockShop_ReplenishProducts", Native_ReplenishProducts);
//	CreateNative("GunXP_UnlockShop_IsProductUnlocked", Native_IsProductUnlocked);

	g_bLate = bLate;

	return APLRes_Success;
}

// GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null)

public int Native_EmitQuestCompletedSound(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	EmitQuestCompletedSound(client);

	return 0;
}


// True is valid, false if not found or disambiguous
public int Native_RegisterNavigationRef(Handle caller, int numParams)
{
	enNavigationRef navRef;

	GetNativeString(1, navRef.classification, sizeof(enNavigationRef::classification));
	GetNativeString(2, navRef.name, sizeof(enNavigationRef::name));
	GetNativeString(3, navRef.description, sizeof(enNavigationRef::description));

	navRef.serial = GetNativeCell(4);

	return RegisterNavigationRef(navRef);
}

public int RegisterNavigationRef(enNavigationRef navRef)
{
	if(g_aNavigationRefs == null)
	{
		g_aNavigationRefs = new ArrayList(sizeof(enNavigationRef));
	}
	
	for(int i=0;i < g_aNavigationRefs.Length;i++)
	{
		enNavigationRef iNavRef;
		g_aNavigationRefs.GetArray(i, iNavRef);
		
		if(StrEqual(navRef.classification, iNavRef.classification) && StrEqual(navRef.name, iNavRef.name) && StrEqual(navRef.description, iNavRef.description))
		{
			g_aNavigationRefs.SetArray(i, navRef);

			return i;
		}
	}

	int slot = g_aNavigationRefs.PushArray(navRef);

	g_aNavigationRefs.SetArray(slot, navRef);
	
	return slot;
}

// True is valid, false if not found or disambiguous
public int Native_IsValidNavigationRef(Handle caller, int numParams)
{
	if(g_aNavigationRefs == null)
	{
		g_aNavigationRefs = new ArrayList(sizeof(enNavigationRef));
		SetNativeCellRef(2, NAVREF_ERROR_NOTFOUND);
		return false;
	}

	char lookup_value[64];
	GetNativeString(1, lookup_value, sizeof(lookup_value));

	ArrayList exclude, include;
	exclude = GetNativeCell(8);
	include = GetNativeCell(9);

	int error, navSerial, serial;
	char classification[16], name[64], description[512];
	if(!CalculateNavigationRef(lookup_value, error, navSerial, serial, classification, name, description, exclude, include))
	{
		SetNativeCellRef(2, error);
		return false;
	}

	SetNativeCellRef(2, error);
	SetNativeCellRef(3, navSerial);
	SetNativeCellRef(4, serial);
	SetNativeString(5, classification, sizeof(enNavigationRef::classification));
	SetNativeString(6, name, sizeof(enNavigationRef::name));
	SetNativeString(7, description, sizeof(enNavigationRef::description));

	return true;


}

// True is triggered, false if not found or disambiguous (use IsValidNavigationRef to check if not found or disambiguous using NAVREF_ERROR_*).
public int Native_TriggerNavigationRef(Handle caller, int numParams)
{
	if(g_aNavigationRefs == null)
	{
		g_aNavigationRefs = new ArrayList(sizeof(enNavigationRef));
		return false;
	}

	int client = GetNativeCell(1);

	char lookup_value[64];
	GetNativeString(2, lookup_value, sizeof(lookup_value));

	ArrayList exclude, include;
	exclude = GetNativeCell(3);
	include = GetNativeCell(4);

	int error, navSerial, serial;
	char classification[16], name[64], description[512];
	if(!CalculateNavigationRef(lookup_value, error, navSerial, serial, classification, name, description, exclude, include))
	{
		return false;
	}

	Call_StartForward(g_fwOnTriggerNavigationRef);

	Call_PushCell(client);
	Call_PushCell(navSerial);
	Call_PushCell(serial);
	Call_PushString(classification);
	Call_PushString(name);
	Call_PushString(description);

	Call_Finish();

	return true;
}

stock bool CalculateNavigationRef(const char[] lookup_value, int &error, int &navSerial, int &serial, char[] classification, char[] name, char[] description, ArrayList exclude, ArrayList include)
{
	int found = -1;

	for(int i=0;i < g_aNavigationRefs.Length;i++)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(i, navRef);

		if(exclude != null && (exclude.FindString(navRef.classification) != -1 || exclude.FindString(navRef.name) != -1 || exclude.FindString(navRef.description) != -1))
			continue;

		else if(include != null && include.FindString(navRef.classification) == -1 && include.FindString(navRef.name) == -1 && include.FindString(navRef.description) == -1)
			continue;

		if(StrEqual(navRef.name, lookup_value, false))
		{
			if(found != -1)
			{
				error = NAVREF_ERROR_DISAMBIGUOUS;
				return false;
			}
			found = i;
		}
	}

	if(found != -1)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(found, navRef);
		
		error = NAVREF_ERROR_NONE;
		navSerial = found;
		serial = navRef.serial;
		strcopy(classification, sizeof(enNavigationRef::classification), navRef.classification);
		strcopy(name, sizeof(enNavigationRef::name), navRef.name);
		strcopy(description, sizeof(enNavigationRef::description), navRef.description);

		return true;
	}


	for(int i=0;i < g_aNavigationRefs.Length;i++)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(i, navRef);

		if(exclude != null && (exclude.FindString(navRef.classification) != -1 || exclude.FindString(navRef.name) != -1 || exclude.FindString(navRef.description) != -1))
			continue;

		else if(include != null && include.FindString(navRef.classification) == -1 && include.FindString(navRef.name) == -1 && include.FindString(navRef.description) == -1)
			continue;

		if(StrEqual(navRef.description, lookup_value, false))
		{
			if(found != -1)
			{
				error = NAVREF_ERROR_DISAMBIGUOUS;
				return false;
			}
			found = i;
		}
	}

	if(found != -1)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(found, navRef);
		
		error = NAVREF_ERROR_NONE;
		navSerial = found;
		serial = navRef.serial;
		strcopy(classification, sizeof(enNavigationRef::classification), navRef.classification);
		strcopy(name, sizeof(enNavigationRef::name), navRef.name);
		strcopy(description, sizeof(enNavigationRef::description), navRef.description);

		return true;
	}

	for(int i=0;i < g_aNavigationRefs.Length;i++)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(i, navRef);

		if(exclude != null && (exclude.FindString(navRef.classification) != -1 || exclude.FindString(navRef.name) != -1 || exclude.FindString(navRef.description) != -1))
			continue;

		else if(include != null && include.FindString(navRef.classification) == -1 && include.FindString(navRef.name) == -1 && include.FindString(navRef.description) == -1)
			continue;
			
		if(StrContains(navRef.name, lookup_value, false) != -1)
		{
			if(found != -1)
			{
				error = NAVREF_ERROR_DISAMBIGUOUS;
				return false;
			}
			found = i;
		}
	}

	if(found != -1)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(found, navRef);
		
		error = NAVREF_ERROR_NONE;
		navSerial = found;
		serial = navRef.serial;
		strcopy(classification, sizeof(enNavigationRef::classification), navRef.classification);
		strcopy(name, sizeof(enNavigationRef::name), navRef.name);
		strcopy(description, sizeof(enNavigationRef::description), navRef.description);

		return true;
	}


	for(int i=0;i < g_aNavigationRefs.Length;i++)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(i, navRef);

		if(exclude != null && (exclude.FindString(navRef.classification) != -1 || exclude.FindString(navRef.name) != -1 || exclude.FindString(navRef.description) != -1))
			continue;

		else if(include != null && include.FindString(navRef.classification) == -1 && include.FindString(navRef.name) == -1 && include.FindString(navRef.description) == -1)
			continue;
			
		if(StrContains(navRef.description, lookup_value, false) != -1)
		{
			if(found != -1)
			{
				error = NAVREF_ERROR_DISAMBIGUOUS;
				return false;
			}
			found = i;
		}
	}

	if(found != -1)
	{
		enNavigationRef navRef;
		g_aNavigationRefs.GetArray(found, navRef);
		
		error = NAVREF_ERROR_NONE;
		navSerial = found;
		serial = navRef.serial;
		strcopy(classification, sizeof(enNavigationRef::classification), navRef.classification);
		strcopy(name, sizeof(enNavigationRef::name), navRef.name);
		strcopy(description, sizeof(enNavigationRef::description), navRef.description);

		return true;
	}

	error = NAVREF_ERROR_NOTFOUND;
	return false;
}

public int Native_IsClientLoaded(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	return g_bLoadedFromDB[client];
}
public int Native_GetXPForLevel(Handle caller, int numParams)
{
	int level = GetNativeCell(1);

	if(level == 0)
		return 0;

	return LEVELS[level-1];
}

public int Native_GetClientLevel(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	if(RPG_Perks_IsEntityTimedAttribute(client, "Mutated"))
		return 0;

	else if(g_bIronman[client])
		return MAX_LEVEL;

	return GetClientLevel(client);
}

public int Native_GetClientRealLevel(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	return GetClientLevel(client);
}

public int Native_IsDebugActive(Handle caller, int numParams)
{
	return g_bDebug;
}


public int Native_AddClientXP(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	bool bPremiumMultiplier = GetNativeCell(3);

	AddClientXP(client, amount, bPremiumMultiplier);

	return 0;
}

public int Native_AddClientXPTransaction(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	bool bPremiumMultiplier = GetNativeCell(3);

	Transaction transaction = GetNativeCell(4);

	AddClientXP(client, amount, bPremiumMultiplier, transaction);

	return 0;
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

	ArrayList reqIdentifiers = GetNativeCell(6);

	bool doubleEdged = GetNativeCell(7);

	char globalDescription[256];
	GetNativeString(8, globalDescription, sizeof(globalDescription));

	ReplaceString(globalDescription, sizeof(globalDescription), "{PERCENT}", "%%");
	ReplaceString(globalDescription, sizeof(globalDescription), "\n", "\n⬤ ");

	perkTree.identifier = identifier;
	perkTree.name = name;
	perkTree.descriptions = descriptions.Clone();
	perkTree.costs = costs.Clone();
	perkTree.levelReqs = levelReqs.Clone();
	perkTree.doubleEdged = doubleEdged;
	perkTree.globalDescription = globalDescription;

	for(int i=0;i < perkTree.levelReqs.Length;i++)
	{
		int levelReq = GetClosestLevelToXP(perkTree.levelReqs.Get(i));

		perkTree.levelReqs.Set(i, levelReq);
	}

	for(int i=0;i < perkTree.descriptions.Length;i++)
	{
		char description[512];
		perkTree.descriptions.GetString(i, description, sizeof(description));

		ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

		perkTree.descriptions.SetString(i, description);
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

	perkTree.perkIndex = -1;


	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree iPerkTree;
		g_aPerkTrees.GetArray(i, iPerkTree);
		
		if(StrEqual(identifier, iPerkTree.identifier))
		{
			perkTree.perkIndex = i;

			g_aPerkTrees.SetArray(i, perkTree);

			enNavigationRef navRef;

			navRef.classification = "Perk Tree";
			navRef.name = name;
			navRef.description = globalDescription;
			navRef.serial = i;

			RegisterNavigationRef(navRef);

			return i;
		}
	}

	int perkIndex = g_aPerkTrees.PushArray(perkTree);

	perkTree.perkIndex = perkIndex;

	g_aPerkTrees.SetArray(perkIndex, perkTree);

	enNavigationRef navRef;

	navRef.classification = "Perk Tree";
	navRef.name = name;
	navRef.description = globalDescription;
	navRef.serial = perkIndex;

	RegisterNavigationRef(navRef);
	
	return perkIndex;
}


public any Native_IsPerkTreeUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int perkIndex = GetNativeCell(2);

	bool bIgnoreMutation = GetNativeCell(3);

	if(!g_bLoadedFromDB[client])
		return PERK_TREE_NOT_UNLOCKED;

	else if(L4D_GetClientTeam(client) == L4DTeam_Infected)
		return PERK_TREE_NOT_UNLOCKED;

	else if(g_iMidSell[client] != -1)
	{
		if(g_iMidSell[client] == perkIndex)
			return g_iUnlockedPerkTrees[client][perkIndex];

		else
			return PERK_TREE_NOT_UNLOCKED;
	}

	else if(!bIgnoreMutation && RPG_Perks_IsEntityTimedAttribute(client, "Mutated"))
		return PERK_TREE_NOT_UNLOCKED;

	enPerkTree perkTree;

	g_aPerkTrees.GetArray(perkIndex, perkTree);

	if(g_bIronman[client])
		return perkTree.costs.Length - 1;

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

		if(count == 0)
		{
			g_iUnlockedPerkTrees[client][perkIndex] = PERK_TREE_NOT_UNLOCKED;
			return PERK_TREE_NOT_UNLOCKED;
		}

		int perkLevel = RoundToCeil((float(averageLevel) / float(count)) / 2.0) - 1;
		g_iUnlockedPerkTrees[client][perkIndex] = perkLevel;
		return perkLevel;
	}
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
	
	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

	int cost = GetNativeCell(4);

	int levelReq = GetClosestLevelToXP(GetNativeCell(5));

	ArrayList reqIdentifiers = GetNativeCell(6);

	bool doubleEdged = GetNativeCell(7);

	skill.identifier = identifier;
	skill.name = name;
	skill.description = description;
	skill.cost = cost;
	skill.levelReq = levelReq;
	skill.doubleEdged = doubleEdged;
	skill.buffWeight = 0;

	if(reqIdentifiers == null)
	{
		skill.reqIdentifiers = null;
	}
	else
	{
		skill.reqIdentifiers = reqIdentifiers.Clone();
	}

	skill.skillIndex = -1;

	delete reqIdentifiers;

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill iSkill;
		g_aSkills.GetArray(i, iSkill);
		
		if(StrEqual(identifier, iSkill.identifier))
		{
			skill.skillIndex = i;
			g_aSkills.SetArray(i, skill);


			enNavigationRef navRef;

			navRef.classification = "Skill";
			navRef.name = name;
			navRef.description = description;
			navRef.serial = i;

			RegisterNavigationRef(navRef);

			return i;
		}
	}

	int skillIndex = g_aSkills.PushArray(skill);

	skill.skillIndex = skillIndex;

	g_aSkills.SetArray(skillIndex, skill);

	enNavigationRef navRef;

	navRef.classification = "Perk Tree";
	navRef.name = name;
	navRef.description = description;
	navRef.serial = skillIndex;

	RegisterNavigationRef(navRef);

	return skillIndex;
}


public any Native_IsSkillUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int skillIndex = GetNativeCell(2);

	bool bIgnoreMutation = GetNativeCell(3);

	if(!g_bLoadedFromDB[client] && !IsFakeClient(client))
		return false;

	else if(L4D_GetClientTeam(client) == L4DTeam_Infected)
		return false;

	else if(g_iMidSell[client] != -1)
	{
		if(g_iMidSell[client] == skillIndex)
			return g_bUnlockedSkills[client][skillIndex];

		else
			return false;
	}

	else if(!bIgnoreMutation && RPG_Perks_IsEntityTimedAttribute(client, "Mutated"))
		return false;

	else if(g_bIronman[client])
		return true;

	if(!IsFakeClient(client))
		return g_bUnlockedSkills[client][skillIndex];

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
			g_bUnlockedSkills[client][skillIndex] = true;
			return true;
		}
		
		g_bUnlockedSkills[client][skillIndex] = false;
		return false;
	}
}


public int Native_RegisterBuff(Handle caller, int numParams)
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
	
	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

	int cost = GetNativeCell(4);

	int levelReq = GetClosestLevelToXP(GetNativeCell(5));

	int buffWeight = GetNativeCell(6);

	ArrayList reqIdentifiers = GetNativeCell(7);

	bool doubleEdged = GetNativeCell(8);

	skill.identifier = identifier;
	skill.name = name;
	skill.description = description;
	skill.cost = cost;
	skill.levelReq = levelReq;
	skill.doubleEdged = doubleEdged;
	skill.buffWeight = buffWeight;

	if(reqIdentifiers == null)
	{
		skill.reqIdentifiers = null;
	}
	else
	{
		skill.reqIdentifiers = reqIdentifiers.Clone();
	}

	skill.skillIndex = -1;

	delete reqIdentifiers;

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill iSkill;
		g_aSkills.GetArray(i, iSkill);
		
		if(StrEqual(identifier, iSkill.identifier))
		{
			skill.skillIndex = i;
			g_aSkills.SetArray(i, skill);

			enNavigationRef navRef;

			navRef.classification = "Buff";
			navRef.name = name;
			navRef.description = description;
			navRef.serial = i;

			RegisterNavigationRef(navRef);

			return i;
		}
	}

	int skillIndex = g_aSkills.PushArray(skill);

	skill.skillIndex = skillIndex;

	g_aSkills.SetArray(skillIndex, skill);

	enNavigationRef navRef;

	navRef.classification = "Buff";
	navRef.name = name;
	navRef.description = description;
	navRef.serial = skillIndex;

	RegisterNavigationRef(navRef);

	return skillIndex;
}


public any Native_IsBuffUnlocked(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int skillIndex = GetNativeCell(2);

	bool bIgnoreMutation = GetNativeCell(3);

	if(!g_bLoadedFromDB[client] && !IsFakeClient(client))
		return false;

	else if(L4D_GetClientTeam(client) == L4DTeam_Infected)
		return false;

	else if(g_iMidSell[client] != -1)
	{
		if(g_iMidSell[client] == skillIndex)
			return g_bUnlockedSkills[client][skillIndex];

		else
			return false;
	}

	else if(!bIgnoreMutation && RPG_Perks_IsEntityTimedAttribute(client, "Mutated"))
		return false;

	else if(g_bIronman[client])
		return true;

	if(!IsFakeClient(client))
		return g_bUnlockedSkills[client][skillIndex];

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
			g_bUnlockedSkills[client][skillIndex] = true;
			return true;
		}
		
		g_bUnlockedSkills[client][skillIndex] = false;
		return false;
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

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "RPG_Perks"))
	{
		//RPG_Perks_RegisterReplicateCvar("sv_multiplayer_sounds");
	}
}
public void OnPluginStart()
{
	//g_fwOnUnlockShopBuy = CreateGlobalForward("GunXP_UnlockShop_OnProductBuy", ET_Ignore, Param_Cell, Param_Cell);

	g_fwOnTriggerNavigationRef = CreateGlobalForward("GunXP_OnTriggerNavigationRef", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_String, Param_String);
	g_fwOnGetPlayerIronman = CreateGlobalForward("GunXP_OnGetPlayerIronman", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnReloadRPGPlugins = CreateGlobalForward("GunXP_OnReloadRPGPlugins", ET_Ignore);
	g_fwOnPlayerLoaded = CreateGlobalForward("GunXP_OnPlayerLoaded", ET_Ignore, Param_Cell);
	g_fwOnTryReloadRPGPlugins = CreateGlobalForward("GunXP_RPGShop_OnTryReloadRPGPlugins", ET_Event, Param_String);
	g_fwOnResetRPG = CreateGlobalForward("GunXP_RPGShop_OnResetRPG", ET_Ignore, Param_Cell);
	g_fwOnPerkTreeBuy = CreateGlobalForward("GunXP_RPGShop_OnPerkTreeBuy", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnSkillBuy = CreateGlobalForward("GunXP_RPGShop_OnSkillBuy", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnBuffBuy = CreateGlobalForward("GunXP_RPGShop_OnBuffBuy", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	//g_aUnlockItems = CreateArray(sizeof(enProduct));
	if(g_aSkills == null)
		g_aSkills = CreateArray(sizeof(enSkill));

	if(g_aPerkTrees == null)
		g_aPerkTrees = CreateArray(sizeof(enPerkTree));
	
	if(g_aNavigationRefs == null)
		g_aNavigationRefs = CreateArray(sizeof(enNavigationRef));

	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("GunXP-RPG");
	
	#endif
	
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_mask", Command_Mask, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rpgdebug", Command_Debug, ADMFLAG_ROOT);

	RegConsoleCmd("sm_survival", Command_Survival);
	RegConsoleCmd("sm_coop", Command_Coop);

	if(!CommandExists("sm_find"))
		RegConsoleCmd("sm_find", Command_FindRPG, "sm_find <name> - Find anything within the RPG's UI");

	else
		RegConsoleCmd("sm_findrpg", Command_FindRPG, "sm_findrpg <name> - Find anything within the RPG's UI");

	RegConsoleCmd("sm_findtalent", Command_FindTalent, "sm_findtalent <name> - Finds a Perk Tree or Skill by name");
	RegConsoleCmd("sm_br", Command_BulletRelease, "sm_br [#userid|name] - Checks aimbot level info");
	RegConsoleCmd("sm_xp", Command_XP);
	RegConsoleCmd("sm_guns", Command_Guns);
	//RegConsoleCmd("sm_ul", Command_UnlockShop);
	RegAdminCmd("sm_givexp", Command_GiveXP, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloadrpg", Command_ReloadRPG, ADMFLAG_ROOT);
	RegConsoleCmd("sm_rpg", Command_RPG, "sm_rpg [#userid|name] - Checks your / another player's RPG progress");
	RegConsoleCmd("sm_buffs", Command_Buffs, "sm_buffs [#userid|name] - Checks your / another player's RPG Buffs");
	RegConsoleCmd("sm_buff", Command_Buffs, "sm_buff [#userid|name] - Checks your / another player's RPG Buffs");
	RegConsoleCmd("sm_skills", Command_Skills, "sm_skills [#userid|name] - Checks your / another player's RPG Skills");
	RegConsoleCmd("sm_skill", Command_Skills, "sm_skill [#userid|name] - Checks your / another player's RPG Skills");
	RegConsoleCmd("sm_perk", Command_PerkTrees, "sm_perk [#userid|name] - Checks your / another player's RPG Perk Trees");
	RegConsoleCmd("sm_perks", Command_PerkTrees, "sm_perks [#userid|name] - Checks your / another player's RPG Perk Trees");

	HookEvent("foot_locker_opened", Event_Disable, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("infected_death", Event_CommonDeath, EventHookMode_Pre);

	// I want tanks and witches to have special "tiers".
	//HookEvent("tank_killed", Event_TankDeath, EventHookMode_Pre);
	//HookEvent("witch_killed", Event_WitchDeath);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("defibrillator_used", Event_DefibSuccess);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	
	hcv_Gamemode = FindConVar("mp_gamemode");

	SetConVarString(UC_CreateConVar("gun_xp_rpg_version", PLUGIN_VERSION), PLUGIN_VERSION);

	hcv_xpDisplayMode = UC_CreateConVar("gun_xp_display_mode", "1", "0 - Normal Behavior. 1 - XP \"Resets\" every level.");

	hcv_priorityGiveGuns = UC_CreateConVar("gun_xp_priority_for_guns", "-2", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 to give a player their guns.\nWhen making a plugin, feel free to track this cvar's value for reference.");
	hcv_xpDifficultyMultiplier = UC_CreateConVar("gun_xp_difficulty_multiplier", "1.0", "XP multiplier for current difficulty. To be modified with cfg/server_dynamic_difficulties.cfg");
	hcv_xpVIPMultiplier = UC_CreateConVar("gun_xp_vip_multiplier", "1.0", "How much to mulitply rewards for VIP players. 1 to disable.");

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
	
	cpLastSecondary = RegClientCookie("GunXP_LastSecondary", "Last Chosen Secondary Weapon", CookieAccess_Private);
	cpLastPrimary = RegClientCookie("GunXP_LastPrimary", "Last Chosen Primary Weapon", CookieAccess_Private);
	cpSaveGuns = RegClientCookie("GunXP_SaveGuns", "Save Guns Choice?", CookieAccess_Private);
	cpAutoRPG = RegClientCookie("GunXP_AutoRPG", "Are we playing auto RPG?", CookieAccess_Private);
	
	HookEntityOutput("commentary_zombie_spawner", "OnSpawnedZombieDeath", ZombieSpawnOutput_PreventFarming);
	
	HookEntityOutput("info_zombie_spawn", "OnSpawnNormal", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnSmoker", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnBoomer", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnHunter", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnSpitter", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnJockey", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnCharger", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnWitch", ZombieSpawnOutput_PreventFarming);
	HookEntityOutput("info_zombie_spawn", "OnSpawnTank", ZombieSpawnOutput_PreventFarming);

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

	RegPluginLibrary("GunXP-RPG");
	RegPluginLibrary("GunXPMod");

	RegPluginLibrary("GunXP_PerkTreeShop");
	RegPluginLibrary("GunXP_SkillShop");

	ConnectDatabase();
}

public void OnAllPluginsLoaded()
{	
	if(g_bLate)
	{
		Call_StartForward(g_fwOnReloadRPGPlugins);

		Call_Finish();
	}

	ConVar convar = FindConVar("l4d2_points_reset_mapchange");

	if(convar != null)
	{
		convar.SetString("coop");
	}
}


public void ConnectDatabase()
{
	char     error[256];
	Database hndl;

	if(SQL_CheckConfig("GunXP-RPG"))
	{
		SQL_TConnect(SQLCB_DatabaseConnected, "GunXP-RPG");
	}
	else
	{
		INSERT_OR_IGNORE_INTO = "OR IGNORE INTO";

		hndl = SQLite_UseDatabase("GunXP-RPG", error, sizeof(error));

		if(hndl == null)
		{
			SetFailState("Could not connect to SQLite. Error: %s", error);
		}
		else
		{
			g_dbGunXP = hndl;

			OnDatabaseConnected();
		}
	}
}


public void SQLCB_DatabaseConnected(Handle owner, Database hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState("Could not connect to database. Reason: %s", error);
	}
	else
	{
		char sIdentifier[11];
		hndl.Driver.GetIdentifier(sIdentifier, sizeof(sIdentifier));

		if(StrEqual(sIdentifier, "mysql", false))
		{
			INSERT_OR_IGNORE_INTO = "IGNORE INTO";
		}

		g_dbGunXP = hndl;

		OnDatabaseConnected();
	}
}

public void OnDatabaseConnected()
{
	g_dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_Players (AuthId VARCHAR(32) NOT NULL UNIQUE, LastName VARCHAR(64) NOT NULL, XP INT(11) NOT NULL, XPCurrency INT(11) NOT NULL, LastSecondary INT(11) NOT NULL, LastPrimary INT(11) NOT NULL)", 2, DBPrio_High);
	g_dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_PerkTrees (AuthId VARCHAR(32) NOT NULL, PerkTreeIdentifier VARCHAR(32) NOT NULL, PerkTreeLevel INT(11) NOT NULL, UNIQUE(AuthId, PerkTreeIdentifier))", 2, DBPrio_High);
	g_dbGunXP.Query(SQLCB_Error, "CREATE TABLE IF NOT EXISTS GunXP_Skills (AuthId VARCHAR(32) NOT NULL, SkillIdentifier VARCHAR(32) NOT NULL, UNIQUE(AuthId, SkillIdentifier))", 2, DBPrio_High);

	dbFullConnected = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
		
		if(IsClientAuthorized(i))
		{
			RequestFrame(FetchStats, i);
		}
	}
}


public void OnClientConnected(int client)
{
	g_bLoadedFromDB[client] = false;

	CalculateStats(client);
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnMapStart()
{
	g_bDebug = false;
	g_iSpawnsState = 0;
	g_bMapStarted = true;

	PrecacheSound(LEVEL_UP_SOUND);
	PrecacheSound(QUEST_COMPLETED_SOUND);

	CreateTimer(1.0, Timer_HudMessageXP, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	TriggerTimer(CreateTimer(5.0, Timer_AutoRPG, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE));
		
	CreateTimer(150.0, Timer_TellAboutShop, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	if(!g_bLate)
	{
		CreateTimer(5.0, Timer_ConvertSpawns, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ConvertSpawns(Handle hTimer)
{
	for(int i=0;i < sizeof(g_sForbiddenMapWeapons);i++)
	{
		int entity = -1;

		while((entity = FindEntityByClassname(entity, g_sForbiddenMapWeapons[i])) != -1)
		{
			OnShouldSpawn_ConvertSpawn(entity);
		}
	}

	return Plugin_Continue;
}

public Action Timer_AutoRPG(Handle hTimer)
{
	Transaction transaction = SQL_CreateTransaction();
	bool bFound = true;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;

		else if(!g_bLoadedFromDB[i])
			continue;

		g_iMidSell[i] = -1;

		// If XP Currency is below 0, it means that an admin stole his XP.
		if(GetClientXPCurrency(i) < 0 || GetXPWorthOfPerkTrees(i) + GetXPWorthOfSkills(i) + GetClientXPCurrency(i) != GetClientXP(i) || GetClientBuffCount(i) > GetClientMaxBuffs(i))
		{
			RefundPerkTreesAndSkills(i);

			CreateTimer(1.0, Timer_AnnounceResetRPG, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);

			continue;
		}
		if(!IsClientAutoRPG(i))
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

			PurchasePerkTreeLevel(i, iPosPerkTree, perkTree, true, transaction);

			PrintToChat(i, "\x04[Gun-XP]\x03 Successfully unlocked Perk Tree\x04 %s\x03 level\x04 %i\x03!", perkTree.name, g_iUnlockedPerkTrees[i][iPosPerkTree] + 1);

			bFound = true;
			
			// Retry this iteration of the loop.
			i--;
		}
		else
		{
			enSkill skill;
			g_aSkills.GetArray(iPosSkill, skill);

			PurchaseSkill(i, iPosSkill, skill, true, transaction);

			PrintToChat(i, "\x04[Gun-XP]\x03 Successfully unlocked the Skill\x04 %s\x03!", skill.name);

			bFound = true;

			// Retry this iteration of the loop.
			i--;
		}
	}

	if(bFound)
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);

	return Plugin_Continue;
}

public Action Timer_AnnounceResetRPG(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return Plugin_Stop;

	PrintToChat(client, "\x04[Gun-XP] \x01Your \x03Perk Trees and Skills\x01 were reset to compensate for a price change.");
	return Plugin_Stop;
}

public Action Timer_HudMessageXP(Handle hTimer)
{	
	int bestTank = 0;

	if(L4D2_IsTankInPlay())
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Infected)
				continue;

			else if(L4D2_GetPlayerZombieClass(i) != L4D2ZombieClass_Tank)
				continue;

			if(bestTank == 0 || RPG_Perks_GetClientHealth(i) < RPG_Perks_GetClientHealth(bestTank))
				bestTank = i;
		}
	}
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		bool bIronman = false;	

		for(int prio=-10;prio <= 10;prio++)
		{
			Call_StartForward(g_fwOnGetPlayerIronman);

			Call_PushCell(prio);
			Call_PushCell(i);
			Call_PushCellRef(bIronman);

			Call_Finish();
		}

		if(g_bIronman[i] != bIronman)
		{
			g_bIronman[i] = bIronman;

			if(!bIronman)
			{
				Call_StartForward(g_fwOnResetRPG);

				Call_PushCell(i);

				Call_Finish();
			}

			if(IsPlayerAlive(i))
			{
				RPG_Perks_RecalculateMaxHP(i);
			}
		}

		char weaponFormat[64];
		char adrenalineFormat[64];
		char tankFormat[64];
		char extraFormat[128];

		char statusEffects[][64] =
		{
			"Shadow Realm",
			"Stun",
			"Frozen",
			"Mutated",
			"Invincible",
			"Immolation",
			"Adrenaline",
			"Hyperactive"
		};

		for(int a=0;a < sizeof(statusEffects);a++)
		{
			if(StrEqual(statusEffects[a], "Adrenaline"))
			{
				if(IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(i) > 0.0)
				{
					FormatEx(adrenalineFormat, sizeof(adrenalineFormat), "[Adrenaline : %i sec]", RoundToFloor(Terror_GetAdrenalineTime(i)));

					a = sizeof(statusEffects) + 1;
				}
			}
			else
			{
				float fDelay;
				RPG_Perks_IsEntityTimedAttribute(i, statusEffects[a], fDelay);

				if(fDelay > 0.0)
				{
					FormatEx(adrenalineFormat, sizeof(adrenalineFormat), "[%s : %i sec]", statusEffects[a], RoundToFloor(fDelay));

					a = sizeof(statusEffects) + 1;
				}
			}
		}

		if(bestTank != 0)
		{	
			FormatEx(tankFormat, sizeof(tankFormat), "[%N : %i HP (%.0f{PERCENT})]", bestTank, RPG_Perks_GetClientHealth(bestTank), RPG_Tanks_GetDamagePercent(i, bestTank));
		}

		if(adrenalineFormat[0] != EOS && tankFormat[0] == EOS)
		{
			FormatEx(extraFormat, sizeof(extraFormat), "\n%s", adrenalineFormat);
		}
		else if(adrenalineFormat[0] == EOS && tankFormat[0] != EOS)
		{
			FormatEx(extraFormat, sizeof(extraFormat), "\n%s", tankFormat);
		}
		else if(adrenalineFormat[0] != EOS && tankFormat[0] != EOS)
		{
			FormatEx(extraFormat, sizeof(extraFormat), "\n%s | %s", adrenalineFormat, tankFormat);
		}

		if(!StrEqual(GUNS_NAMES[g_iLevel[i]], "NULL"))
		{
			FormatEx(weaponFormat,sizeof(weaponFormat), " | [Weapon : %s]", GUNS_NAMES[g_iLevel[i]]);
		}

		ReplaceString(extraFormat, sizeof(extraFormat), "{PERCENT}", "%%");

		if(LEVELS[g_iLevel[i]] != 2147483647)
		{
			char sXP[16], sNextXP[16], sXPCurrency[16];
			
			StringToKMB(GetClientDisplayXP(i), sXP, sizeof(sXP));
			StringToKMB(GetClientDisplayNextXP(i), sNextXP, sizeof(sNextXP));
			StringToKMB(GetClientXPCurrency(i), sXPCurrency, sizeof(sXPCurrency));
			PrintHintText(i, "[Level : %i] | [XP : %s/%s]\n[XP Currency : %s]%s%s", g_iLevel[i], sXP, sNextXP, sXPCurrency, weaponFormat, extraFormat);
		}
		else 
		{
			char sXP[16], sXPCurrency[16];

			StringToKMB(GetClientDisplayXP(i), sXP, sizeof(sXP));
			StringToKMB(GetClientXPCurrency(i), sXPCurrency, sizeof(sXPCurrency));

			PrintHintText(i, "[Level : %i] | [XP : %s/∞]\n[XP Currency : %s]%s%s", g_iLevel[i], sXP, sXPCurrency, weaponFormat, extraFormat);
		}
	}

	return Plugin_Continue;
}


public Action Timer_TellAboutShop(Handle hTimer)
{

	PrintToChatAll("\x04[Gun-XP] \x01Type\x03 !rpg\x01 to buy permanent perks!");
	
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
	
	if(IsClientSaveGuns(client))
	{
		SetClientSaveGuns(client, false);
		PrintToChat(client, "\x05Last guns save\x01 is now disabled.");
		
		if(g_bTookWeapons[client])
			return Plugin_Handled;
	}
	/*if(g_bTookWeapons[client])
		PrintToChat(client, "\01You have already taken weapons this round.");*/
		
	return Plugin_Handled;
}

public Action Command_ReloadRPG(int client, int args)
{


	char sError[256];

	Call_StartForward(g_fwOnTryReloadRPGPlugins);

	Call_PushStringEx(sError, sizeof(sError), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);

	Action result;
	Call_Finish(result);

	if (result >= Plugin_Handled)
	{
		PrintToChat(client, sError);
		return Plugin_Handled;
	}

	GunXP_ReloadPlugin();

	return Plugin_Handled;
}
public Action Command_GiveXP(int client, int args)
{	
	if (args < 1 || args > 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_givexp <#userid|name> [number of xp]");
		return Plugin_Handled;
	}
	char arg[MAX_NAME_LENGTH], arg2[16];
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
			COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_IMMUNITY,
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
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget), args);

	Handle hMenu = CreateMenu(RPG_MenuHandler);

	char TempFormat[512];

	AddMenuItem(hMenu, "0", "Reset choices [FREE]", client == target ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	if(IsClientAutoRPG(target))
	{
		AddMenuItem(hMenu, "1", "Auto RPG [ON]", client == target ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	else
	{
		AddMenuItem(hMenu, "1", "Auto RPG [OFF]", client == target ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	AddMenuItem(hMenu, "2", "Perk Trees");
	AddMenuItem(hMenu, "3", "Skills");

	if(FindAnyBuffs())
		AddMenuItem(hMenu, "4", "Buffs");

	AddMenuItem(hMenu, "5", "Commands");
	AddMenuItem(hMenu, "6", "Quests");

	char sXP[16], sXPCurrency[16];

	StringToKMB(GetClientXP(target), sXP, sizeof(sXP));
	StringToKMB(GetClientXPCurrency(target), sXPCurrency, sizeof(sXPCurrency));

	char buffsFormat[128];

	if(FindAnyBuffs())
	{
		FormatEx(buffsFormat, sizeof(buffsFormat), "\nBuffs are skills with a limit to how many you can buy.");
	}

	if(g_bMask[target])
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy permanent abilities here\nPerk Trees are upgradable abilities.\nSkills are singular abilities.%s\nLevel : 0 | Total XP : 0 | XP Currency : 0", sNameTarget, buffsFormat);
	}
	else
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy permanent abilities here\nPerk Trees are upgradable abilities.\nSkills are singular abilities.%s\nLevel : %i | Total XP : %s | XP Currency : %s", sNameTarget, buffsFormat, GetClientLevel(target), sXP, sXPCurrency);
	}

	if(GetXPWorthOfPerkTrees(target) + GetXPWorthOfSkills(target) + GetClientXPCurrency(target) < GetClientXP(target))
	{
		Format(TempFormat, sizeof(TempFormat), "%s\n%s can claim %i XP Currency from deleted perk trees or skills by resetting your choices.", TempFormat, sNameTarget, GetClientXP(target) - (GetXPWorthOfPerkTrees(target) + GetXPWorthOfSkills(target) + GetClientXPCurrency(target)));
	}
	else
	{
		int iPosPerkTree;
		int iCostPerkTree;
		AutoRPG_FindCheapestPerkTree(target, iPosPerkTree, iCostPerkTree, true);

		int iPosSkill;
		int iCostSkill;
		AutoRPG_FindCheapestSkill(target, iPosSkill, iCostSkill, true);

		// Only need to check both, as the unfound will have infinite cost.

		if(iCostPerkTree < iCostSkill)
		{
			if(iCostPerkTree != 2147483647)
			{
				enPerkTree perkTree;
				g_aPerkTrees.GetArray(iPosPerkTree, perkTree);

				Format(TempFormat, sizeof(TempFormat), "%s\nCheapest Perk Tree: %s [%i XP Currency]", TempFormat, perkTree.name, iCostPerkTree);
			}
		}
		else
		{
			if(iCostSkill != 2147483647)
			{
				enSkill skill;
				g_aSkills.GetArray(iPosSkill, skill);

				Format(TempFormat, sizeof(TempFormat), "%s\nCheapest Skill: %s [%i XP Currency]", TempFormat, skill.name, iCostSkill);
			}
		}
	}

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
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		// By flexible I mean doesn't change when an item is not inserted (buffs)
		int flexibleItem = StringToInt(sInfo);

		switch(flexibleItem)
		{
			case 0:
			{
				ShowConfirmResetMenu(client);
			}

			case 1:
			{
				SetClientAutoRPG(client, !IsClientAutoRPG(client));

				PrintToChat(client, "\x04[Gun-XP] \x01Auto RPG mode is now\x03 %s", IsClientAutoRPG(client) ? "Enabled" : "Disabled");
			}
			case 2:
			{
				// -1 instead of 0 is important for calculating a target.
				Command_PerkTrees(client, -1);
			}

			case 3:
			{
				// -1 instead of 0 is important for calculating a target.
				Command_Skills(client, -1);
			}

			case 4:
			{
				// -1 instead of 0 is important for calculating a target.
				Command_Buffs(client, -1);
			}

			case 5:
			{
				// -1 instead of 0 is important for calculating a target.
				Command_Commands(client, -1);
			}

			case 6:
			{
				FakeClientCommand(client, "sm_q");
			}
		}
	}	

	return 0;
}	

public void ShowConfirmResetMenu(int client)
{
	Handle hMenu = CreateMenu(ConfirmReset_MenuHandler);

	AddMenuItem(hMenu, "", "No");
	AddMenuItem(hMenu, "", "No");
	AddMenuItem(hMenu, "", "RESET ALL PERKS");
	AddMenuItem(hMenu, "", "No");
	AddMenuItem(hMenu, "", "No");
	AddMenuItem(hMenu, "", "No");

	SetMenuTitle(hMenu, "Are you sure you want to reset?");
	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int ConfirmReset_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		// -1 instead of 0 is important for calculating a target.
		Command_RPG(client, -1);
	}
	else if(action == MenuAction_Select)
	{		
		if(item == 2)
		{
			ResetPerkTreesAndSkills(client);

			PrintToChat(client, "\x04[Gun-XP] \x01You have successfully reset all your\x03 Perk Trees and Skills\x01.");
		}
		else
		{
			// -1 instead of 0 is important for calculating a target.
			Command_RPG(client, -1);
		}
	}	

	return 0;
}	
public Action Command_Commands(int client, int args)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget), args);
	
	ShowCommandsMenu(client);
	
	return Plugin_Handled;
}


stock void ShowCommandsMenu(int client, int item=0)
{
	Handle hMenu = CreateMenu(Commands_MenuHandler);

	AddMenuItem(hMenu, "sm_guns", "!guns");
	AddMenuItem(hMenu, "sm_xp", "!xp [#userid|name]");
	AddMenuItem(hMenu, "sm_rpg", "!rpg [#userid|name]");
	AddMenuItem(hMenu, "sm_skill", "!skill [#userid|name]");
	AddMenuItem(hMenu, "sm_perk", "!perk [#userid|name]");

	if(CommandExists("sm_findrpg"))
		AddMenuItem(hMenu, "sm_findrpg", "!findrpg <name>");
	
	else
		AddMenuItem(hMenu, "sm_find", "!find <name>");

	AddMenuItem(hMenu, "sm_findtalent", "!findtalent <talent>");		
	AddMenuItem(hMenu, "sm_tankhp", "!tankhp");
	AddMenuItem(hMenu, "sm_tankinfo", "!tankinfo");
	AddMenuItem(hMenu, "sm_buy", "!buy <alias> [#userid|name]");
	AddMenuItem(hMenu, "sm_br", "!br [#userid|name]");
	AddMenuItem(hMenu, "sm_q", "!q OR !quest");
	AddMenuItem(hMenu, "sm_coop", "!coop");
	AddMenuItem(hMenu, "sm_survival", "!survival");

	if(CheckCommandAccess(client, "sm_mask", ADMFLAG_GENERIC))
		AddMenuItem(hMenu, "sm_mask", "!mask");

	if(CheckCommandAccess(client, "sm_rpgdebug", ADMFLAG_ROOT))
		AddMenuItem(hMenu, "sm_rpgdebug", "!rpgdebug");		

	SetMenuExitBackButton(hMenu, true);

	DisplayMenuAtItem(hMenu, client, item, MENU_TIME_FOREVER);

	return;
}

public int Commands_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		// -1 instead of 0 is important for calculating a target.
		Command_RPG(client, -1);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[32];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		FakeClientCommand(client, sInfo);
	}	

	return 0;
}	

public Action Command_PerkTrees(int client, int args)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget), args);

	ShowPerkTreesMenu(client);

	return Plugin_Handled;
}

stock void ShowPerkTreesMenu(int client, int item=0)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(PerkTreesShop_MenuHandler);

	char TempFormat[200];

	ArrayList aPerkTrees = g_aPerkTrees.Clone();

	SortADTArrayCustom(aPerkTrees, SortADT_PerkTrees);

	for(int a=0;a < aPerkTrees.Length;a++)
	{	
		if(IsFakeClient(client))
			GunXP_RPGShop_IsPerkTreeUnlocked(client, a);

		enPerkTree perkTree;
		aPerkTrees.GetArray(a, perkTree);

		int i = perkTree.perkIndex;

		if(g_iUnlockedPerkTrees[target][i] >= perkTree.costs.Length - 1)
		{
			Format(TempFormat, sizeof(TempFormat), "%s (0 XP) - (Lv. MAX)", perkTree.name);
			char sInfo[11];
			IntToString(perkTree.perkIndex, sInfo, sizeof(sInfo));

			AddMenuItem(hMenu, sInfo, TempFormat, ITEMDRAW_DEFAULT);
		}
		else
		{
			int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[target][i] + 1);

			Format(TempFormat, sizeof(TempFormat), "%s (%i XP) - (Lv. %i)", perkTree.name, cost, g_iUnlockedPerkTrees[target][i] + 1);
			char sInfo[11];
			IntToString(perkTree.perkIndex, sInfo, sizeof(sInfo));

			AddMenuItem(hMenu, sInfo, TempFormat, ITEMDRAW_DEFAULT);
		}
	}

	delete aPerkTrees;
	
	if(g_bMask[target])
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can upgrade Perk Trees here for permanent boosts\nSelect a Perk Tree for more info:\nLevel : 0 | Total XP : 0 | XP Currency : 0%s", sNameTarget, client == target ? "\nHold SHIFT to upgrade instead of viewing" : "");
	}
	else
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can upgrade Perk Trees here for permanent boosts\nSelect a Perk Tree for more info:\nLevel : %i | Total XP : %i | XP Currency : %i%s", sNameTarget, GetClientLevel(target), GetClientXP(target), GetClientXPCurrency(target), client == target ? "\nHold SHIFT to upgrade instead of viewing" : "");
	}
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenuAtItem(hMenu, client, item, MENU_TIME_FOREVER);

	return;
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
		// -1 instead of 0 is important for calculating a target.
		Command_RPG(client, -1);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int perkIndex = StringToInt(sInfo);

		g_iMenuPosPerks[client] = GetMenuSelectionPosition();

		ShowPerkTreeInfo(client, perkIndex);
	}	

	return 0;
}	

public void ShowPerkTreeInfo(int client, int item)
{
	if(IsFakeClient(client))
		GunXP_RPGShop_IsPerkTreeUnlocked(client, item);

	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(PerkTreeInfo_MenuHandler);

	char TempFormat[1024];

	enPerkTree perkTree;
	g_aPerkTrees.GetArray(item, perkTree);

	char sInfo[11];
	IntToString(item, sInfo, sizeof(sInfo));

	AddMenuItem(hMenu, sInfo, "Upgrade Perk Tree", client != target || g_iUnlockedPerkTrees[target][item] >= perkTree.costs.Length - 1 || perkTree.levelReqs.Get(g_iUnlockedPerkTrees[target][item] + 1) > GetClientLevel(target) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	AddMenuItem(hMenu, sInfo, "Upgrade to MAX", client != target || g_iUnlockedPerkTrees[target][item] >= perkTree.costs.Length - 1 || perkTree.levelReqs.Get(g_iUnlockedPerkTrees[target][item] + 1) > GetClientLevel(target) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	AddMenuItem(hMenu, sInfo, "Refund 1 Level", client != target || g_iUnlockedPerkTrees[target][item] == PERK_TREE_NOT_UNLOCKED ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	if(perkTree.globalDescription[0] != EOS)
	{
		FormatEx(TempFormat, sizeof(TempFormat), "\nDescription: %s", perkTree.globalDescription);
	}
	if(g_iUnlockedPerkTrees[target][item] >= perkTree.costs.Length - 1)
	{
		char sCurrentUpgrade[128];
		perkTree.descriptions.GetString(g_iUnlockedPerkTrees[target][item], sCurrentUpgrade, sizeof(sCurrentUpgrade));
		
		Format(TempFormat, sizeof(TempFormat), "%s (0 XP) - (Lv. MAX)%s\nCurrent Upgrade: %s", perkTree.name, TempFormat, sCurrentUpgrade);
		SetMenuTitle(hMenu, TempFormat);
	}
	else
	{
		int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[target][item] + 1);

		char sCurrentUpgrade[128];
		char sNextUpgrade[128];

		if(g_iUnlockedPerkTrees[target][item] == -1)
		{
			FormatEx(sCurrentUpgrade, sizeof(sCurrentUpgrade), "Nothing");
		}
		else
		{
			perkTree.descriptions.GetString(g_iUnlockedPerkTrees[target][item], sCurrentUpgrade, sizeof(sCurrentUpgrade));
		}

		perkTree.descriptions.GetString(g_iUnlockedPerkTrees[target][item] + 1, sNextUpgrade, sizeof(sNextUpgrade));

		if(g_bMask[target])
		{
			perkTree.descriptions.GetString(0, sNextUpgrade, sizeof(sNextUpgrade));

			Format(TempFormat, sizeof(TempFormat), "%s can upgrade this Perk Tree's Level to become permanently stronger\nLevel: 0 | XP Currency: 0\nRequired Level: %i\n%s (%i XP) - (Lv. %i)%s\nCurrent Upgrade: %s\nNext Upgrade: %s", sNameTarget, perkTree.levelReqs.Get(0), perkTree.name, perkTree.costs.Get(0), 0, TempFormat, "Nothing", sNextUpgrade);
		}
		else
		{
			Format(TempFormat, sizeof(TempFormat), "%s can upgrade this Perk Tree's Level to become permanently stronger\nLevel: %i | XP Currency: %i\nRequired Level: %i\n%s (%i XP) - (Lv. %i)%s\nCurrent Upgrade: %s\nNext Upgrade: %s", sNameTarget, GetClientLevel(target), GetClientXPCurrency(target), perkTree.levelReqs.Get(g_iUnlockedPerkTrees[target][item] + 1), perkTree.name, cost, g_iUnlockedPerkTrees[target][item] + 1, TempFormat, sCurrentUpgrade, sNextUpgrade);
		}
		
		SetMenuTitle(hMenu, TempFormat);
	}

	SetMenuExitBackButton(hMenu, true);

	if(GetClientButtons(client) & IN_SPEED)
	{
		PerkTreeInfo_MenuHandler(hMenu, MenuAction_Select, client, 1);

		ShowPerkTreesMenu(client, GetMenuSelectionPosition());

		CloseHandle(hMenu);

	}
	else
	{
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
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
		ShowPerkTreesMenu(client, g_iMenuPosPerks[client]);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int perkIndex = StringToInt(sInfo);

		switch(item)
		{
			case 0:
			{
				TryPurchasePerkTree(client, perkIndex);
			}
			case 1:
			{
				if(item == 1)
				{
					Transaction transaction = SQL_CreateTransaction();

					bool bFound = false;
					while(TryPurchasePerkTree(client, perkIndex, transaction))
					{
						bFound = true;
					}

					if(bFound)
						g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
				}
			}
			case 2:
			{
				TrySellPerkTree(client, perkIndex);
			}
		}
		if(!(GetClientButtons(client) & IN_SPEED))
		{
			ShowPerkTreeInfo(client, perkIndex);
		}
	}

	return 0;
}

stock bool TryPurchasePerkTree(int client, int perkIndex, Transaction transaction = null)
{
	enPerkTree perkTree;

	g_aPerkTrees.GetArray(perkIndex, perkTree);

	if(g_iUnlockedPerkTrees[client][perkIndex] + 1 >= perkTree.costs.Length)
	{
		if(transaction == null)
			PrintToChat(client, "\x04[Gun-XP] \x01You already have this Perk Tree's max Level.");

		return false;
	}

	int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][perkIndex] + 1);
	int levelReq = perkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][perkIndex] + 1);


	if(levelReq > GetClientLevel(client))
	{
		if(transaction == null)
			PrintToChat(client, "\x04[Gun-XP] \x01You need to reach Level %i to unlock this Perk Tree Level!", levelReq);

		return false;
	}
	else if(cost > GetClientXPCurrency(client))
	{
		if(transaction == null)
			PrintToChat(client, "\x04[Gun-XP] \x01You need %i more XP Currency to unlock this Perk Tree level!", cost - GetClientXPCurrency(client));

		return false;
	}
	else if(IsClientAutoRPG(client))
	{
		if(transaction == null)
			PrintToChat(client, "\x04[Gun-XP] \x01You must have auto RPG disabled to purchase Perk Trees!");

		return false;
	}

	PurchasePerkTreeLevel(client, perkIndex, perkTree, false, transaction);

	PrintToChat(client, "\x04[Gun-XP]\x03 Successfully unlocked Perk Tree\x04 %s\x03 level\x04 %i\x03!", perkTree.name, g_iUnlockedPerkTrees[client][perkIndex] + 1);

	return true;
}

stock bool TrySellPerkTree(int client, int perkIndex, Transaction transaction = null)
{
	enPerkTree perkTree;

	g_aPerkTrees.GetArray(perkIndex, perkTree);

	if(g_iUnlockedPerkTrees[client][perkIndex] == PERK_TREE_NOT_UNLOCKED)
	{
		if(transaction == null)
			PrintToChat(client, "\x04[Gun-XP] \x03You don't have any levels for this Perk Tree.");

		return false;
	}


	SellPerkTreeLevel(client, perkIndex, perkTree, false, transaction);

	PrintToChat(client, "\x04[Gun-XP]\x03 Successfully downgraded Perk Tree\x04 %s\x03 to level\x04 %i\x03!", perkTree.name, g_iUnlockedPerkTrees[client][perkIndex] + 1);

	g_iMidSell[client] = perkIndex;

	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(client);

	Call_Finish();

	g_iMidSell[client] = -1;

	return true;
}

public Action Command_Skills(int client, int args)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget), args);
	
	ShowSkillsMenu(client);
	
	return Plugin_Handled;
}

stock void ShowSkillsMenu(int client, int item=0)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(SkillShop_MenuHandler);

	char TempFormat[200];

	ArrayList aSkills = g_aSkills.Clone();

	SortADTArrayCustom(aSkills, SortADT_Skills);

	for(int a=0;a < aSkills.Length;a++)
	{
		if(IsFakeClient(client))
			GunXP_RPGShop_IsSkillUnlocked(client, a);
		
		enSkill skill;
		aSkills.GetArray(a, skill);

		if(skill.buffWeight > 0)
			continue;

		int i = skill.skillIndex;

		Format(TempFormat, sizeof(TempFormat), "%s (%i XP) - (%s)", skill.name, skill.cost, g_bUnlockedSkills[target][i] && !g_bMask[target] ? "Bought" : "Not Bought");

		char sInfo[11];
		IntToString(skill.skillIndex, sInfo, sizeof(sInfo));

		AddMenuItem(hMenu, sInfo, TempFormat);
	}

	delete aSkills;


	if(g_bMask[target])
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy Skills here for permanent boosts\nSelect a Skill for more info:\nLevel : 0 | Total XP : 0 | XP Currency : 0", sNameTarget);
	}
	else
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy Skills here for permanent boosts\nSelect a Skill for more info:\nLevel : %i | Total XP : %i | XP Currency : %i", sNameTarget, GetClientLevel(target), GetClientXP(target), GetClientXPCurrency(target));
	}

	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenuAtItem(hMenu, client, item, MENU_TIME_FOREVER);
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
		// -1 instead of 0 is important for calculating a target.
		Command_RPG(client, -1);
	}
	else if(action == MenuAction_Select)
	{	
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int skillIndex = StringToInt(sInfo);

		g_iMenuPosSkills[client] = GetMenuSelectionPosition();

		ShowSkillInfo(client, skillIndex);
		
	}	

	return 0;
}	

public void ShowSkillInfo(int client, int item)
{
	if(IsFakeClient(client))
		GunXP_RPGShop_IsSkillUnlocked(client, item);

	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(SkillInfo_MenuHandler);

	char TempFormat[1024];

	enSkill skill;
	g_aSkills.GetArray(item, skill);

	char sInfo[11];
	IntToString(item, sInfo, sizeof(sInfo));

	AddMenuItem(hMenu, sInfo, "Purchase Skill", client != target || g_bUnlockedSkills[target][item] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	AddMenuItem(hMenu, sInfo, "Refund Skill", client != target || !g_bUnlockedSkills[target][item] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	if(g_bMask[target])
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy this Skill to become permanently stronger\nLevel: 0 | XP Currency: 0\nRequired Level: 0\n%s (%i XP) - (%s)\nDescription: %s", sNameTarget, skill.name, skill.cost, "Not Bought", skill.description);
	}
	else
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy this Skill to become permanently stronger\nLevel: %i | XP Currency: %i\nRequired Level: %i\n%s (%i XP) - (%s)\nDescription: %s", sNameTarget, GetClientLevel(target), GetClientXPCurrency(target), skill.levelReq, skill.name, skill.cost, g_bUnlockedSkills[target][item] ? "Bought" : "Not Bought", skill.description);
	}
	
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	if(GetClientButtons(client) & IN_SPEED)
	{
		SkillInfo_MenuHandler(hMenu, MenuAction_Select, client, 0);

		ShowSkillsMenu(client, GetMenuSelectionPosition());

		CloseHandle(hMenu);

	}
	else
	{
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
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
		ShowSkillsMenu(client, g_iMenuPosSkills[client]);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int skillIndex = StringToInt(sInfo);

		enSkill skill;

		g_aSkills.GetArray(skillIndex, skill);

		switch(item)
		{
			case 0:
			{
				if(g_bUnlockedSkills[client][skillIndex])
				{
					PrintToChat(client, "\x04[Gun-XP]\x03 You already own this Skill!");
					return 0;
				}
				else if(skill.levelReq > GetClientLevel(client))
				{
					PrintToChat(client, "\x04[Gun-XP] You need to reach Level %i to unlock this Skill!", skill.levelReq);
					return 0;
				}
				else if(skill.cost > GetClientXPCurrency(client))
				{
					PrintToChat(client, "\x04[Gun-XP] You need %i more XP Currency to unlock this skill!", skill.cost - GetClientXPCurrency(client));
					return 0;
				}
				else if(IsClientAutoRPG(client))
				{
					PrintToChat(client, "\x04[Gun-XP] You must have auto RPG disabled to purchase Skills!");
					return 0;
				}
				else
				{
					PurchaseSkill(client, skillIndex, skill, false);

					PrintToChat(client, "\x04[Gun-XP]\x03 Successfully unlocked the Skill\x04 %s\x03!", skill.name);
				}
			}

			case 1:
			{
				if(!g_bUnlockedSkills[client][skillIndex])
				{
					PrintToChat(client, "\x04[Gun-XP]\x03 You do not own this Skill!");
					return 0;
				}

				SellSkill(client, skillIndex, skill);

				PrintToChat(client, "\x04[Gun-XP]\x03 Successfully sold the Skill\x04 %s\x03!", skill.name);
			}
		}

		if(!(GetClientButtons(client) & IN_SPEED))
		{
			ShowSkillsMenu(client);
		}
	}	

	return 0;
}	


public Action Command_Buffs(int client, int args)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget), args);
	
	ShowBuffsMenu(client);
	
	return Plugin_Handled;
}

stock void ShowBuffsMenu(int client, int item=0)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(BuffShop_MenuHandler);

	char TempFormat[200];

	ArrayList aSkills = g_aSkills.Clone();

	SortADTArrayCustom(aSkills, SortADT_Skills);

	for(int a=0;a < aSkills.Length;a++)
	{
		if(IsFakeClient(client))
			GunXP_RPGShop_IsSkillUnlocked(client, a);
		
		enSkill skill;
		aSkills.GetArray(a, skill);

		if(skill.buffWeight <= 0)
			continue;
			
		int i = skill.skillIndex;

		Format(TempFormat, sizeof(TempFormat), "%s (%i XP) - (%s)", skill.name, skill.cost, g_bUnlockedSkills[target][i] && !g_bMask[target] ? "Bought" : "Not Bought");

		char sInfo[11];
		IntToString(skill.skillIndex, sInfo, sizeof(sInfo));

		AddMenuItem(hMenu, sInfo, TempFormat);
	}

	delete aSkills;


	if(g_bMask[target])
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy Buffs here for permanent boosts [Max: %i/%i]\nSelect a Skill for more info:\nLevel : 0 | Total XP : 0 | XP Currency : 0", sNameTarget, GetClientBuffCount(target), GetClientMaxBuffs(target));
	}
	else
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy Buffs here for permanent boosts [Max: %i/%i]\nSelect a Skill for more info:\nLevel : %i | Total XP : %i | XP Currency : %i | ", sNameTarget, GetClientBuffCount(target), GetClientMaxBuffs(target), GetClientLevel(target), GetClientXP(target), GetClientXPCurrency(target));
	}

	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenuAtItem(hMenu, client, item, MENU_TIME_FOREVER);
}

public int BuffShop_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		// -1 instead of 0 is important for calculating a target.
		Command_RPG(client, -1);
	}
	else if(action == MenuAction_Select)
	{	
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int skillIndex = StringToInt(sInfo);

		g_iMenuPosBuffs[client] = GetMenuSelectionPosition();

		ShowBuffInfo(client, skillIndex);
		
	}	

	return 0;
}	

public void ShowBuffInfo(int client, int item)
{
	if(IsFakeClient(client))
		GunXP_RPGShop_IsSkillUnlocked(client, item);

	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(BuffInfo_MenuHandler);

	char TempFormat[1024];

	enSkill skill;
	g_aSkills.GetArray(item, skill);

	char sInfo[11];
	IntToString(item, sInfo, sizeof(sInfo));

	AddMenuItem(hMenu, sInfo, "Purchase Buff", client != target || g_bUnlockedSkills[target][item] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	AddMenuItem(hMenu, sInfo, "Refund Buff", client != target || !g_bUnlockedSkills[target][item] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	char weightFormat[128];

	if(FindAnyWeightedBuffs())
	{
		FormatEx(weightFormat, sizeof(weightFormat), "\nWeighs like %i buffs", skill.buffWeight);
	}

	if(g_bMask[target])
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy this Buff to become permanently stronger%s\nLevel: 0 | XP Currency: 0\nRequired Level: 0\n%s (%i XP) - (%s)\nDescription: %s", sNameTarget, weightFormat, skill.name, skill.cost, "Not Bought", skill.description);
	}
	else
	{
		FormatEx(TempFormat, sizeof(TempFormat), "%s can buy this Buff to become permanently stronger%s\nLevel: %i | XP Currency: %i\nRequired Level: %i\n%s (%i XP) - (%s)\nDescription: %s", sNameTarget, weightFormat, GetClientLevel(target), GetClientXPCurrency(target), skill.levelReq, skill.name, skill.cost, g_bUnlockedSkills[target][item] ? "Bought" : "Not Bought", skill.description);
	}
	
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	if(GetClientButtons(client) & IN_SPEED)
	{
		BuffInfo_MenuHandler(hMenu, MenuAction_Select, client, 0);

		ShowBuffsMenu(client, GetMenuSelectionPosition());

		CloseHandle(hMenu);

	}
	else
	{
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}


public int BuffInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowBuffsMenu(client, g_iMenuPosBuffs[client]);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		int skillIndex = StringToInt(sInfo);

		enSkill skill;

		g_aSkills.GetArray(skillIndex, skill);

		switch(item)
		{
			case 0:
			{
				if(g_bUnlockedSkills[client][skillIndex])
				{
					PrintToChat(client, "\x04[Gun-XP]\x03 You already own this buff!");
					return 0;
				}
				else if(skill.levelReq > GetClientLevel(client))
				{
					PrintToChat(client, "\x04[Gun-XP] You need to reach Level %i to unlock this buff!", skill.levelReq);
					return 0;
				}
				else if(skill.cost > GetClientXPCurrency(client))
				{
					PrintToChat(client, "\x04[Gun-XP] You need %i more XP Currency to unlock this buff!", skill.cost - GetClientXPCurrency(client));
					return 0;
				}
				else if(g_bMask[client])
				{
					PrintToChat(client, "\x04[Gun-XP] You must have\x03 !mask\x04 disabled to purchase buffs (but Perk Trees & Skills are fine)!");
					return 0;
				}
				else if(IsClientAutoRPG(client))
				{
					PrintToChat(client, "\x04[Gun-XP] You must have auto RPG disabled to purchase buffs!");
					return 0;
				}
				else if(GetClientBuffCount(client) + skill.buffWeight > GetClientMaxBuffs(client))
				{
					if(skill.buffWeight == 1)
					{
						PrintToChat(client, "\x04[Gun-XP] You maxed the amount of buffs you can equip at once!");
					}
					else
					{
						PrintToChat(client, "\x04[Gun-XP] You maxed the amount of buffs you can equip at once!");
						PrintToChat(client, "\x04[Gun-XP] Sell buffs that weigh\x03 %i\x04 buffs to buy this buff.", skill.buffWeight + GetClientBuffCount(client) - GetClientMaxBuffs(client));
					}
				}
				else
				{
					PurchaseBuff(client, skillIndex, skill, false);

					PrintToChat(client, "\x04[Gun-XP]\x03 Successfully unlocked the buff\x04 %s\x03!", skill.name);
				}
			}

			case 1:
			{
				if(!g_bUnlockedSkills[client][skillIndex])
				{
					PrintToChat(client, "\x04[Gun-XP]\x03 You do not own this buff!");
					return 0;
				}

				SellBuff(client, skillIndex, skill);

				PrintToChat(client, "\x04[Gun-XP]\x03 Successfully sold the buff\x04 %s\x03!", skill.name);

				g_iMidSell[client] = skillIndex;

				Call_StartForward(g_fwOnResetRPG);

				Call_PushCell(client);

				Call_Finish();

				g_iMidSell[client] = -1;
			}
		}

		if(!(GetClientButtons(client) & IN_SPEED))
		{
			ShowBuffsMenu(client);
		}
	}	

	return 0;
}	


public Action ShowChoiceMenu(int client)
{	
	if(IsFakeClient(client))
	{
		GiveGuns(client);
		return Plugin_Handled;
	}

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
				SetClientSaveGuns(client, true);
				PrintToChat(client, "\x04[Gun-XP] \x01Last Guns save is now enabled. Type \x05!guns\x01 to disable it.");
			}
		}
	}	
	else if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(client))
			PrintToChat(client, "\x04[Gun-XP] \x01Type\x05 !guns\x01 to re-open this menu.");
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
		if(StrEqual(GUNS_CLASSNAMES[i], "null", false))
			continue;

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
			PrintToChat(client, "\x04[Gun-XP] \x01Type\x05 !guns\x01 to re-open this menu.");
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
		if(StrEqual(GUNS_CLASSNAMES[i], "null", false))
			continue;

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
			PrintToChat(client, "\x04[Gun-XP] \x01Type\x05 !guns\x01 to re-open this menu.");
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

	if(StrEqual(GUNS_CLASSNAMES[LastSecondary], "null", false) || StrEqual(GUNS_CLASSNAMES[LastPrimary], "null", false))
		return;

	StripWeaponFromPlayer(client, sClassname);
	GivePlayerItem(client, GUNS_CLASSNAMES[LastSecondary]);

	if(g_iLevel[client] > 3 && StrEqual(GUNS_CLASSNAMES[LastSecondary], "pistol"))
	{
		int weapon = GivePlayerItem(client, GUNS_CLASSNAMES[LastSecondary]);

		if(!L4D_IsInFirstCheckpoint(client) && !StrEqual(GUNS_CLASSNAMES[LastSecondary], "chainsaw") && HasEntProp(weapon, Prop_Data, "m_iClip1"))
		{
			SetEntProp(weapon, Prop_Data, "m_iClip1", 0);
		}
	}
	
	if(g_iLevel[client] >= StartOfPrimary)
	{
		FormatEx(sClassname, sizeof(sClassname), "weapon_%s", GUNS_CLASSNAMES[LastPrimary]);	
		StripWeaponFromPlayer(client, sClassname);
		int weapon = GivePlayerItem(client, GUNS_CLASSNAMES[LastPrimary]);

		if(!L4D_IsInFirstCheckpoint(client))
		{
			SetEntProp(weapon, Prop_Data, "m_iClip1", 0);
		}
	}
		
	g_bTookWeapons[client] = true;
}

public Action Event_Disable(Handle hEvent, char[] Name, bool dontBroadcast)
{
	SetEventBroadcast(hEvent, true);
	return Plugin_Handled;
}
public Action Event_RoundStart(Handle hEvent, char[] Name, bool dontBroadcast)
{
	/*
	if(g_iRestartsLeft > 0)
	{
		char MapName[128];
		GetCurrentMap(MapName, sizeof(MapName));

		L4D_RestartScenarioFromVote(MapName);
	}*/

	return Plugin_Continue;
}
public Action Event_WeaponFire(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return Plugin_Continue;

	char sClassname[64];
	GetEdictClassname(weapon, sClassname, sizeof(sClassname));

	ReplaceStringEx(sClassname, sizeof(sClassname), "weapon_", "");

	for(int i=0;i < sizeof(GUNS_CLASSNAMES);i++)
	{
		if(StrEqual(sClassname, GUNS_CLASSNAMES[i]))
		{
			if(i <= GetClientLevel(client) || IsFakeClient(client))
			{
				if(StrEqual(sClassname, "chainsaw"))
				{
					SetEntProp(weapon, Prop_Data, "m_iClip1", 30);
					return Plugin_Continue;
				}
				else if(!HasEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"))
					return Plugin_Continue;

				int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");

				SetEntProp(client, Prop_Data, "m_iAmmo", 999, _, ammoType);

				return Plugin_Continue;
			}

			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
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
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
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



public Action Event_PlayerDisconnect(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	for(int i=0;i < MAX_ITEMS;i++)
		g_bUnlockedProducts[client][i] = false;

	g_bMask[client] = false;

	return Plugin_Continue;
}

public void ZombieSpawnOutput_PreventFarming(const char[] output, int caller, int activator, float delay)
{
	CreateTimer(1.0, Timer_KillEdict, EntIndexToEntRef(caller), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillEdict(Handle hTimer, int ref)
{
	int entity = EntRefToEntIndex(ref);

	if(entity == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	AcceptEntityInput(entity, "Kill");
	return Plugin_Stop;
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
	if(!g_bMapStarted)
		return;

	else if(!IsValidEntityIndex(entity))
		return;


	for(int i=0;i < sizeof(g_sForbiddenMapWeapons);i++)
	{
		if(StrEqual(classname, g_sForbiddenMapWeapons[i]))
		{
			SDKHook(entity, SDKHook_Spawn, OnShouldSpawn_ConvertSpawn);
		}
	}
}

public Action OnShouldSpawn_ConvertSpawn(int entity)
{
	float fOrigin[3], fAngles[3];

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", fAngles);

	fAngles[0] = 180.0;
	fAngles[2] = 90.0;

	int iSpawn = CreateEntityByName("weapon_smg_spawn");

	if(IsValidEntity(iSpawn))
	{		
		TeleportEntity(iSpawn, fOrigin, fAngles, NULL_VECTOR);
		DispatchKeyValue(iSpawn, "count", "4"); 
		DispatchSpawn(iSpawn);					

		TeleportEntityToGround(iSpawn);
	}

	AcceptEntityInput(entity, "Kill");
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

// I tabbed the irrelevant parameters away :)
public Action SoundHook_NeverOnLevelUp(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],																									 int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	int newClients[MAXPLAYERS+1], newNumClients;

	for(int i=0;i < numClients;i++)
	{
		int client = clients[i];

		if(!RPG_Perks_IsEntityTimedAttribute(client, "Ignore All Sounds"))
			newClients[newNumClients++] = client;
	}

	if(newNumClients == numClients)
		return Plugin_Continue;

	for(int i=0;i < newNumClients;i++)
	{
		clients[i] = newClients[i];
	}

	return Plugin_Changed;
}

public Action Command_Mask(int client, int args)
{
	g_bMask[client] = !g_bMask[client];

	PrintToChat(client, "Masked XP is %s", g_bMask[client] ? "Enabled" : "Disabled");

	return Plugin_Handled;
}

public Action Command_Debug(int client, int args)
{
	Handle hMenu = CreateMenu(Debug_MenuHandler);

	char TempFormat[256];
	FormatEx(TempFormat, sizeof(TempFormat), "Debug Mode: %s", g_bDebug ? "Enabled" : "Disabled");
	AddMenuItem(hMenu, "", TempFormat);

	switch(g_iSpawnsState)
	{
		case 0: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: Normal");	
		case 1: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: Tanks Only");	
		case 2: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: SI Only");	
		case 3: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: CI Only");	
		case 4: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: SI & Tanks Only");
		case 5: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: Witch Only");
		case 6: FormatEx(TempFormat, sizeof(TempFormat), "Spawns: Nothing");
	}

	AddMenuItem(hMenu, "", TempFormat, g_bDebug ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Spawn Tanks", g_bDebug ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "Heal Survivors", g_bDebug ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "Remove Debuffs From Survivors", g_bDebug ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Debug_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
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
				g_bDebug = !g_bDebug;
				g_iSpawnsState = 0;
			}
			case 1:
			{
				g_iSpawnsState = (g_iSpawnsState + 1) % 7;

				for(int i=1;i <= MaxClients;i++)
				{
					if(!IsClientInGame(i))
						continue;

					else if(L4D_GetClientTeam(i) != L4DTeam_Infected)
						continue;

					else if(!IsFakeClient(i))
						continue;

					if(RPG_Perks_GetZombieType(i) == ZombieType_Tank)
					{
						L4D_SetClass(i, view_as<int>(L4D2ZombieClass_Charger));
					}

					KickClient(i);
				}

				int iEntity = -1;
				while ((iEntity = FindEntityByClassname(iEntity, "infected")) != -1)
				{
					AcceptEntityInput(iEntity, "Kill");
				}

				iEntity = -1;
				while ((iEntity = FindEntityByClassname(iEntity, "witch")) != -1)
				{
					AcceptEntityInput(iEntity, "Kill");
				}
			}
			case 2: SpawnTierTankMenu(client);
			case 3:
			{
				for(int i=1;i <= MaxClients;i++)
				{
					if(!IsClientInGame(i))
						continue;

					else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
						continue;

					else if(!IsPlayerAlive(i))
						continue;

					RPG_Perks_SetClientHealth(i, RPG_Perks_GetClientMaxHealth(i));
					RPG_Perks_SetClientTempHealth(i, 0);
				}
			}
			case 4:
			{
				for(int i=1;i <= MaxClients;i++)
				{
					if(!IsClientInGame(i))
						continue;

					else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
						continue;

					else if(!IsPlayerAlive(i))
						continue;

					ArrayList aAttributes = RPG_Perks_GetEntityTimedAttributes(i, ATTRIBUTE_NEGATIVE);

					for(int a=0;a < aAttributes.Length;a++)
					{
						char attributeName[64];
						aAttributes.GetString(a, attributeName, sizeof(attributeName));

						RPG_Perks_ApplyEntityTimedAttribute(i, attributeName, 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
					}

					delete aAttributes;
				}
			}
		}

		if(item != 2)
		{
			Command_Debug(client, 0);
		}
	}	

	return 0;
}	


void SpawnTierTankMenu(int client)
{

	Handle hMenu = CreateMenu(SpawnTierTank_MenuHandler);

	SetMenuTitle(hMenu, "Choose a Tier to Spawn:");

	char TempFormat[32];

	for(int tier=1;tier <= RPG_Tanks_GetMaxTier(false);tier++)
	{
		FormatEx(TempFormat, sizeof(TempFormat), "Tier %i", tier);
		AddMenuItem(hMenu, "", TempFormat);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int SpawnTierTank_MenuHandler(Handle hMenu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = null;
	}
	else if (action == MenuAction_Select)
	{
		SpawnTankMenu(param1, param2 + 1);
	}

	return 0;

}
void SpawnTankMenu(int client, int target_tier)
{
	Handle hMenu = CreateMenu(SpawnTank_MenuHandler);

	SetMenuTitle(hMenu, "Choose a Tier %i to Spawn:", target_tier);
	
	int index = 0;

	int tier;

	char name[32];

	while(RPG_Tanks_LoopTankArray(index, tier, name))
	{
		if(tier == target_tier)
		{
			char sInfo[11], TempFormat[128];
			IntToString(index, sInfo, sizeof(sInfo));

			FormatEx(TempFormat, sizeof(TempFormat), "%s", name);
			AddMenuItem(hMenu, sInfo, TempFormat);
		}

		index++;
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int SpawnTank_MenuHandler(Handle hMenu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = null;
	}
	else if (action == MenuAction_Select)
	{
		char sInfo[11], name[32];
		GetMenuItem(hMenu, param2, sInfo, sizeof(sInfo));

		int tankIndex = StringToInt(sInfo);

		int tier;
		RPG_Tanks_LoopTankArray(tankIndex, tier, name);

		RPG_Tanks_SpawnTank(tankIndex);		
	}

	return 0;
}

public Action Command_Coop(int client, int args)
{
	if(StartCustomVote(-2, "@survivors", 51, "Change mission to Coop?") != 0)
		return Plugin_Handled;

	return Plugin_Handled;
}

public Action Command_Survival(int client, int args)
{
	if(StartCustomVote(-1, "@survivors", 51, "Change mission to Survival?") != 0)
		return Plugin_Handled;

	return Plugin_Handled;
}

public void sm_vote_OnVoteFinished_Post(int client, int VotesFor, int VotesAgainst, int PercentsToPass, bool bCanVote[MAXPLAYERS], char[] VoteSubject, bool bInternal, Handle Caller)
{
	if(Caller != GetMyHandle())
		return;
	
	float ForPercents = (float(VotesFor) / (float(VotesFor) + float(VotesAgainst))) * 100.0;

	if(ForPercents < PercentsToPass)
		return;

	if(client == -1)
	{
		SetConVarString(hcv_Gamemode, "survival");
		ServerCommand("sm_map c1m2_streets");
	}
	else if(client == -2)
	{
		SetConVarString(hcv_Gamemode, "coop");
		ServerCommand("sm_map c1m1_hotel");
	}
}

public Action Command_FindTalent(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_findtalent <talent>");
		return Plugin_Handled;
	}

	char lookup_value[64];

	GetCmdArgString(lookup_value, sizeof(lookup_value));

	int error, serial;
	char classification[16];
	ArrayList include;
	include = new ArrayList(64);

	include.PushString("Perk Tree");
	include.PushString("Skill");
	include.PushString("Buff");

	if(!GunXP_RPG_IsValidNavigationRef(lookup_value, error, _, serial, classification, _, _, _, include))
	{
		if(error == NAVREF_ERROR_DISAMBIGUOUS)
		{
			ReplyToCommand(client, "Ambiguous talent name. Please be more specific.");
			return Plugin_Handled;
		}
		else if(error == NAVREF_ERROR_NOTFOUND)
		{
			ReplyToCommand(client, "Talent not found.");
			return Plugin_Handled;
		}
	}

	GunXP_RPG_TriggerNavigationRef(client, lookup_value, _, include);

	delete include;

	return Plugin_Handled;
}

public Action Command_FindRPG(int client, int args)
{
	if(args == 0)
	{
		char command[16];
		GetCmdArg(0, command, sizeof(command));
		ReplyToCommand(client, "Usage: %s <name>", command);
		return Plugin_Handled;
	}

	char lookup_value[64];

	GetCmdArgString(lookup_value, sizeof(lookup_value));

	int error, serial;
	char classification[16];

	if(!GunXP_RPG_IsValidNavigationRef(lookup_value, error, _, serial, classification))
	{
		if(error == NAVREF_ERROR_DISAMBIGUOUS)
		{
			ReplyToCommand(client, "Ambiguous lookup value. Please be more specific.");
			return Plugin_Handled;
		}
		else if(error == NAVREF_ERROR_NOTFOUND)
		{
			ReplyToCommand(client, "Value not found.");
			return Plugin_Handled;
		}
	}

	GunXP_RPG_TriggerNavigationRef(client, lookup_value);

	return Plugin_Handled;
}
public Action Command_BulletRelease(int client, int args)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget), args);

	Handle hMenu = CreateMenu(BulletRelease_MenuHandler);

	AddMenuItem(hMenu, "", "Aimbot Level 1");
	AddMenuItem(hMenu, "", "Aimbot Level 2");
	AddMenuItem(hMenu, "", "Aimbot Level 3");

	char TempFormat[256];
	FormatEx(TempFormat, sizeof(TempFormat), "Choose an Aimbot Level for details\nAimbot Levels are used to decide whether a certain skill may aimbot onto a target\nUse !br <name> to check if a given skill can aimbot onto that target");

	if(target != client && IsPlayerAlive(client) && IsPlayerAlive(target))
	{
		Format(TempFormat, sizeof(TempFormat), "%s\nChoose a Level to calculate if it would hit if %s was a Tank.", TempFormat, sNameTarget);
	}

	SetMenuTitle(hMenu, TempFormat);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int BulletRelease_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if(action == MenuAction_Select)
	{		
		ShowAimbotLevelInfo(client, item);
	}	

	return 0;
}	

public void ShowAimbotLevelInfo(int client, int item)
{
	// sPossessionNameTarget = You have / Rick Grimes has
	char sNameTarget[64], sPossessionNameTarget[72];
	int target = GetRPGTargetInfo(client, sNameTarget, sizeof(sNameTarget), sPossessionNameTarget, sizeof(sPossessionNameTarget));

	Handle hMenu = CreateMenu(AimbotLevelInfo_MenuHandler);

	char TempFormat[512];

	switch(item)
	{
		case 0: FormatEx(TempFormat, sizeof(TempFormat), "Aimbot Level 1\nCalculated by measuring if an obstacle is between the center of your and the Tank's feet.\nUsed by Shaman and Jr. Psychic Tanks\nIt is weak to both vertical and horizontal obstacles");
		case 1: FormatEx(TempFormat, sizeof(TempFormat), "Aimbot Level 2\nCalculated by measuring if an obstacle is between the center of your and the Tank's feet, legs, stomache, chest and head\nUsed by Sniper Skill and by Psychic and Ulti. Psychic Tanks\nIt is weak to horizontal obstacles");
		case 2: FormatEx(TempFormat, sizeof(TempFormat), "Aimbot Level 3 doesn't exist.\nIf it existed, it would be calculated by checking if it hits any point of your body.");
	}

	if(target != client && item != 2 && IsPlayerAlive(client) && IsPlayerAlive(target))
	{
		Format(TempFormat, sizeof(TempFormat), "%s\nIf %s was a Tank, it would%s be able to hit you with this Aimbot Level's Bullet Release", TempFormat, sNameTarget, GunXP_SetupAimbotStrike(target, client, view_as<AimbotLevels>(item)) ? "" : " NOT");
	}

	AddMenuItem(hMenu, "", "Back");

	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return;
}

public int AimbotLevelInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Command_BulletRelease(client, -1);
	}
	else if(action == MenuAction_Select)
	{		
		Command_BulletRelease(client, -1);
	}	

	return 0;
}	


public Action Command_XP(int client, int args)
{
	CalculateStats(client);
	if(args == 0)
	{
		PrintToChat(client, "\x04[Gun-XP] \x01You have\x03 %i\x01 xp. [Level:\x03 %i\x01]. [XP Currency:\x03 %i\x01].", g_iXP[client], g_iLevel[client], GetClientXPCurrency(client));
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
				COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_IMMUNITY,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
	
		int target = target_list[0];

		CalculateStats(target);

		if(g_bMask[target])
		{
			PrintToChat(client, "\x04[Gun-XP] \x03%N\x01 has\x03 0\x01 xp. [Level:\x03 0\x01]. [XP Currency:\x03 0\x01].", target);
		}
		else
		{
			PrintToChat(client, "\x04[Gun-XP] \x03%N\x01 has\x03 %i\x01 xp. [Level:\x03 %i\x01]. [XP Currency:\x03 %i\x01].", target, GetClientXP(target), GetClientLevel(target), GetClientXPCurrency(target));
		}
	}
	return Plugin_Handled;
}


public void FetchStats(int client)
{
	if(!IsClientInGame(client))
	{
		RequestFrame(FetchStats, client);
		return;
	}

	// RequestFrame is used on this function occasionally.
	if(!IsClientAuthorized(client))
		return;

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
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_Players WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_Skills WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Format(sQuery, sizeof(sQuery), "SELECT * FROM GunXP_PerkTrees WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	Handle DP = CreateDataPack();

	WritePackCell(DP, GetClientUserId(client));

	g_dbGunXP.Execute(transaction, SQLTrans_PlayerLoaded, SQLTrans_SetFailState, DP);
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

stock void AddClientXP(int client, int amount, bool bPremiumMultiplier = true, Transaction transaction = null)
{	
	float PremiumMultiplier = GetConVarFloat(hcv_xpVIPMultiplier);
	
	if(CheckCommandAccess(client, "sm_vip_cca", ADMFLAG_VIP) && PremiumMultiplier != 1.0 && bPremiumMultiplier)
	{
		float xp = float(amount);
		
		xp *= PremiumMultiplier;
		
		amount = RoundFloat(xp);
	}

	float difficultyMultiplier = GetConVarFloat(hcv_xpDifficultyMultiplier);
	
	if(difficultyMultiplier != 1.0 && bPremiumMultiplier)
	{
		float xp = float(amount);
		
		xp *= difficultyMultiplier;
		
		amount = RoundFloat(xp);
	}

	CalculateStats(client);
	
	int preCalculatedLevel = g_iLevel[client];
	
	g_iXP[client] += amount;
	g_iXPCurrency[client] += amount;

	int minLevelUp = -1;
	int maxLevelUp = -1;

	for(int i=preCalculatedLevel;i < MAX_LEVEL;i++)
	{
		if(g_iXP[client] >= LEVELS[i])
		{
			if(!IsFakeClient(client))
			{
				int level = i + 1;

				if(minLevelUp == -1)
				{
					minLevelUp = level;
				}

				maxLevelUp = level;
			}

			if(!StrEqual(GUNS_CLASSNAMES[i], "null"))
			{
				SetClientSaveGuns(client, false);
			}
		}
	}

	if(minLevelUp != -1)
	{
		if(minLevelUp == maxLevelUp)
		{
			PrintToChatAll("\x04[Gun-XP] \x03%N\x01 has\x04 leveled up\x01 to level\x05 %i\x01!", client, minLevelUp);
		}
		else
		{
			PrintToChatAll("\x04[Gun-XP] \x03%N\x01 has\x04 leveled up\x01 from level\x05 %i\x01 to level\x05 %i\x01!", client, minLevelUp - 1, maxLevelUp);
		}

		EmitLevelUpSound(client);
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];

	if(transaction == null)
	{
		g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XP = XP + %i, XPCurrency = XPCurrency + %i WHERE AuthId = '%s'", amount, amount, AuthId);
		g_dbGunXP.Query(SQLCB_Error, sQuery);	
	}
	else
	{
		g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XP = XP + %i, XPCurrency = XPCurrency + %i WHERE AuthId = '%s'", amount, amount, AuthId);
		SQL_AddQuery(transaction, sQuery);
	}

	CalculateStats(client);
}


stock void EmitLevelUpSound(int client)
{
	if(!RPG_Perks_GetSoundMode(client))
		return;
		
	for(int i=0;i < LEVEL_UP_SOUND_MULTIPLIER;i++)
	{
		EmitSoundToClient(client, LEVEL_UP_SOUND, _, SOUND_CHANNEL, 150, _, 1.0, 110);
	}

	AddNormalSoundHook(SoundHook_NeverOnLevelUp);
	RPG_Perks_ApplyEntityTimedAttribute(client, "Ignore All Sounds", 9.5, COLLISION_SET, ATTRIBUTE_NEUTRAL);
}

stock void EmitQuestCompletedSound(int client)
{
	if(!RPG_Perks_GetSoundMode(client))
		return;
		
	for(int i=0;i < QUEST_COMPLETED_SOUND_MULTIPLIER;i++)
	{
		EmitSoundToClient(client, QUEST_COMPLETED_SOUND, _, SOUND_CHANNEL, 150, _, 1.0, 110);
	}

	AddNormalSoundHook(SoundHook_NeverOnLevelUp);
	RPG_Perks_ApplyEntityTimedAttribute(client, "Ignore All Sounds", 9.5, COLLISION_SET, ATTRIBUTE_NEUTRAL);
}


stock int GetClientXP(int client)
{	
	return g_iXP[client];
}

stock int GetClientDisplayXP(int client)
{	
	if(g_iLevel[client] == 0 || !GetConVarBool(hcv_xpDisplayMode))
		return g_iXP[client];

	return g_iXP[client] - LEVELS[g_iLevel[client]-1];
}

stock int GetClientDisplayNextXP(int client)
{	
	if(g_iLevel[client] == 0 || !GetConVarBool(hcv_xpDisplayMode))
		return LEVELS[g_iLevel[client]];

	return LEVELS[g_iLevel[client]] - LEVELS[g_iLevel[client]-1];
}


stock int GetClientXPCurrency(int client)
{	
	return g_iXPCurrency[client];
}

stock int GetClientLevel(int client)
{	
	if(!IsFakeClient(client))
		return g_iLevel[client];

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

			averageLevel += g_iLevel[i];
		}

		if(count == 0)
			return 0;

		return RoundToCeil((float(averageLevel) / float(count)) / 2.0) - 1;
	}
}

stock void ResetPerkTreesAndSkills(int client)
{
	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(client);

	Call_Finish();

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
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XP WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_Skills WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_PerkTrees WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);

		RecalculateBotMaxHP();
	}
}


stock void RefundPerkTreesAndSkills(int client)
{
	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(client);

	Call_Finish();

	StringMap smPerkTrees = new StringMap();
	StringMap smSkills = new StringMap();

	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree perkTree;
		g_aPerkTrees.GetArray(i, perkTree);

		smPerkTrees.SetValue(perkTree.identifier, g_iUnlockedPerkTrees[client][i]);

		g_iUnlockedPerkTrees[client][i] = PERK_TREE_NOT_UNLOCKED;
	}
	
	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill skill;
		g_aSkills.GetArray(i, skill);

		smSkills.SetValue(skill.identifier, g_bUnlockedSkills[client][i]);

		g_bUnlockedSkills[client][i] = false;
	}

	g_iXPCurrency[client] = g_iXP[client];

	Transaction transaction = SQL_CreateTransaction();

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XP WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_Skills WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	g_dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_PerkTrees WHERE AuthId = '%s'", AuthId);
	SQL_AddQuery(transaction, sQuery);

	StringMapSnapshot smSnapPerkTrees = smPerkTrees.Snapshot();
	StringMapSnapshot smSnapSkills = smSkills.Snapshot();

	for(int i=0;i < smSnapPerkTrees.Length;i++)
	{
		char sIdentifier[64];
		smSnapPerkTrees.GetKey(i, sIdentifier, sizeof(sIdentifier));

		int level;
		smPerkTrees.GetValue(sIdentifier, level);

		if(level == PERK_TREE_NOT_UNLOCKED)
			continue;

		for(int perkIndex=0;perkIndex < g_aPerkTrees.Length;perkIndex++)
		{
			enPerkTree perkTree;
			g_aPerkTrees.GetArray(perkIndex, perkTree);
			
			if(StrEqual(sIdentifier, perkTree.identifier))
			{
				for(int dummy=0;dummy <= level;dummy++)
				{
					PurchasePerkTreeLevel(client, perkIndex, perkTree, true, transaction);
				}

				// I don't like breaking in two for loops...
				perkIndex = g_aPerkTrees.Length;
			}			
		}
	}
	
	for(int i=0;i < smSnapSkills.Length;i++)
	{
		char sIdentifier[64];
		smSnapSkills.GetKey(i, sIdentifier, sizeof(sIdentifier));

		int bUnlocked;
		smSkills.GetValue(sIdentifier, bUnlocked);

		if(!bUnlocked)
			continue;

		for(int skillIndex=0;skillIndex < g_aSkills.Length;skillIndex++)
		{
			enSkill skill;
			g_aSkills.GetArray(skillIndex, skill);
			
			if(StrEqual(sIdentifier, skill.identifier))
			{
				if(skill.buffWeight > 0)
					PurchaseBuff(client, skillIndex, skill, true, transaction);
	
				else
					PurchaseSkill(client, skillIndex, skill, true, transaction);

				// I don't like breaking in two for loops...
				skillIndex = g_aSkills.Length;
			}			
		}
	}

	g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);


	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);

		RecalculateBotMaxHP();
	}
}

stock void PurchasePerkTreeLevel(int client, int perkIndex, enPerkTree perkTree, bool bAuto, Transaction transaction = null)
{
	g_iUnlockedPerkTrees[client][perkIndex]++;

	int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][perkIndex]);

	int levelReq = perkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][perkIndex]);

	if(g_iXPCurrency[client] < cost || levelReq > GetClientLevel(client))
	{
		g_iUnlockedPerkTrees[client][perkIndex]--;
		return;
	}

	g_iXPCurrency[client] -= cost;

	bool bExecute = false;
	
	if(transaction == null)
	{
		transaction = SQL_CreateTransaction();

		bExecute = true;
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency - %i WHERE AuthId = '%s'", cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// PerkTreeLevel to -1 to immediately increment it.
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT %s GunXP_PerkTrees (AuthId, PerkTreeIdentifier, PerkTreeLevel) VALUES ('%s', '%s', -1)", INSERT_OR_IGNORE_INTO, AuthId, perkTree.identifier);
	SQL_AddQuery(transaction, sQuery);
	
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_PerkTrees SET PerkTreeLevel = PerkTreeLevel + 1 WHERE AuthId = '%s' AND PerkTreeIdentifier = '%s'", AuthId, perkTree.identifier);
	SQL_AddQuery(transaction, sQuery);

	if(bExecute)
	{
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
	}

	if(!bAuto && transaction == null)
		ShowPerkTreeInfo(client, perkIndex);

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);
	}

	Call_StartForward(g_fwOnPerkTreeBuy);

	Call_PushCell(client);
	Call_PushCell(perkIndex);
	Call_PushCell(g_iUnlockedPerkTrees[client][perkIndex]);

	// Auto RPG?
	Call_PushCell(false);

	Call_Finish();
}

stock void SellPerkTreeLevel(int client, int perkIndex, enPerkTree perkTree, bool bAuto, Transaction transaction = null)
{
	int cost = perkTree.costs.Get(g_iUnlockedPerkTrees[client][perkIndex]);
	g_iXPCurrency[client] += cost;

	g_iUnlockedPerkTrees[client][perkIndex]--;

	bool bExecute = false;
	
	if(transaction == null)
	{
		transaction = SQL_CreateTransaction();

		bExecute = true;
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency + %i WHERE AuthId = '%s'", cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// PerkTreeLevel to -1 to immediately increment it.
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT %s GunXP_PerkTrees (AuthId, PerkTreeIdentifier, PerkTreeLevel) VALUES ('%s', '%s', -1)", INSERT_OR_IGNORE_INTO, AuthId, perkTree.identifier);
	SQL_AddQuery(transaction, sQuery);
	
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_PerkTrees SET PerkTreeLevel = PerkTreeLevel - 1 WHERE AuthId = '%s' AND PerkTreeIdentifier = '%s'", AuthId, perkTree.identifier);
	SQL_AddQuery(transaction, sQuery);

	if(bExecute)
	{
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
	}

	if(!bAuto && transaction == null)
		ShowPerkTreeInfo(client, perkIndex);

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);
	}
}

stock void PurchaseSkill(int client, int skillIndex, enSkill skill, bool bAuto, Transaction transaction = null)
{
	if(g_iXPCurrency[client] < skill.cost || skill.levelReq > GetClientLevel(client))
	{
		g_bUnlockedSkills[client][skillIndex] = false;
		return;
	}

	g_bUnlockedSkills[client][skillIndex] = true;

	g_iXPCurrency[client] -= skill.cost;

	bool bExecute = false;

	if(transaction == null)
	{
		transaction = SQL_CreateTransaction();

		bExecute = true;
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency - %i WHERE AuthId = '%s'", skill.cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// INSERT INTO will guarantee an error if we give someone the same skill twice.
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT %s GunXP_Skills (AuthId, SkillIdentifier) VALUES ('%s', '%s')", INSERT_OR_IGNORE_INTO, AuthId, skill.identifier);
	SQL_AddQuery(transaction, sQuery);

	if(bExecute)
	{
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
	}

	// To make buying skills faster, the function jumps back to list of skills instead.
	//if(!bAuto)
	//	ShowSkillInfo(client, skillIndex);

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);
	}


	Call_StartForward(g_fwOnSkillBuy);

	Call_PushCell(client);
	Call_PushCell(skillIndex);

	// Auto RPG?
	Call_PushCell(bAuto);

	Call_Finish();
}


stock void SellSkill(int client, int skillIndex, enSkill skill, Transaction transaction = null)
{
	g_bUnlockedSkills[client][skillIndex] = false;

	g_iXPCurrency[client] += skill.cost;

	bool bExecute = false;

	if(transaction == null)
	{
		transaction = SQL_CreateTransaction();

		bExecute = true;
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency + %i WHERE AuthId = '%s'", skill.cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// INSERT INTO will guarantee an error if we give someone the same skill twice.
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_Skills WHERE AuthId = '%s' AND SkillIdentifier = '%s'", AuthId, skill.identifier);
	SQL_AddQuery(transaction, sQuery);

	if(bExecute)
	{
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
	}

	// To make buying skills faster, the function jumps back to list of skills instead.
	//if(!bAuto)
	//	ShowSkillInfo(client, skillIndex);

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);
	}

	g_iMidSell[client] = skillIndex;

	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(client);

	Call_Finish();

	g_iMidSell[client] = -1;
}


stock void PurchaseBuff(int client, int skillIndex, enSkill skill, bool bAuto, Transaction transaction = null)
{
	if(g_iXPCurrency[client] < skill.cost || skill.levelReq > GetClientLevel(client) || GetClientBuffCount(client) + skill.buffWeight > GetClientMaxBuffs(client))
	{
		g_bUnlockedSkills[client][skillIndex] = false;
		return;
	}

	g_bUnlockedSkills[client][skillIndex] = true;

	g_iXPCurrency[client] -= skill.cost;

	bool bExecute = false;

	if(transaction == null)
	{
		transaction = SQL_CreateTransaction();

		bExecute = true;
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency - %i WHERE AuthId = '%s'", skill.cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// INSERT INTO will guarantee an error if we give someone the same skill twice.
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT %s GunXP_Skills (AuthId, SkillIdentifier) VALUES ('%s', '%s')", INSERT_OR_IGNORE_INTO, AuthId, skill.identifier);
	SQL_AddQuery(transaction, sQuery);

	if(bExecute)
	{
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
	}

	// To make buying skills faster, the function jumps back to list of skills instead.
	//if(!bAuto)
	//	ShowSkillInfo(client, skillIndex);

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);
	}

	Call_StartForward(g_fwOnBuffBuy);

	Call_PushCell(client);
	Call_PushCell(skillIndex);

	// Auto RPG?
	Call_PushCell(bAuto);

	Call_Finish();
}


stock void SellBuff(int client, int skillIndex, enSkill skill, Transaction transaction = null)
{
	g_bUnlockedSkills[client][skillIndex] = false;

	g_iXPCurrency[client] += skill.cost;

	bool bExecute = false;

	if(transaction == null)
	{
		transaction = SQL_CreateTransaction();

		bExecute = true;
	}

	char AuthId[35];
	GetClientAuthId(client, AuthId_Steam2, AuthId, sizeof(AuthId));

	char sQuery[256];
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "UPDATE GunXP_Players SET XPCurrency = XPCurrency + %i WHERE AuthId = '%s'", skill.cost, AuthId);
	SQL_AddQuery(transaction, sQuery);

	// INSERT INTO will guarantee an error if we give someone the same skill twice.
	g_dbGunXP.Format(sQuery, sizeof(sQuery), "DELETE FROM GunXP_Skills WHERE AuthId = '%s' AND SkillIdentifier = '%s'", AuthId, skill.identifier);
	SQL_AddQuery(transaction, sQuery);

	if(bExecute)
	{
		g_dbGunXP.Execute(transaction, INVALID_FUNCTION, SQLTrans_SetFailState);
	}

	if(IsPlayerAlive(client))
	{
		RPG_Perks_RecalculateMaxHP(client);
	}

	g_iMidSell[client] = skillIndex;

	Call_StartForward(g_fwOnResetRPG);

	Call_PushCell(client);

	Call_Finish();

	g_iMidSell[client] = -1;
}

stock bool FindAnyBuffs()
{
	for(int a=0;a < g_aSkills.Length;a++)
	{
		enSkill skill;
		g_aSkills.GetArray(a, skill);

		if(skill.buffWeight <= 0)
			continue;

		return true;
	}

	return false;
}

stock bool FindAnyWeightedBuffs()
{
	for(int a=0;a < g_aSkills.Length;a++)
	{
		enSkill skill;
		g_aSkills.GetArray(a, skill);

		if(skill.buffWeight <= 1)
			continue;

		return true;
	}

	return false;
}

stock int GetClientBuffCount(int client)
{
	if(IsFakeClient(client))
		return 0;

	int buffCount = 0;

	for(int a=0;a < g_aSkills.Length;a++)
	{
		enSkill skill;
		g_aSkills.GetArray(a, skill);

		int i = skill.skillIndex;

		if(skill.buffWeight <= 0)
			continue;
			
		if(g_bUnlockedSkills[client][i] && !g_bMask[client])
			buffCount += skill.buffWeight;
	}

	return buffCount;
}

stock int GetClientMaxBuffs(int client)
{
	if(IsFakeClient(client))
		return 0;

	return RoundToFloor(float(GetClientLevel(client)) / 10.0);
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
		g_dbGunXP.Format(sQuery, sizeof(sQuery), "INSERT %s GunXP_Players (AuthId, LastName, XP, XPCurrency, LastSecondary, LastPrimary) VALUES ('%s', '%s', 0, 0, 0, 0)", INSERT_OR_IGNORE_INTO, AuthId, Name);

		// We just loaded the client, and this is the first query made after authentication. We need to skip any queued queries to increase XP.
		g_dbGunXP.Query(SQLCB_Error, sQuery, _, DBPrio_High);	

		if(IsClientInGame(client) && IsPlayerAlive(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor)
		{
			RPG_Perks_RecalculateMaxHP(client);

			RecalculateBotMaxHP();
		}

		Call_StartForward(g_fwOnPlayerLoaded);

		Call_PushCell(client);

		Call_Finish();
	
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

	// CalculateStats must be before RecalculateMaxHP to account for perks that depend on your level.
	CalculateStats(client);

	if(IsClientInGame(client) && IsPlayerAlive(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor)
	{
		RPG_Perks_RecalculateMaxHP(client);

		RecalculateBotMaxHP();
	}


	Call_StartForward(g_fwOnPlayerLoaded);

	Call_PushCell(client);

	Call_Finish();
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

public int SortADT_PerkTrees(int index1, int index2, Handle array, Handle hndl)
{
	enPerkTree perkTree1;
	enPerkTree perkTree2;

	GetArrayArray(array, index1, perkTree1);
	GetArrayArray(array, index2, perkTree2);
	
	return SortADT_SkillOrPerkTree(perkTree1.name, perkTree2.name, hndl);
}

public int SortADT_Skills(int index1, int index2, Handle array, Handle hndl)
{
	enSkill skill1;
	enSkill skill2;

	GetArrayArray(array, index1, skill1);
	GetArrayArray(array, index2, skill2);

	return SortADT_SkillOrPerkTree(skill1.name, skill2.name, hndl);
	
	
}

public int SortADT_SkillOrPerkTree(char[] name1, char[] name2, Handle hndl)
{
	return strcmp(name1, name2);
}
stock void StripPlayerWeapons(int client)
{
	for(int i=0;i < 2;i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);
		
		if(weapon != -1)
		{		
			char sClassname[64];
			GetEdictClassname(weapon, sClassname, sizeof(sClassname));

			
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

stock bool IsClientSaveGuns(int client)
{
	char strSaveGuns[3];
	
	GetClientCookie(client, cpSaveGuns, strSaveGuns, sizeof(strSaveGuns));
	
	if(strSaveGuns[0] == EOS)
	{
		return true;
	}
	bool bSaveGuns = view_as<bool>(StringToInt(strSaveGuns));
	
	return bSaveGuns;
}

stock void SetClientSaveGuns(int client, bool bSaveGuns)
{
	char strSaveGuns[3];
	
	IntToString(view_as<int>(bSaveGuns), strSaveGuns, sizeof(strSaveGuns));
	
	SetClientCookie(client, cpSaveGuns, strSaveGuns);
	
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
	char strAutoRPG[3];
	
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


stock void TeleportEntityToGround(int entity)
{
	float vecMins[3], vecMaxs[3], vecOrigin[3], vecFakeOrigin[3];
	
	GetEntPropVector(entity, Prop_Data, "m_vecMins", vecMins);
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", vecMins);
	
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);

	vecOrigin[2] += 32.0;

	vecFakeOrigin = vecOrigin;
	
	vecFakeOrigin[2] = MIN_FLOAT;
	
	TR_TraceHullFilter(vecOrigin, vecFakeOrigin, vecMins, vecMaxs, MASK_SHOT, TraceRayDontHitPlayers);
	
	float fEndOrigin[3];

	TR_GetEndPosition(fEndOrigin);

	fEndOrigin[2] += 2.0;
	
	//TeleportEntity(entity, fEndOrigin, NULL_VECTOR, NULL_VECTOR);
}

public bool TraceRayDontHitPlayers(int entityhit, int mask) 
{
	return (entityhit>MaxClients || entityhit == 0);
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

stock bool AutoRPG_FindCheapestPerkTree(int client, int &position, int &cost, bool ignoreAffordability = false)
{
	CalculateStats(client);

	position = -1;

	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree iPerkTree;
		g_aPerkTrees.GetArray(i, iPerkTree);

		// Perk tree has downsides, don't wanna make it happen just yet.
		if(iPerkTree.doubleEdged)
			continue;

		// This also safely enables checking for next level without leaving array bounds.
		else if(g_iUnlockedPerkTrees[client][i] >= iPerkTree.costs.Length - 1)
			continue;

		else if(GetClientLevel(client) < iPerkTree.levelReqs.Get(g_iUnlockedPerkTrees[client][i] + 1))
			continue;

		else if(GetClientXPCurrency(client) < iPerkTree.costs.Get(g_iUnlockedPerkTrees[client][i] + 1) && !ignoreAffordability)
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

stock bool AutoRPG_FindCheapestSkill(int client, int &position, int &cost, bool ignoreAffordability = false)
{
	CalculateStats(client);

	position = -1;

	int buffCount = GetClientBuffCount(client);
	int maxBuffs = GetClientMaxBuffs(client);

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill iSkill;
		g_aSkills.GetArray(i, iSkill);

		// Perk tree has downsides, don't wanna make it happen just yet.
		if(iSkill.doubleEdged)
			continue;

		else if(g_bUnlockedSkills[client][i])
			continue;

		else if(GetClientLevel(client) < iSkill.levelReq)
			continue;

		else if(GetClientXPCurrency(client) < iSkill.cost && !ignoreAffordability)
			continue;

		else if(iSkill.buffWeight > 0 && buffCount + iSkill.buffWeight > maxBuffs)
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

stock int GetXPWorthOfPerkTrees(int client)
{
	int totalXPWorth = 0;

	for(int i=0;i < g_aPerkTrees.Length;i++)
	{
		enPerkTree iPerkTree;
		g_aPerkTrees.GetArray(i, iPerkTree);

		for(int a=0;a <= g_iUnlockedPerkTrees[client][i];a++)
		{
			if(a >= iPerkTree.costs.Length)
			{
				return 500000000;
			}

			if(iPerkTree.levelReqs.Get(a) > GetClientLevel(client))
			{
				return 500000000;
			}

			totalXPWorth += iPerkTree.costs.Get(a);
		}
	}

	return totalXPWorth;
}

stock int GetXPWorthOfSkills(int client)
{
	int totalXPWorth = 0;

	for(int i=0;i < g_aSkills.Length;i++)
	{
		enSkill iSkill;
		g_aSkills.GetArray(i, iSkill);


		if(!g_bUnlockedSkills[client][i])
			continue;

		if(iSkill.levelReq > GetClientLevel(client))
		{
			return 500000000;
		}

		totalXPWorth += iSkill.cost;
	}

	return totalXPWorth;
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

stock void StringToKMB(int number, char[] buffer, int length)
{
	if(number < 1000)
	{
		FormatEx(buffer, length, "%i", number);
		return;
	}

	switch(RoundToFloor(Logarithm(float(number))))
	{
		case 3, 4, 5:
			FormatEx(buffer, length, "%i.%s%iK", RoundToFloor(float(number) / 1000.0), TrueFloatFraction(float(number) / 1000.0) <= 99 ? "0" : "", TrueFloatFraction(float(number) / 1000.0));
		case 6, 7, 8:
			FormatEx(buffer, length, "%i.%s%iM", RoundToFloor(float(number) / 1000000.0), TrueFloatFraction(float(number) / 1000000.0) <= 99 ? "0" : "", TrueFloatFraction(float(number) / 1000000.0));
		case 9, 10, 11:
			FormatEx(buffer, length, "%i.%s%iB", RoundToFloor(float(number) / 1000000000.0), TrueFloatFraction(float(number) / 1000000000.0) <= 99 ? "0" : "", TrueFloatFraction(float(number) / 1000000000.0));
	}

	int lastChar = buffer[strlen(buffer)-1];

	int len = strlen(buffer);
	
	if(number % 1000 == 0)
	{
		buffer[len - 3] = EOS;
		Format(buffer, length, "%s%c", buffer, lastChar);
	}
	else if(number % 100 == 0)
	{
		buffer[len - 2] = EOS;
		Format(buffer, length, "%s%c", buffer, lastChar);
	}
	else if(number % 10 == 0)
	{
		buffer[len - 1] = EOS;
		Format(buffer, length, "%s%c", buffer, lastChar);
	}


	ReplaceStringEx(buffer, length, ".K", "K");
	ReplaceStringEx(buffer, length, ".M", "M");
	ReplaceStringEx(buffer, length, ".B", "B");
}

stock int TrueFloatFraction(float value, int precision = 3)
{
	float fraction = FloatFraction(value);

	char sFraction[32];
	FloatToString(fraction, sFraction, sizeof(sFraction));

	if(sFraction[0] == '0')
	{
		ReplaceStringEx(sFraction, sizeof(sFraction), "0.", "");
	}

	sFraction[precision] = EOS;

	return StringToInt(sFraction);
}

stock int GetRPGTargetInfo(int client, char[] sNameTarget, int len1, char[] sPossessionNameTarget, int len2, int args = -1)
{
	if(args == -1)
	{
		int target = GetClientOfUserId(g_iRPGTarget[client]);

		if(target == 0 || target == client)
		{
			FormatEx(sNameTarget, len1, "You");
			FormatEx(sPossessionNameTarget, len2, "You have");

			return client;
		}
		else
		{
			GetClientName(target, sNameTarget, len1);
			FormatEx(sPossessionNameTarget, len2, "%s has", sNameTarget);

			return target;
		}
	}
	else if(args == 0)
	{
		g_iRPGTarget[client] = GetClientUserId(client);
		FormatEx(sNameTarget, len1, "You");
		FormatEx(sPossessionNameTarget, len2, "You have");

		return client;
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
				COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_IMMUNITY,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			g_iRPGTarget[client] = GetClientUserId(client);
			FormatEx(sNameTarget, len1, "You");
			FormatEx(sPossessionNameTarget, len2, "You have");

			return client;
		}

		int target = target_list[0];

		g_iRPGTarget[client] = GetClientUserId(target);

		GetClientName(target, sNameTarget, len1);
		FormatEx(sPossessionNameTarget, len2, "%s has", sNameTarget);

		return target;
	}
}

stock void RecalculateBotMaxHP()
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsFakeClient(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		RPG_Perks_RecalculateMaxHP(i);
	}
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}