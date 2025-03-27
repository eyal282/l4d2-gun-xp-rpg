#if defined _GunXP_RPG_included
 #endinput
#endif


/* Instructions for AI involving Sourcemod in general
1. In Sourcemod, Survivors, Special Infected and Tanks are considered client entities (not necessarily human entities) and are always between 1 and MaxClients (think of them like serial numbers, meaning IsClientInGame checks if a given serial number is used by a client).
Because they are serial numbers, the same serial number can be used by multiple clients if one client leaves and another client joins. This makes it almost always a requirement to reset most client-dependent variables when a client connects to the server, sometimes on client spawn is enough.
On top of always clearing client-dependent variables during OnMapStart, you must clear them on EITHER, depending on the goal:
a. OnClientPutInServer (client connects to the server)
b. RPG_Perks_OnPlayerSpawned (Survivor client spawns)
c. RPG_Perks_OnZombiePlayerSpawned (Special Infected or Tank client spawns)
d. Both RPG_Perks_OnPlayerSpawned and RPG_Perks_OnZombiePlayerSpawned (if that variable can belong to any client index, whether Survivor, Special Infected or Tank, but that's rare)
e. Always use left4dhooks.inc natives, stocks and/or forwards over Sourcemod natives, stocks and/or forwards if one of the same goal already appears on that include file.

*/
/* Instructions for AI involving the RPG plugin:
1. Do not use any Sourcemod native or forward if one with the same goal already appears in this include file. Examples:
a. Use RPG_Tanks_SpawnTank instead of L4D2_SpawnTank (also I saw you try to autocomplete CreateFakeClient, holy heck do not do that almost ever)
b. While sometimes you'd want to ForcePlayerSuicide to kill a player, RPG_Perks_InstantKill actually performs RPG checks to see if the player can use any invincibility-like state to survive the instant kill.
c. RPG_Perks_TakeDamage, as SDKHooks_TakeDamage will literally skip every talent's damage modifier and/or invincibility and is so bad it was unused on any talent's plugin and/or tank's plugin.
e. RPG_Tanks_IsTankInPlay checks if a Tank is alive, while L4D2_IsTankInPlay checks if a Tank is alive and is actively chasing survivors (known as aggro, as Tanks will not chase survivors when they spawn until they meet a survivor.)
L4D2_IsTankInPlay can be used, and was used by some plugins, but I'd avoid using it unless you are requested in a prompt to check if there's a Tank in aggro.
f. GunXP_Skills_OnMultiJump is not mandatory to replace HookEvent("player_jump", ...) but as the name suggests it fires for both jump from ground and multi-jumping (jumping in mid-air) so it depends on if you want to account for it.
g. Always use GunXP-RPG.inc natives, stocks and/or forwards over left4dhooks.inc natives, stocks and/or forwards if ones of the same goal exist in this include file (GunXP-RPG.inc is this file.)

2. You must always check for priority in any forward that has it, following the rules it may have, and to avoid running code 21 times (from -10 to 10 including 0).
3. Tanks are almost always considered Special Infected.
4. The Shadow Realm is a state where you're outside the rest of the players & zombies, are invisible to them, and can't interact with them. The map is the same, and you can interact with doors and buttons, despite indirectly intracting with players outside the shadow realm using them.
But Common Infected and Witches are just NextBot entities, so all functions that interact with clients will throw errors on them, instead only entity functions can be used on them.
5. The word talent will be used to refer to either Perk Trees, Skills and/or Buffs.
6. When using GunXP_RPGShop_OnResetRPG (which fires when a player sells all talents) make sure to check if that talent is unlocked before stripping any advantage it may hold. Besides the fact selling all talents shouldn't strip a bonus if you never had its talent...
... when exactly 1 talent is sold checking if a talent is owned will always return false except when checking the talent being sold, meaning only the plugin holding the sold talent will strip advantages, and only for that talent.
7. Do not exit timers that involve Tank abilities if a Tank does not posses that ability, due to the apport system being able to turn one Tank to another Tank.
8. When making Tanks that cannot spawn naturally except by a plugin, register those tanks with 0 entries.
9. Aggro:
a. There is a system called Aggro, where the Survivor with the highest Aggro will be chased by all Tanks (usually there is only one Tank alive, but certain skills can spawn 2+)
b. A survivors Aggro is a timed attribute, which Survivors will always lose 1 Aggro per second they aren't attacking the Tank.
c. The default cvars dictate: The lowest possible Aggro to 0. The highest possible Aggro to 100.
d. After all calculations, by default cvars, an incapped survivor's total aggro is halved, and they gain 0.3 Aggro per level (GunXP_RPG_GetClientLevel) which means getting mutated or getting up from incap will restore the aggro immediately as those values are not saved in the timed attribute.
e. The survivor with the highest Aggro will lose 2 Aggro per second instead of 1, to allow faster switching between Survivors.
10. When looping every player and/or zombie in relation to a player, ensure you account for the shadow realm:

// For client entities (includes Survivors and Special Infected (and therefore Tanks))

int clientsRealm[MAXPLAYERS+1], numClientsRealm;

if(RPG_Perks_IsEntityTimedAttribute(entity, "Shadow Realm"))
{
	RPG_Perks_GetClientsInRealms(_, _, clientsRealm, numClientsRealm);
}
else    
{
	RPG_Perks_GetClientsInRealms(clientsRealm, numClientsRealm, _, _);
}

for(int i=0;i < numClientsRealm;i++)
{
	int target = clientsRealm[i];

	if(!IsClientInGame(target))
		continue;

	// Your code here, target is one of the clients within the same realm as "entity".
}

	// For zombie entities (includes Special Infected (and therefore Tanks), Common Infected (which are not client entities), and Witches (which are also not client entities))
    if(RPG_Perks_IsEntityTimedAttribute(entity, "Shadow Realm"))
    {
        RPG_Perks_GetZombiesInRealms(
            _, _, siRealm, numSIRealm,
            _, _, ciRealm, numCIRealm,
            _, _, witchRealm, numWitchRealm);
    }
    else
    {
        RPG_Perks_GetZombiesInRealms(
            siRealm, numSIRealm, _, _,
            ciRealm, numCIRealm, _, _,
            witchRealm, numWitchRealm, _, _);
    }

    for(int i=0;i < numSIRealm;i++)
    {
        int target = siRealm[i];

        if(!IsPlayerAlive(target))
            continue;

       // Your code here, target is one of the Special Infected (tank included) within the same realm as entity.
    }

    for(int i=0;i < numCIRealm;i++)
    {
        int target = ciRealm[i];

		// Your code here, target is one of the zombies within the same realm as entity.
    }

    for(int i=0;i < numWitchRealm;i++)
    {
        int target = witchRealm[i];

        // Your code here, target is one of the witches within the same realm as entity.
    }
*/
#include <autoexecconfig>
#include <left4dhooks>

