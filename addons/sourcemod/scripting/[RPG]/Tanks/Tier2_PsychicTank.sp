
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

int tankIndex;

float g_fEndDamageReflect[MAXPLAYERS+1];
float g_fEndNightmare[MAXPLAYERS+1];
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
public void OnPluginStart()
{
	AutoExecConfig_SetFile("GunXP-RPGTanks.cfg");

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
		g_fEndNightmare[i] = 0.0;
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

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "infected") || StrEqual(classname, "witch"))
	{
		SDKHook(entity, SDKHook_SpawnPost, Event_ZombieSpawnPost);
	}	
}

public void RPG_Perks_OnGetZombieMaxHP(int priority, int entity, int &maxHP)
{
	if(priority != 0)
		return;

	else if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
		return;
	
	else if(RPG_Tanks_GetClientTank(entity) != tankIndex)
		return;

	int count = GetEntityCount();

	for(int i=0;i < count;i++)
	{
		if(!IsValidEdict(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) == ZombieType_Invalid)
			continue;

		SDKHook(i, SDKHook_SetTransmit, SDKEvent_SetTransmit);
	}

	CreateTimer(30.0, Timer_CastAbility, GetClientUserId(entity), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Timer_CastAbility(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return Plugin_Stop;

	else if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return Plugin_Stop;
	
	else if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return Plugin_Stop;

	int minRNG = 0;

	if(float(RPG_Perks_GetClientHealth(client)) / float(RPG_Perks_GetClientMaxHealth(client)) >= 0.9)
		minRNG = 1;

	switch(GetRandomInt(minRNG, 3))
	{
		case 0:	CastBulletRelease(client);
		case 1:	CastPsychoKinesis(client);
		case 2:	CastNightmare(client);
		case 3:	CastDamageReflect(client);
	}

	return Plugin_Continue;
}

public void CastBulletRelease(int client)
{
	float interval = 0.5;
	int duration = 4;
	g_iBulletRelease[client] = 1 + RoundFloat(duration * (1.0 / interval));

	TriggerTimer(CreateTimer(interval, Timer_BulletRelease, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));

	PrintToChatAll("Bullet Release is active, hide from the tank!!!");
}

public Action Timer_BulletRelease(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0)
		return Plugin_Stop;

	else if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return Plugin_Stop;
	
	else if(RPG_Tanks_GetClientTank(client) != tankIndex)
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

		SDKHooks_TakeDamage(i, client, client, damage, DMG_BULLET, -1, NULL_VECTOR, NULL_VECTOR, false);
	}

	g_iBulletRelease[client]--;

	return Plugin_Continue;
	
}


public void CastPsychoKinesis(int client)
{
	int survivor = FindRandomSurvivorWithoutStatus(client);

	if(survivor == -1)
		return;

	TeleportToCeiling(survivor);	

	RPG_Perks_ApplyEntityTimedAttribute(survivor, "Stun", 12.0, COLLISION_SET_IF_HIGHER);

	PrintToChatAll("%N is hit with Psycho Kinesis.", survivor);
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

	g_fEndNightmare[survivor1] = GetGameTime() + 12.0;

	int survivor2 = FindRandomSurvivorWithoutStatus(client);

	if(survivor2 == -1)
	{
		PrintToChatAll("%N is under nightmare for 12 seconds. He is blind and takes 2x damage from all sources", survivor1);
	}
	else
	{
		g_fEndNightmare[survivor2] = GetGameTime() + 12.0;
		PrintToChatAll("%N & %N are under nightmare for 12 seconds.", survivor1, survivor2);
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

		else if(g_fEndNightmare[i] > GetGameTime())
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
	g_fEndDamageReflect[client] = GetGameTime() + 4.0;

	PrintToChatAll("Damage Reflect is live for 4 seconds, don't shoot the tank!!!");
}

public void Event_ZombieSpawnPost(int entity)
{
	if(RPG_Tanks_IsTankInPlay(tankIndex))
	{
		SDKHook(entity, SDKHook_SetTransmit, SDKEvent_SetTransmit);
	}
}

public void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward)
{
	if(RPG_Tanks_GetClientTank(victim) == tankIndex)
	{
		int count = GetEntityCount();

		for(int i=0;i < count;i++)
		{
			if(!IsValidEdict(i))
				continue;

			else if(RPG_Perks_GetZombieType(i) == ZombieType_Invalid)
				continue;

			SDKUnhook(i, SDKHook_SetTransmit, SDKEvent_SetTransmit);
		}
	}
}

public Action SDKEvent_SetTransmit(int victim, int viewer)
{
	if(!IsPlayer(viewer))
		return Plugin_Continue;

	else if(victim == viewer)
		return Plugin_Continue;

	else if(g_fEndNightmare[viewer] <= GetGameTime())
		return Plugin_Continue;

	else if(L4D_GetPinnedInfected(viewer) == victim)
		return Plugin_Continue;

	return Plugin_Handled;
}

public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(2, 3, "Psychic", "A powerful Psychic Tank that uses Psychic attacks at his enemies\nCasts a random psychic ability every 30 seconds.",
	5000000, 180, 0.1, 3000, 5000, true, true);

	RPG_Tanks_RegisterActiveAbility(tankIndex, "Bullet Release", "Tank must be under 90{PERCENT} HP to use this ability\nTank releases stored bullets in all directions\nDeals damage to survivors every half-second\nDamage is percent based, and scales as the Tank loses HP.\nLasts 4 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Psychokinesis", "Closest Survivor to tank is lifted to the ceiling.\nThe survivor is then held with Telekinesis for 10 seconds before release.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Nightmare", "2 Closest survivors hallucinate a nightmare.\nThey cannot see any player, and take 2x damage from all sources.\nLasts 12 seconds.", 0, 0);
	RPG_Tanks_RegisterActiveAbility(tankIndex, "Damage Reflect", "Tank reflects 100{PERCENT} of unbuffed damage to it.\nLasts 4 seconds.", 0, 0);

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Psychic Powers", "Every 30 seconds, the tank casts a random Psychic Ability.");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Brains, Not Brawn", "Tank deals 10x less damage with punches.");
	//RPG_Tanks_RegisterPassiveAbility(tankIndex, "Psychic Rock", "Tank rock will kill a survivor hit by it.", 0, 0);
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

		else if(RPG_Tanks_GetClientTank(victim) != tankIndex)
			return;
			
		else if(L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Melee || L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Chainsaw || damagetype & DMG_BURN || damagetype & DMG_BLAST)
			return;

		// Damage the attacker by the victim ( damage reflect )
		SDKHooks_TakeDamage(attacker, victim, victim, damage, damagetype, -1, NULL_VECTOR, NULL_VECTOR, false);

		bImmune = true;
		
		return;
	}

	if(priority == 0)
	{
		if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
			return;

		else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
    	    return;

		else if(!IsPlayer(victim) || g_fEndNightmare[victim] < GetGameTime())
			return;

		damage *= 2.0;
	}
}