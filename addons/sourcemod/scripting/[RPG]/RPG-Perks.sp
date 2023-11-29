/* List of things this plugins changes in how L4D2 works:

1. Getting up from ledge hang inflicts damage to you 

*/

#undef REQUIRE_PLUGIN
#include <GunXP-RPG>
#include <ps_api>
#define REQUIRE_PLUGIN
#include <autoexecconfig>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

// Debug variable.
int g_iHurtCount = 0;

public Plugin myinfo =
{
	name        = "RPG Perks",
	author      = "Eyal282",
	description = "Perks for RPG that normally don't work well if multiple plugins want to grant them.",
	version     = PLUGIN_VERSION,
	url         = ""
};

#define SOUND_CHANNEL SNDCHAN_STATIC

#define INVINCIBLE_SOUND "@#music/tank/onebadtank.wav"

// How much times to play the sound?
#define INVINCIBLE_SOUND_MULTIPLIER 2

// Those are the default speeds
#define DEFAULT_RUN_SPEED		220.0
#define DEFAULT_WATER_SPEED 	115.0
#define DEFAULT_LIMP_SPEED		150.0
#define DEFAULT_WALK_SPEED		85.0
#define DEFAULT_CRITICAL_SPEED	85.0
#define DEFAULT_CROUCH_SPEED	75.0
#define DEFAULT_SCOPE_SPEED	85.0

// Max and minimum speeds are applied for legacy kernel, because it works terrible on extreme values
#define MAX_SPEED				650.0
#define MIN_SPEED				65.0	

float ANGLE_STRAIGHT_DOWN[3] = { 90.0, 0.0, 0.0 };

// Player Absolute Speeds
float g_fAbsRunSpeed[MAXPLAYERS+1];			// Normal player speed (default = 220.0)
float g_fAbsWalkSpeed[MAXPLAYERS+1];		// Player speed while walking (default = 85.0)
float g_fAbsCrouchSpeed[MAXPLAYERS+1];		// Player speed while crouching (default = 75.0)
float g_fAbsLimpSpeed[MAXPLAYERS+1];		// Player speed while limping (default = 150.0)
float g_fAbsCriticalSpeed[MAXPLAYERS+1];		// Player speed when 1 HP after 1 incapacitation (default = 85.0)
float g_fAbsWaterSpeed[MAXPLAYERS+1];		// Player speed on water (default = 115.0)
float g_fAbsAdrenalineSpeed[MAXPLAYERS+1];		// Player speed when running under adrenaline effect
float g_fAbsScopeSpeed[MAXPLAYERS+1];		// Player speed while looking through a sniper scope
float g_fAbsCustomSpeed[MAXPLAYERS+1];		// Player speed while under custom condition.

int g_iAbsLastLimpHealth[MAXPLAYERS+1] = { -1, ... };
int g_iAbsLimpHealth[MAXPLAYERS+1];
int g_iOverrideSpeedState[MAXPLAYERS+1] = { SPEEDSTATE_NULL, ... };

float g_fMaterializedTimestamp[MAXPLAYERS+1];

float g_fSpawnPoint[3];
float g_fLastStunOrigin[MAXPLAYERS+1][3];

bool g_bLate;

// 0 = no, 1 = yes, 2 = ignore.
float g_fLastElevatorHeight[2049];
int g_iIsTouching[MAXPLAYERS+1][2049];

int g_refNightmareFogControl = INVALID_ENT_REFERENCE;
int g_refLastFog[MAXPLAYERS+1] = { INVALID_ENT_REFERENCE, ... };

bool g_bNightmare[MAXPLAYERS+1];

bool g_bTeleported[MAXPLAYERS+1];
bool g_bRoundStarted = false;

bool g_bMidInstantKill = false;
bool g_bMidClearAttributes = false;

Handle g_hCheckAttributeExpire;

ConVar g_hGamemode;
ConVar g_hDifficulty;

ConVar g_bRescueDisabled;

ConVar g_hTankSwingInterval;
ConVar g_hTankAttackInterval;

ConVar g_hRPGPetCountForManualDirector;
ConVar g_hRPGManualDirectorInterval;

ConVar g_hRPGTriggerHurtMultiplier;

ConVar g_hRPGIncapPistolPriority;
ConVar g_hInvincibleDamagePriority;

ConVar g_hRPGTankHealth;

ConVar g_hPillsDecayRate;

ConVar g_hKitMaxHeal;

ConVar g_hKitDuration;
ConVar g_hRPGKitDuration;

ConVar g_hDefibDuration;
ConVar g_hRPGDefibDuration;

ConVar g_hReviveHealth;
ConVar g_hReviveDuration;
ConVar g_hRPGReviveDuration;
ConVar g_hRPGLedgeReviveDuration;

ConVar g_hIncapHealth;
ConVar g_hRPGIncapHealth;

ConVar g_hLedgeHangHealth;
ConVar g_hRPGLedgeHangHealth;

ConVar g_hAdrenalineDuration;
ConVar g_hRPGAdrenalineDuration;
ConVar g_hRPGAdrenalineRunSpeed;

ConVar g_hAdrenalineHealPercent;
ConVar g_hRPGAdrenalineHealPercent;

ConVar g_hPainPillsHealPercent;
ConVar g_hRPGPainPillsHealPercent;

ConVar g_hPainPillsHealThreshold;

ConVar g_hCriticalSpeed;
ConVar g_hLimpHealth;
ConVar g_hRPGLimpHealth;

ConVar g_hStartIncapWeapon;

GlobalForward g_fwOnShouldIgnoreEntireTeamTouch;

GlobalForward g_fwOnShouldClosetsRescue;

GlobalForward g_fwOnShouldInstantKill;

GlobalForward g_fwOnGetTankSwingSpeed;

GlobalForward g_fwOnIgniteWithOwnership;

GlobalForward g_fwOnGetMaxLimitedAbility;
GlobalForward g_fwOnTimedAttributeStart;
GlobalForward g_fwOnTimedAttributeExpired;
GlobalForward g_fwOnTimedAttributeTransfered;

GlobalForward g_fwOnGetRPGReplicateCvarValue;

GlobalForward g_fwOnGetRPGSpecialInfectedClass;

GlobalForward g_fwOnGetRPGMaxHP;
GlobalForward g_fwOnGetRPGZombieMaxHP;

GlobalForward g_fwOnRPGPlayerSpawned;
GlobalForward g_fwOnRPGZombiePlayerSpawned;

GlobalForward g_fwOnGetRPGAdrenalineDuration;
GlobalForward g_fwOnGetRPGMedsHealPercent;
GlobalForward g_fwOnGetRPGKitHealPercent;
GlobalForward g_fwOnGetRPGReviveHealthPercent;
GlobalForward g_fwOnGetRPGDefibHealthPercent;

GlobalForward g_fwOnGetRPGKitDuration;
GlobalForward g_fwOnGetRPGDefibDuration;
GlobalForward g_fwOnGetRPGReviveDuration;

GlobalForward g_fwOnGetRPGIncapWeapon;
GlobalForward g_fwOnGetRPGIncapHealth;

GlobalForward g_fwOnGetRPGSpeedModifiers;
GlobalForward g_fwOnCalculateDamage;

int g_iHealth[MAXPLAYERS+1];
int g_iTemporaryHealth[MAXPLAYERS+1];
int g_iMaxHealth[MAXPLAYERS+1];

int g_iLastTemporaryHealth[MAXPLAYERS+1];
int g_iLastPermanentHealth[MAXPLAYERS+1];
char g_sLastSecondaryClassname[MAXPLAYERS+1][64];
int g_iLastSecondaryClip[MAXPLAYERS+1];
bool g_bLastSecondaryDual[MAXPLAYERS+1];

enum struct enTimedAttribute
{
	// "Stun"
	char attributeName[64];

	int entity;
	float fExpire;
	// ATTRIBUTE_*
	int attributeType;

	// TRANSFER_*
	int transferRules;
}

ArrayList g_aTimedAttributes;

// Per round abilities.
enum struct enLimitedAbility
{
	char identifier[32];
	char authId[64];
	int timesUsed;
}

ArrayList g_aLimitedAbilities;

enum struct enReplicateCvar
{
	char cvarName[64];

	StringMap smLastValues;
}

ArrayList g_aReplicateCvars;

public void OnPluginEnd()
{
	int fog = EntRefToEntIndex(g_refNightmareFogControl);

	if(fog != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(fog, "Kill");
		g_refNightmareFogControl = INVALID_ENT_REFERENCE;
	}

	g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
	g_hReviveDuration.FloatValue = g_hRPGReviveDuration.FloatValue;
	g_hLimpHealth.IntValue = g_hRPGLimpHealth.IntValue;
	g_hAdrenalineHealPercent.IntValue = g_hRPGAdrenalineHealPercent.IntValue;
	g_hPainPillsHealPercent.IntValue = g_hRPGPainPillsHealPercent.IntValue;
	g_hTankAttackInterval.FloatValue = 1.5;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(!RPG_Perks_IsEntityTimedAttribute(i, "Stun"))
			continue;
		
		SetEntityMoveType(i, MOVETYPE_WALK);
	}
}



public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{	
	CreateNative("RPG_Perks_InstantKill", Native_InstantKill);
	CreateNative("RPG_Perks_TakeDamage", Native_TakeDamage);
	CreateNative("RPG_Perks_UseAdrenaline", Native_UseAdrenaline);
	CreateNative("RPG_Perks_IgniteWithOwnership", Native_IgniteWithOwnership);
	CreateNative("RPG_Perks_RecalculateMaxHP", Native_RecalculateMaxHP);
	CreateNative("RPG_Perks_SetClientHealth", Native_SetClientHealth);
	CreateNative("RPG_Perks_GetClientHealth", Native_GetClientHealth);
	CreateNative("RPG_Perks_GetClientMaxHealth", Native_GetClientMaxHealth);
	CreateNative("RPG_Perks_SetClientTempHealth", Native_SetClientTempHealth);
	CreateNative("RPG_Perks_GetClientTempHealth", Native_GetClientTempHealth);
	CreateNative("RPG_Perks_IsEntityTimedAttribute", Native_IsEntityTimedAttribute);
	CreateNative("RPG_Perks_GetEntityTimedAttributes", Native_GetEntityTimedAttributes);
	CreateNative("RPG_Perks_ApplyEntityTimedAttribute", Native_ApplyEntityTimedAttribute);
	CreateNative("RPG_Perks_GetClientLimitedAbility", Native_GetClientLimitedAbility);
	CreateNative("RPG_Perks_GetClientLimitedAbilitiesList", Native_GetClientLimitedAbilitiesList);
	CreateNative("RPG_Perks_UseClientLimitedAbility", Native_UseClientLimitedAbility);
	CreateNative("RPG_Perks_ReuseClientLimitedAbility", Native_ReuseClientLimitedAbility);
	CreateNative("RPG_Perks_RegisterReplicateCvar", Native_RegisterReplicateCvar);

	g_bLate = bLate;

	return APLRes_Success;
}

public any Native_InstantKill(Handle caller, int numParams)
{
	if(g_bMidInstantKill)
		return false;

	int victim = GetNativeCell(1);
	int attacker = GetNativeCell(2);
	int inflictor = GetNativeCell(3);
	int damagetype = GetNativeCell(4);
	
	bool bImmune = false;

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnShouldInstantKill);

		Call_PushCell(prio);
		Call_PushCell(victim);
		Call_PushCell(attacker);
		Call_PushCell(inflictor);
		Call_PushCell(damagetype);
		
		Call_PushCellRef(bImmune);

		Call_Finish();	
	}

	if(bImmune)
		return false;

	ConVar cvar = FindConVar("survivor_max_incapacitated_count");

	SetEntProp(victim, Prop_Send, "m_currentReviveCount", cvar.IntValue);

	char filename[512], class[64];
	GetPluginFilename(caller, filename, sizeof(filename));
	GetEdictClassname(victim, class, sizeof(class));

	Format(filename, sizeof(filename), "RPG_Perks_InstantKill: %s - %i - %s", filename, victim, class);

	LogToFile("eyal_crash_detector.txt", filename);
	g_bMidInstantKill = true;
	SDKHooks_TakeDamage(victim, inflictor, attacker, 100000.0, damagetype);
	g_bMidInstantKill = false;

	if(IsPlayerAlive(victim))
		return false;
	
	return true;
}

// For now, DMG_BURN and DMG_FALL will not require this native.
public any Native_TakeDamage(Handle caller, int numParams)
{
	int victim = GetNativeCell(1);
	int attacker = GetNativeCell(2);
	int inflictor = GetNativeCell(3);
	float damage = GetNativeCell(4);
	int damagetype = GetNativeCell(5);
	int hitbox = GetNativeCell(6);
	int hitgroup = GetNativeCell(7);
	
	float fFinalDamage = damage;

	char filename[512], class[64];
	GetPluginFilename(caller, filename, sizeof(filename));
	GetEdictClassname(victim, class, sizeof(class));

	Format(filename, sizeof(filename), "RPG_Perks_TakeDamage: %s - %i - %.1f - %i - %s", filename, victim, damage, damagetype, class);
	LogToFile("eyal_crash_detector.txt", filename);

	Action rtn = RPG_OnTraceAttack(victim, attacker, inflictor, fFinalDamage, damagetype, hitbox, hitgroup);

	if(rtn == Plugin_Handled || rtn == Plugin_Stop)
		return 0.0;

	SDKHooks_TakeDamage(victim, inflictor, attacker, fFinalDamage, damagetype);
	
	return fFinalDamage;
}

public int Native_IgniteWithOwnership(Handle caller, int numParams)
{
	int victim = GetNativeCell(1);
	int attacker = GetNativeCell(2);

	// Prevent crashes, also this works on commons and witches despite the name of the native.
	if(L4D_IsPlayerOnFire(victim))
		return 0;

	else if(LibraryExists("RPG_Tanks") && RPG_Tanks_IsDamageImmuneTo(victim, DAMAGE_IMMUNITY_BURN))
		return 0;

	char filename[512], class[64];
	GetPluginFilename(caller, filename, sizeof(filename));
	GetEdictClassname(victim, class, sizeof(class));

	Format(filename, sizeof(filename), "RPG_Perks_IgniteWithOwnership: %s - %i - %s", filename, victim, class);
	LogToFile("eyal_crash_detector.txt", filename);

	SDKHooks_TakeDamage(victim, attacker, attacker, 0.0, DMG_BURN);
	
	Call_StartForward(g_fwOnIgniteWithOwnership);

	Call_PushCell(victim);
	Call_PushCell(attacker);

	Call_Finish();	

	return 0;
}

public any Native_UseAdrenaline(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	float fDuration = GetNativeCell(2);

	bool bHeal = GetNativeCell(3);

	bool bStacks = GetNativeCell(4);

	if(bHeal)
	{
		int percentToHeal = g_hRPGAdrenalineHealPercent.IntValue;

		Call_StartForward(g_fwOnGetRPGMedsHealPercent);

		Call_PushCell(client);
		Call_PushCell(true);
		Call_PushCellRef(percentToHeal);

		Call_Finish();

		if(percentToHeal > 0)
		{
			GunXP_GiveClientHealth(client, 0, RoundToFloor(GetEntityMaxHealth(client) * (float(percentToHeal) / 100)));
		}
	}

	Call_StartForward(g_fwOnGetRPGAdrenalineDuration);

	Call_PushCell(client);
	Call_PushFloatRef(fDuration);

	Call_Finish();

	if(bStacks)
	{
		if(Terror_GetAdrenalineTime(client) == -1.0)
		{
			L4D2_UseAdrenaline(client, fDuration, false, false);
		}
		else
		{
			fDuration += Terror_GetAdrenalineTime(client);
			
			Terror_SetAdrenalineTime(client, 0.0);

			L4D2_UseAdrenaline(client, fDuration, false, false);
		}
	}
	else if(fDuration > Terror_GetAdrenalineTime(client))
	{
		Terror_SetAdrenalineTime(client, 0.0);

		L4D2_UseAdrenaline(client, fDuration, false, false);	
	}

	return 0;
}

public int Native_RecalculateMaxHP(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	RecalculateMaxHP(client);

	return 0;
}

