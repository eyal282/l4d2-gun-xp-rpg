#if defined _GunXP_RPG_included
 #endinput
#endif

#include <autoexecconfig>
#include <left4dhooks>

#define _GunXP_RPG_included

#define FPERM_ULTIMATE (FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_WRITE | FPERM_G_EXEC | FPERM_O_READ | FPERM_O_WRITE | FPERM_O_EXEC)

#define SPEEDSTATE_NULL -1	// This is to return an invalid speeds and stop attempting to change player movement speed

#define TANK_TIER_UNKNOWN -2
#define TANK_TIER_UNTIERED -1

enum
{
	SPEEDSTATE_RUN,              // Min 110.0
	SPEEDSTATE_WALK,             // Min 65.0
	SPEEDSTATE_CROUCH,           // Min 65.0
	SPEEDSTATE_LIMP,             // Min 65.0
	SPEEDSTATE_CRITICAL,         // Min 65.0
	SPEEDSTATE_WATER,            // Min 65.0
	SPEEDSTATE_ADRENALINE,       // Min 110.0
	SPEEDSTATE_SCOPE,             // Min 65.0
	SPEEDSTATE_CUSTOM,
	SIZEOF_SPEEDSTATES
};

char Colors[][] = 
{
	"{NORMAL}", "{RED}", "{GREEN}", "{LIGHTGREEN}", "{OLIVE}", "{LIGHTRED}", "{GRAY}", "{YELLOW}", "{ORANGE}", "{BLUE}", "{PINK}"
};

char ColorEquivalents[][] =
{
	"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0C", "\x0E"
};


native void GunXP_RPG_AddClientXP(int client, int amount, bool bPremiumMultiplier=true);
native int GunXP_RPG_GetClientLevel(int client);

// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// doubleEdged simply excludes a perk tree from auto RPG because it has apparent downsides.
native int GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null, bool bDoubleEdged = false);
native int GunXP_RPGShop_IsPerkTreeUnlocked(int client, int perkIndex);

// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// doubleEdged simply excludes a skill from auto RPG because it has apparent downsides.
native int GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null, bool bDoubleEdged = false);
native bool GunXP_RPGShop_IsSkillUnlocked(int client, int skillIndex);

// If something that requires recalculating what's the max HP of a client, use this.
native void RPG_Perks_RecalculateMaxHP(int client);

// Sets a client's health allowing over 65535 HP. Only set for tanks please.
native void RPG_Perks_SetClientHealth(int client, int amount);

// Gets a client's health getting if they have over 65535 HP. Feel free to check for non-tanks.
native int RPG_Perks_GetClientHealth(int client);

native int RPG_Tanks_RegisterTank(int tier, int entries, char name[32], char description[512], int maxHP, int speed, int XPRewardMin, int XPRewardMax, bool fireDamageImmune, bool meleeDamageImmune);

// Gets a client's tank index. Do not use this before RPG_Perks_OnZombiePlayerSpawned, and do not use this on non-tank clients.
// Use RPG_Perks_GetZombieType(client) to compare with ZombieType_Tank to ensure its a tank before using this.
// Returns tank index, TANK_TIER_UNTIERED for untiered and TANK_TIER_UNKNOWN on priority -10 of GetZombieMaxHP.
native int RPG_Tanks_GetClientTank(int client);

native bool RPG_Tanks_IsTankInPlay(int tankIndex);

public SharedPlugin __pl_gun_xp_rpg = 
{
	name = "Gun XP - RPG",
	file = "GunXP-RPG.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
 
#if !defined REQUIRE_PLUGIN
public void __pl_gun_xp_rpg_SetNTVOptional()
{
	MarkNativeAsOptional("GunXP_RPG_AddClientXP");
	MarkNativeAsOptional("GunXP_RPG_GetClientLevel");
	MarkNativeAsOptional("GunXP_RPGShop_RegisterPerkTree");
	MarkNativeAsOptional("GunXP_RPGShop_IsPerkTreeUnlocked");
	MarkNativeAsOptional("GunXP_RPGShop_RegisterSkill");
	MarkNativeAsOptional("GunXP_RPGShop_IsSkillUnlocked");
}
#endif

// RPG_Tanks_GetClientTank(victim) will work properly in this forward. After this forward is called it will return TANK_TIER_UNKNOWN.
forward void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPRewardMin, int XPRewardMax);

