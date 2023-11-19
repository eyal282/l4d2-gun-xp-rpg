
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
    name        = "Protective Medkit Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes medkit make you temporarily invincible.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int skillIndex;

float g_fChancePerLevels = 0.1;
int g_iChanceLevels = 5;

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
    HookEvent("heal_success", Event_HealSuccess);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
    if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
        return;

    switch(L4D2_GetWeaponId(weapon))
    {
        case L4D2WeaponId_FirstAidKit:
        {
            speedmodifier = 10.0;
        }
    }
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    int healed = GetClientOfUserId(GetEventInt(event, "subject"));

    if(client == 0)
        return Plugin_Continue;
    
    else if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
        return Plugin_Continue;

    float fDuration = 6.5;

    fDuration += (float(GunXP_RPG_GetClientLevel(client)) / 10.0);

    RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);

    return Plugin_Continue;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Using a First Aid Kit makes you invincible.\nDuration = (level % 10) + 6.5 sec\nDeploy medkit instantly.");
    skillIndex = GunXP_RPGShop_RegisterSkill("Medkit Gives Invincibility", "Protective Medkit", sDescription,
    55000, 0);
}