#define _GunXP_RPG_included

#define FPERM_ULTIMATE (FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_WRITE | FPERM_G_EXEC | FPERM_O_READ | FPERM_O_WRITE | FPERM_O_EXEC)

#define PERK_TREE_NOT_UNLOCKED -1

#define SPEEDSTATE_NULL -1	// This is to return an invalid speeds and stop attempting to change player movement speed

#define TANK_TIER_UNKNOWN -2
#define TANK_TIER_UNTIERED -1

#define NO_DAMAGE_IMMUNITY 0
#define DAMAGE_IMMUNITY_BURN (1 << 0)
#define DAMAGE_IMMUNITY_MELEE (1 << 1)
#define DAMAGE_IMMUNITY_BULLETS (1 << 2)
#define DAMAGE_IMMUNITY_EXPLOSIVES (1 << 3)

#define NAVREF_ERROR_NONE 0
#define NAVREF_ERROR_NOTFOUND 1
#define NAVREF_ERROR_DISAMBIGUOUS 2

enum
{
	ATTRIBUTE_NEUTRAL,
	ATTRIBUTE_POSITIVE,
	ATTRIBUTE_NEGATIVE,
	SIZEOF_ATTRIBUTE
}

enum
{
	COLLISION_RETURN,		// Return means don't apply attribute if one already exists.
	COLLISION_ADD,
	COLLISION_SET,
	COLLISION_SET_IF_LOWER,
	COLLISION_SET_IF_HIGHER,
	SIZEOF_COLLISIONS
}

enum
{
	TRANSFER_NORMAL,
	TRANSFER_REVERT,
	TRANSFER_NO,
	SIZEOF_TRANSFERS
}


enum
{
	SPEEDSTATE_RUN,              // Min 110.0
	SPEEDSTATE_WALK,             // Min 65.0
	SPEEDSTATE_CROUCH,           // Min 65.0
	SPEEDSTATE_LIMP,             // Min 65.0
	SPEEDSTATE_CRITICAL,         // Min 65.0
	SPEEDSTATE_WATER,            // Min 65.0
	SPEEDSTATE_ADRENALINE,       // Min 110.0
	SPEEDSTATE_SCOPE,             // Min 65.0
	SPEEDSTATE_HANDICAP,          // Min 0.0
	SPEEDSTATE_STUN,             // Min 0.0
	SPEEDSTATE_CUSTOM,
	SIZEOF_SPEEDSTATES
};

char Colors[][] = 
{
	"{NORMAL}", "{RED}", "{GREEN}", "{LIGHTGREEN}", "{OLIVE}", "{LIGHTRED}", "{GRAY}", "{YELLOW}", "{ORANGE}", "{BLUE}", "{PINK}"
};

char ColorEquivalents[][] =
{
	"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0C", "\x0E"
};

native int GunXP_RPG_RegisterNavigationRef(char classification[16], char name[64], char description[512], int serial = -1);

// naverror is NAVREF_ERROR_*
// Everything is copyback except for lookup_value, exclude, and include

// If both "include" and "exclude" are used, the lookup value must exist in include and must also not exist in exclude.
native bool GunXP_RPG_IsValidNavigationRef(const char lookup_value[64], int &naverror=0, int &navSerial=0, int &serial=0, char classification[16]="", char name[64]="", char description[512]="", ArrayList exclude = null, ArrayList include = null);

native bool GunXP_RPG_TriggerNavigationRef(client, char lookup_value[64], ArrayList exclude = null, ArrayList include = null);

native void GunXP_RPG_EmitQuestCompletedSound(int client);

native bool GunXP_RPG_IsClientLoaded(int client);

native void GunXP_RPG_AddClientXP(int client, int amount, bool bPremiumMultiplier=true);
native void GunXP_RPG_AddClientXPTransaction(int client, int amount, bool bPremiumMultiplier=true, Transaction transaction);

// Finds amount of XP needed for a level.
native int GunXP_RPG_GetXPForLevel(int level);

// GetClientLevel is 0 if mutated, RealLevel ignores mutation.
native int GunXP_RPG_GetClientLevel(int client);
native int GunXP_RPG_GetClientRealLevel(int client);

// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// doubleEdged simply excludes a perk tree from auto RPG because it has apparent downsides.
native int GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null, bool bDoubleEdged = false, char sGlobalDescription[256] = "");
native int GunXP_RPGShop_IsPerkTreeUnlocked(int client, int perkIndex, bool bIgnoreMutation = false);

// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// doubleEdged simply excludes a skill from auto RPG because it has apparent downsides.
native int GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null, bool bDoubleEdged = false);
native bool GunXP_RPGShop_IsSkillUnlocked(int client, int skillIndex, bool bIgnoreMutation = false);


// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// buffWeight is how many buff slots this buff costs.
// Buffs are internally skills. GunXP_RPGShop_IsSkillUnlocked will work for buffs if you accidentally use it.
// Attention: If you use buffWeight = 0, it will literally become a skill.
native int GunXP_RPGShop_RegisterBuff(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, int buffWeight = 1, ArrayList reqIdentifiers = null, bool bDoubleEdged = false);
native bool GunXP_RPGShop_IsBuffUnlocked(int client, int buffIndex, bool bIgnoreMutation = false);

