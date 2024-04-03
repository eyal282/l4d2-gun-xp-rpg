
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
	name        = "Jockey Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Jockey Tank that makes lots of jockeys.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tankIndex;

ConVar g_hDamagePriority;

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
	RegisterTank();

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgtanks_melee_damage_priority", "-10", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin interacts with unbuffed damage, so it must go first");
}

public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(victim == 0)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(victim) != L4DTeam_Survivor)
		return Plugin_Continue;

	else if(L4D_IsPlayerIncapacitated(victim))
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(attacker) != ZombieType_Tank)
		return Plugin_Continue;

	else if(RPG_Tanks_GetClientTank(attacker) != tankIndex)
		return Plugin_Continue;

	float fOrigin[3];

	GetClientAbsOrigin(victim, fOrigin);

	fOrigin[2] += 512.0;

	int jockey = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Jockey), fOrigin, view_as<float>({0.0, 0.0, 0.0}));


	DataPack DP;
	CreateDataTimer(0.1, Timer_ForceJockey, DP, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP, GetClientUserId(victim));
	WritePackCell(DP, GetClientUserId(jockey));

	return Plugin_Continue;
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
public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(1, 3, "Jockey", "A tank that likes Jockeys\nAll Special Infected spawned will be Jockeys instead\nThis tank shoots jockeys from his arms, and you will be pinned if it hits you.", "All SI become Jockey. Getting hit pins you. Melee does 2x damage.", 200000, 180, 1.0, 150, 200,  DAMAGE_IMMUNITY_BURN);

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Fragile Body", "Tank takes 2x damage from melee");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "My Little Friends", "Every Special Infected that spawns is a Jockey.");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Secret Weapon", "Getting hit by the Tank spawns a Jockey that pins you.");
}


public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority != g_hDamagePriority.IntValue)
        return;

	else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
        return;

	else if(RPG_Tanks_GetClientTank(victim) != tankIndex)
		return;
        
	else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
        return;


	damage *= 2.0;
}

public void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass)
{
	if(priority != 0)
		return;
		
	else if(zclass == L4D2ZombieClass_Tank)
		return;

	else if(!RPG_Tanks_IsTankInPlay(tankIndex))
		return;

	zclass = L4D2ZombieClass_Jockey;
}