stock void RecalculateMaxHP(int client, bool bDontScale = false)
{
	int maxHP = 100;
	
	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetRPGMaxHP);

		Call_PushCell(prio);
		Call_PushCell(client);
		
		Call_PushCellRef(maxHP);

		Call_Finish();	
	}

	if(maxHP <= 0)
		maxHP = 100;

	float fOldPermanentPercent = float(GetEntityHealth(client)) / float(GetEntityMaxHealth(client));
	float fOldTemporaryPercent = float(RPG_Perks_GetClientTempHealth(client)) / float(GetEntityMaxHealth(client));

	SetEntityMaxHealth(client, maxHP);

	g_iMaxHealth[client] = maxHP;
	
	if(bDontScale)
		return;

	// This accounts for temporary health fluctuation instantly, right before we start depending on it, as GunXP_GiveClientHealth can alter Temp Health twice.
	GunXP_GiveClientHealth(client, 0, 0);

	float fPermanentPercent = float(GetEntityHealth(client)) / float(GetEntityMaxHealth(client));
	float fTemporaryPercent = float(RPG_Perks_GetClientTempHealth(client)) / float(GetEntityMaxHealth(client));

	int iPermanentHealth = 0;
	int iTemporaryHealth = 0;

	//80/100 = 148/189

	//newHP / newMaxHP = fOldTemporaryPercent * צשס;
	if(fPermanentPercent != fOldPermanentPercent)
	{
		iPermanentHealth = RoundToFloor((fOldPermanentPercent * GetEntityMaxHealth(client) - GetEntityHealth(client)));
	}

	if(fTemporaryPercent != fOldTemporaryPercent)
	{
		iTemporaryHealth = RoundToFloor((fOldTemporaryPercent * GetEntityMaxHealth(client)) - RPG_Perks_GetClientTempHealth(client));
	}
	
	if(iPermanentHealth + GetEntityHealth(client) == 0)
	{
		iPermanentHealth++;
		iTemporaryHealth--;
	}

	if(iTemporaryHealth + RPG_Perks_GetClientTempHealth(client) < 0)
		iTemporaryHealth = 0;

	if(!L4D_IsPlayerIncapacitated(client))
	{
		GunXP_GiveClientHealth(client, iPermanentHealth, iTemporaryHealth);
	}
}

stock float RoundToAbs(float value)
{
	return float(RoundToFloor(value));
}
public int Native_SetClientHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	
	int hp = GetNativeCell(2);

	if(hp <= 65535)
	{
		SetEntityHealth(client, hp);
		g_iHealth[client] = -1;
	}
	else
	{
		SetEntityHealth(client, 65535);
		g_iHealth[client] = hp;
	}

	return 0;
}


public int Native_GetClientHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	
	if(g_iHealth[client] <= 65535)
	{
		// An incapped tank is dead.
		if(L4D_IsPlayerIncapacitated(client) && L4D_GetClientTeam(client) == L4DTeam_Infected && L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
		{
			return 0;
		}

		return GetEntityHealth(client);
	}

	return g_iHealth[client];
}

public int Native_GetClientMaxHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	if(g_iMaxHealth[client] <= 0)
	{
		return GetEntityMaxHealth(client);
	}

	return g_iMaxHealth[client];
}

public int Native_SetClientTempHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	int hp = GetNativeCell(2);

	SetClientTemporaryHP(client, hp);

	return 0;
}


public int Native_GetClientTempHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	if(g_iTemporaryHealth[client] <= 200)
	{
		return L4D_GetPlayerTempHealth(client);
	}

	return g_iTemporaryHealth[client];
}

public int Native_IsEntityTimedAttribute(Handle caller, int numParams)
{
	if(g_aTimedAttributes == null)
	{
		g_aTimedAttributes = CreateArray(sizeof(enTimedAttribute));

		return false;
	}

	int entity = GetNativeCell(1);
	char attributeName[64];
	GetNativeString(2, attributeName, sizeof(attributeName));

	int size = g_aTimedAttributes.Length;

	for(int i=0;i < size;i++)
	{
		enTimedAttribute attribute;
		g_aTimedAttributes.GetArray(i, attribute);

		if(attribute.entity == entity && StrEqual(attributeName, attribute.attributeName))
		{
			SetNativeCellRef(3, attribute.fExpire - GetGameTime());

			return true;
		}
	}

	return false;
}


public any Native_GetEntityTimedAttributes(Handle caller, int numParams)
{
	ArrayList array = new ArrayList(sizeof(enTimedAttribute::attributeName));

	if(g_aTimedAttributes == null)
	{
		g_aTimedAttributes = CreateArray(sizeof(enTimedAttribute));

		return array;
	}

	int entity = GetNativeCell(1);

	int attributeType = GetNativeCell(2);

	int size = g_aTimedAttributes.Length;

	for(int i=0;i < size;i++)
	{
		enTimedAttribute attribute;
		g_aTimedAttributes.GetArray(i, attribute);

		if(attribute.entity == entity && attribute.attributeType == attributeType)
		{
			array.PushString(attribute.attributeName);
		}
	}

	return array;
}

public int Native_ApplyEntityTimedAttribute(Handle caller, int numParams)
{
	if(g_bMidClearAttributes)
		return true;

	if(g_aTimedAttributes == null)
	{
		g_aTimedAttributes = CreateArray(sizeof(enTimedAttribute));
	}

	int entity = GetNativeCell(1);
	char attributeName[64];
	GetNativeString(2, attributeName, sizeof(attributeName));

	float duration = GetNativeCell(3);

	int collision = GetNativeCell(4);

	int attributeType = GetNativeCell(5);

	int transferRules = GetNativeCell(6);

	int size = g_aTimedAttributes.Length;

	for(int i=0;i < size;i++)
	{
		enTimedAttribute attribute;
		g_aTimedAttributes.GetArray(i, attribute);

		if(attribute.entity == entity && StrEqual(attributeName, attribute.attributeName))
		{
			switch(collision)
			{
				case COLLISION_RETURN: return false;
				case COLLISION_ADD: attribute.fExpire += duration;
				case COLLISION_SET: attribute.fExpire = GetGameTime() + duration;
				case COLLISION_SET_IF_LOWER:
				{
					if(attribute.fExpire - GetGameTime() < duration)
					{
						attribute.fExpire = GetGameTime() + duration;
					}
					else
					{
						return false;
					}
				}

				case COLLISION_SET_IF_HIGHER:
				{
					if(attribute.fExpire - GetGameTime() > duration)
					{
						attribute.fExpire = GetGameTime() + duration;
					}
					else
					{
						return false;
					}
				}
			}
			
			g_aTimedAttributes.SetArray(i, attribute);

			if(attribute.fExpire <= GetGameTime())
			{
				Call_StartForward(g_fwOnTimedAttributeTransfered);

				Call_PushCell(entity);
				Call_PushCell(entity);
				Call_PushString(attribute.attributeName);

				Call_Finish();
			}

			if(IsPlayer(entity) && duration > 1.0)
			{
				CheckClientSpeedModifiers(entity);
			}

			// Can be null while applying an attribute DURING g_fwOnTimedAttributeTransfered
			if(g_hCheckAttributeExpire == INVALID_HANDLE)
				g_hCheckAttributeExpire = CreateTimer(duration, Timer_CheckAttributeExpire, _, TIMER_FLAG_NO_MAPCHANGE);

			TriggerTimer(g_hCheckAttributeExpire);

			return true;
		}
	}

	enTimedAttribute attribute;
	attribute.attributeName = attributeName;
	attribute.entity = entity;
	attribute.fExpire = GetGameTime() + duration;
	attribute.attributeType = attributeType;
	attribute.transferRules = transferRules;

	g_aTimedAttributes.PushArray(attribute);

	Call_StartForward(g_fwOnTimedAttributeStart);

	Call_PushCell(entity);
	Call_PushString(attribute.attributeName);
	Call_PushCell(duration);

	Call_Finish();

	if(IsPlayer(entity) && duration > 1.0)
	{
		CheckClientSpeedModifiers(entity);
	}

	if(g_hCheckAttributeExpire == INVALID_HANDLE)
		g_hCheckAttributeExpire = CreateTimer(duration, Timer_CheckAttributeExpire, _, TIMER_FLAG_NO_MAPCHANGE);

	TriggerTimer(g_hCheckAttributeExpire);
	
	return true;
}

public int Native_GetClientLimitedAbility(Handle caller, int numParams)
{
	if(g_aLimitedAbilities == null)
	{
		g_aLimitedAbilities = CreateArray(sizeof(enLimitedAbility));
	}

	int client = GetNativeCell(1);
	char identifier[32];
	GetNativeString(2, identifier, sizeof(identifier));

	int size = g_aLimitedAbilities.Length;

	int timesUsed = 0;
	char sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));

	for(int i=0;i < size;i++)
	{
		enLimitedAbility ability;

		g_aLimitedAbilities.GetArray(i, ability);


		if(StrEqual(sAuthId, ability.authId))
		{
			timesUsed = ability.timesUsed;
			break;
		}
	}

	int maxUses = 0;

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetMaxLimitedAbility);

		Call_PushCell(prio);
		Call_PushCell(client);

		Call_PushString(identifier);

		Call_PushCellRef(maxUses);

		Call_Finish();	
	}

	SetNativeCellRef(3, timesUsed);
	SetNativeCellRef(4, maxUses);

	return 0;
}


public any Native_GetClientLimitedAbilitiesList(Handle caller, int numParams)
{
	ArrayList array = new ArrayList(sizeof(enLimitedAbility::identifier));

	if(g_aLimitedAbilities == null)
	{
		g_aLimitedAbilities = CreateArray(sizeof(enLimitedAbility));

		return array;
	}

	int client = GetNativeCell(1);

	int size = g_aLimitedAbilities.Length;

	char sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));

	for(int i=0;i < size;i++)
	{
		enLimitedAbility ability;

		g_aLimitedAbilities.GetArray(i, ability);

		if(StrEqual(sAuthId, ability.authId))
		{
			array.PushString(ability.identifier);
		}
	}

	return array;
}

public int Native_UseClientLimitedAbility(Handle caller, int numParams)
{
	if(g_aLimitedAbilities == null)
	{
		g_aLimitedAbilities = CreateArray(sizeof(enLimitedAbility));

		return false;
	}

	int client = GetNativeCell(1);
	char identifier[32];
	GetNativeString(2, identifier, sizeof(identifier));

	int size = g_aLimitedAbilities.Length;

	int pos = -1;
	int timesUsed = 0;
	char sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));

	for(int i=0;i < size;i++)
	{
		enLimitedAbility ability;

		g_aLimitedAbilities.GetArray(i, ability);

		if(StrEqual(sAuthId, ability.authId))
		{
			timesUsed = ability.timesUsed;
			pos = i;
			break;
		}
	}

	if(pos == -1)
	{
		enLimitedAbility ability;

		ability.identifier = identifier;
		ability.authId = sAuthId;
		ability.timesUsed = 0;

		pos = g_aLimitedAbilities.PushArray(ability);
	}

	int maxUses = 0;

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetMaxLimitedAbility);

		Call_PushCell(prio);
		Call_PushCell(client);

		Call_PushString(identifier);
		
		Call_PushCellRef(maxUses);

		Call_Finish();	
	}

	if(timesUsed >= maxUses)
		return false;


	enLimitedAbility ability;

	ability.identifier = identifier;
	ability.authId = sAuthId;
	ability.timesUsed = timesUsed + 1;

	g_aLimitedAbilities.SetArray(pos, ability);
	return true;
}

public int Native_ReuseClientLimitedAbility(Handle caller, int numParams)
{
	if(g_aLimitedAbilities == null)
	{
		g_aLimitedAbilities = CreateArray(sizeof(enLimitedAbility));

		return false;
	}

	int client = GetNativeCell(1);
	char identifier[32];
	GetNativeString(2, identifier, sizeof(identifier));

	int size = g_aLimitedAbilities.Length;

	int pos = -1;
	int timesUsed = 0;
	char sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));

	for(int i=0;i < size;i++)
	{
		enLimitedAbility ability;

		g_aLimitedAbilities.GetArray(i, ability);

		if(StrEqual(sAuthId, ability.authId))
		{
			timesUsed = ability.timesUsed;
			pos = i;
			break;
		}
	}

	if(pos == -1)
	{
		enLimitedAbility ability;

		ability.identifier = identifier;
		ability.authId = sAuthId;
		ability.timesUsed = 0;

		pos = g_aLimitedAbilities.PushArray(ability);
	}

	if(timesUsed == 0)
		return false;

	enLimitedAbility ability;

	ability.identifier = identifier;
	ability.authId = sAuthId;
	ability.timesUsed = timesUsed - 1;

	g_aLimitedAbilities.SetArray(pos, ability);

	return true;
}


public int Native_RegisterReplicateCvar(Handle caller, int numParams)
{
	if(g_aReplicateCvars == null)
	{
		g_aReplicateCvars = CreateArray(sizeof(enReplicateCvar));
	}

	char cvarName[64];
	GetNativeString(1, cvarName, sizeof(cvarName));

	int size = g_aReplicateCvars.Length;

	for(int i=0;i < size;i++)
	{
		enReplicateCvar repCvar;

		g_aReplicateCvars.GetArray(i, repCvar);

		if(StrEqual(cvarName, repCvar.cvarName))
		{
			return 0;
		}
	}	

	enReplicateCvar repCvar;
	
	repCvar.cvarName = cvarName;
	repCvar.smLastValues = new StringMap();

	g_aReplicateCvars.PushArray(repCvar);

	return 0;
}
public Action Timer_CheckAttributeExpire(Handle hTimer)
{
	g_hCheckAttributeExpire = INVALID_HANDLE;

	float shortestToExpire = 999999999.0;

	// Can't declare size because the size changes over time.
	for(int i=0;i < g_aTimedAttributes.Length;i++)
	{
		enTimedAttribute attribute;
		g_aTimedAttributes.GetArray(i, attribute);

		if(!IsValidEdict(attribute.entity))
		{
			g_aTimedAttributes.Erase(i);
			i--;
			continue;
		}

		else if(attribute.fExpire - GetGameTime() <= 0.05)
		{
			g_aTimedAttributes.Erase(i);
			i--;

			Call_StartForward(g_fwOnTimedAttributeExpired);

			Call_PushCell(attribute.entity);
			Call_PushString(attribute.attributeName);

			Call_Finish();

			continue;
		}
		else
		{
			if(attribute.fExpire < shortestToExpire)
			{
				shortestToExpire = attribute.fExpire;
			}
		}
	}

	if(shortestToExpire < 99999999.0)
	{
		g_hCheckAttributeExpire = CreateTimer(shortestToExpire - GetGameTime(), Timer_CheckAttributeExpire, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Stop;
}

public void OnMapStart()
{
	PrecacheSound(INVINCIBLE_SOUND);
	PrecacheSound("physics/glass/glass_impact_bullet4.wav");

	if(!g_bLate)
	{
		for(int i=1;i < sizeof(g_bTeleported);i++)
		{
			g_bTeleported[i] = false;
			g_bNightmare[i] = false;
			g_iAbsLastLimpHealth[i] = -1;
		}
	}
	else
	{
		TryCreateNightmareFogEntity();
	}

	g_hCheckAttributeExpire = INVALID_HANDLE;

	g_aLimitedAbilities.Clear();
	g_aTimedAttributes.Clear();

	TriggerTimer(CreateTimer(1.0, Timer_CheckSpeedModifiers, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));

	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));


	LogToFile("eyal_crash_detector.txt", mapname);
}

public Action Timer_CheckSpeedModifiers(Handle hTimer)
{
	g_iHurtCount = 0;

	// As opposed to Tank Swing Interval, this is basically the "CS:GO invisible timer involving changing weapons". Tank can't switch weapons.
	g_hTankAttackInterval.FloatValue = 0.0;
	g_hLimpHealth.IntValue = 0;
	g_hAdrenalineDuration.FloatValue = 0.0;
	g_hAdrenalineHealPercent.IntValue = 0;
	g_hPainPillsHealPercent.IntValue = 0;
	g_hPainPillsHealThreshold.IntValue = 32767;

	g_hKitMaxHeal.IntValue = 32767;
	// Prediction error fix.
	g_hCriticalSpeed.FloatValue = DEFAULT_RUN_SPEED;

	char sGamemode[64];
	GetConVarString(g_hGamemode, sGamemode, sizeof(sGamemode));

	if(LibraryExists("GunXP-RPG"))
	{
		if(!StrEqual(sGamemode, "coop"))
		{
			g_hGamemode.SetString("coop");
			ServerCommand("changelevel c1m1_hotel");
		}
	}

	Call_StartForward(g_fwOnShouldClosetsRescue);

	Action rtn;

	Call_Finish(rtn);

	// L4D2_IsRealismMode is bugged for now...
	if(rtn >= Plugin_Handled || view_as<int>(L4D2_IsRealismMode()) == 1)
	{
		g_bRescueDisabled.BoolValue = true;
	}
	else
	{
		g_bRescueDisabled.BoolValue = false;
	}

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		CheckClientSpeedModifiers(i);
	}

	return Plugin_Continue;
}

