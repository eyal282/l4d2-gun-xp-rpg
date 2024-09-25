
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>
#include <ps_api>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name        = "Shaman Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Shaman Tank that casts magical abilities to kill the survivors.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tankIndex;

int infernoIndex, vomitIndex, jockeyIndex, mutationIndex, regenIndex, bulletReleaseIndex, bossIndex;

float g_fVomitRadius = 256.0;

int g_iBulletRelease[MAXPLAYERS+1];

public void OnLibraryAdded(const char[] name)
{
	// GunXP-RPG is to make Mutation only work with GunXP - RPG
	if (StrEqual(name, "RPG_Tanks") || StrEqual(name, "GunXP-RPG"))
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
	RegisterTank();

	HookEvent("player_now_it", Event_Boom, EventHookMode_Post);
}

public void OnMapStart()
{
	TriggerTimer(CreateTimer(1.0, Timer_ShamanTank, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));

	PrecacheParticle("error");

	for(int i=0;i < sizeof(g_iBulletRelease);i++)
	{
		g_iBulletRelease[i] = 0;
	}
}

public Action L4D_OnCThrowActivate(int ability)
{
	int tank = GetEntPropEnt(ability, Prop_Send, "m_hOwnerEntity");

	if(tank == -1)
		return Plugin_Continue;

	else if(RPG_Tanks_GetClientTank(tank) != tankIndex)
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Event_Boom(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(!RPG_Tanks_IsTankInPlay(tankIndex))
		return Plugin_Continue;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Nightmare", 30.0, COLLISION_SET_IF_LOWER, ATTRIBUTE_NEGATIVE);

	return Plugin_Continue;
}

public Action Timer_ShamanTank(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Tanks_GetClientTank(i) != tankIndex)
			continue;

		OnShamanTankTimer(i);
	}

	return Plugin_Continue;
}

public void OnShamanTankTimer(int client)
{
	int weapon = L4D_GetPlayerCurrentWeapon(client);

	if(weapon != -1)
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", 2000000000.0);
		SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", 2000000000.0);
	}

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Tanks_GetClientTank(i) == tankIndex)
			continue;

		else if(RPG_Tanks_GetClientTankTier(i) >= 2)
			continue;

		if(RPG_Perks_GetClientHealth(i) * 2 > RPG_Perks_GetClientMaxHealth(i))
		{
			RPG_Perks_SetClientHealth(i, RPG_Perks_GetClientMaxHealth(i) / 2);
		}
	}
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public Action SDKEvent_NeverTransmit(int victim, int viewer)
{
	return Plugin_Handled;
}
public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(2, 3, "Shaman", "A wizard Tank that uses magical abilities to kill survivors.", "Weak tank that uses magic abilities like Inferno and Bullet Release like Fire Balls", 2000000, 180, 0.3, 1500, 2500, DAMAGE_IMMUNITY_BURN|DAMAGE_IMMUNITY_MELEE, GunXP_GenerateHexColor(0, 128, 0));

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Weak Physique", "Tank deals less damage when punching\nTank cannot throw rocks.\nTank attacks slower");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Confusion and Horror", "No matter the source, Survivors gain NIGHTMARE for 30 seconds when Biled.");

	regenIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Regeneration", "Tank heals 125k HP, unless another Tank is spawned", 60, 60);

	infernoIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Inferno", "Spawns an Inferno on the Tank's location", 20, 30);

	char TempFormat[256];
	FormatEx(TempFormat, sizeof(TempFormat), "Biles all survivors in a %.0f unit radius", g_fVomitRadius);

	vomitIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Vomit", TempFormat, 90, 100);
	bulletReleaseIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Bullet Release", "Tank must be under 90{PERCENT} HP to use this ability\nTank casts stored bullets like fireballs in all directions using Aimbot Level 1 ( !br )\nDeals 10 damage to survivors every half-second\nLasts 7 seconds.", 45, 45);
	jockeyIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Summon Minion Jesters", "Spawns 2 Jockeys that pin closest 2 survivors\nThis always works no matter how far the survivors are.", 75, 90);
	bossIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Summon Minion Boss", "If this is the only tank, spawns a Tier 1 Tank and halves its HP", 120, 180);

	if(LibraryExists("GunXP-RPG"))
	{
		mutationIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Mutation", "Mutates all survivors for 10 seconds", 120, 120);
	}
}



public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority != 0)
        return;

	else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
        return;

	else if(RPG_Tanks_GetClientTank(victim) != tankIndex)
		return;
        
	else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
        return;


	damage /= 4.0;
}
public void RPG_Perks_OnGetTankSwingSpeed(int priority, int client, float &delay)
{
	if(priority != 0)
		return;

	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	delay += 1.0;
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	if(abilityIndex == jockeyIndex)
		CastJockey(client);

	else if(abilityIndex == bossIndex)
		CastBoss(client);

	else if(abilityIndex == vomitIndex)
		CastVomit(client);

	else if(abilityIndex == mutationIndex)
		CastMutation(client);

	else if(abilityIndex == regenIndex)
		CastRegen(client);

	else if(abilityIndex == infernoIndex)
		CastInferno(client);
	
	else if(abilityIndex == bulletReleaseIndex)
		CastBulletRelease(client);
}

