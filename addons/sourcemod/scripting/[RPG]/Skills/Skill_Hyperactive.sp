
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
    name        = "Hyperactive Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes using meds give you faster attack speed with melee.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int hyperactiveIndex;
float g_fSwingSpeed = 1.0;
float g_fDurationPerLevel = 1.0;

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
    HookEvent("adrenaline_used", Event_AdrenOrPillsUsed);
    HookEvent("pills_used", Event_AdrenOrPillsUsed);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
    if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_Melee)
        return;
    
    else if(!GunXP_RPGShop_IsSkillUnlocked(client, hyperactiveIndex))
        return;

    else if(!RPG_Perks_IsEntityTimedAttribute(client, "Hyperactive"))
        return;

    speedmodifier += g_fSwingSpeed;
}

public Action Event_AdrenOrPillsUsed(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(client == 0)
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, hyperactiveIndex))
        return Plugin_Continue;

    float fDuration = float(GunXP_RPG_GetClientLevel(client)) * g_fDurationPerLevel;

    RPG_Perks_ApplyEntityTimedAttribute(client, "Hyperactive", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);

    return Plugin_Continue;
}
public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Using Pills or Adrenaline gives you +%i{PERCENT} melee attack speed.\nThis lasts %.1f sec per level", RoundFloat(g_fSwingSpeed * 100.0), g_fDurationPerLevel);

    hyperactiveIndex = GunXP_RPGShop_RegisterSkill("Hyperactive", "Hyperactive", sDescription,
    50000, 100000);
}