public void CheckClientSpeedModifiers(int client)
{
	if(L4D_GetClientTeam(client) == L4DTeam_Survivor)
	{
		if(!L4D_IsPlayerIncapacitated(client))
		{
			g_iLastTemporaryHealth[client] = RPG_Perks_GetClientTempHealth(client);
			g_iLastPermanentHealth[client] = GetEntityHealth(client);
		}
		if(RPG_Perks_IsEntityTimedAttribute(client, "Stun"))
		{
			TeleportEntity(client, g_fLastStunOrigin[client], NULL_VECTOR, NULL_VECTOR);
		}

		if(!L4D_HasAnySurvivorLeftSafeArea() && !L4D2_IsTankInPlay())
		{
			if(IsPlayerSpawnStuck(client) && !g_bTeleported[client])
			{
				TeleportToStartArea(client);
			}

			ExecuteFullHeal(client);

			L4D_SetPlayerTempHealth(client, 0);
			g_iTemporaryHealth[client] = 0;
		}
		g_iOverrideSpeedState[client] = SPEEDSTATE_NULL;
		g_iAbsLimpHealth[client] = g_hRPGLimpHealth.IntValue;
		g_fAbsRunSpeed[client] = DEFAULT_RUN_SPEED;
		g_fAbsWalkSpeed[client] = DEFAULT_WALK_SPEED;
		g_fAbsCrouchSpeed[client] = DEFAULT_CROUCH_SPEED;
		g_fAbsLimpSpeed[client] = DEFAULT_LIMP_SPEED;
		g_fAbsCriticalSpeed[client] = DEFAULT_CRITICAL_SPEED;
		g_fAbsWaterSpeed[client] = DEFAULT_WATER_SPEED;
		g_fAbsAdrenalineSpeed[client] = g_hRPGAdrenalineRunSpeed.FloatValue;
		g_fAbsScopeSpeed[client] = DEFAULT_SCOPE_SPEED;
		g_fAbsCustomSpeed[client] = 0.0;


		for(int prio=-10;prio <= 10;prio++)
		{
			Call_StartForward(g_fwOnGetRPGSpeedModifiers);

			Call_PushCell(prio);
			Call_PushCell(client);
			Call_PushCellRef(g_iOverrideSpeedState[client]);
			Call_PushCellRef(g_iAbsLimpHealth[client]);
			Call_PushFloatRef(g_fAbsRunSpeed[client]);
			Call_PushFloatRef(g_fAbsWalkSpeed[client]);
			Call_PushFloatRef(g_fAbsCrouchSpeed[client]);
			Call_PushFloatRef(g_fAbsLimpSpeed[client]);
			Call_PushFloatRef(g_fAbsCriticalSpeed[client]);
			Call_PushFloatRef(g_fAbsWaterSpeed[client]);
			Call_PushFloatRef(g_fAbsAdrenalineSpeed[client]);
			Call_PushFloatRef(g_fAbsScopeSpeed[client]);
			Call_PushFloatRef(g_fAbsCustomSpeed[client]);

			Call_Finish();
		}

		if(!IsFakeClient(client) && g_iAbsLastLimpHealth[client] != g_iAbsLimpHealth[client])
		{
			char sValue[11];
			IntToString(g_iAbsLimpHealth[client], sValue, sizeof(sValue));

			SendConVarValue(client, g_hLimpHealth, sValue);
		}
	}

	CheckClientReplicatedCvars(client);

	g_iAbsLastLimpHealth[client] = g_iAbsLimpHealth[client];

	if(!RPG_Perks_IsEntityTimedAttribute(client, "Invincible"))
	{
		if(RPG_Perks_IsEntityTimedAttribute(client, "Invincible Music"))
		{
			RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible Music", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
			StopInvincibleSound(client);
		}

		return;
	}

	if(!RPG_Perks_IsEntityTimedAttribute(client, "Invincible Music"))
	{
		RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible Music", 60.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
		EmitInvincibleSound(client);
	}
}

public void CheckClientReplicatedCvars(int client)
{
	int size = g_aReplicateCvars.Length;

	char sKey[16];
	IntToString(GetClientUserId(client), sKey, sizeof(sKey));

	for(int pos=0;pos < size;pos++)
	{
		enReplicateCvar repCvar;

		g_aReplicateCvars.GetArray(pos, repCvar);

		char sValue[256];

		ConVar cvar = FindConVar(repCvar.cvarName);

		if(cvar != null)
		{			
			cvar.GetString(sValue, sizeof(sValue));

			for(int prio=-10;prio <= 10;prio++)
			{
				Call_StartForward(g_fwOnGetRPGReplicateCvarValue);

				Call_PushCell(prio);
				Call_PushCell(client);
				Call_PushString(repCvar.cvarName);
				Call_PushStringEx(sValue, sizeof(sValue), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);

				Call_Finish();
			}

			char sLastValue[256];

			if(!repCvar.smLastValues.GetString(sKey, sLastValue, sizeof(sLastValue)) || !StrEqual(sValue, sLastValue, false))
			{
				repCvar.smLastValues.SetString(sKey, sValue);

				RPG_SendConVarValue(client, cvar, sValue);
			}
		}
	}	
}
/*
public Action Command_ConcussionTest(int client, int args)
{
	ChangeClientTeam(client, 3);

	L4D_RespawnPlayer(client);

	return Plugin_Continue;
}
*/
public Action Command_KinesisTest(int client, int args)
{
	SetEntityGravity(client, -0.5);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 285.0 }));

	RPG_Perks_ApplyEntityTimedAttribute(client, "Psychokinesis Height Check5", 0.2, COLLISION_SET, ATTRIBUTE_NEGATIVE);

	return Plugin_Handled;
}

public Action Command_StunTest(int client, int args)
{
	RPG_Perks_ApplyEntityTimedAttribute(client, "Stun", 15.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);

	return Plugin_Handled;
}

public Action Command_MutationTest(int client, int args)
{
	RPG_Perks_ApplyEntityTimedAttribute(client, "Mutated", 15.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);

	return Plugin_Handled;
}

