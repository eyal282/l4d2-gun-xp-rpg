#include <autoexecconfig>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

public Plugin myinfo =
{
	name        = "RPG Dynamic Difficulty",
	author      = "Eyal282",
	description = "Dynamic Config to change any cvar on your mind based on the difficulty.",
	version     = PLUGIN_VERSION,
	url         = ""
};

enum struct enDifficultyCvar
{
    ConVar hndl;
    char cvarName[64];
    char easyValue[128];
    char normalValue[128];
    char advancedValue[128];
    char expertValue[128];
}

ArrayList g_aCvars;

ConVar g_hDifficulty;

char g_sFolder[] = "cfg/server_dynamic_difficulties.cfg";

public void OnPluginStart()
{
    g_aCvars = new ArrayList(sizeof(enDifficultyCvar));

    g_hDifficulty = FindConVar("z_difficulty");

    HookConVarChange(g_hDifficulty, cvChange_Difficulty);
}

public void OnAllPluginsLoaded()
{
    LoadConfig();

    char newValue[16];
    g_hDifficulty.GetString(newValue, sizeof(newValue));

    cvChange_Difficulty(g_hDifficulty, newValue, newValue);
}

public void LoadConfig()
{
    g_aCvars.Clear();

    if(!FileExists(g_sFolder))
    {
        File file = OpenFile(g_sFolder, "a+");

        file.WriteLine("// Use the syntax cvar = 5,10,15,20 to decide the cvar's value for each difficulty.");
        file.WriteLine("// Keeping in mind that starting a line with // prevents the plugin from reading it, here's an example:");
        file.WriteLine("// z_charger_health = 600,1200,2400,5000");
        file.WriteLine("// The above example will set charger HP to 600 on Easy, 1200 on Normal, 2400 on Advanced, 5000 on Expert.");

        delete file;
    }

    File file = OpenFile(g_sFolder, "r");

    char lineBuffer[512];

    while(!IsEndOfFile(file) && ReadFileLine(file, lineBuffer, sizeof(lineBuffer)))
    {
        if(lineBuffer[0] == ';' || (lineBuffer[0] == lineBuffer[1] && lineBuffer[0] == '/'))
            continue;

        while(StrContains(lineBuffer, " ") != -1)
        {
            ReplaceString(lineBuffer, sizeof(lineBuffer), " ", "");
        }

        // This is tab, not space.
        while(StrContains(lineBuffer, " ") != -1)
        {
            ReplaceString(lineBuffer, sizeof(lineBuffer), " ", "");
        }

        char cvarName[64], cvarValues[512];
        
        int pos = SplitString(lineBuffer, "=", cvarName, sizeof(cvarName));
        
        if(pos == -1)
            continue;

        FormatEx(cvarValues, sizeof(cvarValues), lineBuffer[pos]);

        char explodedCvarValues[4][128];

        int sharpnels = ExplodeString(cvarValues, ",", explodedCvarValues, sizeof(explodedCvarValues), sizeof(explodedCvarValues[]));

        if(sharpnels != 4)
        {
            SetFailState("The following line was found pointing to %s than 4 difficulty settings:\n%s", sharpnels > 4 ? "more" : "less", lineBuffer);

            return;
        }

        ConVar hndl = FindConVar(cvarName);

        enDifficultyCvar diffCvar;

        diffCvar.hndl = hndl;
        diffCvar.cvarName = cvarName;
        diffCvar.easyValue = explodedCvarValues[0];
        diffCvar.normalValue = explodedCvarValues[1];
        diffCvar.advancedValue = explodedCvarValues[2];
        diffCvar.expertValue = explodedCvarValues[3];

        g_aCvars.PushArray(diffCvar);
    }
}

public void cvChange_Difficulty(ConVar convar, const char[] oldValue, const char[] newValue)
{
    for(int i=0;i < g_aCvars.Length;i++)
    {
        enDifficultyCvar diffCvar;

        g_aCvars.GetArray(i, diffCvar);

        ConVar hndl = diffCvar.hndl;

        if(hndl == null)
            hndl = FindConVar(diffCvar.cvarName);

        if(hndl == null)
            continue;

        int flags = hndl.Flags;

        hndl.Flags = (flags & ~FCVAR_NOTIFY);

        if(StrEqual(newValue, "easy", false))
            hndl.SetString(diffCvar.easyValue);

        else if(StrEqual(newValue, "normal", false))
            hndl.SetString(diffCvar.normalValue);

        else if(StrEqual(newValue, "advanced", false))
            hndl.SetString(diffCvar.advancedValue);

        else if(StrEqual(newValue, "impossible", false))
            hndl.SetString(diffCvar.expertValue);

        hndl.Flags = flags;
    }
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
    char newValue[16];
    g_hDifficulty.GetString(newValue, sizeof(newValue));

    cvChange_Difficulty(g_hDifficulty, newValue, newValue);
}

stock Handle CreateFile(const char[] path, const char[] mode = "w+")
{
	char dir[8][PLATFORM_MAX_PATH];
	int count = ExplodeString(path, "/", dir, 8, sizeof(dir[]));
	for(int i = 0; i < count-1; i++)
	{
		if(i > 0)
			Format(dir[i], sizeof(dir[]), "%s/%s", dir[i-1], dir[i]);
			
		if(!DirExists(dir[i]))
			CreateDirectory(dir[i], 511);
	}
	
	return OpenFile(path, mode);
}