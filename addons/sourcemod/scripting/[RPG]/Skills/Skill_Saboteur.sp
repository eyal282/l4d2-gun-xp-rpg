
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
	name        = "Saboteur Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that increases the cooldown of Tank's Activated Abilities",
	version     = PLUGIN_VERSION,
	url         = ""
};

int saboIndex;

float g_fInitSabo = 10.0;
float g_fStackSabo = 2.0;

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


public void RPG_Perks_OnTimedAttributeStart(int entity, char attributeName[64])
{
	if(strncmp(attributeName, "Cast Active Ability #", 21) != 0)
		return;

	else if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
		return;

	else if(RPG_Tanks_GetClientTank(entity) < 0)
		return;

	int count = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(IsFakeClient(i))
			continue;

		else if(!GunXP_RPGShop_IsSkillUnlocked(i, saboIndex))
			continue;

		count++;
	}

	if(count == 0)
		return;

	float fDelay;
	RPG_Perks_IsEntityTimedAttribute(entity, attributeName, fDelay);

	if(fDelay <= 0.0)
		return;

	float fPercentIncrease = g_fInitSabo + (g_fStackSabo * (count - 1));
	float fDelayIncrease = fDelay * (fPercentIncrease / 100.0);

	if(fDelayIncrease <= 0.0)
		return;

	RPG_Perks_ApplyEntityTimedAttribute(entity, attributeName, fDelayIncrease, COLLISION_ADD, ATTRIBUTE_NEUTRAL);

	RPG_Perks_IsEntityTimedAttribute(entity, attributeName, fDelay);
}
public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Increases cooldown of Tanks activated abilities by %.0f{PERCENT}, stacks for %.0f{PERCENT} for each human Survivor with this Skill\nThis skill works even while dead, unless in Spectator team", g_fInitSabo, g_fStackSabo);

	saboIndex = GunXP_RPGShop_RegisterSkill("Tank Ability Cooldown Increase", "Saboteur", sDescription,
	50000, 0);
}