public Action Command_NightmareTest(int client, int args)
{
	RPG_Perks_ApplyEntityTimedAttribute(client, "Nightmare", 15.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
	return Plugin_Handled;
}

public void OnPluginStart()
{
	if(g_bLate)
	{
		g_bRoundStarted = true;
		
		for(int i=0;i < sizeof(g_bTeleported);i++)
		{
			g_bTeleported[i] = true;
		}
	}

	//RegAdminCmd("sm_concussiontest", Command_ConcussionTest, ADMFLAG_ROOT);
	RegAdminCmd("sm_psychotest", Command_KinesisTest, ADMFLAG_ROOT);
	RegAdminCmd("sm_kinesistest", Command_KinesisTest, ADMFLAG_ROOT);
	RegAdminCmd("sm_psychokinesistest", Command_KinesisTest, ADMFLAG_ROOT);
	RegAdminCmd("sm_stuntest", Command_StunTest, ADMFLAG_ROOT);
	RegAdminCmd("sm_mutationtest", Command_MutationTest, ADMFLAG_ROOT);
	RegAdminCmd("sm_nightmaretest", Command_NightmareTest, ADMFLAG_ROOT);

	if(g_aTimedAttributes == null)
		g_aTimedAttributes = CreateArray(sizeof(enTimedAttribute));
	
	if(g_aLimitedAbilities == null)
		g_aLimitedAbilities = CreateArray(sizeof(enLimitedAbility));

	if(g_aReplicateCvars == null)
		g_aReplicateCvars = CreateArray(sizeof(enReplicateCvar));

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_first_spawn", Event_PlayerFirstSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("tank_killed", Event_TankKilled, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStartPre, EventHookMode_Pre);
	HookEvent("heal_begin", Event_HealBegin);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("defibrillator_used", Event_DefibUsed, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_PlayerReplacesABot, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_BotReplacesAPlayer, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Post);
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrabPre, EventHookMode_Pre);
	HookEvent("revive_begin", Event_ReviveBeginPre, EventHookMode_Pre);

	HookEvent("pounce_end", Event_VictimFreeFromPin, EventHookMode_Post);
	HookEvent("tongue_release", Event_VictimFreeFromPin, EventHookMode_Post);
	HookEvent("jockey_ride_end", Event_VictimFreeFromPin, EventHookMode_Post);
	HookEvent("charger_carry_end", Event_VictimFreeFromPin, EventHookMode_Post);
	HookEvent("charger_pummel_end", Event_VictimFreeFromPin, EventHookMode_Post);

	HookEntityOutput("trigger_multiple", "OnStartTouch", TriggerMultiple_StartTouch);
	HookEntityOutput("trigger_multiple", "OnEndTouch", TriggerMultiple_EndTouch);

	HookEntityOutput("func_elevator", "OnReachedTop", FuncElevator_ReachFloor);
	HookEntityOutput("func_elevator", "OnReachedBottom", FuncElevator_ReachFloor);
	HookEntityOutput("func_tracktrain", "OnStart", FuncElevator_ReachFloor);
	HookEntityOutput("func_tracktrain", "OnNextPoint", FuncElevator_CalculateReachFloor);

	// Plugin_Handled if not.

	g_fwOnShouldIgnoreEntireTeamTouch = CreateGlobalForward("RPG_Perks_OnShouldIgnoreEntireTeamTouch", ET_Event, Param_Cell);

	g_fwOnShouldClosetsRescue = CreateGlobalForward("RPG_Perks_OnShouldClosetsRescue", ET_Event);

	g_fwOnShouldInstantKill = CreateGlobalForward("RPG_Perks_OnShouldInstantKill", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);

	g_fwOnGetTankSwingSpeed = CreateGlobalForward("RPG_Perks_OnGetTankSwingSpeed", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);

	g_fwOnIgniteWithOwnership = CreateGlobalForward("RPG_Perks_OnIgniteWithOwnership", ET_Ignore, Param_Cell, Param_Cell);

	g_fwOnGetMaxLimitedAbility = CreateGlobalForward("RPG_Perks_OnGetMaxLimitedAbility", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_CellByRef);


	g_fwOnTimedAttributeStart = CreateGlobalForward("RPG_Perks_OnTimedAttributeStart", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_fwOnTimedAttributeExpired = CreateGlobalForward("RPG_Perks_OnTimedAttributeExpired", ET_Ignore, Param_Cell, Param_String);
	g_fwOnTimedAttributeTransfered = CreateGlobalForward("RPG_Perks_OnTimedAttributeTransfered", ET_Ignore, Param_Cell, Param_Cell, Param_String);

	g_fwOnGetRPGReplicateCvarValue = CreateGlobalForward("RPG_Perks_OnGetReplicateCvarValue", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);

	g_fwOnGetRPGSpecialInfectedClass = CreateGlobalForward("RPG_Perks_OnGetSpecialInfectedClass", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);

	g_fwOnGetRPGMaxHP = CreateGlobalForward("RPG_Perks_OnGetMaxHP", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGZombieMaxHP = CreateGlobalForward("RPG_Perks_OnGetZombieMaxHP", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);

	g_fwOnRPGPlayerSpawned = CreateGlobalForward("RPG_Perks_OnPlayerSpawned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnRPGZombiePlayerSpawned = CreateGlobalForward("RPG_Perks_OnZombiePlayerSpawned", ET_Ignore, Param_Cell);

	g_fwOnGetRPGAdrenalineDuration = CreateGlobalForward("RPG_Perks_OnGetAdrenalineDuration", ET_Ignore, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGMedsHealPercent = CreateGlobalForward("RPG_Perks_OnGetMedsHealPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGKitHealPercent = CreateGlobalForward("RPG_Perks_OnGetKitHealPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGReviveHealthPercent = CreateGlobalForward("RPG_Perks_OnGetReviveHealthPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
	g_fwOnGetRPGDefibHealthPercent = CreateGlobalForward("RPG_Perks_OnGetDefibHealthPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);

	g_fwOnGetRPGKitDuration = CreateGlobalForward("RPG_Perks_OnGetKitDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGDefibDuration = CreateGlobalForward("RPG_Perks_OnGetDefibDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGReviveDuration = CreateGlobalForward("RPG_Perks_OnGetReviveDuration", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);

	g_fwOnGetRPGIncapHealth = CreateGlobalForward("RPG_Perks_OnGetIncapHealth", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGIncapWeapon = CreateGlobalForward("RPG_Perks_OnGetIncapWeapon", ET_Ignore, Param_Cell, Param_CellByRef);

	g_fwOnGetRPGSpeedModifiers = CreateGlobalForward("RPG_Perks_OnGetRPGSpeedModifiers", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef);
	g_fwOnCalculateDamage = CreateGlobalForward("RPG_Perks_OnCalculateDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);

	AutoExecConfig_SetFile("RPG-Perks");

	g_hGamemode = FindConVar("mp_gamemode");
	g_hDifficulty = FindConVar("z_difficulty");

	g_hRPGIncapPistolPriority = AutoExecConfig_CreateConVar("rpg_incap_pistol_priority", "0", "Do not blindly edit this cvar.\nSetting to an absurd number will remove incap pistol functionality\nThis is a priority from -10 to 10 indicating an order of priority to grant an incapped player their pistol when they spawn.");
	g_hInvincibleDamagePriority = AutoExecConfig_CreateConVar("rpg_invincible_damage_priority", "5", "Do not blindly edit this cvar.\nSetting to an absurd number will remove incap pistol functionality\nThis is a priority from -10 to 10 indicating an order of priority to grant an incapped player their pistol when they spawn.");

	g_hRPGPetCountForManualDirector = AutoExecConfig_CreateConVar("rpg_pet_count_for_manual_director", "4", "If pet count is this or higher, manually spawn a SI at fixed intervals");
	g_hRPGManualDirectorInterval = AutoExecConfig_CreateConVar("rpg_manual_director_interval", "25", "Number of seconds to spawn an SI if manual director is live.\nSet to 0 or lower to crash the server.");

	g_hRPGTriggerHurtMultiplier = AutoExecConfig_CreateConVar("rpg_trigger_hurt_multiplier", "10.0", "Multiplier of damage inflicted to ZOMBIES by trigger_hurt that has greater than 600 damage.\nOn rooftop finale if a charger doesn't instantly die from the trigger_hurt, bugs can easily occur.");

	g_hRPGTankHealth = AutoExecConfig_CreateConVar("rpg_z_tank_health", "4000", "Default health of the Tank");

	g_bRescueDisabled = FindConVar("sv_rescue_disabled");

	g_hTankSwingInterval = FindConVar("tank_swing_interval");
	g_hTankAttackInterval = FindConVar("z_tank_attack_interval");

	g_hPillsDecayRate = FindConVar("pain_pills_decay_rate");

	g_hKitMaxHeal = FindConVar("first_aid_kit_max_heal");

	g_hKitDuration = FindConVar("first_aid_kit_use_duration");
	g_hRPGKitDuration = AutoExecConfig_CreateConVar("rpg_first_aid_kit_use_duration", "5", "Default time for use with first aid kit.");

	g_hDefibDuration = FindConVar("defibrillator_use_duration");
	g_hRPGDefibDuration = AutoExecConfig_CreateConVar("rpg_defibrillator_use_duration", "5", "Default time for use with defibrillator.");

	g_hReviveHealth = FindConVar("survivor_revive_health");
	g_hReviveDuration = FindConVar("survivor_revive_duration");
	g_hRPGReviveDuration = AutoExecConfig_CreateConVar("rpg_survivor_revive_duration", "5", "Default time for reviving.");
	g_hRPGLedgeReviveDuration = AutoExecConfig_CreateConVar("rpg_survivor_ledge_revive_duration", "5", "Default time for reviving from a ledge.");


	g_hIncapHealth = FindConVar("survivor_incap_health");
	g_hRPGIncapHealth = AutoExecConfig_CreateConVar("rpg_survivor_incap_health", "300", "Default HP for being incapacitated");

	g_hLedgeHangHealth = FindConVar("survivor_ledge_grab_health");
	g_hRPGLedgeHangHealth = AutoExecConfig_CreateConVar("rpg_survivor_ledge_grab_health", "300", "Default HP for ledge hanging");

	g_hCriticalSpeed = FindConVar("survivor_limp_walk_speed");
	g_hLimpHealth = FindConVar("survivor_limp_health");
	g_hRPGLimpHealth = AutoExecConfig_CreateConVar("rpg_survivor_limp_health", "40", "Default HP under which you start limping");

	g_hRPGAdrenalineHealPercent = AutoExecConfig_CreateConVar("rpg_adrenaline_health_buffer", "25", "Default percent of max HP adrenaline heals for");
	g_hAdrenalineHealPercent = FindConVar("adrenaline_health_buffer");

	g_hRPGPainPillsHealPercent = AutoExecConfig_CreateConVar("rpg_pain_pills_health_value", "50", "Default percent of max HP pain pills heal for");
	g_hPainPillsHealPercent = FindConVar("pain_pills_health_value");

	g_hPainPillsHealThreshold = FindConVar("pain_pills_health_threshold");

	g_hRPGAdrenalineDuration = AutoExecConfig_CreateConVar("rpg_adrenaline_duration", "15.0", "Default time adrenaline lasts for.");
	g_hAdrenalineDuration = FindConVar("adrenaline_duration");

	g_hRPGAdrenalineRunSpeed = AutoExecConfig_CreateConVar("rpg_adrenaline_run_speed", "260", "Default Speed for Adrenaline");

	g_hStartIncapWeapon = AutoExecConfig_CreateConVar("rpg_start_incap_weapon", "0", "0 - No weapon. 1 - Pistol. 2 - Double Pistol. 3 - Magnum");

	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();

	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
	}

	int count = GetEntityCount();

	for (int i = MaxClients+1;i < count;i++)
	{
		if(!IsValidEdict(i))
			continue;

		char sClassname[64];
		GetEdictClassname(i, sClassname, sizeof(sClassname));

		OnEntityCreated(i, sClassname);
	}

	RegPluginLibrary("RPG_Perks");

	// Fixes the fact sv_glowenable is a launcher cvar that doesn't exist.
	if(FindConVar("sv_glowenable") == null)
	{
		CreateConVar("sv_glowenable", "1", "Bug fixing cvar, lets replicating disabling glow.", FCVAR_CLIENTDLL|FCVAR_REPLICATED);
	}

	RPG_Perks_RegisterReplicateCvar("sv_glowenable");
}

public void GunXP_OnReloadRPGPlugins()
{
	#if defined _GunXP_RPG_included

	if(GetFeatureStatus(FeatureType_Native, "RPG_Tanks_GetClientTank") == FeatureStatus_Available)
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(RPG_Tanks_GetClientTank(i) < 0)
				continue;

			UC_PrintToChatRoot("Didn't reload RPG-Perks.smx because a tiered tank is alive.");
			return;
		}
	}

	GunXP_ReloadPlugin();
	#endif

}

public void GunXP_RPGShop_OnResetRPG(int client)
{
	TriggerTimer(CreateTimer(0.0, Timer_CheckSpeedModifiers, _, TIMER_FLAG_NO_MAPCHANGE));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!IsValidEntityIndex(entity))
		return;

	if(StrEqual(classname, "info_survivor_position"))
	{
		SDKHook(entity, SDKHook_SpawnPost, Event_OnSpawnpointSpawnPost);
	}
	if(StrEqual(classname, "infected") || StrEqual(classname, "witch"))
	{
		SDKHook(entity, SDKHook_SpawnPost, Event_ZombieSpawnPost);
		SDKHook(entity, SDKHook_SetTransmit, SDKEvent_SetTransmit);
	}
	if(StrEqual(classname, "func_elevator"))
	{
		SDKHook(entity, SDKHook_SpawnPost, Event_ElevatorSpawnPost);
	}
}

public void Event_ElevatorSpawnPost(int entity)
{
	float fOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

	g_fLastElevatorHeight[entity] = fOrigin[2];

	CreateTimer(0.7, Timer_CalculateElevatorPosition, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Timer_CalculateElevatorPosition(Handle hTimer, int ref)
{
	int entity = EntRefToEntIndex(ref);

	if(entity == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	float fOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

	float fLastHeight = g_fLastElevatorHeight[entity];

	g_fLastElevatorHeight[entity] = fOrigin[2];

	if(FloatAbs(fLastHeight - fOrigin[2]) <= 1.1)
		return Plugin_Continue;

	else if(RPG_Perks_IsEntityTimedAttribute(entity, "Calculate Elevator Reach Floor"))
	{
		// 5.0 seconds because of Atrium doing funny stuff...
		RPG_Perks_ApplyEntityTimedAttribute(entity, "Calculate Elevator Reach Floor", 5.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
		return Plugin_Continue;
	}
	
	// 5.0 seconds because of Atrium doing funny stuff...
	RPG_Perks_ApplyEntityTimedAttribute(entity, "Calculate Elevator Reach Floor", 5.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
	FuncElevator_ReachFloor("Bruh Train", entity, entity, 0.0);

	return Plugin_Continue;
}

public void Event_ZombieSpawnPost(int entity)
{
	int maxHP = GetEntityMaxHealth(entity);

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetRPGZombieMaxHP);

		Call_PushCell(prio);
		Call_PushCell(entity);
		
		Call_PushCellRef(maxHP);

		Call_Finish();	
	}

	SetEntityMaxHealth(entity, maxHP);

	// SetEntityHealth is broken in SM against Common Infected.
	SetEntProp(entity, Prop_Data, "m_iHealth", maxHP);

	SDKHook(entity, SDKHook_TraceAttack, Event_TraceAttack);
	SDKHook(entity, SDKHook_OnTakeDamageAlive, Event_TakeDamage);
	SDKHook(entity, SDKHook_SetTransmit, SDKEvent_SetTransmit);
}

public Action SDKEvent_SetTransmit(int victim, int viewer)
{
	if(!IsPlayer(viewer))
		return Plugin_Continue;

	else if(victim == viewer)
		return Plugin_Continue;

	else if(!g_bNightmare[viewer])
		return Plugin_Continue;

	else if(L4D_GetPinnedInfected(viewer) == victim)
		return Plugin_Continue;

	return Plugin_Handled;
}

public void Event_OnSpawnpointSpawnPost(int entity)
{
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", g_fSpawnPoint);
}

public Action L4D_TankClaw_OnPlayerHit_Pre(int tank, int claw, int player)
{
	if(RPG_Perks_IsEntityTimedAttribute(player, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D2_OnPlayerFling(int client, int attacker, float vecDir[3])
{
	if(RPG_Perks_IsEntityTimedAttribute(client, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D_OnLedgeGrabbed(int client)
{
	if(RPG_Perks_IsEntityTimedAttribute(client, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D2_OnStagger(int target, int source)
{
	if(RPG_Perks_IsEntityTimedAttribute(target, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

// The survivor that is about to get stumbled as a result of "attacker" capping someone in close proximity
public Action L4D2_OnPounceOrLeapStumble(int victim, int attacker)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

// Called when someone is about to be hit by a Tank rock or lunged by a Hunter
public Action L4D_OnKnockedDown(int client, int reason)
{
	if(RPG_Perks_IsEntityTimedAttribute(client, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

// Called when a player is about to be flung probably by Charger impact.
public Action L4D2_OnThrowImpactedSurvivor(int attacker, int victim)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D_OnPouncedOnSurvivor(int victim, int attacker)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D_OnGrabWithTongue(int victim, int attacker)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D2_OnJockeyRide(int victim, int attacker)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action L4D2_OnStartCarryingVictim(int victim, int attacker)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
	{
		L4D_StaggerPlayer(attacker, attacker, {0.0, 0.0, 0.0});

		char TempFormat[128];
		FormatEx(TempFormat, sizeof(TempFormat), "GetPlayerFromUserID(%i).SetModel(GetPlayerFromUserID(%i).GetModelName())", GetClientUserId(attacker), GetClientUserId(attacker));
		L4D2_ExecVScriptCode(TempFormat);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}


public Action L4D_OnVomitedUpon(int victim, int& attacker, bool& boomerExplosion)
{
	if(RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return Plugin_Handled;

	return Plugin_Continue;
}


public void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass)
{
	if(priority != -5)
		return;
		
	else if(zclass == L4D2ZombieClass_Tank)
		return;

	else if(GetPetCount() < g_hRPGPetCountForManualDirector.IntValue)
		return;

	zclass = view_as<L4D2ZombieClassType>(GetRandomInt(1, 6));
}

// Requires RPG_Perks_RegisterReplicateCvar to fire.
public void RPG_Perks_OnGetReplicateCvarValue(int priority, int client, const char cvarName[64], char sValue[256])
{
	if(priority != 0)
		return;

	else if(!RPG_Perks_IsEntityTimedAttribute(client, "Nightmare"))
		return;

	else if(!StrEqual(cvarName, "sv_glowenable"))
		return;

	sValue = "0";
}

public void RPG_Perks_OnShouldInstantKill(int priority, int victim, int attacker, int inflictor, int damagetype, bool &bImmune)
{
	if(priority != g_hInvincibleDamagePriority.IntValue)
		return;

	else if(RPG_Perks_GetZombieType(victim) == ZombieType_Invalid)
		return;

	else if(!RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return;

	bImmune = true;
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority != g_hInvincibleDamagePriority.IntValue)
		return;

	else if(RPG_Perks_GetZombieType(victim) == ZombieType_Invalid)
		return;

	else if(!RPG_Perks_IsEntityTimedAttribute(victim, "Invincible"))
		return;

	bImmune = true;

}

public void RPG_Perks_OnTimedAttributeStart(int entity, char attributeName[64], float fDuration)
{	
	float fOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

	RPG_CalculateColorByAttributes(entity, attributeName);
	
	if(StrEqual(attributeName, "Invincible"))
	{
		RPG_Perks_ApplyEntityTimedAttribute(entity, "Invincible Rainbow Color", 0.1, COLLISION_SET, ATTRIBUTE_POSITIVE);
		return;
	}
	if(StrEqual(attributeName, "Frozen") || StrEqual(attributeName, "Stun"))
	{
		if(IsPlayer(entity))
		{
			L4D_StaggerPlayer(entity, entity, {0.0, 0.0, 0.0});

			char TempFormat[128];
			FormatEx(TempFormat, sizeof(TempFormat), "GetPlayerFromUserID(%i).SetModel(GetPlayerFromUserID(%i).GetModelName())", GetClientUserId(entity), GetClientUserId(entity));
			L4D2_ExecVScriptCode(TempFormat);
		}
	}
	if(StrEqual(attributeName, "Frozen"))
	{
		SetEntityFlags(entity, GetEntityFlags(entity) | FL_FROZEN);

		if(RPG_Perks_GetZombieType(entity) != ZombieType_CommonInfected && RPG_Perks_GetZombieType(entity) != ZombieType_Witch)
		{
			SetEntityMoveType(entity, MOVETYPE_NONE);
		}

		EmitAmbientSound("physics/glass/glass_impact_bullet4.wav", fOrigin, entity, SNDLEVEL_RAIDSIREN);

		
		
		return;
	}
	if(StrEqual(attributeName, "Nightmare"))
	{
		if(RPG_Perks_GetZombieType(entity) != ZombieType_NotInfected)
			return;

		g_bNightmare[entity] = true;

		int fog = GetEntPropEnt(entity, Prop_Data, "m_hCtrl");

		if(fog != -1)
		{
			g_refLastFog[entity] = EntIndexToEntRef(GetEntPropEnt(entity, Prop_Data, "m_hCtrl"));
		}

		return;
	}
	if(!StrEqual(attributeName, "Stun"))
		return;

	if(RPG_Perks_GetZombieType(entity) == ZombieType_CommonInfected || RPG_Perks_GetZombieType(entity) == ZombieType_Witch)
	{
		SetEntityFlags(entity, GetEntityFlags(entity) | FL_FROZEN);
	}
	else
	{
		SetEntityMoveType(entity, MOVETYPE_NONE);
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", g_fLastStunOrigin[entity]);
	}

	TE_SetupSparks(fOrigin, {0.0, 0.0, 0.0}, 5, 5);

	SetEntityRenderColor(entity, 238, 210, 2);
}

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
	if(StrEqual(attributeName, "RPG Perks Manual Director"))
	{
		RPG_Perks_ApplyEntityTimedAttribute(0, "RPG Perks Manual Director", g_hRPGManualDirectorInterval.FloatValue, COLLISION_SET, ATTRIBUTE_NEUTRAL);

		if(GetPetCount() < g_hRPGPetCountForManualDirector.IntValue)
			return;

		float fOrigin[3];
		L4D_GetRandomPZSpawnPosition(L4D_GetHighestFlowSurvivor(), view_as<int>(L4D2ZombieClass_Charger), 7, fOrigin);

		L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Charger), fOrigin, view_as<float>({0.0, 0.0, 0.0}));

		return;
	}

	Invincible_RPG_Perks_OnTimedAttributeExpired(entity, attributeName);

	// For ease of access, this is func_tracktrain's reach floor calculations.
	_RPG_Perks_OnTimedAttributeExpired(entity, attributeName);

	RPG_CalculateColorByAttributes(entity, attributeName);

	if(StrEqual(attributeName, "Frozen") || StrEqual(attributeName, "Stun"))
	{
		if(!IsPlayer(entity) && GetEntityHealth(entity) <= 0)
		{
			AcceptEntityInput(entity, "BecomeRagdoll");

			return;
		}
	}
	if(StrEqual(attributeName, "Frozen"))
	{
		SetEntityFlags(entity, GetEntityFlags(entity) & ~FL_FROZEN);

		if(RPG_Perks_GetZombieType(entity) != ZombieType_CommonInfected && RPG_Perks_GetZombieType(entity) != ZombieType_Witch)
		{
			SetEntityMoveType(entity, MOVETYPE_WALK);
		}

		return;
	}
	if(StrEqual(attributeName, "Nightmare"))
	{
		g_bNightmare[entity] = false;

		if(EntRefToEntIndex(g_refNightmareFogControl) == INVALID_ENT_REFERENCE)
			return;

		// If current fog is not nightmare fog, the game changed it for the player and we need to not reset to old, because old is gone.
		else if(GetEntPropEnt(entity, Prop_Data, "m_hCtrl") != EntRefToEntIndex(g_refNightmareFogControl))
			return;

		SetEntPropEnt(entity, Prop_Data, "m_hCtrl", EntRefToEntIndex(g_refLastFog[entity]));

		return;
	}
	if(!StrEqual(attributeName, "Stun"))
		return;

	if(RPG_Perks_GetZombieType(entity) == ZombieType_CommonInfected || RPG_Perks_GetZombieType(entity) == ZombieType_Witch)
	{
		SetEntityFlags(entity, GetEntityFlags(entity) & ~FL_FROZEN);
	}
	else
	{
		SetEntityMoveType(entity, MOVETYPE_WALK);

		TeleportEntity(entity, g_fLastStunOrigin[entity], NULL_VECTOR, NULL_VECTOR);
	}
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
	Invincible_RPG_Perks_OnTimedAttributeTransfered(oldClient, newClient, attributeName);

	RPG_CalculateColorByAttributes(newClient, attributeName);

	if(oldClient == newClient)
		return;

	if(StrEqual(attributeName, "Frozen"))
	{
		SetEntityFlags(oldClient, GetEntityFlags(oldClient) & ~FL_FROZEN);
		SetEntityFlags(newClient, GetEntityFlags(newClient) | FL_FROZEN);

		SetEntityMoveType(oldClient, MOVETYPE_WALK);
		SetEntityMoveType(newClient, MOVETYPE_NONE);

		return;
	}
	if(StrEqual(attributeName, "Nightmare"))
	{
		g_bNightmare[newClient] = true;
		g_bNightmare[oldClient] = false;

		return;
	}
	if(!StrEqual(attributeName, "Stun"))
		return;

	// Not possible to transfer to common or witch...
	SetEntityMoveType(newClient, MOVETYPE_NONE);
	SetEntityMoveType(oldClient, MOVETYPE_WALK);

	g_fLastStunOrigin[newClient] = g_fLastStunOrigin[oldClient];
}

public void RPG_CalculateColorByAttributes(int entity, char attributeName[64])
{
	if(!StrEqual(attributeName, "Stun") && !StrEqual(attributeName, "Frozen") && !StrEqual(attributeName, "Mutated") && strncmp(attributeName, "Invincible", 10) != 0)
		return;

	if(RPG_Perks_IsEntityTimedAttribute(entity, "Invincible"))
	{
		SetEntityRenderColor(entity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
		return;
	}
	else if(RPG_Perks_IsEntityTimedAttribute(entity, "Mutated"))
	{
		SetEntityRenderColor(entity, 255, 0, 0, 255);
		return;
	}
	else if(RPG_Perks_IsEntityTimedAttribute(entity, "Frozen"))
	{
		SetEntityRenderColor(entity, 0, 128, 255, 192);
		return;
	}
	else if(RPG_Perks_IsEntityTimedAttribute(entity, "Stun"))
	{
		SetEntityRenderColor(entity, 238, 210, 2, 255);
		return;
	}

	SetEntityRenderColor(entity, 255, 255, 255, 255);
}

public void Invincible_RPG_Perks_OnTimedAttributeExpired(int attributeEntity, char attributeName[64])
{
	if(StrEqual(attributeName, "Invincible Rainbow Color"))
	{
		RPG_Perks_ApplyEntityTimedAttribute(attributeEntity, "Invincible Rainbow Color", 0.1, COLLISION_SET, ATTRIBUTE_POSITIVE);
	}
	if(StrEqual(attributeName, "Invincible Music"))
	{
		int client = attributeEntity;
		
		if(!RPG_Perks_IsEntityTimedAttribute(client, "Invincible"))
			return;

		EmitInvincibleSound(client);
		RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible Music", 30.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
	}
	else if(StrEqual(attributeName, "Invincible"))
	{
		int client = attributeEntity;

		if(RPG_Perks_IsEntityTimedAttribute(client, "Invincible Music"))
		{
			RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible Music", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
			StopInvincibleSound(client);
		}
	}
}


public void Invincible_RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
	if(!StrEqual(attributeName, "Invincible Music"))
		return;

	// Infinite loop otherwise
	else if(oldClient == newClient)
	{
		StopInvincibleSound(oldClient);
		return;
	}

	StopInvincibleSound(oldClient);
	RPG_Perks_ApplyEntityTimedAttribute(newClient, "Invincible Music", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
}

stock void EmitInvincibleSound(int client)
{
	for(int i=0;i < INVINCIBLE_SOUND_MULTIPLIER;i++)
	{
		EmitSoundToClient(client, INVINCIBLE_SOUND, _, SOUND_CHANNEL, 150, _, 1.0, 103);
	}
}

stock void StopInvincibleSound(int client)
{
	for(int i=0;i < INVINCIBLE_SOUND_MULTIPLIER;i++)
	{
		StopSound(client, SOUND_CHANNEL, INVINCIBLE_SOUND);
	}
}

// Must add natives for after a player spawns for incap hidden pistol.
public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
	if(priority != g_hRPGIncapPistolPriority.IntValue)
		return;

	else if(!L4D_IsPlayerIncapacitated(client))
	{
		RPG_Perks_RecalculateMaxHP(client);

		return;
	}

	else if(L4D_IsPlayerHangingFromLedge(client))
		return;

	int index = g_hStartIncapWeapon.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapWeapon);

	Call_PushCell(client);
	Call_PushCellRef(index);

	Call_Finish();
	
	switch(index)
	{
		case 0:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);
		}
		case 1:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");

			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);

			EquipPlayerWeapon(client, weapon);
		}
		case 2:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");
			
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 1);

			EquipPlayerWeapon(client, weapon);

			SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Send, "m_iClip1") * 2);
		}
		default:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			GivePlayerItem(client, "weapon_pistol_magnum");
		}
	}
}

public Action Event_ReviveBeginPre(Event event, const char[] name, bool dontBroadcast)
{
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(reviver == 0)
		return Plugin_Continue;

	float fDuration = g_hRPGReviveDuration.FloatValue;

	if(L4D_IsPlayerHangingFromLedge(subject))
	{
		fDuration = g_hRPGLedgeReviveDuration.FloatValue;
	}

	Call_StartForward(g_fwOnGetRPGReviveDuration);

	Call_PushCell(reviver);
	Call_PushCell(subject);
	Call_PushCell(L4D_IsPlayerHangingFromLedge(subject));
	Call_PushFloatRef(fDuration);

	Call_Finish();

	g_hReviveDuration.FloatValue = fDuration;

	return Plugin_Continue;
}

public Action Event_VictimFreeFromPin(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));

	if (client == 0)
		return Plugin_Continue;

	if(RPG_Perks_IsEntityTimedAttribute(client, "Stun"))
	{
		SetEntityMoveType(client, MOVETYPE_NONE);

		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fLastStunOrigin[client]);
	}

	if(!L4D_IsPlayerIncapacitated(client))
		return Plugin_Continue;

	else if(L4D_IsPlayerHangingFromLedge(client))
		return Plugin_Continue;

	int index = g_hStartIncapWeapon.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapWeapon);

	Call_PushCell(client);
	Call_PushCellRef(index);

	Call_Finish();
	
	switch(index)
	{
		case 0:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);
		}
		case 1:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");

			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);

			EquipPlayerWeapon(client, weapon);
		}
		case 2:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");
			
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 1);

			EquipPlayerWeapon(client, weapon);

			SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Send, "m_iClip1") * 2);
		}
		default:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			GivePlayerItem(client, "weapon_pistol_magnum");
		}
	}

	return Plugin_Continue;	
}

