
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name        = "Psychic Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Psychic Tank that uses mind power to strike survivors.",
	version     = PLUGIN_VERSION,
	url         = ""
};

ConVar g_hReflectDamagePriority;

int strongerTankIndex;
int tankIndex;
int weakerTankIndex;

int strongerPsychicPowersIndex;
int psychicPowersIndex;
int weakerPsychicPowersIndex;

float g_fLastHeight[MAXPLAYERS+1];
float g_fEndDamageReflect[MAXPLAYERS+1];
bool g_bNightmare[MAXPLAYERS+1];
int g_iBulletRelease[MAXPLAYERS+1];


public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "RPG_Tanks"))
	{
		RegisterTank();
	}
}

public void OnConfigsExecuted()
{
	RegisterTank();

}

public void OnPluginEnd()
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		SetEntityGravity(i, 1.0);
	}
}
public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	AutoExecConfig_SetFile("GunXP-PsychicTank.cfg");

	g_hReflectDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgtanks_reflect_damage_priority", "-10", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin interacts with unbuffed damage, so it must go first");

	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();

	RegisterTank();

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		Event_ZombieSpawnPost(i);
	}
}

public void OnMapStart()
{
	for(int i=0;i < sizeof(g_fEndDamageReflect);i++)
	{
		g_fEndDamageReflect[i] = 0.0;
		g_bNightmare[i] = false;
		g_iBulletRelease[i] = 0;
	}
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void OnClientPutInServer(int client)
{
	Event_ZombieSpawnPost(client);
}


public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(victim == 0)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0)
		return Plugin_Continue;

	// Also checks if dead.
	else if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(attacker) != ZombieType_Tank)
		return Plugin_Continue;

	else if(RPG_Tanks_GetClientTank(attacker) != strongerTankIndex)
		return Plugin_Continue;

	char sWeaponName[32];
	GetEventString(hEvent, "weapon", sWeaponName, sizeof(sWeaponName));

	if(StrEqual(sWeaponName, "tank_rock"))
	{
		// If you don't check if InstantKill succeeded you're getting infinite looped and plugin crash...
		if(!RPG_Perks_InstantKill(victim, attacker, attacker, DMG_CRIT))
			return Plugin_Continue;

		ClientCommand(victim, "player/neck_snap_01.wav");

		PrintToChatAll("%N was instantly killed by the Tank's Rock", victim);
	}
	else if(StrEqual(sWeaponName, "tank_claw") && RPG_Perks_IsEntityTimedAttribute(victim, "Nightmare"))
	{
		// If you don't check if InstantKill succeeded you're getting infinite looped and plugin crash...
		if(!RPG_Perks_InstantKill(victim, attacker, attacker, DMG_CRIT))
			return Plugin_Continue;

		ClientCommand(victim, "player/neck_snap_01.wav");

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
				continue;

			RPG_Perks_ApplyEntityTimedAttribute(i, "Nightmare", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
		}

		PrintToChatAll("%N was instantly killed by the Tank during Nightmare", victim);
		PrintToChatAll("The Nightmare has faded");
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!IsValidEntityIndex(entity))
        return;

	if(StrEqual(classname, "infected") || StrEqual(classname, "witch"))
	{
		SDKHook(entity, SDKHook_SpawnPost, Event_ZombieSpawnPost);
	}	
}


public void RPG_Perks_OnTimedAttributeStart(int entity, char attributeName[64], float fDuration)
{
	if(!StrEqual(attributeName, "Nightmare"))
		return;

	else if(RPG_Perks_GetZombieType(entity) != ZombieType_NotInfected)
		return;

	g_bNightmare[entity] = true;
}

