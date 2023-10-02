
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
    name        = "Cluster Pipe Bombs Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes pipe bombs cluster. Chance for infininte recursion.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int skillIndex;

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
    HookEvent("adrenaline_used", Event_AdrenalineUsed);
    HookEvent("pills_used", Event_PillsUsed);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    int healed = GetClientOfUserId(GetEventInt(event, "subject"));

    if(client == 0)
        return Plugin_Continue;
    
    TryClearDebuffs(healed, client, true);

    return Plugin_Continue;
}

public Action Event_AdrenalineUsed(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(client == 0)
        return Plugin_Continue;

    TryClearDebuffs(client, client);

    return Plugin_Continue;
}


public Action Event_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(client == 0)
        return Plugin_Continue;

    TryClearDebuffs(client, client);

    return Plugin_Continue;
}

stock void TryClearDebuffs(int victim, int healer, bool bCertain = false)
{
    float fDuration = -1.0;

    bool bSkillActive = false;

    if(RPG_Perks_IsEntityTimedAttribute(healer, "Mutated", fDuration))
    {
        RPG_Perks_ApplyEntityTimedAttribute(healer, "Mutated", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
    }

    bSkillActive = GunXP_RPGShop_IsSkillUnlocked(healer, skillIndex);    

    if(!bCertain)
    {
        float fChance = g_fChancePerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(victim)) / float(g_iChanceLevels)));

        float fGamble = GetRandomFloat(0.0, 1.0);

        if(fGamble >= fChance)
            bSkillActive = false;
    }

    if(fDuration != -1.0)
    {
        RPG_Perks_ApplyEntityTimedAttribute(healer, "Mutated", fDuration, COLLISION_SET, ATTRIBUTE_NEGATIVE);
    }

    if(bSkillActive)
    {
        ArrayList aAttributes = RPG_Perks_GetEntityTimedAttributes(victim, ATTRIBUTE_NEGATIVE);

        for(int i=0;i < aAttributes.Length;i++)
        {
            char attributeName[64];
            aAttributes.GetString(i, attributeName, sizeof(attributeName));

            RPG_Perks_ApplyEntityTimedAttribute(victim, attributeName, 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE);
        }

        delete aAttributes;
    }
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Using a First Aid Kit clears all debuffs.\nUsing Adrenaline or Pills has a chance to clear all debuffs.\nChance is %.1f{PERCENT} per %i Levels\nThis skill is active even under MUTATED debuff.", g_fChancePerLevels * 100.0, g_iChanceLevels);
    skillIndex = GunXP_RPGShop_RegisterSkill("Medkit Clears Debuffs", "Special First Aid", sDescription,
    40000, 0);
}


