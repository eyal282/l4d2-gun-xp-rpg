
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
    name        = "Bodyguard Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that lets you reflect damage a survivor takes from non-Tank zombies to yourself.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int bodyguardIndex;

int g_iLastButtons[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

int g_iBodyguard[MAXPLAYERS+1];

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

public void OnMapStart()
{
    for(int i=0;i < sizeof(g_fNextExpireJump);i++)
    {
        g_fNextExpireJump[i] = 0.0;

        g_iJumpCount[i] = 0;
    }

    CreateTimer(0.5, Timer_MonitorBodyguard, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


public Action Timer_MonitorBodyguard(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(g_iBodyguard[i] == 0 || GetClientOfUserId(g_iBodyguard[i]) == 0)
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_IsPlayerIncapacitated(i))
            continue;

        else if(L4D_GetPinnedInfected(i) != 0 || L4D_GetAttackerCarry(i) != 0)
            continue;

        else if(HasMeleeEquipped(i))
            continue;

        int weapon = L4D_GetPlayerCurrentWeapon(i);

        if(weapon == -1)
            continue;

        else if(GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") > GetGameTime())
            continue;

        TryRemoveBodyguard(i);
    }

    return Plugin_Continue;
}
public void OnPluginStart()
{
    RegisterSkill();

    HookEvent("tongue_release", Event_PinEnded);
    HookEvent("pounce_end", Event_PinEnded);
    HookEvent("jockey_ride_end", Event_PinEnded);
    // Be careful not to carelessly alter active weapon here...
    HookEvent("charger_carry_end", Event_PinEnded);
    HookEvent("charger_pummel_end", Event_PinEnded);
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == -10)
    {
        if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
            return;

        else if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
            return;
        
        else if(damagetype & DMG_DROWNRECOVER)
            return;

        int bodyguard = GetRandomBodyguard(victim);

        if(bodyguard == 0)
            return;

        RPG_Perks_TakeDamage(bodyguard, attacker, inflictor, damage, damagetype);

        bImmune = true;
        
        return;
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    int lastButtons = g_iLastButtons[client];

    g_iLastButtons[client] = buttons;


    if(g_bSpam[client] || L4D_GetPinnedInfected(client) != 0 || L4D_GetAttackerCarry(client) != 0)
        return Plugin_Continue;

    if(buttons & IN_RELOAD && !(lastButtons & IN_RELOAD) && g_fNextExpireJump[client] > GetGameTime())
    {
    
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, bodyguardIndex))
        {
            ShowBodyguardMenu(client);
        }

        return Plugin_Continue;
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(buttons & IN_RELOAD)
        {
            g_iJumpCount[client]++;
        }
    }

    return Plugin_Continue;
}

public Action Timer_SpamOff(Handle Timer, int client)
{
    g_bSpam[client] = false;

    return Plugin_Continue;
}

public void ShowBodyguardMenu(int client)
{
    Handle hMenu = CreateMenu(Bodyguard_MenuHandler);

    for (int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(client == i)
            continue;

        else if(IsFakeClient(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        char strUserId[20], iName[128];
        IntToString(GetClientUserId(i), strUserId, sizeof(strUserId));
        GetClientName(i, iName, sizeof(iName));

        if(!IsPlayerAlive(i))
        {
            Format(iName, sizeof(iName), "%s [DEAD]", iName);
        }

        AddMenuItem(hMenu, strUserId, iName);
    }

    SetMenuTitle(hMenu, "Choose who to bodyguard:");

    DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int Bodyguard_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
        CloseHandle(hMenu);

    else if (action == MenuAction_Select)
    {
        char strUserId[20], strIgnoreable[1];
        int target;
        GetMenuItem(hMenu, item, strUserId, sizeof(strUserId), target, strIgnoreable, 0);

        target = GetClientOfUserId(StringToInt(strUserId));

        if(target == 0)
            return 0;
        
        else if(g_iBodyguard[client] == target)
            return 0;

        else if(g_iBodyguard[target] == GetClientUserId(client))
        {
            PrintToChat(client, "You cannot Bodyguard your Bodyguard.");

            return 0;
        }
        
        TryRemoveBodyguard(client);

        g_iBodyguard[client] = GetClientUserId(target);

        PrintToChat(client, "You are now %N's Bodyguard", target);
        PrintToChat(target, "%N is now your Bodyguard. They will take damage for you.", client);
    }

    return 0;
}


public Action Event_PinEnded(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));

    if(g_iBodyguard[victim] == 0 || GetClientOfUserId(g_iBodyguard[victim]) == 0)
        return Plugin_Continue;

    int activeWeapon = L4D_GetPlayerCurrentWeapon(victim);

    if(activeWeapon != -1)
    {
        int weapon = GetPlayerWeaponSlot(victim, L4D_WEAPON_SLOT_SECONDARY);

        if (weapon != -1)
        {
            char Classname[64];

            GetEdictClassname(weapon, Classname, sizeof(Classname));

            FakeClientCommand(victim, "use %s", Classname);
        }
    }

    return Plugin_Continue;
}

public void RegisterSkill()
{
    bodyguardIndex = GunXP_RPGShop_RegisterSkill("Bodyguard", "Bodyguard", "Triple click RELOAD with a Pistol / Melee to bodyguard a Survivor.\nBodyguard is removed when you change weapons.\nYou take the target's damage instead of them.\nIf a target has 2 Bodyguards, they will randomly split damage.",
    0, 600000);
}

stock bool HasMeleeEquipped(int client, int weapon = -1)
{
    if(weapon == -1)
    {
        weapon = L4D_GetPlayerCurrentWeapon(client);
    }

    if(GetPlayerWeaponSlot(client, L4D_WEAPON_SLOT_SECONDARY) == weapon)
    {
        return true;
    }

    return false;
}

stock int GetRandomBodyguard(int client)
{
    int players[MAXPLAYERS+1], count;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(g_iBodyguard[i] != GetClientUserId(client))
            continue;
        
        else if(i == client)
            continue;

        players[count++] = i;
    }

    if(count == 0)
        return 0;

    return players[GetRandomInt(0, count-1)];
}

stock void TryRemoveBodyguard(int bodyguard)
{
    if(g_iBodyguard[bodyguard] == 0)
        return;

    int target = GetClientOfUserId(g_iBodyguard[bodyguard]);

    g_iBodyguard[bodyguard] = 0;

    if(target != 0)
    {
        PrintToChat(bodyguard, "You are no longer %N's Bodyguard.", target);
        PrintToChat(target, "%N is no longer your Bodyguard", bodyguard);
    }
}