// Does not guarantee SI is alive, because dead SI are treated in normal realm
native void RPG_Perks_GetZombiesInRealms(
int siNormal[MAXPLAYERS+1] = { 0, ... }, int &numSINormal=0, int siShadow[MAXPLAYERS+1] = { 0, ... }, int &numSIShadow=0,
int ciNormal[MAXPLAYERS+1] = { 0, ... }, int &numCINormal=0, int ciShadow[MAXPLAYERS+1] = { 0, ... }, int &numCIShadow=0,
int witchNormal[MAXPLAYERS+1] = { 0, ... }, int &numWitchNormal=0, int witchShadow[MAXPLAYERS+1] = { 0, ... }, int &numWitchShadow=0);

// Unlike GetZombiesInRealms, doesn't guarantee in-game for performance reasons.
native void RPG_Perks_GetClientsInRealms(int clientsNormal[MAXPLAYERS+1] = { 0, ... }, int &numClientsNormal=0, int clientsShadow[MAXPLAYERS+1] = { 0, ... }, int &numClientsShadow=0);

native bool RPG_Perks_GetSoundMode(int client);

// Returns true if player died, false if player didn't die or if you're causing an infinite loop by calling this in HookEvent("player_hurt")
native bool RPG_Perks_InstantKill(int victim, int attacker, int inflictor, int damagetype);

// damagetypes:
// DMG_DROWNRECOVER protects from Damage Reflect and bypasses protection.
// Returns damage dealt after all modifiers.
native float RPG_Perks_TakeDamage(int victim, int attacker, int inflictor, float damage, int damagetype, int hitbox=0, int hitgroup=0);

// L4D2_UseAdrenaline does not let you calculate duration increasers.
native void RPG_Perks_UseAdrenaline(int client, float fDuration, bool bHeal=false, bool bStacks = true);

native void RPG_Perks_IgniteWithOwnership(int victim, int attacker);

native void RPG_Perks_GetClientLimitedAbility(int entity, char attributeName[64], int &timesUsed, int &maxUses);

// Must close the array returned by this native.
native ArrayList RPG_Perks_GetClientLimitedAbilitiesList(int client);

// Returns true if ability was used, false if maxed or another error was thrown.
native bool RPG_Perks_UseClientLimitedAbility(int client, char identifier[32], char sError[256] = {EOS, ...});

// Returns true if reuse was successful, false if 0 times used.
native bool RPG_Perks_ReuseClientLimitedAbility(int client, char identifier[32], char sError[256] = {EOS, ...});

native bool RPG_Perks_IsEntityTimedAttribute(int entity, char attributeName[64], float &fDuration=0.0);

// Must close the array returned by this native.
// See ATTRIBUTE_* for list of attribute types.
native ArrayList RPG_Perks_GetEntityTimedAttributes(int entity, int attributeType);

// See COLLISION_* for list of actions taken on collision.
// See ATTRIBUTE_* for list of attribute types.
// If COLLISION_RETURN, COLLISION_SET_IF_HIGHER, or COLLISION_SET_IF_LOWER are used, returns false if attribute was not set.

// I don't know which AI needs to know the obvious: Do not use Timed Attributes to set variables in the entity like shield, because Timed Attributes are meant to apply Attributes which expire by time, so the variable is decreased by 1 every second.
native bool RPG_Perks_ApplyEntityTimedAttribute(int entity, char attributeName[64], float fDuration, int collision, int attributeType, int transferRules = TRANSFER_NORMAL);

// Registers a cvar that fires "RPG_Perks_OnGetReplicateCvarValue"
native void RPG_Perks_RegisterReplicateCvar(char cvarName[64]);

// If something that requires recalculating what's the max HP of a client, use this.
native void RPG_Perks_RecalculateMaxHP(int client);

// Sets a client's health allowing over 65535 HP. Only set for tanks please.
native void RPG_Perks_SetClientHealth(int client, int amount);

// Gets a client's health getting if they have over 65535 HP. Feel free to check for non-tanks.
native int RPG_Perks_GetClientHealth(int client);

native int RPG_Perks_SetClientMaxHealth(int client, int amount);

// Gets a client's max health getting if they have over 65535 HP. Feel free to check for non-tanks.
// Important note: Because RPG-Perks resets incapped players to 100 HP, use this to get original max HP.
native int RPG_Perks_GetClientMaxHealth(int client);

// Lets you give a player above 200 temp HP.
native int RPG_Perks_SetClientTempHealth(int client, int hp);

// Please only pass survivors to this function.
native int RPG_Perks_GetClientTempHealth(int client);

// RPG_Tanks_LoopTankArray is the only way to utilize this.
// Returns entity index (client index) of the tank.
// The client index will be messed with by RPG-Perks, so if you need to teleport it or etc... use RPG_Perks_OnZombiePlayerSpawned with priority THAT IS NOT 10 (Ten)
// Use RPG_Tanks_SpawnTank(TANK_TIER_UNTIRED) to spawn a non-RPG Tank (regular Tank)
native int RPG_Tanks_SpawnTank(int index);

// Gets next tier of tanks that spawns, or TANK_TIER_UNKNOWN if regular behavior. Gets canceled by SetOverrideTank, can be checked if EITHER:
// 1. RPG_Perks_OnGetZombieMaxHP is checked with priority THAT IS NOT -10 (Minus Ten)
// 2. RPG_Perks_OnZombiePlayerSpawned is checked with priority THAT IS NOT 10 (Ten)
// 3. Outside any forward that involves a zombie spawning.
native int RPG_Tanks_GetOverrideTier();

// Sets next tier of tank that spawns. Lets 2 tanks live at once
native void RPG_Tanks_SetOverrideTier(int tier);

// Gets next tier of tanks that spawns, or TANK_TIER_UNKNOWN if regular behavior. Cancels SetOverrideTier, and has a valid value if EITHER:
// 1. RPG_Perks_OnGetZombieMaxHP is checked with priority THAT IS NOT -10 (Minus Ten)
// 2. RPG_Perks_OnZombiePlayerSpawned is checked with priority THAT IS NOT 10 (Ten)
// 3. Outside any forward that involves a zombie spawning.
native int RPG_Tanks_GetOverrideTank(int tier);