// return Plugin_Handled and edit sError to prevent reloading.
forward Action GunXP_RPGShop_OnTryReloadRPGPlugins(char sError[256]);

// At this point, every perk tree and skill were removed.
forward void GunXP_OnReloadRPGPlugins();
forward void GunXP_RPGShop_OnPerkTreeBuy(int client, int perkIndex, int perkLevel, bool bAutoRPG);
forward void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG);

// This is called while the player still has their current perk tree and skills.
forward void GunXP_RPGShop_OnResetRPG(int client);


// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.

forward void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass);


// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.

// Use RPG_Perks_GetZombieType(entity) to get a ZombieType_* of what kind of a zombie it is.
forward void RPG_Perks_OnGetZombieMaxHP(int priority, int entity, int &maxHP);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.
forward void RPG_Perks_OnGetMaxHP(int priority, int client, int &maxHP);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.
// Gun XP - RPG gives guns on priority -2 by default, with a cvar named "gun_xp_priority_for_guns" to alter it.
// RPG-Perks gives hidden incap pistol on priority 0 by default, with a cvar named "rpg_incap_pistol_priority" to alter it.
forward void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
forward void RPG_Perks_OnZombiePlayerSpawned(int priority, int client);

// WARNING! THIS FORWARD FIRES 20 TIMES PER ATTACK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how damage is interacted and just want to multiply the damage, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the damage to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.
// bDontInterruptActions protects a Survivor from having a timer reset for picking incapacitated players and pouring gas cans.
// bDontStagger protects a Special Infected or a Tank from explosive ammo stagger, RPG stagger, incendiary ammo burn, all instant kills, and can also seriously mess with damage output.
// bDontInstakill can seriously mess with damage output, and breaks explosive ammo stagger. Use with care.
// bImmune is like setting damage to 0.0, but enables plugins to block your damage immunity. Example: Tier 1 tank is immune to fire damage. Flaming katana deals fire damage and ignores all fire immunity.

// If you want to distinguish what actions to protect, make an incap check or check if victim has a gascan like item held.
// If you want to protect from stagger but allow incendiary ammo, check for damagetype == DMG_BLAST
forward void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune);

// WARNING! THIS FORWARD FIRES 20 TIMES PER CALCULATION, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how speed is interacted and just want to multiply the speed, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the speed to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.
// overrideSpeedState ignores what the speed of the player should be and instead overrides it to something else.
// fCustomSpeed will only work if overrideSpeedState is set to custom.
forward void RPG_Perks_OnGetRPGSpeedModifiers(int priority, int client, int &overrideSpeedState, int &iLimpHealth, float &fRunSpeed, float &fWalkSpeed, float &fCrouchSpeed, float &fLimpSpeed, float &fCriticalSpeed, float &fWaterSpeed, float &fAdrenalineSpeed, float &fScopeSpeed, float &fCustomSpeed);

forward void RPG_Perks_OnGetKitHealPercent(int reviver, int victim, int &percent);
forward void RPG_Perks_OnGetReviveHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent);

forward void RPG_Perks_OnGetKitDuration(int reviver, int victim, float &fDuration);
forward void RPG_Perks_OnGetReviveDuration(int reviver, int victim, bool bLedge, float &fDuration);

forward void RPG_Perks_OnGetIncapHealth(int client, bool bLedge, int &health);

// index means the following:
// 0 - No weapon. 1 - Pistol. 2 - Double Pistol. 3 - Magnum
forward void RPG_Perks_OnGetIncapWeapon(int reviver, int &index)
//forward void RPG_Perks_OnGetLimpSpeed(int)

enum ZombieType
{
	ZombieType_Smoker			= 1,
	ZombieType_Boomer			= 2,
	ZombieType_Hunter			= 3,
	ZombieType_Spitter			= 4,
	ZombieType_Jockey			= 5,
	ZombieType_Charger			= 6,
	ZombieType_Witch			= 7,
	ZombieType_Tank			= 8,
	ZombieType_NotInfected		= 9,
	ZombieType_CommonInfected		= 10,
	ZombieType_Invalid				= 11
};

