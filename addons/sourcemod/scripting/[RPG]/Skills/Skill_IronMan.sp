
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
	name        = "Iron Man Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that gives a gigantic HP boost but you die on incap.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int bileGogglesIndex;

public void BileGoggles_OnDoesHaveBileGoggles(int client, bool &bGoggles, float &fCleanTime)
{
	fCleanTime += 85.0;
	fCleanTime -= GunXP_RPG_GetClientLevel(client);

	if(GunXP_RPGShop_IsSkillUnlocked(client, bileGogglesIndex))
	{
		bGoggles = true;
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
    bileGogglesIndex = GunXP_RPGShop_RegisterSkill("Bile Goggles", "Bile Goggles", "Press +ZOOM to remove the Bile Goggles to see again.\nIf your eyes are hit while it's removed,\n they won't help you.\nGoggles return to eyes in 100 seconds subtracted by your level.",
	 20000, 75000);
}