public Action Event_RoundStart(Handle hEvent, char[] Name, bool dontBroadcast)
{
	RPG_Perks_ApplyEntityTimedAttribute(0, "RPG Perks Manual Director", g_hRPGManualDirectorInterval.FloatValue, COLLISION_SET, ATTRIBUTE_NEUTRAL);

	AcceptEntityInput(g_refNightmareFogControl, "Kill");

	g_refNightmareFogControl = INVALID_ENT_REFERENCE;

	for(int i=0;i < sizeof(g_bTeleported);i++)
	{
		g_bTeleported[i] = false;
		g_bNightmare[i] = false;
	}
	
	g_bRoundStarted = true;

	g_aLimitedAbilities.Clear();
	RPG_ClearTimedAttributes();

	return Plugin_Continue;
}

public Action Event_RoundEnd(Handle hEvent, char[] Name, bool dontBroadcast)
{
	g_aLimitedAbilities.Clear();
	RPG_ClearTimedAttributes();

	g_bRoundStarted = false;

	return Plugin_Continue;
}


public Action Event_PlayerFirstSpawn(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return Plugin_Continue;

	DataPack DP = CreateDataPack();

	WritePackCell(DP, GetEventInt(hEvent, "userid"));
	WritePackCell(DP, true);
	
	RequestFrame(Event_PlayerSpawnFrame, DP);

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	RPG_ClearTimedAttributes(client);

	return Plugin_Continue;
}
public Action Event_PlayerSpawn(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	DataPack DP = CreateDataPack();

	WritePackCell(DP, GetEventInt(hEvent, "userid"));

	if(!g_bRoundStarted)
		WritePackCell(DP, true);

	else
		WritePackCell(DP, false);
	
	RequestFrame(Event_PlayerSpawnFrame, DP);

	return Plugin_Continue;
}

public Action Event_TankKilled(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	else if(L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
		return Plugin_Continue;

	dontBroadcast = true;
	return Plugin_Handled;
}

public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	g_iHurtCount++;

	if(g_iHurtCount > 200)
	{
		g_iHurtCount = 0;

		char classname[64];
		int attackerent = GetEventInt(hEvent, "attackerentid");
		GetEdictClassname(attackerent, classname, sizeof(classname));

		LogError("EYAL282!!! Found 200 hurt quickly!!!\nClient: %i, attacker classname: %s", client, classname);
	}
	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	else if(L4D_GetClientTeam(client) == L4DTeam_Survivor)
	{
		if(L4D_IsPlayerIncapacitated(client))
		{
			if(!L4D_IsPlayerHangingFromLedge(client))
			{
				g_iTemporaryHealth[client] = 0;
			}
			
			return Plugin_Continue;
		}
		if(g_iTemporaryHealth[client] <= 200)
			return Plugin_Continue;

		else if(GetEntityHealth(client) != 1)
		{
			// Bog fix...
			SetClientTemporaryHP(client, g_iTemporaryHealth[client]);
			return Plugin_Continue;
		}

		int hpLost = GetEventInt(hEvent, "dmg_health");
		
		SetClientTemporaryHP(client, g_iTemporaryHealth[client] - hpLost);

		return Plugin_Continue;
	}
	else if(GetEntityHealth(client) <= 0)
		return Plugin_Continue;

	else if(g_iHealth[client] <= 65535)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(client) != L4DTeam_Infected)
		return Plugin_Continue;

	int hpLost = 65535 - GetEntityHealth(client);

	g_iHealth[client] -= hpLost;

	if(g_iHealth[client] <= 65535)
	{
		SetEntityHealth(client, g_iHealth[client]);
		g_iHealth[client] = -1;
	}
	else
	{
		SetEntityHealth(client, 65535);
	}

	return Plugin_Continue;
}

public void Event_PlayerSpawnFrame(DataPack DP)
{
	RequestFrame(Event_PlayerSpawnTwoFrames, DP);
}
public void Event_PlayerSpawnTwoFrames(DataPack DP)
{
	RequestFrame(Event_PlayerSpawnThreeFrames, DP);
}

public void Event_PlayerSpawnThreeFrames(DataPack DP)
{
	ResetPack(DP);

	int userid = ReadPackCell(DP);

	bool bFirstSpawn = ReadPackCell(DP);

	CloseHandle(DP);
	
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return;

	else if(g_bTeleported[client])
	{
		bFirstSpawn = false;
	}

	TryCreateNightmareFogEntity();

	g_iHealth[client] = -1;
	g_iMaxHealth[client] = -1;

	if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
	{
		// Fake clients cannot be ghosts, and make sure he didn't materialize.
		if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Infected || (GetGameTime() - g_fMaterializedTimestamp[client] <= 0.05 && !IsFakeClient(client)))
			return;

		// While we're not materialzing, tanks have an annoying bug involving an instant double spawn.
		g_fMaterializedTimestamp[client] = GetGameTime();

		L4D2ZombieClassType zclass = L4D2_GetPlayerZombieClass(client);

		L4D2ZombieClassType originalZClass = zclass;

		for(int prio=-10;prio <= 10;prio++)
		{
			Call_StartForward(g_fwOnGetRPGSpecialInfectedClass);

			Call_PushCell(prio);
			Call_PushCell(client);
			
			Call_PushCellRef(zclass);

			Call_Finish();	
		}

		if(originalZClass != zclass)
		{
			int weapon;
			while ((weapon = GetPlayerWeaponSlot(client, 0)) != -1)
			{
				RemovePlayerItem(client, weapon);
				RemoveEdict(weapon);
			}

			L4D2_SetPlayerZombieClass(client, zclass);
			L4D_SetClass(client, view_as<int>(zclass));

			if(IsFakeClient(client))	
				SetClientName(client, g_sBossNames[view_as<int>(zclass)]);
		}

		int maxHP = RPG_Perks_GetClientHealth(client);

		if(L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
		{
			maxHP = g_hRPGTankHealth.IntValue;

			if(maxHP > 65535)
			{
				g_iHealth[client] = maxHP;
				g_iMaxHealth[client] = maxHP;

				SetEntityMaxHealth(client, 65535);
				SetEntityHealth(client, 65535);
			}
			else
			{
				g_iHealth[client] = -1;
				g_iMaxHealth[client] = maxHP;
				SetEntityMaxHealth(client, maxHP);
				SetEntityHealth(client, maxHP);
			}
		}


		for(int prio=-10;prio <= 10;prio++)
		{
			Call_StartForward(g_fwOnGetRPGZombieMaxHP);

			Call_PushCell(prio);
			Call_PushCell(client);
			
			Call_PushCellRef(maxHP);

			Call_Finish();	
		}

		if(maxHP > 65535)
		{
			g_iHealth[client] = maxHP;
			g_iMaxHealth[client] = maxHP;

			SetEntityMaxHealth(client, 65535);
			SetEntityHealth(client, 65535);
		}
		else
		{
			g_iHealth[client] = -1;
			g_iMaxHealth[client] = maxHP;

			SetEntityMaxHealth(client, maxHP);
			SetEntityHealth(client, maxHP);
		}

		Call_StartForward(g_fwOnRPGZombiePlayerSpawned);

		Call_PushCell(client);

		Call_Finish();

		return;
	}

	else if(!IsPlayerAlive(client) && bFirstSpawn)
	{
		L4D_RespawnPlayer(client);
	}

	int maxHP = 100;
	
	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetRPGMaxHP);

		Call_PushCell(prio);
		Call_PushCell(client);
		
		Call_PushCellRef(maxHP);

		Call_Finish();	
	}

	if(maxHP <= 0)
		maxHP = 100;

	SetEntityMaxHealth(client, maxHP);

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnRPGPlayerSpawned);

		Call_PushCell(prio);
		Call_PushCell(client);

		Call_PushCell(bFirstSpawn);

		Call_Finish();	
	}

	if(bFirstSpawn)
	{
		if(IsPlayerSpawnStuck(client))
		{
			TeleportToStartArea(client);
		}

		ExecuteFullHeal(client);

		L4D_SetPlayerTempHealth(client, 0);
	}
}

public void TryCreateNightmareFogEntity()
{
	int fog = EntRefToEntIndex(g_refNightmareFogControl);

	if(fog != INVALID_ENT_REFERENCE)
		return;

	int entity = CreateEntityByName("env_fog_controller");

	if(IsValidEntity(entity))
	{	
		DispatchKeyValue(entity, "fogenable", "1"); 	
		DispatchKeyValue(entity, "spawnflags", "1"); 
		DispatchKeyValue(entity, "fogmaxdensity", "1"); 
		DispatchKeyValue(entity, "fogstart", "0");
		DispatchKeyValue(entity, "fogend", "256");
		DispatchKeyValue(entity, "farz", "8192");
		DispatchKeyValue(entity, "fogcolor", "32 32 32"); 
		DispatchKeyValue(entity, "foglerptime", "0.0"); 
		
		DispatchSpawn(entity);				
		ActivateEntity(entity);

		AcceptEntityInput(entity, "TurnOn");
	}
	else
	{
		entity = INVALID_ENT_REFERENCE;
	}

	g_refNightmareFogControl = EntIndexToEntRef(entity);
}

public Action Event_PlayerIncapStartPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	// Tanks get incapacitated on death.
	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return Plugin_Continue;

	int health = g_hRPGIncapHealth.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapHealth);

	Call_PushCell(client);
	Call_PushCell(false);
	Call_PushCellRef(health);

	Call_Finish();

	g_hIncapHealth.IntValue = health;

	if(g_hRPGIncapPistolPriority.IntValue > 10 || g_hRPGIncapPistolPriority.IntValue < -10)
		return Plugin_Continue;

	int weapon = GetPlayerWeaponSlot(client, 1);
	
	if(weapon != -1)
	{
		GetEdictClassname(weapon, g_sLastSecondaryClassname[client], sizeof(g_sLastSecondaryClassname[]));

		g_iLastSecondaryClip[client] = GetEntProp(weapon, Prop_Send, "m_iClip1");
		
		if(HasEntProp(weapon, Prop_Send, "m_isDualWielding"))
			g_bLastSecondaryDual[client] = view_as<bool>(GetEntProp(weapon, Prop_Send, "m_isDualWielding"));

		else
			g_bLastSecondaryDual[client] = false;
	}
	else
	{
		g_sLastSecondaryClassname[client][0] = EOS;	
		g_iLastSecondaryClip[client] = 0;
		g_bLastSecondaryDual[client] = false;
	}

	// To prevent incap damage reduce issues.
	SetEntityMaxHealth(client, 100);

	return Plugin_Continue;
}


public Action Event_BotReplacesAPlayer(Handle event, const char[] name, bool dontBroadcast)
{
	int oldPlayer = GetClientOfUserId(GetEventInt(event, "player"));
	int newPlayer = GetClientOfUserId(GetEventInt(event, "bot"));

	g_iAbsLastLimpHealth[newPlayer] = -1;
	g_iLastTemporaryHealth[newPlayer] = 0;
	g_iLastPermanentHealth[newPlayer] = 0;
	g_bTeleported[newPlayer] = g_bTeleported[oldPlayer];

	SetEntPropEnt(newPlayer, Prop_Data, "m_hCtrl", oldPlayer);
	
	int entity = -1;

	while((entity = FindEntityByClassname(entity, "trigger_multiple")) != -1)
	{
		g_iIsTouching[newPlayer][entity] = g_iIsTouching[oldPlayer][entity];
	}

	TransferTimedAttributes(oldPlayer, newPlayer); 

	ClearReplicateCvarsLastValues(oldPlayer, true);
	ClearReplicateCvarsLastValues(newPlayer);
	
	CheckClientSpeedModifiers(newPlayer);

	if(!L4D_IsPlayerIncapacitated(newPlayer))
	{
		int health = GetEntityHealth(newPlayer);

		RPG_Perks_RecalculateMaxHP(oldPlayer);

		SetEntityMaxHealth(newPlayer, GetEntityMaxHealth(oldPlayer));
		SetEntityHealth(newPlayer, health);

		RPG_Perks_RecalculateMaxHP(newPlayer);
	}

	DataPack DP = CreateDataPack();

	WritePackCell(DP, GetClientUserId(newPlayer));
	WritePackCell(DP, false);
	
	RequestFrame(Event_PlayerSpawnFrame, DP);

	return Plugin_Continue;
}

