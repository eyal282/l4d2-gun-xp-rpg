#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

public Plugin myinfo =
{
	name        = "Parry Tactics Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that prevents you from ",
	version     = PLUGIN_VERSION,
	url         = ""
};


// Make identifier as descriptive as possible.
native int GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null);
native bool GunXP_RPGShop_IsSkillUnlocked(int client, int skillIndex);

int parryTacticsIndex = -1;

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
public void OnPluginStart()
{
    RegisterSkill();

    for (int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;
            
        OnClientPutInServer(i);
    }
}

public void RegisterSkill()
{
    parryTacticsIndex = GunXP_RPGShop_RegisterSkill("Parry Tactics", "Parry Tactics", "While you are incapped, your revive cannot be interrupted by damage", 8000, 15);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
}

public Action Event_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!L4D_IsPlayerIncapacitated(victim))
		return Plugin_Continue;

	else if(damage >= float(GetEntityHealth(victim)))
		return Plugin_Continue;

	char sClassname[64];
	GetEdictClassname(attacker, sClassname, sizeof(sClassname));

	if(!StrEqual(sClassname, "infected") && !StrEqual(sClassname, "witch") && (attacker == 0 || (IsPlayer(attacker) && L4D_GetClientTeam(attacker) != L4DTeam_Infected)))
		return Plugin_Continue;

	else if(!GunXP_RPGShop_IsSkillUnlocked(victim, parryTacticsIndex))
		return Plugin_Continue;

	SetEntityHealth(victim, GetEntityHealth(victim) - RoundFloat(damage));
	Event hNewEvent = CreateEvent("player_hurt", true);

	SetEventInt(hNewEvent, "userid", GetClientUserId(victim));

	if(IsPlayer(attacker))
	{
		SetEventInt(hNewEvent, "attacker", GetClientUserId(attacker));
	}
	else
	{
		SetEventInt(hNewEvent, "attacker", 0);
	}
	
	SetEventInt(hNewEvent, "attackerentid", attacker);
	SetEventInt(hNewEvent, "health", GetEntityHealth(victim));
	SetEventInt(hNewEvent, "dmg_health", RoundFloat(damage));
	SetEventInt(hNewEvent, "dmg_armor", 0);
	SetEventInt(hNewEvent, "hitgroup", 0);
	SetEventInt(hNewEvent, "type", damagetype);

    FireEvent(hNewEvent);

   return Plugin_Stop;
}

stock bool IsPlayer(int client)
{
	if(client == 0)
		return false;
	
	else if(client > MaxClients)
		return false;
	
	return true;
}


public void BitchSlapBackwards(int victim, int attacker, float strength)    // Stole the dodgeball tactic from https://forums.alliedmods.net/showthread.php?t=17116
{
	float origin[3], velocity[3];
	GetEntPropVector(attacker, Prop_Data, "m_vecOrigin", origin);
	GetVelocityFromOrigin(victim, origin, strength, velocity);
	velocity[2] = strength / 10.0;

	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
}
stock void GetVelocityFromOrigin(int ent, float fOrigin[3], float fSpeed, float fVelocity[3])    // Will crash server if fSpeed = -1.0
{
	float fEntOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", fEntOrigin);

	// Velocity = Distance / Time

	float fDistance[3];
	fDistance[0] = fEntOrigin[0] - fOrigin[0];
	fDistance[1] = fEntOrigin[1] - fOrigin[1];
	fDistance[2] = fEntOrigin[2] - fOrigin[2];

	float fTime = (GetVectorDistance(fEntOrigin, fOrigin) / fSpeed);

	if (fTime == 0.0)
		fTime = 1 / (fSpeed + 1.0);

	fVelocity[0] = fDistance[0] / fTime;
	fVelocity[1] = fDistance[1] / fTime;
	fVelocity[2] = fDistance[2] / fTime;
}

stock bool IsPlayerStuck(int client, const float Origin[3] = NULL_VECTOR, float HeightOffset = 0.0)
{
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

stock void TeleportToGround(int client)
{
	float vecMin[3], vecMax[3], vecOrigin[3], vecFakeOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	GetClientAbsOrigin(client, vecOrigin);
	vecFakeOrigin = vecOrigin;

	vecFakeOrigin[2] = MIN_FLOAT;

	TR_TraceHullFilter(vecOrigin, vecFakeOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);

	TR_GetEndPosition(vecOrigin);

	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);
}

stock bool UC_IsNullVector(const float Vector[3])
{
	return (Vector[0] == NULL_VECTOR[0] && Vector[0] == NULL_VECTOR[1] && Vector[2] == NULL_VECTOR[2]);
}

public bool TraceRayDontHitPlayers(int entityhit, int mask)
{
	return (entityhit > MaxClients || entityhit == 0);
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