public void CastJockey(int client)
{
	int survivor1 = FindRandomSurvivorNearby(client, 65535.0);

	if(survivor1 == -1)
		return;

	float fOrigin[3];

	GetClientAbsOrigin(survivor1, fOrigin);

	fOrigin[2] += 512.0;

	int jockey = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Jockey), fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	DataPack DP;
	CreateDataTimer(0.1, Timer_ForceJockey, DP, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP, GetClientUserId(survivor1));
	WritePackCell(DP, GetClientUserId(jockey));

	int survivor2 = FindRandomSurvivorNearby(client, 65535.0, survivor1);

	if(survivor2 == -1)
		return;

	GetClientAbsOrigin(survivor2, fOrigin);

	fOrigin[2] += 512.0;

	jockey = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Jockey), fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	DataPack DP2;
	CreateDataTimer(0.1, Timer_ForceJockey, DP2, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP2, GetClientUserId(survivor2));
	WritePackCell(DP2, GetClientUserId(jockey));
}

public void CastBoss(int client)
{
	int tankCount = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		tankCount++;
	}

	if(tankCount >= 2)
		return;

	UC_PrintToChatAll("Shaman Tank brought a FRIEND!!!");

	RPG_Tanks_SetOverrideTier(1);

	int target = GetAnyClient();

	float fOrigin[3];

	// Accepts invalid client
	if(!L4D_GetRandomPZSpawnPosition(target, view_as<int>(L4D2ZombieClass_Tank), 10, fOrigin))
		return;

	L4D2_SpawnTank(fOrigin, view_as<float>({0.0, 0.0, 0.0}));
}

public Action Timer_ForceJockey(Handle hTimer, DataPack DP)
{
	ResetPack(DP);

	int survivor = GetClientOfUserId(ReadPackCell(DP));
	int jockey = GetClientOfUserId(ReadPackCell(DP));

	if(survivor == 0 || jockey == 0)
		return Plugin_Continue;

	L4D2_ForceJockeyVictim(survivor, jockey);

	return Plugin_Continue;
}

public void CastVomit(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		float fSurvivorOrigin[3];
		GetClientAbsOrigin(i, fSurvivorOrigin);

		if (GetVectorDistance(fOrigin, fSurvivorOrigin) < g_fVomitRadius && !IsPlayerBoomerBiled(i))
		{
			L4D_CTerrorPlayer_OnVomitedUpon(i, client);
		}
	}
}

public void CastInferno(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	L4D_DetonateProjectile(L4D_MolotovPrj(client, fOrigin, view_as<float>({0.0, 0.0, 0.0})));

	int entity = CreateEntityByName("info_particle_system");

	DispatchKeyValue(entity, "effect_name", "error");

	DispatchSpawn(entity);
	ActivateEntity(entity);

	TeleportEntity(entity, fOrigin, NULL_VECTOR, NULL_VECTOR);

	AcceptEntityInput(entity, "Start");

	//SetVariantString("!activator");
	//AcceptEntityInput(entity, "SetParent", target);

	//if( type == 0 )	SetVariantString("fuse");
	//else			SetVariantString("pipebomb_light");
	//AcceptEntityInput(entity, "SetParentAttachment", target);
}


public void CastMutation(int client)
{
	float fDuration = 10.0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		RPG_Perks_ApplyEntityTimedAttribute(i, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
	}

	PrintToChatAll("All survivors are mutated for %.0f seconds.", fDuration);
	PrintToChatAll("Mutated players lose all abilities");
}

public void CastRegen(int client)
{
	int tankCount = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		tankCount++;
	}

	if(tankCount >= 2)
		return;

	GunXP_RegenerateTankHealth(client, 125000);
}


public void CastBulletRelease(int client)
{
	float interval = 0.5;
	int duration = 7;

	g_iBulletRelease[client] = 1 + RoundFloat(duration * (1.0 / interval));

	TriggerTimer(CreateTimer(interval, Timer_BulletRelease, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));

	PrintToChatAll("Bullet Release is active for %i seconds, take cover or take damage!!!", duration);
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
			ClientCommand(i, "play )weapons/scout/gunfire/scout_fire-1.wav");

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

		RPG_Perks_TakeDamage(i, client, client, 10.0, DMG_BULLET);
	}

	g_iBulletRelease[client]--;

	return Plugin_Continue;
	
}

public bool TraceRayDontHitTarget(int entityhit, int mask, int target) 
{
    return (entityhit != target);
}

stock int FindRandomSurvivorNearby(int client, float fMaxDistance, int exception=0, int exception2=0, int exception3=0)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	int   winner    = -1;
	float winnerDistance = fMaxDistance;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		// Technically unused because the tank can never be survivor but still...
		else if(client == i || exception == i || exception2 == i || exception3 == i)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		float fSurvivorOrigin[3];
		GetClientAbsOrigin(i, fSurvivorOrigin);

		if (GetVectorDistance(fOrigin, fSurvivorOrigin) < winnerDistance)
		{
			winner    = i;
			winnerDistance = GetVectorDistance(fOrigin, fSurvivorOrigin);
		}
	}

	return winner;
}

stock bool IsPlayerBoomerBiled(int iClient)
{
    return (GetGameTime() <= GetEntPropFloat(iClient, Prop_Send, "m_itTimer", 1));
}

void PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	if( FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}

int GetAnyClient()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && L4D_GetClientTeam(i) == L4DTeam_Survivor && IsPlayerAlive(i) )
			return i;
	}
	return 0;
}