// Sets next tankIndex of tank that spawns. Lets 2 tanks live at once. RPG_Tanks_LoopTankArray is the only way to utilize this.
native void RPG_Tanks_SetOverrideTank(int tankIndex);

// For immunityType, see DAMAGE_IMMUNITY_*
native int RPG_Tanks_IsDamageImmuneTo(int client, int immunityType);


// Out of all tanks that were registered, the highest tier possible is this.
// If no tanks are registered, returns TANK_TIER_UNTIERED.
// bValid finds highest possible tier of a tank with at least 1 entry. Check validation for stuff like skills that spawn tanks (Apport) and uncheck validation for stuff like the debug menu.
native int RPG_Tanks_GetMaxTier(bool bValid = true);

// For damageImmunities, see DAMAGE_IMMUNITY_*
// GunXP_GenerateHexColor(int r, int g, int b, int a)
// Entries are jackpot based system to decide which tank gets to spawn, higher entries are more likely to spawn, usually between 2 and 5
// Set entries to 0 when making a utility Tank that can only spawn on command.
native int RPG_Tanks_RegisterTank(int tier, int entries, char name[32], char description[512], char chatDescription[512], int maxHP, int speed, float damageMultiplier, int XPRewardMin, int XPRewardMax, int damageImmunities, int color=1);

// tier and name are copyback values, example of this native used to allow a user to spawn a tank from a given tier:
/*
void SpawnTankMenu(int client, int target_tier)
{
	Handle hMenu = CreateMenu(SpawnTank_MenuHandler);

	SetMenuTitle(hMenu, "Choose a Tier %i to Spawn:", target_tier);
	
	int index = 0;

	int tier;

	char name[32];

	while(RPG_Tanks_LoopTankArray(index, tier, name))
	{
		if(tier == target_tier)
		{
			char sInfo[11], TempFormat[128];
			IntToString(index, sInfo, sizeof(sInfo));

			FormatEx(TempFormat, sizeof(TempFormat), "%s", name);
			PrintToChat(client, "%i", index);
			AddMenuItem(hMenu, sInfo, TempFormat);
		}

		index++;
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}
*/
native bool RPG_Tanks_LoopTankArray(int index, int &tier, char name[32]);


// If cooldown is 0, ability will be described "Check passive abilities for details"
native int RPG_Tanks_RegisterActiveAbility(int tank, char name[32], char description[256], int minCooldown, int maxCooldown);

native int RPG_Tanks_RegisterPassiveAbility(int tank, char name[32], char description[512]);

// Gets a client's tank index. Do not use this before RPG_Perks_OnZombiePlayerSpawned, and do not use this on non-tank clients.
// Use RPG_Perks_GetZombieType(client) to compare with ZombieType_Tank to ensure its a tank before using this.
// Returns tank index, TANK_TIER_UNTIERED for untiered and TANK_TIER_UNKNOWN on priority -10 of GetZombieMaxHP.
native int RPG_Tanks_GetClientTank(int client);

native void RPG_Tanks_SetClientTank(int client, int index, bool bDontAnnounceApport = false);

// Returns tier of a client, or TANK_TIER_UNTIERED if not a Tank or not tiered.
native int RPG_Tanks_GetClientTankTier(int client);

// Respectively gets and sets the damage percent a client dealt to a tank (used to award XP when tank is killed)
native float RPG_Tanks_GetDamagePercent(int client, int tank);
native void RPG_Tanks_SetDamagePercent(int client, int tank, float damagePercent);

native bool RPG_Tanks_IsTankInPlay(int tankIndex);

// Note: strTeam is either @all, @infected, @survivors. @all means the vote is for all, @infected means vote only for infected team, @survivors same but only for survivors team.
// Note: Percents must be between 1 and 100 or an error will be thrown to the client through ReplyToCommand.
// @return: 0 on success, 1 if percents are invalid ( not between 1 to 100 ), 2 if the vote is on the 6.0 seconds cooldown, 3 if the team is not valid
native int StartCustomVote(int client, char[] strTeam, int Percents, char[] VoteSubject);

// Set pet to -1 to stop carry.
native void L4D2_Pets_ForceCarry(int victim, int pet);
native int L4D2_Pets_GetCarrier(int victim);