public Action Event_PlayerReplacesABot(Handle event, const char[] name, bool dontBroadcast)
{
	int oldPlayer = GetClientOfUserId(GetEventInt(event, "bot"));
	int newPlayer = GetClientOfUserId(GetEventInt(event, "player"));

	g_iAbsLastLimpHealth[newPlayer] = -1;
	g_sLastSecondaryClassname[newPlayer][0] = EOS;
	g_iLastSecondaryClip[newPlayer] = 0;
	g_bLastSecondaryDual[newPlayer] = false;

	g_iLastTemporaryHealth[newPlayer] = 0;
	g_iLastPermanentHealth[newPlayer] = 0;
	g_bTeleported[newPlayer] = g_bTeleported[oldPlayer];

	SetEntPropEnt(newPlayer, Prop_Data, "m_hCtrl", oldPlayer);

	int entity = -1;

	while((entity = FindEntityByClassname(entity, "trigger_multiple")) != -1)
	{
		g_iIsTouching[newPlayer][entity] = g_iIsTouching[oldPlayer][entity];
	}

	TransferTimedAttributes(oldPlayer, newPlayer); 

	ClearReplicateCvarsLastValues(oldPlayer, true);
	ClearReplicateCvarsLastValues(newPlayer);
	
	CheckClientSpeedModifiers(newPlayer);

	if(!L4D_IsPlayerIncapacitated(newPlayer))
	{
		int health = GetEntityHealth(newPlayer);

		RPG_Perks_RecalculateMaxHP(oldPlayer);

		SetEntityMaxHealth(newPlayer, GetEntityMaxHealth(oldPlayer));
		SetEntityHealth(newPlayer, health);

		RPG_Perks_RecalculateMaxHP(newPlayer);
	}

	DataPack DP = CreateDataPack();

	WritePackCell(DP, GetClientUserId(newPlayer));
	WritePackCell(DP, false);
	
	RequestFrame(Event_PlayerSpawnFrame, DP);

	return Plugin_Continue;
}

stock void ClearReplicateCvarsLastValues(int client, bool bReset = false)
{
	int size = g_aReplicateCvars.Length;

	char sKey[16];
	IntToString(GetClientUserId(client), sKey, sizeof(sKey));

	for(int i=0;i < size;i++)
	{
		enReplicateCvar repCvar;

		g_aReplicateCvars.GetArray(i, repCvar);
		
		StringMap map = repCvar.smLastValues;

		map.SetString(sKey, "RPG_Perks_Null");

		if(bReset)
		{
			ConVar cvar = FindConVar(repCvar.cvarName);

			if(cvar != null)
			{
				char sValue[256];

				cvar.GetString(sValue, sizeof(sValue));

				RPG_SendConVarValue(client, cvar, sValue);
			}
		}
	}	
}

// This is to allow editing the array in g_fwOnTimedAttributeTransfered
enum struct enFireList
{
	int oldPlayer;
	int newPlayer;
	char attributeName[64];
}

public void TransferTimedAttributes(int oldPlayer, int newPlayer)
{
	ArrayList aFireList = CreateArray(sizeof(enFireList));

	int size = g_aTimedAttributes.Length;

	for(int i=0;i < size;i++)
	{
		enTimedAttribute attribute;
		g_aTimedAttributes.GetArray(i, attribute);

		if(attribute.entity == oldPlayer && attribute.transferRules == TRANSFER_NORMAL)
		{
			attribute.entity = newPlayer;
			g_aTimedAttributes.SetArray(i, attribute);	


			enFireList fireList;
			fireList.oldPlayer = oldPlayer;
			fireList.newPlayer = newPlayer;
			fireList.attributeName = attribute.attributeName;

			aFireList.PushArray(fireList);
		}
		if(attribute.entity == newPlayer && attribute.transferRules == TRANSFER_REVERT)
		{
			attribute.entity = oldPlayer;
			g_aTimedAttributes.SetArray(i, attribute);	

			enFireList fireList;
			fireList.oldPlayer = newPlayer;
			fireList.newPlayer = oldPlayer;
			fireList.attributeName = attribute.attributeName;
		}
	}

	size = aFireList.Length;

	for(int i=0;i < size;i++)
	{
		enFireList fireList;
		aFireList.GetArray(i, fireList);

		Call_StartForward(g_fwOnTimedAttributeTransfered);

		Call_PushCell(fireList.oldPlayer);
		Call_PushCell(fireList.newPlayer);
		Call_PushString(fireList.attributeName);

		Call_Finish();
	}

	delete aFireList;
}

public Action Event_HealBegin(Event event, const char[] name, bool dontBroadcast)
{
	int healed = GetClientOfUserId(GetEventInt(event, "subject"));

	g_iLastTemporaryHealth[healed] = RPG_Perks_GetClientTempHealth(healed);
	g_iLastPermanentHealth[healed] = GetEntityHealth(healed);

	return Plugin_Continue;
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int healed = GetClientOfUserId(GetEventInt(event, "subject"));

	if(client == 0)
		return Plugin_Continue;

	int percentToHeal = 0;

	Call_StartForward(g_fwOnGetRPGKitHealPercent);

	Call_PushCell(client);
	Call_PushCell(healed);

	Call_PushCellRef(percentToHeal);

	Call_Finish();

	if(percentToHeal <= 0)
	{
		// No infinite HP from 32767 first_aid_kit_max_heal ( to enable using it at all times )
		GunXP_GiveClientHealth(healed, 0, 0);
		return Plugin_Continue;
	}

	SetEntityHealth(healed, 0);

	GunXP_GiveClientHealth(healed, g_iLastPermanentHealth[healed] + RoundToFloor(GetEntityMaxHealth(healed) * (float(percentToHeal) / 100.0)), g_iLastTemporaryHealth[healed]);

	return Plugin_Continue;
}

public Action Event_AdrenalineUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	int percentToHeal = g_hRPGAdrenalineHealPercent.IntValue;

	Call_StartForward(g_fwOnGetRPGMedsHealPercent);

	Call_PushCell(client);
	Call_PushCell(true);
	Call_PushCellRef(percentToHeal);

	Call_Finish();

	if(percentToHeal > 0)
	{
		GunXP_GiveClientHealth(client, 0, RoundToFloor(GetEntityMaxHealth(client) * (float(percentToHeal) / 100)));
	}

	float fDuration = g_hRPGAdrenalineDuration.FloatValue;

	Call_StartForward(g_fwOnGetRPGAdrenalineDuration);

	Call_PushCell(client);
	Call_PushFloatRef(fDuration);

	Call_Finish();

	Terror_SetAdrenalineTime(client, fDuration);

	return Plugin_Continue;
}


public Action Event_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	int percentToHeal = g_hRPGPainPillsHealPercent.IntValue;

	Call_StartForward(g_fwOnGetRPGMedsHealPercent);

	Call_PushCell(client);
	Call_PushCell(false);
	Call_PushCellRef(percentToHeal);

	Call_Finish();

	if(percentToHeal > 0)
	{
		GunXP_GiveClientHealth(client, 0, RoundToFloor(GetEntityMaxHealth(client) * (float(percentToHeal) / 100)));
	}

	return Plugin_Continue;
}

public Action Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int revived = GetClientOfUserId(event.GetInt("subject"));

	if(revived == 0)
		return Plugin_Continue;

	// Even on ledge hang, must set new max HP because we reset to 100 to avoid damage bug.
	RecalculateMaxHP(revived, true);

	if(GetEventBool(event, "ledge_hang"))
		return Plugin_Continue;

	int temporaryHealthPercent = 0;
	int permanentHealthPercent = 0;

	Call_StartForward(g_fwOnGetRPGReviveHealthPercent);

	Call_PushCell(client);
	Call_PushCell(revived);

	Call_PushCellRef(temporaryHealthPercent);
	Call_PushCellRef(permanentHealthPercent);

	Call_Finish();

	if(temporaryHealthPercent < 0)
		temporaryHealthPercent = 0;

	if(permanentHealthPercent < 0)
		permanentHealthPercent = 0;

	if(temporaryHealthPercent == 0 && permanentHealthPercent == 0)
	{
		return Plugin_Continue;
	}


	SetEntityHealth(revived, 0);
	L4D_SetPlayerTempHealth(revived, 0);
	g_iTemporaryHealth[revived] = 0;

	int tempHP = RoundToFloor(GetEntityMaxHealth(revived) * (float(temporaryHealthPercent) / 100.0));
	int permHP = RoundToFloor(GetEntityMaxHealth(revived) * (float(permanentHealthPercent) / 100.0));

	if(tempHP <= 0)
	{
		tempHP = g_hReviveHealth.IntValue;
	}

	if(permHP <= 0)
	{
		permHP = 1;
		tempHP -= 1;
	}

	GunXP_GiveClientHealth(revived, permHP, tempHP);
	
	RPG_Perks_SetClientTempHealth(revived, RPG_Perks_GetClientTempHealth(revived));

	int weapon = GetPlayerWeaponSlot(revived, 1);

	if(g_sLastSecondaryClassname[revived][0] != EOS)
	{
		if(weapon != -1)
		{
			RemovePlayerItem(revived, weapon);
		}

		int newWeapon = GivePlayerItem(revived, g_sLastSecondaryClassname[revived]);

		if(newWeapon != -1)
		{
			SetEntProp(newWeapon, Prop_Send, "m_iClip1", g_iLastSecondaryClip[revived]);

			if(g_bLastSecondaryDual[revived])
			{
				SetEntProp(newWeapon, Prop_Send, "m_isDualWielding", 0);
				SDKHooks_DropWeapon(revived, newWeapon);
				SetEntProp(newWeapon, Prop_Send, "m_isDualWielding", 1);

				EquipPlayerWeapon(revived, newWeapon);

				// We already restore ammo.
				//SetEntProp(newWeapon, Prop_Send, "m_iClip1", GetEntProp(newWeapon, Prop_Send, "m_iClip1") * 2);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_DefibUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int revived = GetClientOfUserId(event.GetInt("subject"));

	if(revived == 0)
		return Plugin_Continue;

	int temporaryHealthPercent = 0;
	int permanentHealthPercent = 0;

	Call_StartForward(g_fwOnGetRPGDefibHealthPercent);

	Call_PushCell(client);
	Call_PushCell(revived);

	Call_PushCellRef(temporaryHealthPercent);
	Call_PushCellRef(permanentHealthPercent);

	Call_Finish();

	int maxHP = 100;
	
	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetRPGMaxHP);

		Call_PushCell(prio);
		Call_PushCell(revived);
		
		Call_PushCellRef(maxHP);

		Call_Finish();	
	}

	if(maxHP <= 0)
		maxHP = 100;

	SetEntityMaxHealth(revived, maxHP);

	if(temporaryHealthPercent == 0 && permanentHealthPercent == 0)
	{
		permanentHealthPercent = 50;
	}
	if(temporaryHealthPercent < 0)
		temporaryHealthPercent = 0;

	if(permanentHealthPercent < 0)
		permanentHealthPercent = 0;

	SetEntityHealth(revived, 0);
	L4D_SetPlayerTempHealth(revived, 0);
	g_iTemporaryHealth[revived] = 0;

	GunXP_GiveClientHealth(revived, RoundToFloor(GetEntityMaxHealth(revived) * (float(permanentHealthPercent) / 100.0)), RoundToFloor(GetEntityMaxHealth(revived) * (float(temporaryHealthPercent) / 100.0)));

	if(GetEntityHealth(revived) == 0)
	{
		SetEntityHealth(revived, 1);
		GunXP_GiveClientHealth(revived, 0, -1);
	}
	
	return Plugin_Continue;
}



public Action Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	// Fastest reviver in the west
	if(!L4D_IsPlayerIncapacitated(client))
		return Plugin_Continue;

	// Tanks get incapacitated on death.
	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return Plugin_Continue;

	else if(g_hRPGIncapPistolPriority.IntValue > 10 || g_hRPGIncapPistolPriority.IntValue < -10)
		return Plugin_Continue;

	int index = g_hStartIncapWeapon.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapWeapon);

	Call_PushCell(client);
	Call_PushCellRef(index);

	Call_Finish();
	
	switch(index)
	{
		case 0:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);
		}
		case 1:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");

			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);

			EquipPlayerWeapon(client, weapon);
		}
		case 2:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");
			
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 1);

			EquipPlayerWeapon(client, weapon);

			SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Send, "m_iClip1") * 2);
		}
		default:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			GivePlayerItem(client, "weapon_pistol_magnum");
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerLedgeGrabPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	int health = g_hRPGLedgeHangHealth.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapHealth);

	Call_PushCell(client);
	Call_PushCell(true);
	Call_PushCellRef(health);

	Call_Finish();

	g_hLedgeHangHealth.IntValue = health;

	return Plugin_Continue;
}

public void TriggerMultiple_StartTouch(const char[] output, int caller, int activator, float delay)
{
	int touchCount, fakeCount, teamCount;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		Call_StartForward(g_fwOnShouldIgnoreEntireTeamTouch);

		Call_PushCell(i);

		Action rtn;
		Call_Finish(rtn);

		if(rtn >= Plugin_Handled)
		{
			g_iIsTouching[i][caller] = 2;
		}
	}

	if(g_iIsTouching[activator][caller] != 2)
	{
		g_iIsTouching[activator][caller] = 1;
	}

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(GetEntProp(caller, Prop_Data, "m_iEntireTeam") != GetClientTeam(i))
			continue;

		teamCount++;

		if(g_iIsTouching[i][caller] == 1)
			touchCount++;

		else if(g_iIsTouching[i][caller] == 2)
			fakeCount++;
	}

	// Normal entire team, let the game do its logic.
	if(fakeCount == 0)
		return;

	if(touchCount + fakeCount == teamCount)
	{
		FireEntityOutput(caller, "OnEntireTeamStartTouch");
	}
}

public void TriggerMultiple_EndTouch(const char[] output, int caller, int activator, float delay)
{
	int touchCount, fakeCount, teamCount;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(GetEntProp(caller, Prop_Data, "m_iEntireTeam") != GetClientTeam(i))
			continue;

		teamCount++;

		if(g_iIsTouching[i][caller] == 1)
			touchCount++;

		else if(g_iIsTouching[i][caller] == 2)
			fakeCount++;
	}

	// Normal entire team, let the game do its logic.
	if(fakeCount == 0)
	{
		g_iIsTouching[activator][caller] = 0;
		return;
	}

	if(touchCount + fakeCount == teamCount)
	{
		FireEntityOutput(caller, "OnEntireTeamEndTouch");
	}

	if(g_iIsTouching[activator][caller] != 2)
	{
		g_iIsTouching[activator][caller] = 0;
	}
}

public void FuncElevator_CalculateReachFloor(const char[] output, int caller, int activator, float delay)
{
	RPG_Perks_ApplyEntityTimedAttribute(caller, "Calculate Train Reach Floor", 0.2, COLLISION_SET, ATTRIBUTE_NEUTRAL);
}

// Variation of RPG_Perks_OnTimedAttributeExpired for ease of access.
public void _RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
	if(StrEqual(attributeName, "Calculate Train Reach Floor"))
	{
		FuncElevator_ReachFloor("Bruh Train", entity, entity, 0.0);
	}
}

public void FuncElevator_ReachFloor(const char[] output, int caller, int activator, float delay)
{
	bool bAny;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(RPG_GetLiteralGroundEntity(i, caller) != caller)
			continue;

		bAny = true;
	}

	if(!bAny)
		return;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		int pet = -1;
		
		if(GetFeatureStatus(FeatureType_Native, "L4D2_Pets_GetCarrier") == FeatureStatus_Available)
		{
			pet = L4D2_Pets_GetCarrier(i);
		}

		float fOrigin[3];
		GetEntPropVector(caller, Prop_Data, "m_vecAbsOrigin", fOrigin);

		if(pet != -1)
		{
			TeleportEntity(pet, fOrigin, NULL_VECTOR, NULL_VECTOR);
		}

		pet = L4D_GetPinnedInfected(i);

		if(pet != 0)
		{
			TeleportEntity(pet, fOrigin, NULL_VECTOR, NULL_VECTOR);
		}

		TeleportEntity(i, fOrigin, NULL_VECTOR, NULL_VECTOR);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, Event_TraceAttack);
	SDKHook(client, SDKHook_OnTakeDamageAlive, Event_TakeDamage);
	SDKHook(client, SDKHook_SetTransmit, SDKEvent_SetTransmit);
	SDKHook(client, SDKHook_PostThinkPost, SDKEvent_Think);
	AnimHookEnable(client, INVALID_FUNCTION, OnTankStartSwingPost);

}


