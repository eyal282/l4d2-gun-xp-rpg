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
    name        = "Splitter Tank --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Tank that splits into smaller tanks on death",
    version     = PLUGIN_VERSION,
    url         = ""
};

int tankIndexSplitter;
int tankIndexSpliter;
int tankIndexSplier;

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "RPG_Tanks"))
    {
        RegisterTanks();
    }
}

public void OnConfigsExecuted()
{
    RegisterTanks();
}

public void OnPluginStart()
{
    RegisterTanks();
}

public void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward)
{
    int tankType = RPG_Tanks_GetClientTank(victim);
    
    if(tankType == tankIndexSplitter)
    {
        SpawnSplitTanks(victim, tankIndexSpliter);
    }
    else if(tankType == tankIndexSpliter)
    {
        SpawnSplitTanks(victim, tankIndexSplier);
    }
}

void SpawnSplitTanks(int victim, int nextTankType)
{
    float origin[3];
    GetClientAbsOrigin(victim, origin);
    
    for(int i = 0; i < 2; i++)
    {
        RPG_Tanks_SetOverrideTank(nextTankType);
        
        int newTank = RPG_Tanks_SpawnTank(nextTankType);
        if(newTank > 0)
        {
            TeleportEntity(newTank, origin, NULL_VECTOR, NULL_VECTOR);
            
            int maxHealth = RPG_Perks_GetClientMaxHealth(newTank);
            RPG_Perks_SetClientMaxHealth(newTank, maxHealth / 2);
            RPG_Perks_SetClientHealth(newTank, maxHealth / 2);
        }
    }
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RegisterTanks()
{
    // Only Splitter can spawn naturally, others spawn from splits
    tankIndexSplitter = RPG_Tanks_RegisterTank(2, 3, "Splitter", 
        "A tank that splits into two Spliter tanks when killed\nSpliter tanks split into Splier tanks\nSplier tanks are the final form", 
        "Splits into 2 Spliter tanks on death", 
        200000, 180, 1.0, 300, 400, NO_DAMAGE_IMMUNITY, 
        GunXP_GenerateHexColor(255, 165, 0));

    // Register with 0 entries since they only spawn from splits
    tankIndexSpliter = RPG_Tanks_RegisterTank(2, 0, "Spliter", 
        "A tank born from a Splitter's death\nSplits into two Splier tanks when killed", 
        "Splits into 2 Splier tanks on death", 
        100000, 180, 1.0, 200, 250, NO_DAMAGE_IMMUNITY, 
        GunXP_GenerateHexColor(200, 130, 0));

    tankIndexSplier = RPG_Tanks_RegisterTank(2, 0, "Splier", 
        "The final form of the splitting process\nDoes not split further", 
        "Final form, does not split", 
        50000, 180, 1.0, 100, 150, NO_DAMAGE_IMMUNITY, 
        GunXP_GenerateHexColor(150, 100, 0));

    RPG_Tanks_RegisterPassiveAbility(tankIndexSplitter, "Split", "On death, splits into two Spliter tanks with half health");
    RPG_Tanks_RegisterPassiveAbility(tankIndexSpliter, "Split", "On death, splits into two Splier tanks with half health");
    RPG_Tanks_RegisterPassiveAbility(tankIndexSplier, "Final Form", "The last stage of splitting");
}
