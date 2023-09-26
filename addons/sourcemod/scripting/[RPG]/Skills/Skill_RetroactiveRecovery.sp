
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
	if(RPG_Tanks_GetClientTank(victim) == TANK_TIER_UNTIERED)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, skillIndex))
		return;

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
}
public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "When a tiered Tank dies, all survivors heal %.1f{PERCENT} of max HP\nThis skill stacks across all survivors.", g_fHealPercent);

	skillIndex = GunXP_RPGShop_RegisterSkill("Heal Team when Tank dies", "Retroactive Recovery", sDescription,
	30000, 100000);
}