public void SDKEvent_Think(int client)
{
	if(!g_bNightmare[client])
		return;

	int nightmareFog = EntRefToEntIndex(g_refNightmareFogControl);

	// Note the fact we break here instead of continue.
	if(nightmareFog == INVALID_ENT_REFERENCE)
		return;

	int curFogRef = INVALID_ENT_REFERENCE;
	int curFog = GetEntPropEnt(client, Prop_Data, "m_hCtrl");

	if(curFog != INVALID_ENT_REFERENCE)
		EntIndexToEntRef(curFog);

	if(curFogRef != g_refLastFog[client] && curFogRef != g_refNightmareFogControl)
		g_refLastFog[client] = curFogRef;

	if(curFogRef != nightmareFog)
	{
		SetEntPropEnt(client, Prop_Data, "m_hCtrl", nightmareFog);
	}
}
public Action OnTankStartSwingPost(int client, int &sequence)
{
	// 0 Clue how the other two got here...
	//if(sequence != PLAYERANIMEVENT_PRIMARY_ATTACK && sequence != PLAYERANIMEVENT_HEAL_OTHER && sequence != PLAYERANIMEVENT_CROUCH_HEAL_INCAPACITATED_ABOVE)
	//	return Plugin_Continue;

	if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return Plugin_Continue;

	int weapon = L4D_GetPlayerCurrentWeapon(client);

	if(weapon == -1)
		return Plugin_Continue;
		
	else if(GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") - GetGameTime() <= g_hTankSwingInterval.FloatValue)
		return Plugin_Continue;

	float fDelay = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") - GetGameTime() - g_hTankSwingInterval.FloatValue;
	CreateTimer(fDelay, Timer_CheckTankSwing, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action Timer_CheckTankSwing(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client == 0)
		return Plugin_Continue;

	int weapon = L4D_GetPlayerCurrentWeapon(client);
	
	if(weapon == -1)
		return Plugin_Continue;

	else if(RPG_Perks_IsEntityTimedAttribute(client, "Punch Cooldown Live"))
		return Plugin_Continue;

	float fOriginalDelay = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") - GetGameTime();

	float fDelay = fOriginalDelay;

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetTankSwingSpeed);

		Call_PushCell(prio);
		Call_PushCell(client);
		
		Call_PushFloatRef(fDelay);

		Call_Finish();	
	}

	if(fDelay == fOriginalDelay)
		return Plugin_Continue;

	if(fDelay <= 0.1)
		fDelay = 0.1;

	RPG_Perks_ApplyEntityTimedAttribute(client, "Punch Cooldown Live", fDelay, COLLISION_SET, ATTRIBUTE_NEUTRAL);

	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + fDelay);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + fDelay);

	SetEntPropFloat(client, Prop_Data, "m_flNextAttack", GetGameTime() + fDelay);
	SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", GetGameTime() + fDelay);

	int iAttackTimer = FindSendPropInfo("CTankClaw", "m_attackTimer");
	SetEntData(weapon, iAttackTimer + 4, GetGameTime() + fDelay);
	SetEntData(weapon, iAttackTimer + 8, GetGameTime() + fDelay);


	iAttackTimer = FindSendPropInfo("CTankClaw", "m_swingTimer");
	SetEntData(weapon, iAttackTimer + 4, GetGameTime() + fDelay);
	SetEntData(weapon, iAttackTimer + 8, GetGameTime() + fDelay);

	iAttackTimer = FindSendPropInfo("CTankClaw", "m_lowAttackDurationTimer");
	SetEntData(weapon, iAttackTimer + 4, GetGameTime() + fDelay);
	SetEntData(weapon, iAttackTimer + 8, GetGameTime() + fDelay);


	return Plugin_Continue;
}

// I suspect fall damage is fully ignored in these functions.
public Action Event_TakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{		
	if(RPG_Perks_GetZombieType(victim) == ZombieType_Invalid)
		return Plugin_Continue;

	else if(damage == 0.0)
		return Plugin_Continue;

	else if(!SurvivorVictimNextBotAttacker(victim, attacker) && !(damagetype & DMG_BURN) && !(damagetype & DMG_FALL) && !(damagetype & DMG_DROWNRECOVER) && !IsDamageToSelf(victim, attacker) && !IsPinDamage(victim, attacker))
		return Plugin_Continue;


	float fFinalDamage = damage;

	Action rtn = RPG_OnTraceAttack(victim, attacker, inflictor, fFinalDamage, damagetype, 0, 0);

	damage = fFinalDamage;

	return rtn;
	
}

// Trace Attack does not trigger with common on survivor violence. ACCOUNT FOR IT.
public Action Event_TraceAttack(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{	
	if(RPG_Perks_GetZombieType(victim) == ZombieType_Invalid)
		return Plugin_Continue;

	else if(damage == 0.0)
		return Plugin_Continue;

	else if(SurvivorVictimNextBotAttacker(victim, attacker) || damagetype & DMG_BURN || damagetype & DMG_FALL || damagetype & DMG_DROWNRECOVER || IsDamageToSelf(victim, attacker) || IsPinDamage(victim, attacker))
		return Plugin_Continue;

	float fFinalDamage = damage;

	Action rtn = RPG_OnTraceAttack(victim, attacker, inflictor, fFinalDamage, damagetype, hitbox, hitgroup);

	damage = fFinalDamage;

	// Only on trace attack
	if(rtn == Plugin_Continue)
		rtn = Plugin_Changed;

	return rtn;
}

public Action RPG_OnTraceAttack(int victim, int &attacker, int inflictor, float& damage, int damagetype, int hitbox, int hitgroup)
{
	bool bDontInterruptActions;
	bool bDontStagger;
	bool bDontInstakill;
	bool bImmune;

	if(IsPlayer(victim) && damage >= 600.0 && (damagetype & DMG_DROWN || damagetype & DMG_FALL || IsDamageToSelf(victim, attacker)))
	{
		damage = damage * g_hRPGTriggerHurtMultiplier.FloatValue;
	}

	char sClass[64];
	GetEdictClassname(inflictor, sClass, sizeof(sClass));

	if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank && damagetype & DMG_BURN && StrEqual(sClass, "entityflame", false))
	{
		damage = CalculateTankBurnDamage(victim);
	}

	
	for(int i=-10;i <= 10;i++)
	{
		Call_StartForward(g_fwOnCalculateDamage);

		Call_PushCell(i);
		Call_PushCell(victim);
		Call_PushCell(attacker);
		Call_PushCell(inflictor);
		Call_PushFloatRef(damage);
		Call_PushCell(damagetype);
		Call_PushCell(hitbox);
		Call_PushCell(hitgroup);
		Call_PushCellRef(bDontInterruptActions);
		Call_PushCellRef(bDontStagger);
		Call_PushCellRef(bDontInstakill);
		Call_PushCellRef(bImmune);

		Call_Finish();

		if(damage < 0.0)
			damage = 0.0;
	}
	
	if(IsPlayer(attacker) && !IsPlayer(victim))
	{
		// Commons are allergic to logic. At least bDontInstaKill doesn't break explosive ammo nor does it break hit animations.
		bDontInstakill = true;

	}

	if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank && damagetype & DMG_BURN && StrEqual(sClass, "entityflame", false))
	{
		// To award tank burner.
		bDontStagger = true;
	}

	if(IsPlayer(attacker) && L4D_GetClientTeam(attacker) == L4DTeam_Infected)
	{
		int owner = GetEntPropEnt(attacker, Prop_Send, "m_hOwnerEntity");

		if(owner != -1 && owner != victim)
			attacker = owner;
	}
	if(bImmune)
	{
		damage = 0.0;
		return Plugin_Stop;
	}
	if(IsPlayer(victim) && damage >= 600.0 && (damagetype & DMG_DROWN || damagetype & DMG_FALL))
	{
		// trigger_hurt is capped to 5000...
		bDontInstakill = true;
	}

	// If a player is standing, let the tank interrupt actions or the tank punch fling animation won't play.
	if(RPG_Perks_GetZombieType(victim) == ZombieType_NotInfected && RPG_Perks_GetZombieType(attacker) == ZombieType_Tank && !L4D_IsPlayerIncapacitated(victim))
		bDontInterruptActions = false;

	if(IsPlayer(attacker) && IsPlayer(victim) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
		bDontInterruptActions = false;

	// This is because witch for some reason absorbs damage modifiers.
	if(!IsPlayer(victim))
	{
		char sClassname[64];
		GetEdictClassname(victim, sClassname, sizeof(sClassname));

		if(StrEqual(sClassname, "witch"))
			bDontInstakill = true;
	}

	char filename[512], class[64];
	GetEdictClassname(victim, class, sizeof(class));

	Format(filename, sizeof(filename), "RPG_OnTraceAttack: %s - %i - %s - %.1f - noinsta: %i nostagger: %i dontinter: %i", filename, victim, class, damage, damagetype, bDontInstakill, bDontStagger, bDontInterruptActions);
	LogToFile("eyal_crash_detector.txt", filename);

	if(damage == 0.0)
		return Plugin_Stop;

	else if(!IsPlayer(victim))
	{
		if(damage > float(GetEntityHealth(victim)) && GetEntityFlags(victim) & FL_FROZEN)
		{
			RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
			RPG_Perks_ApplyEntityTimedAttribute(victim, "Frozen", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
		}
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;
	}

	// Time to die / incap
	else if(damage >= float(GetEntityHealth(victim) + L4D_GetPlayerTempHealth(victim)))
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	// Let fall damage insta kill.
	else if(attacker == victim || attacker == 0)
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	if(L4D_GetClientTeam(victim) == L4DTeam_Survivor)
	{
		if(!bDontInterruptActions)
			return bDontInstakill ? Plugin_Changed : Plugin_Continue;

		//SDKHooks_TakeDamage(victim, victim, attacker, damage, damagetype, 0, NULL_VECTOR, NULL_VECTOR, true);

		if(damage < float(GetEntityHealth(victim)))
		{
			SetEntityHealth(victim, GetEntityHealth(victim) - RoundToFloor(damage));
		}
		else
		{

			// Above is already a detection if damage exceeds the player's entire health, no need to check.
			L4D_SetPlayerTempHealth(victim, L4D_GetPlayerTempHealth(victim) - RoundToFloor(damage));

			SetEntityHealth(victim, 1);
		}
		
		MakeDelayedPlayerHurtEvent(victim, attacker, inflictor, damage, damagetype);
		
		return Plugin_Stop;
	}
	else if(L4D_GetClientTeam(victim) == L4DTeam_Infected)
	{
		if(!bDontStagger)
		{
			return bDontInstakill ? Plugin_Changed : Plugin_Continue;
		}

		SetEntityHealth(victim, GetEntityHealth(victim) - RoundFloat(damage));
		
		MakeDelayedPlayerHurtEvent(victim, attacker, inflictor, damage, damagetype);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

// Hopefully will prevent crashes..
public void MakeDelayedPlayerHurtEvent(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	Handle DP = CreateDataPack();

	WritePackCell(DP, victim);
	WritePackCell(DP, attacker);
	WritePackCell(DP, inflictor);
	WritePackFloat(DP, damage);
	WritePackCell(DP, damagetype);

	RequestFrame(Frame_FirePlayerHurtEvent, DP);
}

public void Frame_FirePlayerHurtEvent(Handle DP)
{
	ResetPack(DP);

	int victim = ReadPackCell(DP);
	int attacker = ReadPackCell(DP);
	int inflictor = ReadPackCell(DP);
	float damage = ReadPackFloat(DP);
	int damagetype = ReadPackCell(DP);

	CloseHandle(DP);

	if(IsPlayer(victim) && !IsClientInGame(victim))
		return;

	else if(RPG_Perks_GetZombieType(victim) == ZombieType_Invalid)
		return;
		
	Event hNewEvent = CreateEvent("player_hurt", true);

	SetEventInt(hNewEvent, "userid", GetClientUserId(victim));

	if(IsPlayer(attacker) && IsClientInGame(attacker))
	{
		SetEventInt(hNewEvent, "attacker", GetClientUserId(attacker));
	}
	else
	{
		SetEventInt(hNewEvent, "attacker", 0);
	}

	if(inflictor != 0 && !IsPlayer(inflictor) && IsValidEdict(inflictor))
	{

		char sWeaponName[64];
		GetEdictClassname(inflictor, sWeaponName, sizeof(sWeaponName));

		ReplaceStringEx(sWeaponName, sizeof(sWeaponName), "weapon_", "");

		SetEventString(hNewEvent, "weapon", sWeaponName);
	}
	else if(inflictor == attacker && IsPlayer(attacker))
	{
		int weapon = L4D_GetPlayerCurrentWeapon(attacker);

		if(weapon != -1)
		{
			
			char sWeaponName[64];
			GetEdictClassname(weapon, sWeaponName, sizeof(sWeaponName));

			ReplaceStringEx(sWeaponName, sizeof(sWeaponName), "weapon_", "");

			SetEventString(hNewEvent, "weapon", sWeaponName);
		}
	}

	SetEventInt(hNewEvent, "attackerentid", attacker);
	SetEventInt(hNewEvent, "health", GetEntityHealth(victim));
	SetEventInt(hNewEvent, "dmg_health", RoundFloat(damage));
	SetEventInt(hNewEvent, "dmg_armor", 0);
	SetEventInt(hNewEvent, "hitgroup", 0);
	SetEventInt(hNewEvent, "type", damagetype);

	FireEvent(hNewEvent);
}

public Action L4D2_BackpackItem_StartAction(int client, int entity, any type)
{
	switch(type)
	{
		case L4D2WeaponId_FirstAidKit:
		{
			float fDuration = g_hRPGKitDuration.FloatValue;

			int target = 0;

			Call_StartForward(g_fwOnGetRPGKitDuration);

			Call_PushCell(client);
			Call_PushCell(target);
			Call_PushFloatRef(fDuration);

			Call_Finish();

			g_hKitDuration.FloatValue = fDuration;
		}

		case L4D2WeaponId_Defibrillator:
		{
			float fDuration = g_hRPGDefibDuration.FloatValue;

			int target = 0;

			Call_StartForward(g_fwOnGetRPGDefibDuration);

			Call_PushCell(client);
			Call_PushCell(target);
			Call_PushFloatRef(fDuration);

			Call_Finish();

			g_hDefibDuration.FloatValue = fDuration;
		}
	}


	return Plugin_Continue;
}

public void L4D2_BackpackItem_StartAction_Post(int client, int entity, any type)
{
	switch(type)
	{
		case L4D2WeaponId_FirstAidKit:
		{
			g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
		}

		case L4D2WeaponId_Defibrillator:
		{
			g_hDefibDuration.FloatValue = g_hRPGDefibDuration.FloatValue;
		}
	}
}

public void L4D_OnMaterializeFromGhost(int client)
{
	g_fMaterializedTimestamp[client] = GetGameTime();
}

public void L4D_OnEnterGhostState(int client)
{
	if(IsFakeClient(client))
		return;

	RequestFrame(Frame_GhostState, GetClientUserId(client));
}

public void Frame_GhostState(int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return;

	L4D2ZombieClassType zclass = L4D2_GetPlayerZombieClass(client);

	L4D2ZombieClassType originalZClass = zclass;

	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetRPGSpecialInfectedClass);

		Call_PushCell(prio);
		Call_PushCell(client);
		
		Call_PushCellRef(zclass);

		Call_Finish();	
	}

	if(originalZClass != zclass)
	{
		int weapon;
		while ((weapon = GetPlayerWeaponSlot(client, 0)) != -1)
		{
			RemovePlayerItem(client, weapon);
			RemoveEdict(weapon);
		}
		
		L4D_SetClass(client, view_as<int>(zclass));
		L4D2_SetPlayerZombieClass(client, zclass);
	}

	int maxHP = RPG_Perks_GetClientHealth(client);

	if(L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
	{
		maxHP = g_hRPGTankHealth.IntValue;

		if(maxHP > 65535)
		{
			g_iHealth[client] = maxHP;
			g_iMaxHealth[client] = maxHP;

			SetEntityMaxHealth(client, 65535);
			SetEntityHealth(client, 65535);
		}
		else
		{
			g_iHealth[client] = -1;
			g_iMaxHealth[client] = maxHP;

			SetEntityMaxHealth(client, maxHP);
			SetEntityHealth(client, maxHP);
		}
	}


	for(int prio=-10;prio <= 10;prio++)
	{
		Call_StartForward(g_fwOnGetRPGZombieMaxHP);

		Call_PushCell(prio);
		Call_PushCell(client);
		
		Call_PushCellRef(maxHP);

		Call_Finish();	
	}

	if(maxHP > 65535)
	{
		g_iHealth[client] = maxHP;
		g_iMaxHealth[client] = maxHP;

		SetEntityMaxHealth(client, 65535);
		SetEntityHealth(client, 65535);
	}
	else
	{
		g_iHealth[client] = -1;
		g_iMaxHealth[client] = maxHP;
		
		SetEntityMaxHealth(client, maxHP);
		SetEntityHealth(client, maxHP);
	}

	Call_StartForward(g_fwOnRPGZombiePlayerSpawned);

	Call_PushCell(client);

	Call_Finish();

	return;
}

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Survivor) return Plugin_Continue;
	
	switch(GetMostRestrictiveSpeed(client, SPEEDSTATE_RUN))
	{
		case SPEEDSTATE_NULL: return Plugin_Continue;
		case SPEEDSTATE_RUN: retVal = g_fAbsRunSpeed[client];
		case SPEEDSTATE_WALK: retVal = g_fAbsWalkSpeed[client];
		case SPEEDSTATE_CROUCH: retVal = g_fAbsCrouchSpeed[client];
		case SPEEDSTATE_LIMP: retVal = g_fAbsLimpSpeed[client];
		case SPEEDSTATE_CRITICAL: retVal = g_fAbsCriticalSpeed[client];
		case SPEEDSTATE_WATER: retVal = g_fAbsWaterSpeed[client];
		case SPEEDSTATE_ADRENALINE: retVal = g_fAbsAdrenalineSpeed[client];
		case SPEEDSTATE_SCOPE: retVal = g_fAbsScopeSpeed[client];
	}

	if(retVal > MAX_SPEED)
		retVal = MAX_SPEED;

	else if(retVal < MIN_SPEED)
		retVal = MIN_SPEED;


	return Plugin_Handled;
}