public SharedPlugin __pl_gun_xp_rpg = 
{
	name = "Gun XP - RPG",
	file = "GunXP-RPG.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
 
#if !defined REQUIRE_PLUGIN
public void __pl_gun_xp_rpg_SetNTVOptional()
{
	MarkNativeAsOptional("GunXP_RPG_AddClientXP");
	MarkNativeAsOptional("GunXP_RPG_GetClientLevel");
	MarkNativeAsOptional("GunXP_RPGShop_RegisterPerkTree");
	MarkNativeAsOptional("GunXP_RPGShop_IsPerkTreeUnlocked");
	MarkNativeAsOptional("GunXP_RPGShop_RegisterSkill");
	MarkNativeAsOptional("GunXP_RPGShop_IsSkillUnlocked");
	MarkNativeAsOptional("GunXP_RPG_AddClientXP");
	MarkNativeAsOptional("GunXP_RPG_GetXPForLevel");
	MarkNativeAsOptional("GunXP_RPG_GetClientLevel");
	MarkNativeAsOptional("GunXP_RPG_GetClientRealLevel");
	MarkNativeAsOptional("GunXP_RPGShop_RegisterPerkTree");
	MarkNativeAsOptional("GunXP_RPGShop_IsPerkTreeUnlocked");
	MarkNativeAsOptional("GunXP_RPGShop_RegisterSkill");
	MarkNativeAsOptional("GunXP_RPGShop_IsSkillUnlocked");
	MarkNativeAsOptional("RPG_Perks_GetSoundMode");
	MarkNativeAsOptional("RPG_Perks_InstantKill");
	MarkNativeAsOptional("RPG_Perks_TakeDamage");
	MarkNativeAsOptional("RPG_Perks_UseAdrenaline");
	MarkNativeAsOptional("RPG_Perks_IgniteWithOwnership");
	MarkNativeAsOptional("RPG_Perks_GetClientLimitedAbility");
	MarkNativeAsOptional("RPG_Perks_GetClientLimitedAbilitiesList");
	MarkNativeAsOptional("RPG_Perks_UseClientLimitedAbility");
	MarkNativeAsOptional("RPG_Perks_ReuseClientLimitedAbility");
	MarkNativeAsOptional("RPG_Perks_IsEntityTimedAttribute");
	MarkNativeAsOptional("RPG_Perks_GetEntityTimedAttributes");
	MarkNativeAsOptional("RPG_Perks_ApplyEntityTimedAttribute");
	MarkNativeAsOptional("RPG_Perks_RecalculateMaxHP");
	MarkNativeAsOptional("RPG_Perks_SetClientHealth");
	MarkNativeAsOptional("RPG_Perks_GetClientHealth");
	MarkNativeAsOptional("RPG_Perks_SetClientMaxHealth");
	MarkNativeAsOptional("RPG_Perks_GetClientMaxHealth");
	MarkNativeAsOptional("RPG_Perks_SetClientTempHealth");
	MarkNativeAsOptional("RPG_Perks_GetClientTempHealth");
	MarkNativeAsOptional("RPG_Tanks_IsDamageImmuneTo");
	MarkNativeAsOptional("RPG_Tanks_RegisterTank");
	MarkNativeAsOptional("RPG_Tanks_RegisterActiveAbility");
	MarkNativeAsOptional("RPG_Tanks_RegisterPassiveAbility");
	MarkNativeAsOptional("RPG_Tanks_GetClientTank");
	MarkNativeAsOptional("RPG_Tanks_SetClientTank");
	MarkNativeAsOptional("RPG_Tanks_GetClientTankTier");
	MarkNativeAsOptional("RPG_Tanks_GetDamagePercent");
	MarkNativeAsOptional("RPG_Tanks_SetDamagePercent");
	MarkNativeAsOptional("RPG_Tanks_IsTankInPlay");
	MarkNativeAsOptional("StartCustomVote");
	MarkNativeAsOptional("L4D2_Pets_ForceCarry");
	MarkNativeAsOptional("L4D2_Pets_GetCarrier");
}
#endif

forward void RPG_DailyQuests_OnGetMaxDailyQuests(int client, int &maxQuests);

// Fires for regular jumps too.
forward void GunXP_Skills_OnMultiJump(int client, bool bMultiJump);

// RPG_Tanks_GetClientTank(victim) will work properly in this forward. After this forward is called, RPG_Tanks_GetClientTank(victim) will return TANK_TIER_UNKNOWN.
// XPReward is the amount of XP awarded. It will be -1 if not enough damage was dealt.
forward void RPG_Tanks_OnRPGTankKilled(int victim, int attacker, int XPReward);

forward void RPG_Tanks_OnUntieredTankKilled(int victim, int attacker);

// abilityIndex is the index registered with RPG_Tanks_RegisterActiveAbility
// Note: Verify the tank is the same index as yours, because two activated abilities by different tanks can have the same index.
forward void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex);

// The navigation system is meant to display information about mechanics based on name or description, so if you trigger a navigation ref of a perk tree, it'll open its menu showing the description (and obviously you can immediately buy it)
forward void GunXP_OnTriggerNavigationRef(int client, int navSerial, int serial, char[] classification, char[] name, char[] description);

// return Plugin_Handled and edit sError to prevent reloading.
forward Action GunXP_RPGShop_OnTryReloadRPGPlugins(char sError[256]);

// At this point, every perk tree and skill were removed.
forward void GunXP_OnReloadRPGPlugins();
forward void GunXP_OnPlayerLoaded(int client);

// Auto RPG is true if the talent was bought automatically by the Auto RPG system, which automatically buys a talent if the player has enough XP Currency.
forward void GunXP_RPGShop_OnPerkTreeBuy(int client, int perkIndex, int perkLevel, bool bAutoRPG);
forward void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG);

// This is called while the player still has their current perk tree and skills.
// Also called when player begins mutating.
// You must check if the perk tree / skill is unlocked before you act with the player. This is because upon selling a talent, only that talent is shown with IsPerkTreeUnlocked or IsSkillUnlocked
// DO NOT UNDER ANY CIRCUMSTANCE SELL OR RESET A PLAYER IN THIS FORWARD IN ANY WAY SHAPE OR FORM ABLE TO.
forward void GunXP_RPGShop_OnResetRPG(int client);

// Decides how far into the shadow realm a player can see.
forward void RPG_Perks_OnGetShadowRealmVision(int client, float &fVision);

// return Plugin_Handled to ignore the client (please keep it for the rest of the round), Plugin_Continue otherwise.
// This basically decides if the client used a special movement ability that allows it to bypass an elevator, meaning an elevator that stops working until all survivors are inside will not check for that client, because he may have used his movement ability to literally reach the end of the map, the safe room.
forward Action RPG_Perks_OnShouldIgnoreEntireTeamTouch(int client);

// return Plugin_Handled to prevent closets rescue, Plugin_Continue to allow.
forward Action RPG_Perks_OnShouldClosetsRescue();

// WARNING! THIS FORWARD FIRES 20 TIMES PER CHECK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// Generally you should set-up a cvar and make the priority 0. Other plugins will be closer or further from 10 based on what they need.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the speed to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// After that, it would be recommended to multiply the swing speed.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.

// ATTENTION!!! float delay is the time it takes for the tank to swing after his hand connects with survivor / air.
forward void RPG_Perks_OnGetTankSwingSpeed(int priority, int client, float &delay);

// Called when RPG_Perks_IgniteWithOwnership is used.
forward void RPG_Perks_OnIgniteWithOwnership(int victim, int attacker);

// WARNING! THIS FORWARD FIRES 20 TIMES PER CHECK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// Generally you should set-up a cvar and make the priority 0. Other plugins will be closer or further from 10 based on what they need.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// It is recommended in general that you only add and don't multiply.
forward void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses);

forward void RPG_Perks_OnTimedAttributeStart(int entity, char attributeName[64], float fDuration);

