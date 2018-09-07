#include <sourcemod> 
#include <clientprefs>
#include <zipcore_csgocolors> 

#pragma semicolon 1

#define SERVER_TAG "[{lightyellow}Speed {darkblue}O {green}Meter{default}]"


bool g_bHideSpeedMeter[MAXPLAYERS + 1] = true;

Handle AdvertInterval;
Handle MeterLocation;

Handle g_hClientSpeedCookie = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Speed o Meter",
	author = "Cruze",
	description = "1.0-beta",
	version = "",
	url = ""
}
public void OnPluginStart() 
{
	MeterLocation		=	CreateConVar("ssm_location", "1", "where should speed meter be shown. 0 = CenterHUD, 1 = New CSGO HUD");
	AdvertInterval	=	CreateConVar("ssm_advertinterval", "600.0", "Interval of time between advert", FCVAR_PLUGIN, true, 0.0, true, 1800.0);
	
	AutoExecConfig(true, "cruze_speedometer");
	
	RegConsoleCmd("sm_speed", Toggle_Speed, "Toggle SpeedMeter");
	RegConsoleCmd("sm_speedmeter", Toggle_Speed, "Toggle SpeedMeter");
	RegConsoleCmd("sm_speedometer", Toggle_Speed, "Toggle SpeedMeter");

	g_hClientSpeedCookie = RegClientCookie("clientspeedcookie", "Cookie to check if speedmeter is blocked", CookieAccess_Private);
	for (new i = MaxClients; i > 0; --i) 
	{
		if (!AreClientCookiesCached(i)) 
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}
public OnConfigsExecuted()
{
	CreateTimer(GetConVarFloat(AdvertInterval), plugin_Advert, _, TIMER_REPEAT);
}
public Action plugin_Advert(Handle timer)
{
	CPrintToChatAll("%s Type {magenta}!speedmeter{default} to toggle speed meter!", SERVER_TAG);
}
public Action Toggle_Speed (int client, int args)
{
	g_bHideSpeedMeter[client] = !g_bHideSpeedMeter[client];
	if (g_bHideSpeedMeter[client]) 
	{
		CPrintToChat(client, "%s {magenta} Disabled Speed Meter.", SERVER_TAG);
		SetClientCookie(client, g_hClientSpeedCookie, "0");
	} else 
	{
		CPrintToChat(client, "%s {magenta} Enabled Speed Meter.", SERVER_TAG);
		SetClientCookie(client, g_hClientSpeedCookie, "1");
	}
	return Plugin_Handled;
}
public void OnClientCookiesCached(int client) 
{
	char sValue[8];
	GetClientCookie(client, g_hClientSpeedCookie, sValue, sizeof(sValue));
	
	g_bHideSpeedMeter[client] = (sValue[0] != '\0' && StringToInt(sValue));
}
public void OnClientDisconnect(int client) 
{
	g_bHideSpeedMeter[client] = false;
}
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3],
								int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) 
{

	//Thanks SHUFEN.jp(https://forums.alliedmods.net/member.php?u=250145) for helping me out here!! ^___^
	if(IsValidClient(client) && g_bHideSpeedMeter[client]) 
	{	
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		float fVelocity = SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
		SetHudTextParamsEx(-1.0, 0.65, 0.1, {255, 255, 255, 255}, {0, 0, 0, 255}, 0, 0.0, 0.0, 0.0);
		
		if(IsPlayerAlive(client))
		{
			if(GetConVarBool(MeterLocation))
			{
				ShowHudText(client, 3, "Speed: %.2f u/s", fVelocity);
			}
			else
			{
			//PrintCenterText(client, "Speed: %.2f u/s", fVelocity);
				PrintHintText(client, "Speed: %.2f u/s", fVelocity);
			}
		}
		if(IsClientObserver(client))
		{
			int spectarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (spectarget < 1 || spectarget > MaxClients || !IsClientInGame(spectarget))
				return;

			char ClientName[32];
			GetClientName(spectarget, ClientName, 32);
			if(GetConVarBool(MeterLocation))
			{
				ShowHudText(client, 3, "%s's Speed: %.2f u/s", ClientName, fVelocity);
			}
			else
			{
				//PrintCenterText(client, "%s's Speed: %.2f u/s", ClientName, fVelocity);
				PrintHintText(client, "%s's Speed: %.2f u/s", ClientName, fVelocity);
			}
		}
	}
}
	
bool IsValidClient(client, bool bAllowBots = true, bool bAllowDead = true)
{
    if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
    {
        return false;
    }
    return true;
}