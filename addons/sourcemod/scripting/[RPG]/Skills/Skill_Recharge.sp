
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
	name        = "Recharge Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that recharges all limited abilities when a tiered tank dies.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int skillIndex;

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

	// Delay to account for insta kill and retroactive revive.
	CreateTimer(0.3, Timer_RechargeCheck, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RechargeCheck(Handle hTimer, int userid)
{
	int attacker = GetClientOfUserId(userid);

	if(attacker == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(attacker))
		return Plugin_Continue;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, skillIndex))
		return Plugin_Continue;

	ArrayList abilities = RPG_Perks_GetClientLimitedAbilitiesList(attacker);

	bool bAny = false;

	for(int i=0;i < abilities.Length;i++)
	{
		char sIdentifier[32];
		abilities.GetString(i, sIdentifier, sizeof(sIdentifier));

		while(RPG_Perks_ReuseClientLimitedAbility(attacker, sIdentifier))
		{
			bAny = true;
		}
	}

	if(bAny)
	{
		PrintToChat(attacker, "Recharged all Limited Abilities");
	}
	else
	{
		PrintToChat(attacker, "Could not find a Limited Ability to recharge");
	}
	CloseHandle(abilities);

	return Plugin_Continue;
}

public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "When a tiered Tank dies, recharge all abilities with limited use per round.");

	skillIndex = GunXP_RPGShop_RegisterSkill("Recharge Abilities", "Recharge", sDescription,
	50000, 0);
}