// Last Clear bad attributes.
float g_fLastClear[MAXPLAYERS+1];

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
	if(strncmp(attributeName, "Psychokinesis Height Check", 26, false) == 0)
	{
		// Player cleared this attribute with Special Medkit
		if(g_fLastClear[entity] == GetGameTime())
		{
			SetEntityGravity(entity, 1.0);
			return;
		}

		float fOrigin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

		if(g_fLastHeight[entity] == fOrigin[2])
		{
			float fDuration = StringToFloat(attributeName[26]);

			SetEntityGravity(entity, 1.0);

			RPG_Perks_ApplyEntityTimedAttribute(entity, "Stun", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

			return;
		}

		g_fLastHeight[entity] = fOrigin[2];
		SetEntityGravity(entity, -0.5);

		RPG_Perks_ApplyEntityTimedAttribute(entity, attributeName, 0.2, COLLISION_SET, ATTRIBUTE_NEGATIVE);

		return;
	}
	if(!StrEqual(attributeName, "Nightmare"))
		return;


	g_bNightmare[entity] = false;
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
	if(strncmp(attributeName, "Psychokinesis Height Check", 26, false) == 0)
	{
		if(oldClient == newClient)
		{
			SetEntityGravity(newClient, 1.0);
			g_fLastClear[newClient] = GetGameTime();
			return;
		}

		float fOrigin[3];
		GetEntPropVector(newClient, Prop_Data, "m_vecAbsOrigin", fOrigin);

		g_fLastHeight[newClient] = fOrigin[2];
		SetEntityGravity(newClient, -0.5);
		SetEntityGravity(oldClient, 1.0);
		TeleportEntity(newClient, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 285.0 }));
		return;
	}
	if(!StrEqual(attributeName, "Nightmare"))
		return;

	else if(oldClient == newClient)
		return;

	g_bNightmare[newClient] = true;
	g_bNightmare[oldClient] = false;
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
	if(RPG_Tanks_GetClientTank(client) != tankIndex && RPG_Tanks_GetClientTank(client) != weakerTankIndex && RPG_Tanks_GetClientTank(client) != strongerTankIndex)
		return;

	if(abilityIndex != psychicPowersIndex && abilityIndex != weakerPsychicPowersIndex && abilityIndex != strongerPsychicPowersIndex)
		return;

	int minRNG = 0;

	if(float(RPG_Perks_GetClientHealth(client)) / float(RPG_Perks_GetClientMaxHealth(client)) >= 0.9)
		minRNG = 1;

	float fMinRatio = 0.15;

	if(RPG_Tanks_GetClientTank(client) == tankIndex)
		fMinRatio = 0.3;

	if(float(RPG_Perks_GetClientHealth(client)) / float(RPG_Perks_GetClientMaxHealth(client)) <= fMinRatio)
	{
		CastBulletRelease(client);

		return;
	}

	switch(GetRandomInt(minRNG, 3))
	{
		case 0:	CastBulletRelease(client);
		case 1: CastPsychoKinesis(client);
		case 2:	CastNightmare(client);
		case 3: CastDamageReflect(client);
	}	
}

public void CastBulletRelease(int client)
{
	float interval = 0.5;
	int duration = 4;

	if(RPG_Tanks_GetClientTank(client) == tankIndex)
		duration = 7;

	else if(RPG_Tanks_GetClientTank(client) == strongerTankIndex)
		duration = 10;

	g_iBulletRelease[client] = 1 + RoundFloat(duration * (1.0 / interval));

	TriggerTimer(CreateTimer(interval, Timer_BulletRelease, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));

	PrintToChatAll("Bullet Release is active for %i seconds, hide from the tank!!!", duration);
}

public Action Timer_BulletRelease(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return Plugin_Stop;

	else if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return Plugin_Stop;
	
	else if(RPG_Tanks_GetClientTank(client) == TANK_TIER_UNTIERED || RPG_Tanks_GetClientTank(client) == TANK_TIER_UNKNOWN)
		return Plugin_Stop;

	else if(g_iBulletRelease[client] <= 0)
		return Plugin_Stop;

	
	float fOrigin[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		if(!IsFakeClient(i))
			ClientCommand(i, "play )weapons/awp/gunfire/awp1.wav");

		if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		float fSurvivorOrigin[3];
		GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", fSurvivorOrigin);
		
		TR_TraceRayFilter(fOrigin, fSurvivorOrigin, MASK_PLAYERSOLID, RayType_EndPoint, TraceRayDontHitTarget, client);

		if(!TR_DidHit())
			continue;

		else if(TR_GetEntityIndex() != i)
			continue;
		
		float ratio = 1.0 - (float(RPG_Perks_GetClientHealth(client)) / float(RPG_Perks_GetClientMaxHealth(client)));

		float damage = ratio * RPG_Perks_GetClientMaxHealth(i);

		RPG_Perks_TakeDamage(i, client, client, damage, DMG_BULLET|DMG_DROWNRECOVER);
	}

	g_iBulletRelease[client]--;

	return Plugin_Continue;
	
}


public void CastPsychoKinesis(int client)
{
	int survivor = FindRandomSurvivorWithoutStatus(client);

	if(survivor == -1)
		return;

	PrintToChatAll("%N is hit with Psycho Kinesis.", survivor);

	float fOrigin[3];
	GetEntPropVector(survivor, Prop_Data, "m_vecAbsOrigin", fOrigin);

	g_fLastHeight[survivor] = fOrigin[2];
	SetEntityGravity(survivor, -0.5);
	TeleportEntity(survivor, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 285.0 }));
	
	float fDuration = 12.0;

	if(RPG_Tanks_GetClientTank(client) == strongerTankIndex)
		fDuration = 15.0;

	char attributeName[64];
	FormatEx(attributeName, sizeof(attributeName), "Psychokinesis Height Check%i", RoundFloat(fDuration));

	RPG_Perks_ApplyEntityTimedAttribute(survivor, attributeName, 0.2, COLLISION_SET, ATTRIBUTE_NEGATIVE);
}

