
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
	name        = "Retroactive Recovery Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that heals all survivors when a tiered tank dies.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int skillIndex;

float g_fHealPercent = 12.5;

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
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward)
{
	if(RPG_Tanks_GetClientTankTier(victim) == TANK_TIER_UNTIERED)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, skillIndex))
		return;

	// Delay to account for insta kill
	for(int i=0;i < RPG_Tanks_GetClientTankTier(victim);i++)
	{
		CreateTimer(0.1, Timer_RetroactiveCheck, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_RetroactiveCheck(Handle hTimer, int userid)
{
	int attacker = GetClientOfUserId(userid);

	if(attacker == 0)
		return Plugin_Continue;

	if(IsPlayerAlive(attacker))
	{
		CreateTimer(0.1, Timer_RetroactiveRevive, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);
	}

	CreateTimer(0.2, Timer_RetroactiveRecover, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action Timer_RetroactiveRevive(Handle hTimer, int userid)
{
	int attacker = GetClientOfUserId(userid);

	if(attacker == 0)
		return Plugin_Continue;
		
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;
		
		else if(RPG_Perks_IsEntityTimedAttribute(i, "Retroactive Revive Cooldown"))
			continue;
			
		float fChance = 0.01 * float(GunXP_RPG_GetClientLevel(attacker));

		float fGamble = GetRandomFloat(0.0, 1.0);

		// If gamble fails or succeeds, break to prevent respawning everybody...
		if(fGamble >= fChance)
			break;

		L4D2_VScriptWrapper_ReviveByDefib(i);
		
		RPG_Perks_ApplyEntityTimedAttribute(i, "Retroactive Revive Cooldown", 0.5, COLLISION_SET, ATTRIBUTE_NEUTRAL);

		float fOrigin[3];
		GetClientAbsOrigin(attacker, fOrigin);

		TeleportEntity(i, fOrigin, NULL_VECTOR, NULL_VECTOR);

		RPG_Perks_RecalculateMaxHP(i);

		SetEntityHealth(i, 1);
		RPG_Perks_SetClientTempHealth(i, 0);

		PrintToChatAll("%N was revived by %N's Retroactive Recovery", i, attacker);

		break;
	}

	return Plugin_Continue;
}
public Action Timer_RetroactiveRecover(Handle hTimer, int userid)
{
	int attacker = GetClientOfUserId(userid);

	if(attacker == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(attacker))
		return Plugin_Continue;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;
		
		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		int hpToAdd = RoundToCeil((g_fHealPercent / 100.0) * float(GetEntityMaxHealth(i)));

		GunXP_GiveClientHealth(i, hpToAdd);
	}

	return Plugin_Continue;
}
public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "When a tiered Tank dies, random survivor may respawn with chance equal to your level\nActivates a number of times equal to Tank's Tier\nAfter all respawns, heal all for %.1f{PERCENT} of max HP\nThis skill stacks across all survivors, but dead players cannot activate this skill.", g_fHealPercent);

	skillIndex = GunXP_RPGShop_RegisterSkill("Heal Team when Tank dies", "Retroactive Recovery", sDescription,
	30000, 100000);
}

