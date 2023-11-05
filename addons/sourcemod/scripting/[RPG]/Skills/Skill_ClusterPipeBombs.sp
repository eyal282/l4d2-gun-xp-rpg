
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

float g_fSpawnTime[2049] = { -1.0, ... };

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

public void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
	if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_PipeBomb)
        return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
		return;

	speedmodifier = 10.0;
}

int g_iClusterCombo[2048];

float g_fChanceMultiplier = 4.0;

public void OnEntityCreated(int entity, const char[] classname)
{
    if(!IsValidEntityIndex(entity))
        return;

    g_fSpawnTime[entity] = GetGameTime();
    g_iClusterCombo[entity] = 0;
}
public void L4D_PipeBomb_Detonate_Post(int entity, int client)
{
    if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
        return;

    // Propane Tank / Oxygen Tank
    else if(g_fSpawnTime[entity] == GetGameTime())
        return;

    float fOrigin[3];
    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

    float fChance = (0.01 * g_fChanceMultiplier * float(GunXP_RPG_GetClientLevel(client))) / Pow(2.0, float(g_iClusterCombo[entity]));

    if(fChance * 100.0 < float(GunXP_RPG_GetClientLevel(client)))
        fChance = (0.01 * float(GunXP_RPG_GetClientLevel(client)));

    float fGamble = GetRandomFloat(0.0, 1.0);

    if(fGamble < fChance)
    {
        float fVelocity[3], fAngle[3];

        fVelocity[0] = GetRandomFloat(30.0, 50.0);
        fVelocity[1] = GetRandomFloat(30.0, 50.0);
        fVelocity[2] = GetRandomFloat(250.0, 300.0);

        for(int i=0;i < 2;i++)
        {
            if(GetRandomInt(0, 1) == 1)
            {
                fVelocity[i] *= -1.0;
            }
        }
        
        fAngle[0] = GetRandomFloat(300.0, 500.0);
        fAngle[1] = GetRandomFloat(300.0, 500.0);
        fAngle[2] = GetRandomFloat(-500.0, 500.0);

        int weapon = L4D_PipeBombPrj(client, fOrigin, fAngle, true);

        TeleportEntity(weapon, NULL_VECTOR, fAngle, fVelocity);

        L4D_AngularVelocity(entity, fAngle);

        g_iClusterCombo[weapon] = g_iClusterCombo[entity] + 1;

        PrintToChat(client, "Pipe Cluster Combo #%i ( %.0f%% )", g_iClusterCombo[weapon], fChance * 100.0);
    }
    else if(g_iClusterCombo[entity] > 0)
    {
        float fTotalChance = 1.0;
        for(int i=1;i < g_iClusterCombo[entity];i++)
        {
            float fCurChance = (0.01 * g_fChanceMultiplier * float(GunXP_RPG_GetClientLevel(client))) / Pow(2.0, float(i));

            if(fCurChance * 100.0 < float(GunXP_RPG_GetClientLevel(client)))
                fCurChance = (0.01 * float(GunXP_RPG_GetClientLevel(client)));

            if(fCurChance < 1.0)
            {
                fTotalChance *= fCurChance;
            }
        }
        PrintToChat(client, "Pipe Cluster Combo Ended #%i ( Σ%.7f%% )", g_iClusterCombo[entity], fTotalChance * 100.0);
    }
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Whenever a pipe bomb detonates, another may spawn.\nChance equals your level x%.0f.\nEach cluster, chance halves capped at your level.\nAn infinite recursion may occur with this Skill.\nDeploy Pipe Bombs instantly", g_fChanceMultiplier);

    skillIndex = GunXP_RPGShop_RegisterSkill("Cluster Pipe Bombs", "Cluster Pipe Bombs", sDescription,
    27000, 0);
}




bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}