forward void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64]);

// if oldClient == newClient, the duration was modified.
forward void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64]);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// &sValue is a copyback string
forward void RPG_Perks_OnGetReplicateCvarValue(int priority, int client, const char cvarName[64], char sValue[256]);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.

forward void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass);


// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.

// Use RPG_Perks_GetZombieType(entity) to get a ZombieType_* of what kind of a zombie it is.
forward void RPG_Perks_OnGetZombieMaxHP(int priority, int entity, int &maxHP);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how health is interacted and just want to add a value to the max hp, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Check for priority closer to 10 if you want to multiply max health to make all added max HP make you gain more HP.
forward void RPG_Perks_OnGetMaxHP(int priority, int client, int &maxHP);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever about order of execution, use "if(priority != 0) return;"
// This forward only fires for Survivors.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// Gun XP - RPG gives guns on priority -2 by default, with a cvar named "gun_xp_priority_for_guns" to alter it.
// Unrelated to this native, RPG-Perks gives hidden incap pistol on priority 0 by default, with a cvar named "rpg_incap_pistol_priority" to alter it.
forward void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn);

// WARNING! THIS FORWARD FIRES 20 TIMES PER SPAWN, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever about order of execution, use "if(priority != 0) return;"
// This forward only fires for Special Infected (and therefore Tanks too)
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// I can't think of a reason to use a priority closer to -10.
// bApport should almost never be changed. Change to true if you want every plugin to think what is basically "this tank is borderline being spawned as a debug tank"
forward void RPG_Perks_OnZombiePlayerSpawned(int priority, int client, bool &bApport);

// WARNING! THIS FORWARD FIRES 20 TIMES PER ATTACK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// It is recommended to default priority of 0 but have a cvar that lets controlling it.
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the damage to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.
// Please use odd priorities to remove bImmune and even priorities to enable bImmune

forward void RPG_Perks_OnShouldInstantKill(int priority, int victim, int attacker, int inflictor, int damagetype, bool &bImmune);

// WARNING! THIS FORWARD FIRES 20 TIMES PER ATTACK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how damage is interacted and just want to multiply the damage, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the damage to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.
// bDontInterruptActions protects a Survivor from having a timer reset for picking incapacitated players and pouring gas cans.
// bDontStagger protects a Special Infected or a Tank from explosive ammo stagger, RPG stagger, incendiary ammo burn, all instant kills, and can also seriously mess with damage output.
// bDontInstakill can seriously mess with damage output, and breaks explosive ammo stagger. Use with care.
// bImmune is like setting damage to 0.0, but enables plugins to block your damage immunity. Example: Tier 1 tank is immune to fire damage. Flaming katana deals fire damage and ignores all fire immunity.

// If you want to distinguish what actions to protect, make an incap check or check if victim has a gascan like item held.
// If you want to protect from stagger but allow incendiary ammo, check for damagetype == DMG_BLAST
forward void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune);

// WARNING! THIS FORWARD FIRES 20 TIMES PER CALCULATION, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how speed is interacted and just want to multiply the speed, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -10 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 10 it will run LAST.
// Check for priority closer to -10 if you want to SET the speed to a certain value.
// Check for priority closer to 10 if you want to go after another plugin to fix something they did.
// Do not hog -10 and 10, this may have severe consequences when a programmer cannot naturally go before / after you.
// overrideSpeedState ignores what the speed of the player should be and instead overrides it to something else.
// fCustomSpeed will only work if overrideSpeedState is set to custom.
forward void RPG_Perks_OnGetRPGSpeedModifiers(int priority, int client, int &overrideSpeedState, int &iLimpHealth, float &fRunSpeed, float &fWalkSpeed, float &fCrouchSpeed, float &fLimpSpeed, float &fCriticalSpeed, float &fWaterSpeed, float &fAdrenalineSpeed, float &fScopeSpeed, float &fCustomSpeed);

// These are self explanatory.
forward void RPG_Perks_OnGetAdrenalineDuration(int client, float &fDuration);
forward void RPG_Perks_OnGetMedsHealPercent(int client, bool bAdrenaline, float &percentToHeal);
forward void RPG_Perks_OnGetKitHealPercent(int reviver, int victim, int &percent);
forward void RPG_Perks_OnGetReviveHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent);
forward void RPG_Perks_OnGetDefibHealthPercent(int reviver, int victim, int &temporaryHealthPercent, int &permanentHealthPercent);

// Time it takes to heal (with medkit) or revive a survivor, respectively.
forward void RPG_Perks_OnGetKitDuration(int reviver, int victim, float &fDuration);
forward void RPG_Perks_OnGetReviveDuration(int reviver, int victim, bool bLedge, float &fDuration);

forward void RPG_Perks_OnGetIncapHealth(int client, bool bLedge, int &health);

// index means the following:
// 0 - No weapon. 1 - Pistol. 2 - Double Pistol. 3 - Magnum
forward void RPG_Perks_OnGetIncapWeapon(int reviver, int &index)

// Caller is the plugin's handle, bInternal is only used when the vote plugin calls the vote, so it's irrelevant.

// This code is an auto include in this forward:

/*
	float ForPercents = (float(VotesFor) / (float(VotesFor) + float(VotesAgainst))) * 100.0;

	if(ForPercents < PercentsToPass)
		return;
*/
forward void sm_vote_OnVoteFinished_Post(int client, int VotesFor, int VotesAgainst, int PercentsToPass, bool bCanVote[MAXPLAYERS], char[] VoteSubject, bool bInternal, Handle Caller);

enum ZombieType
{
	ZombieType_Smoker			= 1,
	ZombieType_Boomer			= 2,
	ZombieType_Hunter			= 3,
	ZombieType_Spitter			= 4,
	ZombieType_Jockey			= 5,
	ZombieType_Charger			= 6,
	ZombieType_Witch			= 7,
	ZombieType_Tank			= 8,
	ZombieType_NotInfected		= 9,
	ZombieType_CommonInfected		= 10,
	ZombieType_Invalid				= 11
};

