
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
    name        = "Eternal Flame Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes zombies you burn unextinguishable",
    version     = PLUGIN_VERSION,
    url         = ""
};

int eternalFlameIndex;

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
    HookEvent("player_hurt", Event_PlayerHurt);

    RegisterSkill();
}


public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public Action L4D_PlayerExtinguish(int client)
{
    if(RPG_Perks_GetZombieType(client) == ZombieType_NotInfected)
        return Plugin_Continue;

    else if(!RPG_Perks_IsEntityTimedAttribute(client, "Eternal Flame"))
        return Plugin_Continue;

    return Plugin_Handled;
}


public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

    char weaponName[16];
    GetEventString(hEvent, "weapon", weaponName, sizeof(weaponName));

    if(!StrEqual(weaponName, "entityflame"))
        return Plugin_Continue;

    // Invalid for zombies means dead.
    else if(RPG_Perks_GetZombieType(victim) == ZombieType_Invalid)
        return Plugin_Continue;

    else if(RPG_Perks_GetZombieType(victim) == ZombieType_NotInfected)
        return Plugin_Continue;

    else if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, eternalFlameIndex))
        return Plugin_Continue;

    if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
    {
        if(RPG_Tanks_CanBeIgnited(victim))
        {
            RPG_Perks_ApplyEntityTimedAttribute(victim, "Eternal Flame", 86400.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
            RPG_Perks_IgniteWithOwnership(victim, attacker);
        }
    }
    else
    {
        RPG_Perks_ApplyEntityTimedAttribute(victim, "Eternal Flame", 86400.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
        RPG_Perks_IgniteWithOwnership(victim, attacker);
    }   

    return Plugin_Continue;
}

public void RPG_Perks_OnIgniteWithOwnership(int victim, int attacker)
{
    if(RPG_Perks_GetZombieType(victim) == ZombieType_NotInfected)
        return;

    else if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, eternalFlameIndex))
        return;

    if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
    {
        if(RPG_Tanks_CanBeIgnited(victim))
        {
            RPG_Perks_ApplyEntityTimedAttribute(victim, "Eternal Flame", 86400.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
        }
    }
    else
    {
        RPG_Perks_ApplyEntityTimedAttribute(victim, "Eternal Flame", 86400.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
    }     
}
public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == 10)
    {
        if(damage == 0.0 || bImmune)
            return;
        
        else if(!WillDamageInflictBurn(inflictor, damagetype))
            return;

        else if(RPG_Perks_GetZombieType(victim) == ZombieType_NotInfected)
            return;

        else if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
            return;

        else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, eternalFlameIndex))
            return;

        if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
        {
            if(RPG_Tanks_CanBeIgnited(victim))
            {
                RPG_Perks_ApplyEntityTimedAttribute(victim, "Eternal Flame", 86400.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
                RPG_Perks_IgniteWithOwnership(victim, attacker);
            }
        }
        else
        {
            RPG_Perks_ApplyEntityTimedAttribute(victim, "Eternal Flame", 86400.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
            RPG_Perks_IgniteWithOwnership(victim, attacker);
        }
    }
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Zombies ignited by you cannot be extinguished");

    eternalFlameIndex = GunXP_RPGShop_RegisterSkill("Eternal Flame", "Eternal Flame", sDescription,
    10010, 40000);
}


stock bool WillDamageInflictBurn(int inflictor, int damagetype)
{
    if(damagetype & DMG_BURN)
        return true;

    if(L4D2_GetWeaponUpgrades(inflictor) & L4D2_WEPUPGFLAG_INCENDIARY && L4D2_GetWeaponUpgradeAmmoCount(inflictor) > 0)
        return true;

    return false;
}