// If the entity is dead, returns invalid.
stock ZombieType RPG_Perks_GetZombieType(int entity)
{
	if(IsPlayer(entity))
	{
		if(!IsPlayerAlive(entity))
			return ZombieType_Invalid;

		switch(L4D_GetClientTeam(entity))
		{
			case L4DTeam_Survivor: return ZombieType_NotInfected;
			case L4DTeam_Infected: return view_as<ZombieType>(L4D2_GetPlayerZombieClass(entity));
			default: return ZombieType_Invalid;
		}
	}
	else
	{
		char sClassname[64];
		GetEdictClassname(entity, sClassname, sizeof(sClassname));

		if(GetEntProp(entity, Prop_Data, "m_lifeState") != 0)
		{
			return ZombieType_Invalid;
		}
		if(StrEqual(sClassname, "infected"))
		{
			return ZombieType_CommonInfected;
		}
		else if(StrEqual(sClassname, "witch"))
		{
			return ZombieType_Witch;
		}

		return ZombieType_Invalid;
	}
}
stock void UC_ReplyToCommand(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[256];

	VFormat(buffer, sizeof(buffer), format, 3);
	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	ReplyToCommand(client, buffer);
}

stock void UC_PrintToChat(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	
	char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 3);
	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	PrintToChat(client, buffer);
}

stock void UC_PrintToChatAll(const char[] format, any ...)
{	
	char buffer[256];
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		
		UC_PrintToChat(i, buffer);
	}
}

stock void UC_StringToUpper(char[] buffer)
{
	int length = strlen(buffer);
	for(int i=0;i < length;i++)
		buffer[i] = CharToUpper(buffer[i]);
}

stock void UC_PrintToChatEyal(const char[] format, any...)
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
			UC_PrintToChat(i, buffer);
	}
}

stock ConVar UC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	ConVar hndl = AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);

	if (flags & FCVAR_PROTECTED)
		ServerCommand("sm_cvar protect %s", name);

	return hndl;
}

stock bool IsPlayer(int entity)
{
	if(entity >= 1 && entity <= MaxClients)
		return true;
		
	return false;
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
	return GetEntProp(entity, Prop_Data, "m_iHealth");
}

stock void GunXP_GiveClientHealth(int client, int permanentHP = 0, int temporaryHP = 0)
{
	if(GetEntityHealth(client) + permanentHP + L4D_GetPlayerTempHealth(client) > GetEntityMaxHealth(client))
	{
		if(GetEntityHealth(client) + permanentHP > GetEntityMaxHealth(client))
		{
			SetEntityHealth(client, GetEntityMaxHealth(client));
		}
		else
		{
			SetEntityHealth(client, GetEntityHealth(client) + permanentHP);
			L4D_SetPlayerTempHealth(client, GetEntityMaxHealth(client) - GetEntityHealth(client) + 1);
		}
	}
	else
	{
		SetEntityHealth(client, GetEntityHealth(client) + permanentHP);
	}

	if(GetEntityHealth(client) + temporaryHP + L4D_GetPlayerTempHealth(client) > GetEntityMaxHealth(client))
	{
		L4D_SetPlayerTempHealth(client, GetEntityMaxHealth(client) - GetEntityHealth(client) + 1);
	}
	else
	{
		L4D_SetPlayerTempHealth(client, L4D_GetPlayerTempHealth(client) + temporaryHP + 1);
	}
}
/**
 * @brief Reloads a plugin.
 *
 * @param plugin	Plugin Handle (INVALID_HANDLE uses the calling plugin).
 * @noreturn
 */
stock GunXP_ReloadPlugin(Handle plugin = INVALID_HANDLE)
{
	char filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins reload %s", filename);
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
		GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));
		
		if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
			PrintToChat(i, buffer);
	}
}

stock void PrintToChatIfEyal(int client, const char[] format, any ...)
{
	if(!IsPlayer(client))
		return;

	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 3);

	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
		PrintToChat(client, buffer);
}
