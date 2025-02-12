#include <GunXP-RPG>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

public Plugin myinfo =
{
    name        = "Cowboy Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to make pistols better",
    version     = PLUGIN_VERSION,
    url         = ""
};

int cowboyIndex = -1;

ConVar g_hDamagePriority;

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "GunXP_PerkTreeShop"))
    {
        RegisterPerkTree();
    }
}

public void OnConfigsExecuted()
{
    RegisterPerkTree();

}

public void OnPluginStart()
{
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

    RegisterPerkTree();

    AutoExecConfig_SetFile("GunXP-CowboyPerkTree.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_cowboy_damage_priority", "0", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public Action Event_WeaponFire(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if(weapon == -1)
        return Plugin_Continue;

    char sClassname[64];
    GetEdictClassname(weapon, sClassname, sizeof(sClassname));

    if(!StrEqual(sClassname, "weapon_pistol_magnum"))
        return Plugin_Continue;

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, cowboyIndex);

    if(perkLevel <= 3)
        return Plugin_Continue;

    SetEntProp(weapon, Prop_Send, "m_iClip1", 11);

    return Plugin_Continue;
}

public void WH_OnReloadModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, cowboyIndex);

    if(perkLevel <= 0)
        return;

    else if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_PistolMagnum)
        return;

    speedmodifier += 1.0;

    if(perkLevel <= 3)
        return;

    speedmodifier += 9.0;
}

public void WH_OnGetRateOfFire(int client, int weapon, int weapontype, float &speedmodifier)
{
    if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_PistolMagnum)
        return;
    
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, cowboyIndex);

    if(perkLevel <= 4)
        return;

    speedmodifier += 1.0;
}

// Requires RPG_Perks_RegisterReplicateCvar to fire.
public void RPG_Perks_OnGetReplicateCvarValue(int priority, int client, const char cvarName[64], char sValue[256])
{
    if(priority != 0)
        return;

    int weapon = L4D_GetPlayerCurrentWeapon(client);

    if(weapon == -1)
        return;
        
    else if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_PistolMagnum)
        return;

    else if(GunXP_RPGShop_IsPerkTreeUnlocked(client, cowboyIndex) <= 4)
        return;

    if(StrEqual(cvarName, "punch_angle_decay_rate"))
    {
        sValue = "999999999";
    }
    else if(StrEqual(cvarName, "z_gun_vertical_punch"))
    {
        sValue = "0";
    }
    else if(StrEqual(cvarName, "survivor_incapacitated_dizzy_severity", false) || StrEqual(cvarName, "survivor_incapacitated_accuracy_penalty"))
    {
        sValue = "0.0";
    }
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == 10 && damage > 0.0 && !bImmune && damage < GetEntityHealth(victim))
    {
        if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
            return;

        else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
            return;
            
        int weapon = L4D_GetPlayerCurrentWeapon(attacker);

        if(weapon == -1)
            return;
            
        else if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_PistolMagnum)
            return;

        else if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
            return;

        int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, cowboyIndex);

        if(perkLevel >= 3)
        { 
            RPG_Perks_ApplyEntityTimedAttribute(victim, "Frozen", 2.0, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
        }
        else if(perkLevel >= 2)
        {
            RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", 1.0, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
        }

        return;
    }
    if(priority != g_hDamagePriority.IntValue)
        return;

    else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

    else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return;

    int weapon = L4D_GetPlayerCurrentWeapon(attacker);

    if(weapon == -1)
        return;
        
    else if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_PistolMagnum)
        return;
        
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, cowboyIndex);

    if(perkLevel == -1)
        return;

    damage *= 2.0;

    if(perkLevel >= 5 && RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
    {
        damage /= 2.0;
    }
}
public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    descriptions.PushString("Magnum deals double damage");
    costs.Push(2000);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(20));

    descriptions.PushString("Double reload time of Magnum.");
    costs.Push(4000);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(34));

    descriptions.PushString("Magnum stuns non-Tank target for 1 second. Stacks.");
    costs.Push(5000);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(53));

    descriptions.PushString("Magnum freezes non-Tank target for 2 seconds instead. Stacks.");
    costs.Push(5000);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(54));

    descriptions.PushString("Magnum has unlimited ammo");
    costs.Push(25000);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(55));

    descriptions.PushString("Double Magnum's Firerate, but halve damage to Tank\nPerfect Steadiness with Magnum.");
    costs.Push(50000);
    xpReqs.Push(GunXP_RPG_GetXPForLevel(56));

    cowboyIndex = GunXP_RPGShop_RegisterPerkTree("Stronger Magnum", "Cowboy", descriptions, costs, xpReqs);

    if(LibraryExists("RPG_Perks"))
    {
        RPG_Perks_RegisterReplicateCvar("survivor_incapacitated_accuracy_penalty");
        RPG_Perks_RegisterReplicateCvar("survivor_incapacitated_dizzy_severity");
        RPG_Perks_RegisterReplicateCvar("punch_angle_decay_rate");
        RPG_Perks_RegisterReplicateCvar("z_gun_vertical_punch");
    }
}
