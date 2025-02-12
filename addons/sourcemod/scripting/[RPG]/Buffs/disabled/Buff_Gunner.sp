
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
    name        = "Gunner Buff --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Buff that makes guns deal more damage to SI",
    version     = PLUGIN_VERSION,
    url         = ""
};

int buffIndex;

// 0.1 = 10%
float bonusDamage = 0.1;

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

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority != 0)
        return;

    else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

    else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return;

    else if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank || RPG_Perks_GetZombieType(victim) == ZombieType_Witch || RPG_Perks_GetZombieType(victim) == ZombieType_CommonInfected)
        return;
        
    // This damage type is used to deal damage that ignores immunities. You probably don't want this as DMG_BULLET is applied by Immolation and Anger Ignition.
    else if(damagetype & DMG_DROWNRECOVER)
        return;
        
    else if(!(damagetype & DMG_BULLET))
        return;
    
    // Use GunXP_RPGShop_IsBuffUnlocked(attacker, hyperactiveIndex, true) if your buff ignores mutations.
    else if(!GunXP_RPGShop_IsBuffUnlocked(attacker, buffIndex))
        return;

    damage += damage * bonusDamage;
}

public void RegisterSkill()
{
    // buffWeight is the amount of buffs this buff weighs (steals from your buff slots). Setting below 1 will literally make it a skill (and it'll appear in skill shop instead)
    int buffWeight = 1;

    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Guns deal +%i{PERCENT} more damage to Special Infected", RoundFloat(bonusDamage * 100.0));

    buffIndex = GunXP_RPGShop_RegisterBuff("Guns do more damage to SI", "Gunner", sDescription,
    2000, GunXP_RPG_GetXPForLevel(25), buffWeight);
}