// If the entity is dead, returns invalid.
// You can pass anything as long as it's a valid edict.
stock ZombieType RPG_Perks_GetZombieType(int entity, bool bAllowDead = false)
{
	if(IsPlayer(entity))
	{
		if(!IsClientInGame(entity) && IsPlayerAlive(entity) && !bAllowDead)
			return ZombieType_Invalid;

		switch(L4D_GetClientTeam(entity))
		{
			case L4DTeam_Survivor: return ZombieType_NotInfected;
			case L4DTeam_Infected: return view_as<ZombieType>(L4D2_GetPlayerZombieClass(entity));
			default: return ZombieType_Invalid;
		}
	}
	else
	{
		char sClassname[64];
		GetEdictClassname(entity, sClassname, sizeof(sClassname));

		if(StrEqual(sClassname, "infected"))
		{
			if(GetEntProp(entity, Prop_Data, "m_lifeState") != 0 && !bAllowDead)
			{
				return ZombieType_Invalid;
			}

			return ZombieType_CommonInfected;
		}
		else if(StrEqual(sClassname, "witch"))
		{
			if(GetEntProp(entity, Prop_Data, "m_lifeState") != 0 && !bAllowDead)
			{
				return ZombieType_Invalid;
			}

			return ZombieType_Witch;
		}

		return ZombieType_Invalid;
	}
}

stock bool UC_SilentCvar(const char[] cvarName, const char[] value, int iValue = -2147451520, ConVar hndl = null)
{
	if(hndl == null)
		hndl = FindConVar(cvarName);

	if(hndl == null)
		return false;

	int flags = hndl.Flags;

	hndl.Flags = (flags & ~FCVAR_NOTIFY);

	char prevValue[512];
	hndl.GetString(prevValue, sizeof(prevValue));

	if(iValue == -2147451520)
	{
		if(!StrEqual(value, prevValue))
			hndl.SetString(value, true);
	}
	else
	{
		char iValueStr[11];
		IntToString(iValue, iValueStr, sizeof(iValueStr));

		if(!StrEqual(iValueStr, prevValue))
			hndl.SetInt(iValue, true);
	}

	hndl.Flags = flags;

	return true;
}
enum AimbotLevels
{
	AimbotLevel_One,
	AimbotLevel_Two	
}

public bool GunXP_SetupAimbotStrike(int client, int victim, AimbotLevels aimbotLevel)
{
	switch(aimbotLevel)
	{
		case AimbotLevel_One:
		{
			float fOrigin[3], fVictimOrigin[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);
			GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

			TR_TraceRayFilter(fOrigin, fVictimOrigin, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_DontHitTarget, client);

			if(!TR_DidHit())
				return false;

			else if(TR_GetEntityIndex() != victim)
				return false;

			return true;
		}
		case AimbotLevel_Two:
		{
			float fOrigin[3], fVictimOrigin[3];
			GetClientEyePosition(client, fOrigin);

			GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

			float fIncrementList[] = { 0.0, 1.0, 3.0, 5.0, 8.0, 16.0, 32.0, 60.0, 64.0 };

			float fOriginalHeight = fVictimOrigin[2];

			for(int i=0;i < sizeof(fIncrementList);i++)
			{
				fVictimOrigin[2] = fOriginalHeight + fIncrementList[i];

				float fAngle[3];
				MakeVectorFromPoints(fOrigin, fVictimOrigin, fAngle);
			
				GetVectorAngles(fAngle, fAngle);

				TR_TraceRayFilter(fOrigin, fAngle, MASK_SHOT, RayType_Infinite, TraceFilter_HitTarget, victim);

				float fTest[3];
				TR_GetEndPosition(fTest);

				if(TR_DidHit() && TR_GetEntityIndex() == victim)
				{
					return true;
				}
			}

			return false;
		}
	}

	return false;
}

public bool TraceFilter_HitTarget(int entity, int contentsMask, int target)
{
    if (entity == target)
        return true;

    return false;
}

public bool TraceFilter_DontHitTarget(int entityhit, int mask, int target) 
{
    return (entityhit != target);
}


stock void UC_ReplyToCommand(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[256];

	VFormat(buffer, sizeof(buffer), format, 3);

	char sReplaceFrom[2], sReplaceTo[32];

	sReplaceFrom[0] = buffer[0]
	sReplaceFrom[1] = EOS;
	FormatEx(sReplaceTo, sizeof(sReplaceTo), "{GREEN}{NORMAL}%s", sReplaceFrom);
	
	ReplaceStringEx(buffer, sizeof(buffer), sReplaceFrom, sReplaceTo);

	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	ReplaceString(buffer, sizeof(buffer), "{PERCENT}", "%%");
	
	ReplyToCommand(client, buffer);
}

stock void UC_PrintToChat(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	
	char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 3);

	char sReplaceFrom[2], sReplaceTo[32];

	sReplaceFrom[0] = buffer[0]
	sReplaceFrom[1] = EOS;
	FormatEx(sReplaceTo, sizeof(sReplaceTo), "{GREEN}{NORMAL}%s", sReplaceFrom);
	
	ReplaceStringEx(buffer, sizeof(buffer), sReplaceFrom, sReplaceTo);

	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	ReplaceString(buffer, sizeof(buffer), "{PERCENT}", "%%");
	
	PrintToChat(client, buffer);
}

stock void UC_PrintToChatAll(const char[] format, any ...)
{	
	char buffer[256];
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		
		UC_PrintToChat(i, buffer);
	}
}


stock void UC_PrintToChatRoot(const char[] format, any ...)
{	
	char buffer[256];
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(!CheckCommandAccess(i, "sm_reloadrpg", ADMFLAG_ROOT))
			continue;
			
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		
		UC_PrintToChat(i, buffer);
	}
}

stock void UC_StringToUpper(char[] buffer)
{
	int length = strlen(buffer);
	for(int i=0;i < length;i++)
		buffer[i] = CharToUpper(buffer[i]);
}

stock bool IsClientEyal(int client)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Engine, steamid, sizeof(steamid));
		
	if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
		return true;
		
	return false;
}