public Action L4D_OnGetWalkTopSpeed(int client, float &retVal)
{
	if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Survivor) return Plugin_Continue;
		
	switch(GetMostRestrictiveSpeed(client, SPEEDSTATE_WALK))
	{
		case SPEEDSTATE_NULL: return Plugin_Continue;
		case SPEEDSTATE_RUN: retVal = g_fAbsRunSpeed[client];
		case SPEEDSTATE_WALK: retVal = g_fAbsWalkSpeed[client];
		case SPEEDSTATE_CROUCH: retVal = g_fAbsCrouchSpeed[client];
		case SPEEDSTATE_LIMP: retVal = g_fAbsLimpSpeed[client];
		case SPEEDSTATE_CRITICAL: retVal = g_fAbsCriticalSpeed[client];
		case SPEEDSTATE_WATER: retVal = g_fAbsWaterSpeed[client];
		case SPEEDSTATE_SCOPE: retVal = g_fAbsScopeSpeed[client];
		case SPEEDSTATE_CUSTOM: retVal = g_fAbsCustomSpeed[client];
	}	

	// Let the client walk instead of zooming forward while walking.
	if(retVal > g_fAbsWalkSpeed[client])
		retVal = g_fAbsWalkSpeed[client];
		
	if(retVal > MAX_SPEED)
		retVal = MAX_SPEED;

	else if(retVal < MIN_SPEED)
		retVal = MIN_SPEED;

	return Plugin_Handled;
}	

public Action L4D_OnGetCrouchTopSpeed(int client, float &retVal)
{
	if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Survivor) return Plugin_Continue;
	
	switch(GetMostRestrictiveSpeed(client, SPEEDSTATE_CROUCH))
	{
		case SPEEDSTATE_NULL: return Plugin_Continue;
		case SPEEDSTATE_RUN: retVal = g_fAbsRunSpeed[client];
		case SPEEDSTATE_WALK: retVal = g_fAbsWalkSpeed[client];
		case SPEEDSTATE_CROUCH: retVal = g_fAbsCrouchSpeed[client];
		case SPEEDSTATE_LIMP: retVal = g_fAbsLimpSpeed[client];
		case SPEEDSTATE_CRITICAL: retVal = g_fAbsCriticalSpeed[client];
		case SPEEDSTATE_WATER: retVal = g_fAbsWaterSpeed[client];
		case SPEEDSTATE_SCOPE: retVal = g_fAbsScopeSpeed[client];
		case SPEEDSTATE_CUSTOM: retVal = g_fAbsCustomSpeed[client];
	}

	// Let the client crouch instead of zooming forward while crouching.
	if(retVal > g_fAbsCrouchSpeed[client])
		retVal = g_fAbsCrouchSpeed[client];

	if(retVal > MAX_SPEED)
		retVal = MAX_SPEED;

	else if(retVal < MIN_SPEED)
		retVal = MIN_SPEED;

	return Plugin_Handled;
}


/**
 * Checks all the status of the client to decide what condition is the most restrictive to apply to the survivor
 * in the case is under adrenaline effect it will do the oposite and will apply the fastest speed possible based on logic
 * it works assuming that injuries, water or exhaustion will only decrease movement speed, if they are set faster than normal speeds they won't boost players
 */
int GetMostRestrictiveSpeed(int client, int speedType)	// speedType -> speed of the survivor that depends of what the player is doing
{
	// Ignore dead or incap players to avoid innecesary function calls
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated") )
		return SPEEDSTATE_NULL;

	if(g_iOverrideSpeedState[client] != SPEEDSTATE_NULL)
	{
		return g_iOverrideSpeedState[client];
	}
	bool bAdrenaline = view_as<bool>(GetEntProp(client, Prop_Send, "m_bAdrenalineActive"));
	bool bScoped = GetEntPropEnt(client, Prop_Send, "m_hZoomOwner") != -1;
	int result;
	float fSpeed;
	switch( speedType )
	{
		case SPEEDSTATE_RUN:
		{
			// if the client is scoping, first of all try to check if scoping is slower than running (it should...)
			if( bScoped && g_fAbsScopeSpeed[client] < g_fAbsRunSpeed[client] )
			{
				fSpeed = g_fAbsScopeSpeed[client];
				result = SPEEDSTATE_SCOPE;
			}
			else
			{
				fSpeed = g_fAbsRunSpeed[client];
				result = SPEEDSTATE_RUN;
			}
			/** 
			 * In case the adrenaline is on, it will try to get the fastest available speed (should be adrenaline)
			 * unless survivor is using sniper scope, where it will use the slower option (scope or the adrenaline speed)
			 * in other words overrides water/exhaustion/injuries speed penalty
			 */
			if( bAdrenaline )
			{
				// Survivor is running so it should apply adrenaline if faster
				if( result == SPEEDSTATE_RUN && g_fAbsAdrenalineSpeed[client] >= fSpeed )
				{
					// No need to check anything more
					return SPEEDSTATE_ADRENALINE;
				}
				return result;
			}
		}
		
		case SPEEDSTATE_WALK:
		{
			if( bScoped && g_fAbsScopeSpeed[client] < g_fAbsWalkSpeed[client] )
			{
				fSpeed = g_fAbsScopeSpeed[client];
				result = SPEEDSTATE_SCOPE;
			}
			else
			{
				fSpeed = g_fAbsWalkSpeed[client];
				result = SPEEDSTATE_WALK;
			}
			// On walking/crouching adrenaline speed won't be applied, only ignore everything after this
			if( bAdrenaline )
				return result;
		}
		
		case SPEEDSTATE_CROUCH:
		{
			fSpeed = g_fAbsCrouchSpeed[client];
			if( bScoped && g_fAbsScopeSpeed[client] < fSpeed )
			{
				fSpeed = g_fAbsScopeSpeed[client];
				result = SPEEDSTATE_SCOPE;
			}
			else
			{
				fSpeed = g_fAbsCrouchSpeed[client];
				result = SPEEDSTATE_CROUCH;
			}
			if( bAdrenaline )
				return result;
		}
	}
	
	// Start restrictions 
	if( GetEntityFlags(client) & FL_INWATER && g_fAbsWaterSpeed[client] < fSpeed ) // Survivor is on water
	{
		fSpeed = g_fAbsWaterSpeed[client];
		result = SPEEDSTATE_WATER;
	}
	int limping = GetLimping(client);

	if( limping == SPEEDSTATE_CRITICAL && g_fAbsCriticalSpeed[client] < fSpeed )
		return SPEEDSTATE_CRITICAL;
		
	if( limping == SPEEDSTATE_LIMP && g_fAbsLimpSpeed[client] < fSpeed )
		return SPEEDSTATE_LIMP;
		
	return result;
}

/**
 * This determines if the survivor has reached the limp situation (by default absolute health is under 40)
 * This function never must be called under adrenaline because it doesn't check this situation
 * Avoid calls under adrenaline or you will get false results
 */
int GetLimping(int client)
{
	int iAbsHealth = GetEntityHealth(client) + L4D_GetPlayerTempHealth(client);

	if(iAbsHealth >= 1 && iAbsHealth < g_iAbsLimpHealth[client])
	{
		if( iAbsHealth == 1 && GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0) return SPEEDSTATE_CRITICAL;
			
		else return SPEEDSTATE_LIMP;
	}
	else return SPEEDSTATE_RUN;
}

stock int GetClosestPlayerToAim(int client)
{
	float fOrigin[3], fAngles[3], fFwd[3];

	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);

	GetAngleVectors(fAngles, fFwd, NULL_VECTOR, NULL_VECTOR);

	int winner = 0;
	float winnerProduct = 1.0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(client == i)
			continue;

		else if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(GetClientTeam(i) != GetClientTeam(client))
			continue;

		else if(!ArePlayersInLOS(client, i))
			continue;

		float fTargetOrigin[3];
		GetClientEyePosition(i, fTargetOrigin);

		float fSubOrigin[3];

		SubtractVectors(fOrigin, fTargetOrigin, fSubOrigin);

		NormalizeVector(fSubOrigin, fSubOrigin);

		float fDotProduct = GetVectorDotProduct(fFwd, fSubOrigin);

		if(winnerProduct > fDotProduct)
		{
			winnerProduct = fDotProduct;
			winner = i;
		}
	}

	if(winner == 0)
	{
		return 0;
	}

	return winner;
}

stock bool ArePlayersInLOS(int client1, int client2)
{
	float vecMin[3], vecMax[3], vecOriginClient1[3], vecOriginClient2[3];

	GetClientMins(client1, vecMin);
	GetClientMaxs(client1, vecMax);

	GetClientAbsOrigin(client1, vecOriginClient1);
	GetClientAbsOrigin(client2, vecOriginClient2);

	TR_TraceHullFilter(vecOriginClient1, vecOriginClient2, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);

	return !TR_DidHit();
}

public bool TraceRayDontHitPlayers(int entityhit, int mask)
{
	return (entityhit > MaxClients || entityhit == 0);
}



stock bool IsPlayerSpawnStuck(int client, const float Origin[3] = NULL_VECTOR, float HeightOffset = 0.0)
{
	if(!GameRules_GetProp("m_bInIntro") && ClosestSpawnPointDistance(client) > 256.0)
		return true;

	float vecMin[3], vecMax[3], vecOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	if (UC_IsNullVector(Origin))
	{
		GetClientAbsOrigin(client, vecOrigin);

		vecOrigin[2] += HeightOffset;
	}
	else
	{
		vecOrigin = Origin;

		vecOrigin[2] += HeightOffset;
	}

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);
	return TR_DidHit();
}

stock bool UC_IsNullVector(const float Vector[3])
{
	return (Vector[0] == NULL_VECTOR[0] && Vector[0] == NULL_VECTOR[1] && Vector[2] == NULL_VECTOR[2]);
}

stock float ClosestSpawnPointDistance(int client)
{
	float winnerDist = 9999999.0;

	float fOrigin[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

	if(GetVectorDistance(fOrigin, g_fSpawnPoint) < winnerDist)
		winnerDist = GetVectorDistance(fOrigin, g_fSpawnPoint);

	return winnerDist;
}

stock void SetClientTemporaryHP(int client, int hp)
{
	g_iTemporaryHealth[client] = hp;

	if(hp <= 200)
	{
		L4D_SetPlayerTempHealth(client, hp);
	}
	else
	{
		L4D_SetPlayerTempHealth(client, 200);

		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() + (float(hp - 200)) / g_hPillsDecayRate.FloatValue + 1.0 / g_hPillsDecayRate.FloatValue);
	}
}

stock int GetClientTemporaryHP(int client)
{
	if(g_iTemporaryHealth[client] <= 200)
	{
		return L4D_GetPlayerTempHealth(client);
	}
	else
	{
		return RoundToFloor((GetEntPropFloat(client, Prop_Send, "m_healthBufferTime") * g_hPillsDecayRate.FloatValue) - (GetGameTime() * g_hPillsDecayRate.FloatValue) + 200);
	}
}


stock bool SurvivorVictimNextBotAttacker(int victim, int attacker)
{
	if(RPG_Perks_GetZombieType(victim) == ZombieType_NotInfected && (RPG_Perks_GetZombieType(attacker) == ZombieType_CommonInfected || RPG_Perks_GetZombieType(attacker) == ZombieType_Witch))
		return true;

	return false;
}

stock bool IsDamageToSelf(int victim, int attacker)
{
	if(victim == attacker)
		return true;

	else if(attacker == 0)
		return true;

	char sClassname[64];
	if(attacker != 0)
		GetEdictClassname(attacker, sClassname, sizeof(sClassname));

	if(strncmp(sClassname, "trigger_hurt", 12) == 0 || strncmp(sClassname, "point_hurt", 10) == 0)
	{
		return true;
	}

	return false;
}


stock bool IsPinDamage(int victim, int attacker)
{
	if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
		return false;

	else if(!IsPlayer(attacker))
		return false;

	else if(L4D_GetPinnedInfected(victim) != attacker)
		return false;

	return true;
}

stock float CalculateTankBurnDamage(int victim)
{

	char sGamemode[64], sDifficulty[64];
	GetConVarString(g_hGamemode, sGamemode, sizeof(sGamemode));
	GetConVarString(g_hDifficulty, sDifficulty, sizeof(sDifficulty));
	
	float burnDuration = 0.0;

	if(StrEqual(sGamemode, "versus", false) || StrEqual(sGamemode, "survival", false))
	{
		burnDuration = GetConVarFloat(FindConVar(("tank_burn_duration")));
	}
	else
	{
		if(StrEqual(sDifficulty, "Impossible", false))
		{
			burnDuration = GetConVarFloat(FindConVar(("tank_burn_duration_expert")));
		}
		else if(StrEqual(sDifficulty, "Hard", false))
		{
			burnDuration = GetConVarFloat(FindConVar(("tank_burn_duration_hard")));
		}
		else
		{
			burnDuration = GetConVarFloat(FindConVar(("tank_burn_duration")));
		}
	}

	float burnLeft = (float(GetEntityHealth(victim)) / float(GetEntityMaxHealth(victim))) * burnDuration;

	// Tanks take fire damage five times per second.
	burnLeft -= 0.2;

	float damageNeeded = float(GetEntityHealth(victim)) - ((burnLeft / burnDuration) * float(GetEntityMaxHealth(victim)));

	return damageNeeded;
}

stock int RPG_GetPlayerUsingATarget(int victim)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		if(L4D_GetPlayerUseTarget(i) == victim)
			return i;
	}

	return -1;
}

stock void RPG_SendConVarValue(int client, ConVar cvar, char[] sValue)
{
	if(IsFakeClient(client))
	{
		char sCvarName[256];
		cvar.GetName(sCvarName, sizeof(sCvarName));

		SetFakeClientConVar(client, sCvarName, sValue);
	}
	else
	{
		char sCvarName[256];
		cvar.GetName(sCvarName, sizeof(sCvarName));

		SendConVarValue(client, cvar, sValue);
	}
}

// Like m_hGroundEntity but if you're in the air, gets the same ground entity.
stock int RPG_GetLiteralGroundEntity(int client, int potentialEntity)
{
	float fOrigin[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

	TR_TraceRayFilter(fOrigin, ANGLE_STRAIGHT_DOWN, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_HitTarget, potentialEntity);

	if(TR_DidHit() && TR_GetEntityIndex() == potentialEntity)
		return potentialEntity;

	return -1;
}

#if !defined _GunXP_RPG_included
public bool TraceFilter_HitTarget(int entity, int contentsMask, int target)
{
	if (entity == target)
		return true;

	return false;
}
#endif
stock void TeleportToStartArea(int client)
{	
	ArrayList aAreas = CreateArray(1);
	L4D_GetAllNavAreas(aAreas);

	Address winnerArea = Address_Null;
	float fWinnerFlow;

	for(int i=0;i < aAreas.Length;i++)
	{
		float fFlow = L4D2Direct_GetTerrorNavAreaFlow(aAreas.Get(i));

		if(fFlow < 0.0)
			continue;

		if(winnerArea == Address_Null || fWinnerFlow > fFlow)
		{
			fWinnerFlow = fFlow;
			winnerArea = aAreas.Get(i);
		}
	}

	CloseHandle(aAreas);

	float fOrigin[3];
	L4D_FindRandomSpot(view_as<int>(winnerArea), fOrigin);

	TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);

	g_bTeleported[client] = true;
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}

stock void RPG_ClearTimedAttributes(int entity = 0)
{
	g_bMidClearAttributes = true;

	// Can't declare size because the size changes over time.
	for(int i=0;i < g_aTimedAttributes.Length;i++)
	{
		enTimedAttribute attribute;
		g_aTimedAttributes.GetArray(i, attribute);

		if(entity == 0 || attribute.entity == entity)
		{
			g_aTimedAttributes.Erase(i);
			i--;
			
			if(IsPlayer(entity) && !IsClientInGame(entity))
				continue;
			
			else if(!IsValidEdict(entity))
				continue;

			Call_StartForward(g_fwOnTimedAttributeExpired);

			Call_PushCell(attribute.entity);
			Call_PushString(attribute.attributeName);

			Call_Finish();
		}
	}

	g_bMidClearAttributes = false;
}

stock int GetPetCount()
{
	int count = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Infected)
			continue;

		int owner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");

		if(owner == -1)
			continue;

		else if(RPG_Perks_GetZombieType(owner) != ZombieType_NotInfected)
			continue;

		count++;
	}

	return count;
}