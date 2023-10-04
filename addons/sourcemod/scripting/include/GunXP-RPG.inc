#if defined _GunXP_RPG_included
 #endinput
#endif

#include <autoexecconfig>
#include <left4dhooks>

#define _GunXP_RPG_included

#define FPERM_ULTIMATE (FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_WRITE | FPERM_G_EXEC | FPERM_O_READ | FPERM_O_WRITE | FPERM_O_EXEC)

#define PERK_TREE_NOT_UNLOCKED -1

#define SPEEDSTATE_NULL -1	// This is to return an invalid speeds and stop attempting to change player movement speed

#define TANK_TIER_UNKNOWN -2
#define TANK_TIER_UNTIERED -1

#define NO_DAMAGE_IMMUNITY 0
#define DAMAGE_IMMUNITY_BURN (1 << 0)
#define DAMAGE_IMMUNITY_MELEE (1 << 1)
#define DAMAGE_IMMUNITY_BULLETS (1 << 2)
#define DAMAGE_IMMUNITY_EXPLOSIVES (1 << 2)

enum
{
	ATTRIBUTE_NEUTRAL,
	ATTRIBUTE_POSITIVE,
	ATTRIBUTE_NEGATIVE,
	SIZEOF_ATTRIBUTE
}

enum
{
	COLLISION_RETURN,		// Return means don't apply attribute if one already exists.
	COLLISION_ADD,
	COLLISION_SET,
	COLLISION_SET_IF_LOWER,
	COLLISION_SET_IF_HIGHER,
	SIZEOF_COLLISIONS
}

enum
{
	TRANSFER_NORMAL,
	TRANSFER_REVERT,
	TRANSFER_NO,
	SIZEOF_TRANSFERS
}


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
	SPEEDSTATE_HANDICAP,          // Min 0.0
	SPEEDSTATE_STUN,             // Min 0.0
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


// Returns true if player died, false otherwise.
native bool RPG_Perks_InstantKill(int victim, int attacker, int inflictor, int damagetype);

// Returns damage dealt after all modifiers.
native float RPG_Perks_TakeDamage(int victim, int attacker, int inflictor, float damage, int damagetype, int hitbox=0, int hitgroup=0);

native void RPG_Perks_IgniteWithOwnership(int victim, int attacker);

native void RPG_Perks_GetClientLimitedAbility(int entity, char attributeName[64], int &timesUsed, int &maxUses);


// Returns true if ability was used, false if maxed or another error was thrown.
native bool  RPG_Perks_UseClientLimitedAbility(int client, char identifier[32], char sError[256] = {EOS, ...});

native bool RPG_Perks_IsEntityTimedAttribute(int entity, char attributeName[64], float &fDuration=0.0);

// Must close the array returned by this native.
// See ATTRIBUTE_* for list of attribute types.
native ArrayList RPG_Perks_GetEntityTimedAttributes(int entity, int attributeType);

// See COLLISION_* for list of actions taken on collision.
// See ATTRIBUTE_* for list of attribute types.
// If COLLISION_RETURN, COLLISION_SET_IF_HIGHER, or COLLISION_SET_IF_LOWER are used, returns false if attribute was not set.
native bool RPG_Perks_ApplyEntityTimedAttribute(int entity, char attributeName[64], float fDuration, int collision, int attributeType, int transferRules = TRANSFER_NORMAL);

// If something that requires recalculating what's the max HP of a client, use this.
native void RPG_Perks_RecalculateMaxHP(int client);

// Sets a client's health allowing over 65535 HP. Only set for tanks please.
native void RPG_Perks_SetClientHealth(int client, int amount);

// Gets a client's health getting if they have over 65535 HP. Feel free to check for non-tanks.
native int RPG_Perks_GetClientHealth(int client);

// Gets a client's max health getting if they have over 65535 HP. Feel free to check for non-tanks.
native int RPG_Perks_GetClientMaxHealth(int client);

// Lets you give a player above 200 temp HP.
native int RPG_Perks_SetClientTempHealth(int client, int hp);

// Please only pass survivors to this function.
native int RPG_Perks_GetClientTempHealth(int client);

// For immunityType, see DAMAGE_IMMUNITY_*
native int RPG_Tanks_IsDamageImmuneTo(int client, int immunityType);

// For damageImmunities, see DAMAGE_IMMUNITY_*
native int RPG_Tanks_RegisterTank(int tier, int entries, char name[32], char description[512], int maxHP, int speed, float damageMultiplier, int XPRewardMin, int XPRewardMax, int damageImmunities);


// If cooldown is 0, ability will be described "Check passive abilities for details"
native int RPG_Tanks_RegisterActiveAbility(int tank, char name[32], char description[256], int minCooldown, int maxCooldown);

