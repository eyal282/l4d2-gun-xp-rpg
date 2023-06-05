
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
	name        = "Cowardice Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that removes limping slowdown when a tank is live.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int cowardiceIndex;

public void RPG_Perks_OnGetLimpSpeed(int client, float &fSpeed)
{

	if(L4D2_IsTankInPlay() && GunXP_RPGShop_IsSkillUnlocked(client, cowardiceIndex))
	{
        if(fSpeed < 220)
		    fSpeed = 220.0;
	}
}
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

public void RegisterSkill()
{
    cowardiceIndex = GunXP_RPGShop_RegisterSkill("No Limp Slowdown if Tank", "Cowardice", "If a tank is spawned, limping speed is disabled.",
	 500, 20000);
}

