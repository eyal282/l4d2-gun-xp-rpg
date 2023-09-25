
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
	name        = "Sticky Bile Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that makes bile stun targets for x seconds",
	version     = PLUGIN_VERSION,
	url         = ""
};

int bileIndex;

float g_fStunTimeCommons = 30.0;
float g_fStunTimeSpecials = 15.0;
float g_fStunTimeTanks = 5.0;

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
	HookEvent("player_now_it", Event_PlayerNowIt);

	RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public Action Event_PlayerNowIt(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0 || victim == 0)
		return Plugin_Continue;

	if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
		return Plugin_Continue;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, bileIndex))
		return Plugin_Continue;

	
	float fDuration = g_fStunTimeSpecials;

	if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
		fDuration = g_fStunTimeTanks;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", fDuration, COLLISION_SET_IF_HIGHER, ATTRIBUTE_NEGATIVE);

	return Plugin_Continue;
}

public void L4D2_Infected_HitByVomitJar_Post(int victim, int attacker)
{
	if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, bileIndex))
		return;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", g_fStunTimeCommons, COLLISION_SET_IF_HIGHER, ATTRIBUTE_NEGATIVE);
}
public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Bile jar becomes extremely sticky\nStuns Common Infected for %.0f seconds\nStuns Special Infected for %.0f seconds\nStuns Tanks for %.0f seconds.", g_fStunTimeCommons, g_fStunTimeSpecials, g_fStunTimeTanks);
	bileIndex = GunXP_RPGShop_RegisterSkill("Sticky Bile", "Sticky Bile", sDescription,
	500000, 0);
}