native int RPG_Tanks_RegisterPassiveAbility(int tank, char name[32], char description[512]);

// Gets a client's tank index. Do not use this before RPG_Perks_OnZombiePlayerSpawned, and do not use this on non-tank clients.
// Use RPG_Perks_GetZombieType(client) to compare with ZombieType_Tank to ensure its a tank before using this.
// Returns tank index, TANK_TIER_UNTIERED for untiered and TANK_TIER_UNKNOWN on priority -10 of GetZombieMaxHP.
native int RPG_Tanks_GetClientTank(int client);

native float RPG_Tanks_GetDamagePercent(int client, int tank);
native void RPG_Tanks_SetDamagePercent(int client, int tank, float damagePercent);

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
// XPReward is set to -1 if not enough damage is dealt.
forward void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward);

// abilityIndex is the index registered with RPG_Tanks_RegisterActiveAbility
// Note: Verify the tank is the same index as yours, because two activated abilities by different tanks can have the same index.
forward void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex);

// return Plugin_Handled and edit sError to prevent reloading.
forward Action GunXP_RPGShop_OnTryReloadRPGPlugins(char sError[256]);

// At this point, every perk tree and skill were removed.
forward void GunXP_OnReloadRPGPlugins();
forward void GunXP_RPGShop_OnPerkTreeBuy(int client, int perkIndex, int perkLevel, bool bAutoRPG);
forward void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG);

// This is called while the player still has their current perk tree and skills.
// Also called when player begins mutating.
// You must check if the perk tree / skill is unlocked before you act with the player. This is because upon selling a talent, only that talent is shown with IsPerkTreeUnlocked or IsSkillUnlocked
// DO NOT UNDER ANY CIRCUMSTANCE SELL OR RESET A PLAYER IN THIS FORWARD IN ANY WAY SHAPE OR FORM ABLE TO.
forward void GunXP_RPGShop_OnResetRPG(int client);


// WARNING! THIS FORWARD FIRES 20 TIMES PER CHECK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// Generally you should set-up a cvar and make the priority 0. Other plugins will be closer or further from 10 based on what they need.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the speed to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// After that, it would be recommended to multiply the swing speed.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.

// ATTENTION!!! float delay is the time it takes for the tank to swing after his hand connects with survivor / air.
forward void RPG_Perks_OnGetTankSwingSpeed(int priority, int client, float &delay);

// Called when RPG_Perks_IgniteWithOwnership is used.
forward void RPG_Perks_OnIgniteWithOwnership(int victim, int attacker);

// WARNING! THIS FORWARD FIRES 20 TIMES PER CHECK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// Generally you should set-up a cvar and make the priority 0. Other plugins will be closer or further from 10 based on what they need.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// It is recommended in general that you only add and don't multiply.
forward void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses);

forward void RPG_Perks_OnTimedAttributeStart(int client, char attributeName[64], float fDuration);

forward void RPG_Perks_OnTimedAttributeExpired(int client, char attributeName[64]);

// if oldClient == newClient, the duration was modified.
forward void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64]);

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
// It is recommended to default priority of 0 but have a cvar that lets controlling it.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the damage to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.
// bImmune is like setting damage to 0.0, but enables plugins to block your damage immunity. Example: Tier 1 tank is immune to fire damage. Flaming katana deals fire damage and ignores all fire immunity.

