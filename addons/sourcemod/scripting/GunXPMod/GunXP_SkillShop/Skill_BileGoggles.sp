

#include <ps_api>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name        = "Bile Goggles Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that gives you a pair of Bile Goggles to remove to be able to see again.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int bileGogglesIndex;

// Make identifier as descriptive as possible.

native int GunXP_RPG_GetClientLevel(int client);

native int GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null);
native bool GunXP_RPGShop_IsSkillUnlocked(int client, int skillIndex);


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

public void RegisterSkill()
{
    bileGogglesIndex = GunXP_RPGShop_RegisterSkill("Bile Goggles", "Bile Goggles", "Press +ZOOM to remove the Bile Goggles to see again.\nIf your eyes are hit while it's removed,\n they won't help you.\nGoggles return to eyes in 100 seconds subtracted by your level.",
	 20000, 25);
}

