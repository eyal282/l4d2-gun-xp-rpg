
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
	name        = "Ultimate Samurai Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that makes melee swing incredibly fast.",
	version     = PLUGIN_VERSION,
	url         = ""
};

ConVar g_hDamagePriority;

int samuraiIndex;

float g_fSwingSpeedPerLevels = 0.5;
int g_iSwingSpeedLevels = 10;
float g_fMeleeDamagePerLevels = 0.1;
int g_iMeleeDamageLevels = 2;

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
    AutoExecConfig_SetFile("GunXP-RPGShop.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_ultimate_samurai_damage_priority", "0", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority == 10)
	{
		if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
	        return;

		else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        	return;
	
		else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
        	return;
	
		else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, samuraiIndex))
			return;

		else if(damage == 0.0 || bImmune)
			return;

		if(RPG_Tanks_CanBeIgnited(victim))
		{
			RPG_Perks_IgniteWithOwnership(victim, attacker);
		}
	}
	if(priority != g_hDamagePriority.IntValue)
        return;

	else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

	else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return;
        
	else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
        return;
    
	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, samuraiIndex))
		return;

	damage += damage * (1.0 + (g_fMeleeDamagePerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(attacker)) / float(g_iMeleeDamageLevels)))));
}

public void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
	if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_Melee)
        return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(client, samuraiIndex))
		return;

	speedmodifier = 10.0;
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_Melee)
        return;
    
	else if(!GunXP_RPGShop_IsSkillUnlocked(client, samuraiIndex))
		return;

	speedmodifier += g_fSwingSpeedPerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(client)) / float(g_iSwingSpeedLevels)));
}

public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Melee swings gain +%i{PERCENT} speed per %i levels\nDeploy melee instantly.\nMelee sets targets on fire.\n+%i{PERCENT} melee damage per %i levels.", RoundFloat(g_fSwingSpeedPerLevels * 100.0), g_iSwingSpeedLevels, RoundFloat(g_fMeleeDamagePerLevels * 100.0), g_iMeleeDamageLevels);
   	samuraiIndex = GunXP_RPGShop_RegisterSkill("Ultimate Samurai", "Ultimate Samurai", sDescription,
	80000, 200000);
}