forward void RPG_Perks_OnShouldInstantKill(int priority, int victim, int attacker, int inflictor, int damagetype, bool &bImmune);

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
forward void RPG_Perks_OnGetDefibHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent);

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
// You can pass anything as long as it's a valid edict.
stock ZombieType RPG_Perks_GetZombieType(int entity, bool bAllowDead = false)
{
	if(IsPlayer(entity))
	{
		if(!IsPlayerAlive(entity) && !bAllowDead)
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

		if(StrEqual(sClassname, "infected"))
		{
			if(GetEntProp(entity, Prop_Data, "m_lifeState") != 0 && !bAllowDead)
			{
				return ZombieType_Invalid;
			}

			return ZombieType_CommonInfected;
		}
		else if(StrEqual(sClassname, "witch"))
		{
			if(GetEntProp(entity, Prop_Data, "m_lifeState") != 0 && !bAllowDead)
			{
				return ZombieType_Invalid;
			}

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

	char sReplaceFrom[2], sReplaceTo[32];

	sReplaceFrom[0] = buffer[0]
	sReplaceFrom[1] = EOS;
	FormatEx(sReplaceTo, sizeof(sReplaceTo), "{GREEN}{NORMAL}%s", sReplaceFrom);
	
	ReplaceStringEx(buffer, sizeof(buffer), sReplaceFrom, sReplaceTo);

	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	ReplaceString(buffer, sizeof(buffer), "{PERCENT}", "%%");
	
	ReplyToCommand(client, buffer);
}

stock void UC_PrintToChat(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	
	char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 3);

	char sReplaceFrom[2], sReplaceTo[32];

	sReplaceFrom[0] = buffer[0]
	sReplaceFrom[1] = EOS;
	FormatEx(sReplaceTo, sizeof(sReplaceTo), "{GREEN}{NORMAL}%s", sReplaceFrom);
	
	ReplaceStringEx(buffer, sizeof(buffer), sReplaceFrom, sReplaceTo);

	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	ReplaceString(buffer, sizeof(buffer), "{PERCENT}", "%%");
	
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

stock bool IsClientEyal(int client)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Engine, steamid, sizeof(steamid));
		
	if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
		return true;
		
	return false;
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


// This function can alter your temporary health twice in a row. If you wish to set, you can call this function with 0 permanent and 0 temporary to ensure it does if it wants to.
stock void GunXP_GiveClientHealth(int client, int permanentHP = 0, int temporaryHP = 0)
{
	if(GetEntityHealth(client) + permanentHP + RPG_Perks_GetClientTempHealth(client) > GetEntityMaxHealth(client))
	{
		if(GetEntityHealth(client) + permanentHP > GetEntityMaxHealth(client))
		{
			SetEntityHealth(client, GetEntityMaxHealth(client));
		}
		else
		{
			SetEntityHealth(client, GetEntityHealth(client) + permanentHP);
			RPG_Perks_SetClientTempHealth(client, GetEntityMaxHealth(client) - GetEntityHealth(client) + 1);
		}
	}
	else
	{
		SetEntityHealth(client, GetEntityHealth(client) + permanentHP);
	}

	if(GetEntityHealth(client) + temporaryHP + RPG_Perks_GetClientTempHealth(client) > GetEntityMaxHealth(client))
	{
		RPG_Perks_SetClientTempHealth(client, GetEntityMaxHealth(client) - GetEntityHealth(client) + 1);

	}
	else
	{
		RPG_Perks_SetClientTempHealth(client, RPG_Perks_GetClientTempHealth(client) + temporaryHP + 1);
	}
}

stock void GunXP_RegenerateTankHealth(int client, int amount)
{
	RPG_Perks_SetClientHealth(client, RPG_Perks_GetClientHealth(client) + amount);

	if(RPG_Perks_GetClientHealth(client) > RPG_Perks_GetClientMaxHealth(client))
	{
		RPG_Perks_SetClientHealth(client, RPG_Perks_GetClientMaxHealth(client));
	}
}

stock void ExecuteFullHeal(int client)
{
	if (GetClientTeam(client) == view_as<int>(L4DTeam_Survivor))
	{
		bool bIncap, bPinned;
		bIncap  = L4D_IsPlayerIncapacitated(client);
		bPinned = L4D_IsPlayerPinned(client);
		if (bIncap && bPinned)
		{
			Handle convar = FindConVar("survivor_incap_health");

			SetEntityHealth(client, GetConVarInt(convar));
		}
		else if (bIncap)
		{
			FullyHealPlayer(client);

			if (L4D_IsPlayerIncapacitated(client))
				L4D2_VScriptWrapper_ReviveFromIncap(client);

			SetEntityHealthToMax(client);
		}
		else
		{
			FullyHealPlayer(client);

			if (L4D_IsPlayerIncapacitated(client))
				L4D2_VScriptWrapper_ReviveFromIncap(client);

			SetEntityHealthToMax(client);
		}
	}
	else
	{
		SetEntityHealthToMax(client);
	}

	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
}

stock void SetEntityHealthToMax(int entity)
{
	SetEntityHealth(entity, GetEntProp(entity, Prop_Send, "m_iMaxHealth"));
}

stock void FullyHealPlayer(int client)
{
	char code[512];

	FormatEx(code, sizeof(code), "ret <- GetPlayerFromUserID(%d).GiveItem(\"health\"); <RETURN>ret</RETURN>", GetClientUserId(client));

	char sOutput[512];
	L4D2_GetVScriptOutput(code, sOutput, sizeof(sOutput));
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

stock void PrintToConsoleEyal(const char[] format, any...)
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

		if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
			PrintToConsole(i, buffer);
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

stock void PrintToConsoleIfEyal(int client, const char[] format, any ...)
{
	if(!IsPlayer(client))
		return;

	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 3);

	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
		PrintToConsole(client, buffer);
}