stock ConVar UC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	ConVar hndl = AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);

	if (flags & FCVAR_PROTECTED)
		ServerCommand("sm_cvar protect %s", name);

	return hndl;
}

stock bool IsPlayer(int entity)
{
	if(entity >= 1 && entity <= MaxClients)
		return true;
		
	return false;
}

stock void SetEntityMaxHealth(int entity, int amount)
{
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", amount);
}

stock int GetEntityMaxHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

stock int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iHealth");
}


// This function can alter your temporary health twice in a row. If you wish to set, you can call this function with 0 permanent and 0 temporary to ensure it does if it wants to.
stock void GunXP_GiveClientHealth(int client, int permanentHP = 0, int temporaryHP = 0)
{
	if(GetEntityHealth(client) + permanentHP + RPG_Perks_GetClientTempHealth(client) > GetEntityMaxHealth(client))
	{
		if(GetEntityHealth(client) + permanentHP > GetEntityMaxHealth(client))
		{
			SetEntityHealth(client, GetEntityMaxHealth(client));
		}
		else
		{
			SetEntityHealth(client, GetEntityHealth(client) + permanentHP);
			RPG_Perks_SetClientTempHealth(client, GetEntityMaxHealth(client) - GetEntityHealth(client) + 1);
		}
	}
	else
	{
		SetEntityHealth(client, GetEntityHealth(client) + permanentHP);
	}

	if(GetEntityHealth(client) + temporaryHP + RPG_Perks_GetClientTempHealth(client) > GetEntityMaxHealth(client))
	{
		RPG_Perks_SetClientTempHealth(client, GetEntityMaxHealth(client) - GetEntityHealth(client) + 1);

	}
	else
	{
		RPG_Perks_SetClientTempHealth(client, RPG_Perks_GetClientTempHealth(client) + temporaryHP + 1);
	}
}

stock void GunXP_RegenerateTankHealth(int client, int amount)
{
	RPG_Perks_SetClientHealth(client, RPG_Perks_GetClientHealth(client) + amount);

	if(RPG_Perks_GetClientHealth(client) > RPG_Perks_GetClientMaxHealth(client))
	{
		RPG_Perks_SetClientHealth(client, RPG_Perks_GetClientMaxHealth(client));
	}
}

stock void ExecuteFullHeal(int client)
{
	if (GetClientTeam(client) == view_as<int>(L4DTeam_Survivor))
	{
		bool bIncap, bPinned;
		bIncap  = L4D_IsPlayerIncapacitated(client);
		bPinned = L4D_IsPlayerPinned(client);
		if (bIncap && bPinned)
		{
			Handle convar = FindConVar("survivor_incap_health");

			SetEntityHealth(client, GetConVarInt(convar));
		}
		else if (bIncap)
		{
			FullyHealPlayer(client);

			if (L4D_IsPlayerIncapacitated(client))
				L4D2_VScriptWrapper_ReviveFromIncap(client);

			SetEntityHealthToMax(client);
		}
		else
		{
			FullyHealPlayer(client);

			if (L4D_IsPlayerIncapacitated(client))
				L4D2_VScriptWrapper_ReviveFromIncap(client);

			SetEntityHealthToMax(client);
		}
	}
	else
	{
		SetEntityHealthToMax(client);
	}

	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
}

stock int GunXP_GenerateHexColor(int r, int g, int b, int a=255)
{
	return ((r & 0xff) << 24) | ((g & 0xff) << 16) | ((b & 0xff) << 8) | (a & 0xff);
}

stock void GunXP_GenerateRGBColor(int hex, int RGBA[4])
{
	RGBA[0] = ((hex >> 24) & 0xFF);
	RGBA[1] = ((hex >> 16) & 0xFF);
	RGBA[2] = ((hex >> 8) & 0xFF);
	RGBA[3] = ((hex) & 0xFF);
}
stock void SetEntityHealthToMax(int entity)
{
	SetEntityHealth(entity, GetEntProp(entity, Prop_Send, "m_iMaxHealth"));
}

stock void FullyHealPlayer(int client)
{
	char code[512];

	FormatEx(code, sizeof(code), "ret <- GetPlayerFromUserID(%d).GiveItem(\"health\"); <RETURN>ret</RETURN>", GetClientUserId(client));

	char sOutput[512];
	L4D2_GetVScriptOutput(code, sOutput, sizeof(sOutput));
}

stock int RPG_GetPlayerCarry(int client)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(L4D2_Pets_GetCarrier(i) == client)
        {
            return i;
        }
    }

    return -1;
}
/**
 * @brief Reloads a plugin.
 *
 * @param plugin	Plugin Handle (INVALID_HANDLE uses the calling plugin).
 * @noreturn
 */
stock GunXP_ReloadPlugin(Handle plugin = INVALID_HANDLE)
{
	char filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins reload %s", filename);
}

/**
 * @brief Unloads a plugin.
 *
 * @param plugin	Plugin Handle (INVALID_HANDLE uses the calling plugin).
 * @noreturn
 */
stock GunXP_UnloadPlugin(Handle plugin = INVALID_HANDLE)
{
	char filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins unload %s", filename);
}

stock void PrintToChatEyal(const char[] format, any ...)
{
	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;

		char steamid[64];
		GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));
		
		if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
			PrintToChat(i, buffer);
	}
}

stock void PrintToConsoleEyal(const char[] format, any...)
{
	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (IsFakeClient(i))
			continue;

		char steamid[64];
		GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));

		if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
			PrintToConsole(i, buffer);
	}
}

stock void PrintToChatIfEyal(int client, const char[] format, any ...)
{
	if(!IsPlayer(client))
		return;

	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 3);

	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
		PrintToChat(client, buffer);
}

stock void PrintToConsoleIfEyal(int client, const char[] format, any ...)
{
	if(!IsPlayer(client))
		return;

	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 3);

	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if(StrEqual(steamid, "STEAM_1:0:49508144") || StrEqual(steamid, "STEAM_1:0:28746258") || StrEqual(steamid, "STEAM_1:1:463683348"))
		PrintToConsole(client, buffer);
}