
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
	name        = "Out With A Blast Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that spawns live grenades when you die.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int skillIndex;

float g_fDeathOrigin[MAXPLAYERS+1][3];

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "GunXP_SkillShop"))
	{
		RegisterSkill();
	}
}

public void OnConfigsExecuted()
{
	RegisterSkill();
}


public void OnMapStart()
{
	CreateTimer(2.5, Timer_CheckDeathOrigin, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


public Action Timer_CheckDeathOrigin(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		FindClientDeathOrigin(i);
	}

	return Plugin_Continue;
}

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

	RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority != 10)
		return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
		return;	
		
	FindClientDeathOrigin(victim);
}
public void RPG_Perks_OnShouldInstantKill(int priority, int victim, int attacker, int inflictor, int damagetype, bool &bImmune)
{
	if(priority != 10)
		return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
		return;

	FindClientDeathOrigin(victim);
}


public Action Event_PlayerDeath(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(!GunXP_RPGShop_IsSkillUnlocked(victim, skillIndex))
		return Plugin_Continue;

	int grenadesToSpawn = RoundToFloor(float(GunXP_RPG_GetClientRealLevel(victim)) / 21.0);

	ArrayList aLegalGrenades = CreateArray(1);

	aLegalGrenades.Push(L4D2WeaponId_Molotov);
	aLegalGrenades.Push(L4D2WeaponId_PipeBomb);
	aLegalGrenades.Push(L4D2WeaponId_Vomitjar);

	g_fDeathOrigin[victim][2] += 4.0;

	for(int i=0;i < grenadesToSpawn;i++)
	{
		if(aLegalGrenades.Length <= 0)
			break;

		int RNG = GetRandomInt(0, aLegalGrenades.Length - 1);
		L4D2WeaponId weaponID = aLegalGrenades.Get(RNG);
		aLegalGrenades.Erase(RNG);

		switch(weaponID)
		{
			case L4D2WeaponId_Molotov:
			{
				L4D_MolotovPrj(victim, g_fDeathOrigin[victim], view_as<float>({0.0, 0.0, 0.0}));
			}
			case L4D2WeaponId_PipeBomb:
			{
				float fVelocity[3], fAngle[3];

				fVelocity[0] = GetRandomFloat(30.0, 50.0);
				fVelocity[1] = GetRandomFloat(30.0, 50.0);
				fVelocity[2] = GetRandomFloat(250.0, 300.0);

				for(int a=0;a < 2;a++)
				{
					if(GetRandomInt(0, 1) == 1)
					{
						fVelocity[a] *= -1.0;
					}
				}
				
				fAngle[0] = GetRandomFloat(300.0, 500.0);
				fAngle[1] = GetRandomFloat(300.0, 500.0);
				fAngle[2] = GetRandomFloat(-500.0, 500.0);

				int grenade = L4D_PipeBombPrj(victim, g_fDeathOrigin[victim], view_as<float>({0.0, 0.0, 0.0}), true);

				TeleportEntity(grenade, NULL_VECTOR, fAngle, fVelocity);

				L4D_AngularVelocity(grenade, fAngle);
			}
			case L4D2WeaponId_Vomitjar:
			{
				L4D2_VomitJarPrj(victim, g_fDeathOrigin[victim], view_as<float>({0.0, 0.0, 0.0}));
			}
		}
	}

	delete aLegalGrenades;

	return Plugin_Continue;
}

public void FindClientDeathOrigin(int client)
{
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fDeathOrigin[client]);
}

public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "When you die, spawns unique random grenades, equal to your level divided by 25");

	skillIndex = GunXP_RPGShop_RegisterSkill("Grenades on Death", "Out With A Blast", sDescription,
	125000, GunXP_RPG_GetXPForLevel(25));
}