public Action RocketLiftoff(Handle hTimer, int UserId)
{
	int client = GetClientOfUserId(UserId);

	if (client == 0)
		return Plugin_Stop;

	

	return Plugin_Stop;
}

stock void TeleportToCeiling(int client)
{
	float vecMin[3], vecMax[3], vecOrigin[3], vecFakeOrigin[3];
    
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
    
	GetClientAbsOrigin(client, vecOrigin);
	vecFakeOrigin = vecOrigin;
	
	vecFakeOrigin[2] = 999999.0;
    
	TR_TraceHullFilter(vecOrigin, vecFakeOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);
	
	TR_GetEndPosition(vecOrigin);
	
	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);
}

public bool TraceRayDontHitPlayers(int entityhit, int mask) 
{
    return (entityhit>MaxClients || entityhit == 0);
}

public bool TraceRayDontHitTarget(int entityhit, int mask, int target) 
{
    return (entityhit != target);
}

public void CastNightmare(int client)
{
	int survivor1 = FindRandomSurvivorWithoutStatus(client);

	if(survivor1 == -1)
		return;

	float fDuration = 12.0;

	if(RPG_Tanks_GetClientTank(client) == tankIndex)
		fDuration = 20.0;

	else if(RPG_Tanks_GetClientTank(client) == strongerTankIndex)
	{
		fDuration = 10.0;

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			// Technically unused because the tank can never be survivor but still...
			else if(client == i)
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
				continue;

			RPG_Perks_ApplyEntityTimedAttribute(i, "Nightmare", 10.0, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
		}

		PrintToChatAll("All survivors are under nightmare for %.0f seconds. They are blind and take 2x damage from all sources", fDuration);
		PrintToChatAll("If the Tank hits a survivor, he will instantly die.");
		return;
	}

	RPG_Perks_ApplyEntityTimedAttribute(survivor1, "Nightmare", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

	int survivor2 = FindRandomSurvivorWithoutStatus(client);

	if(survivor2 == -1)
	{
		PrintToChatAll("%N is under nightmare for %.0f seconds. He is blind and takes 2x damage from all sources", survivor1, fDuration);
	}
	else
	{
		RPG_Perks_ApplyEntityTimedAttribute(survivor2, "Nightmare", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

		PrintToChatAll("%N & %N are under nightmare for %.0f seconds.", survivor1, survivor2, fDuration);
		PrintToChatAll("They are blind and take 2x damage from all sources");
	}
}

stock int FindRandomSurvivorWithoutStatus(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	int   winner    = -1;
	float winnerDistance = 65535.0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		// Technically unused because the tank can never be survivor but still...
		else if(client == i)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(g_bNightmare[i])
			continue;

		float fSurvivorOrigin[3];
		GetClientAbsOrigin(i, fSurvivorOrigin);

		if (winner == -1 || GetVectorDistance(fOrigin, fSurvivorOrigin) < winnerDistance)
		{
			winner    = i;
			winnerDistance = GetVectorDistance(fOrigin, fSurvivorOrigin);
		}
	}

	return winner;
}
public void CastDamageReflect(int client)
{
	float fDuration = 4.0;

	if(RPG_Tanks_GetClientTank(client) == tankIndex)
		fDuration = 7.0;

	else if(RPG_Tanks_GetClientTank(client) == strongerTankIndex)
		fDuration = 10.0;

	g_fEndDamageReflect[client] = GetGameTime() + fDuration;

	PrintToChatAll("Damage Reflect is live for %.0f seconds, don't shoot the tank!!!", fDuration);
}

public void Event_ZombieSpawnPost(int entity)
{
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

public void RegisterTank()
{
	strongerTankIndex = RPG_Tanks_RegisterTank(3, 3, "Ultimate Psychic", "The strongest Psychic Tank the survivors will ever witness\nCasts a random psychic ability every 20 seconds.",
	2500000, 180, 0.333333, 55000, 65000, DAMAGE_IMMUNITY_BURN|DAMAGE_IMMUNITY_MELEE|DAMAGE_IMMUNITY_EXPLOSIVES);

	strongerPsychicPowersIndex = RPG_Tanks_RegisterActiveAbility(strongerTankIndex, "Psychic Powers", "On cast, the tank casts a random Psychic Ability.", 20, 20);
	RPG_Tanks_RegisterActiveAbility(strongerTankIndex, "Bullet Release", "If tank is over 90{PERCENT} HP, this ability won't be castable\nTank releases stored bullets in all directions\nDeals damage to survivors every half-second\nDamage is percent based, and scales as the Tank loses HP.\nLasts 10 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(strongerTankIndex, "Psychokinesis", "Closest Survivor to tank is lifted to the ceiling.\nThe survivor is then held with Telekinesis for 15 seconds before release.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(strongerTankIndex, "Nightmare", "All survivors hallucinate a nightmare.\nThey cannot see any player, and take 2x damage from all sources.\nLasts 10 seconds.\nThe Tank instantly kills a survivor under Nightmare, returning the rest to normal", 0, 0);
	RPG_Tanks_RegisterActiveAbility(strongerTankIndex, "Damage Reflect", "Tank reflects 100{PERCENT} of unbuffed damage to it.\nLasts 10 seconds.", 0, 0);

	RPG_Tanks_RegisterPassiveAbility(strongerTankIndex, "Brains, Not Brawn", "Tank deals 3x less damage with punches.");
	RPG_Tanks_RegisterPassiveAbility(strongerTankIndex, "Adaptability", "When the tank is under 30{PERCENT} HP, it will only cast Bullet Release");
	RPG_Tanks_RegisterPassiveAbility(strongerTankIndex, "Psychic Rock", "The Tank's rock instantly kills a survivor it hits.");

	tankIndex = RPG_Tanks_RegisterTank(2, 3, "Psychic", "A powerful Psychic Tank that uses Psychic attacks at his enemies\nCasts a random psychic ability every 20 seconds.",
	1500000, 180, 0.2, 6000, 8000, DAMAGE_IMMUNITY_BURN|DAMAGE_IMMUNITY_MELEE|DAMAGE_IMMUNITY_EXPLOSIVES);

	psychicPowersIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Psychic Powers", "On cast, the tank casts a random Psychic Ability.", 20, 20);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Bullet Release", "If tank is over 90{PERCENT} HP, this ability won't be castable\nTank releases stored bullets in all directions\nDeals damage to survivors every half-second\nDamage is percent based, and scales as the Tank loses HP.\nLasts 7 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Psychokinesis", "Closest Survivor to tank is lifted to the ceiling.\nThe survivor is then held with Telekinesis for 12 seconds before release.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Nightmare", "2 Closest survivors hallucinate a nightmare.\nThey cannot see any player, and take 2x damage from all sources.\nLasts 20 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Damage Reflect", "Tank reflects 100{PERCENT} of unbuffed damage to it.\nLasts 7 seconds.", 0, 0);

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Brains, Not Brawn", "Tank deals 5x less damage with punches.");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Adaptability", "When the tank is under 30{PERCENT} HP, it will only cast Bullet Release");

	weakerTankIndex = RPG_Tanks_RegisterTank(1, 5, "Apprentice Psychic", "A weak Psychic Tank that uses Psychic attacks at his enemies\nCasts a random psychic ability every 30 seconds.",
	500000, 180, 0.2, 500, 750, DAMAGE_IMMUNITY_BURN|DAMAGE_IMMUNITY_MELEE);

	weakerPsychicPowersIndex = RPG_Tanks_RegisterActiveAbility(weakerTankIndex, "Psychic Powers", "On cast, the tank casts a random Psychic Ability.", 30, 30);
	RPG_Tanks_RegisterActiveAbility(weakerTankIndex, "Bullet Release", "If tank is over 90{PERCENT} HP, this ability won't be castable\nTank releases stored bullets in all directions\nDeals damage to survivors every half-second\nDamage is percent based, and scales as the Tank loses HP.\nLasts 4 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(weakerTankIndex, "Psychokinesis", "Closest Survivor to tank is lifted to the ceiling.\nThe survivor is then held with Telekinesis for 12 seconds before release.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(weakerTankIndex, "Nightmare", "2 Closest survivors hallucinate a nightmare.\nThey cannot see any player, and take 2x damage from all sources.\nLasts 12 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(weakerTankIndex, "Damage Reflect", "Tank reflects 100{PERCENT} of unbuffed damage to it.\nLasts 4 seconds.", 0, 0);

	RPG_Tanks_RegisterPassiveAbility(weakerTankIndex, "Brains, Not Brawn", "Tank deals 5x less damage with punches.");
	RPG_Tanks_RegisterPassiveAbility(weakerTankIndex, "Adaptability", "When the tank is under 15{PERCENT} HP, it will only cast Bullet Release");
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority == g_hReflectDamagePriority.IntValue)
	{
		if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
			return;

		else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
			return;

		else if(g_fEndDamageReflect[victim] < GetGameTime())
			return;
		
		else if(L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Melee || L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Chainsaw || damagetype & DMG_BURN || damagetype & DMG_BLAST || damagetype & DMG_DROWNRECOVER)
			return;

		// Damage the attacker by the victim ( damage reflect )
		RPG_Perks_TakeDamage(attacker, victim, victim, damage, damagetype);

		bImmune = true;
		
		return;
	}

	if(priority == 0)
	{
		if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
			return;

		else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
    	    return;

		else if(!IsPlayer(victim) || !g_bNightmare[victim])
			return;

		damage *= 2.0;
	}
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}