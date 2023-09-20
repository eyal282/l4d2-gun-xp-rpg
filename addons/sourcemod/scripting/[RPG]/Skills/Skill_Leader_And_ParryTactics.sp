#include <GunXP-RPG>
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
	name        = "Leader & Parry Tactics Skills --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skills that involve not interrupting actions.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int parryTacticsIndex = -1;
int leaderIndex = -1;

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
	parryTacticsIndex = GunXP_RPGShop_RegisterSkill("Parry Tactics", "Parry Tactics", "While you are incapped, your revive cannot be interrupted by damage.\nIf reviver has Leader skill, and fallen has Parry Tactics skill,\nRevive is 25%% faster", 3000, 4000);
	leaderIndex = GunXP_RPGShop_RegisterSkill("Leader", "Leader", "+5 Max HP per Level.\nYou revive players with +20{PERCENT} permanent HP\nAll timer based actions you perform cannot be interrupted\nIf reviver has Leader skill, and fallen has Parry Tactics skill,\nRevive is 25%% faster", 10000, 12500);
}


public void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG)
{
	if(skillIndex != leaderIndex)
		return;

	RPG_Perks_RecalculateMaxHP(client);
}

public void RPG_Perks_OnGetMaxHP(int priority, int client, int &maxHP)
{
	if(priority != 0)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(client, leaderIndex))
		return;

	maxHP += 5 * GunXP_RPG_GetClientLevel(client);
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority != 0)
		return;

	else if(!IsPlayer(victim))
		return;

	if(GunXP_RPGShop_IsSkillUnlocked(victim, leaderIndex) && !L4D_IsPlayerIncapacitated(victim))
	{
		bDontInterruptActions = true;
	}
	if(L4D_IsPlayerIncapacitated(victim))
	{ 
		int reviver = GetEntPropEnt(victim, Prop_Send, "m_reviveOwner");

		if(GunXP_RPGShop_IsSkillUnlocked(victim, parryTacticsIndex) || (reviver != -1 && GunXP_RPGShop_IsSkillUnlocked(reviver, leaderIndex)))
		{
			bDontInterruptActions = true;
		}
	}
}

public void RPG_Perks_OnGetReviveDuration(int reviver, int victim, bool bLedge, float &fDuration)
{
	if(!GunXP_RPGShop_IsSkillUnlocked(victim, parryTacticsIndex) || !GunXP_RPGShop_IsSkillUnlocked(reviver, leaderIndex))
		return;

	float percent = 25.0;

	fDuration -= (percent * fDuration) / (percent + 100.0);
}

public void RPG_Perks_OnGetReviveHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent)
{
	if(!GunXP_RPGShop_IsSkillUnlocked(reviver, leaderIndex))
		return;

	permanentHealthPercent += 20;

}