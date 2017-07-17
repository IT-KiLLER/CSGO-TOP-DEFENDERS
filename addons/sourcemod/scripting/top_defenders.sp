
/*	Copyright (C) 2017 IT-KiLLER
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#pragma semicolon 1
#pragma newdecls required
//#define DEBUG // this enabled debug mode!
#define TAG_COLOR 	"{green}[SM]{default}"

ConVar sm_top_defenders_enabled, sm_top_defenders_top_list, sm_top_defenders_winners,
 sm_top_defenders_minium_damage, sm_top_defenders_hide_enabled, sm_top_defenders_hide_angle,
 sm_top_defenders_hide_timer, sm_top_defenders_hide_cooldown, sm_top_defenders_download_enabled,
 sm_top_defenders_hats_enabled;

enum player_damange
{
	playerid,
	hits,
	kills,
	damange,
};

enum hats
{	
	String:hatname[32],
	String:model[256],
	bool:enabled,
	bool:multifiles,
	bool:download,
	Float:height,
	Float:size,
	Float:angles[3],
	Handle:downloadArray[100],
};

	/* list texts format START */
	static char top_header[128];
	static char top_winner[128];
	static char top_nonwinner[128];
	static char top_footer[128];
	/* list text format END */

	bool ClientHasHat[MAXPLAYERS+1]={false,...}; 
	int entity_client[MAXPLAYERS+1]={INVALID_ENT_REFERENCE,...}; 
	int hatsArray[128][hats];
	int damangeArray[MAXPLAYERS+1][player_damange];
	int tempArray[5][player_damange]; 
	Handle timer_client[MAXPLAYERS+1]={INVALID_HANDLE,...};
	float cooldowntime[MAXPLAYERS+1] = {0.0, ...};

public Plugin myinfo = 
{
	name = "[CS:GO] TOP DEFENDERS", 
	author = "IT-KiLLER", 
	description = "The players who have made the most damage are presented after each round.", 
	version = "1.0", 
	url = "https://github.com/IT-KiLLER"
}

public void OnPluginStart()
{
	sm_top_defenders_enabled = CreateConVar("sm_top_defenders_enabled", "1.0", "Plugin is enabled or disabled.", _, true, 0.0, true, 1.0);
	sm_top_defenders_download_enabled = CreateConVar("sm_top_defenders_download_enabled", "1.0", "Download is enabled or disabled.", _, true, 0.0, true, 1.0);
	sm_top_defenders_hats_enabled = CreateConVar("sm_top_defenders_hats_enabled", "1.0", "Enabled/disabled the command !hat.", _, true, 0.0, true, 1.0);
	sm_top_defenders_top_list = CreateConVar("sm_top_defenders_top_list", "5.0", "How many players will be listed on the top list. (1.0-20.0)", _, true, 1.0, true, 64.0);
	sm_top_defenders_winners = CreateConVar("sm_top_defenders_winners", "1.0", "How many will be top winners and get !hat permission. (1.0-10.0)", _, true, 1.0, true, 64.0);
	sm_top_defenders_hide_enabled = CreateConVar("sm_top_defenders_hide_enabled", "1.0", "Hide the hat when the player climbs or looks up.", _, true, 0.0, true, 1.0);
	sm_top_defenders_hide_timer = CreateConVar("sm_top_defenders_hide_timer", "0.5", "Checking the player angles and mode every x seconds. (0.2-10.0)", _, true, 0.2, true, 10.0);
	sm_top_defenders_hide_cooldown = CreateConVar("sm_top_defenders_hide_cooldown", "2.0", "How many x seconds the hat should be transparent. (0.0-10.0)", _, true, 0.0, true, 10.0);
	sm_top_defenders_hide_angle = CreateConVar("sm_top_defenders_hide_angle", "-60.00", "The angle to hide the hat. (-180.0 - 180.0)", _, true, -180.0, true, 180.0);
	sm_top_defenders_minium_damage = CreateConVar("sm_top_defenders_minium_damage", "500.0", "The total minimum damage for players to be listed. (1.0-5000.0)", _, true, 1.0, true, 5000.0);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
	RegAdminCmd("sm_reload_topdefenders", reloadHats, ADMFLAG_ROOT, "Reloads the config file.");
	RegConsoleCmd("sm_hat", HatCommand, "Opens the hat menu.");
	RegConsoleCmd("sm_hats", HatCommand, "Opens the hat menu.");
	LoadConfigHats();
	#if defined DEBUG
		resetDamangesArrays();
		resetPermissionArrays();
		for(int client = 1; client <= MaxClients; client++)
			ClientHasHat[client]=true;
	#endif
}

#if defined DEBUG
public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
		RemoveHat(client);
}
#endif

stock void LoadConfigHats()
{
	for (int index = 1; index < 128; index++)
	{
		Format(hatsArray[index][hatname],32, "");
		Format(hatsArray[index][model], 256, "");
		hatsArray[index][enabled] = false;
		hatsArray[index][download] = false;
		hatsArray[index][multifiles] = false;
		hatsArray[index][enabled] = false;
		hatsArray[index][height] = 0.0;
		hatsArray[index][size] = 0.0;
		hatsArray[index][angles] = {0.0, 0.0, 0.0};
		hatsArray[index][downloadArray] = INVALID_HANDLE;
	}
	KeyValues hKeyValues = new KeyValues("top defenders");
	char config_path[PLATFORM_MAX_PATH]="addons/sourcemod/configs/top_defenders.cfg";
	char buffer_temp[256];
	float buffer_float[3]; 

	hKeyValues.ImportFromFile(config_path);
	LogMessage("Loading %s", config_path);

	hKeyValues.Rewind();
	if(hKeyValues.JumpToKey("colors"))
	{
		hKeyValues.GetString("top_header", top_header, sizeof(top_header));
		#if defined DEBUG
			PrintToServer("color: %s", top_header); // debuging
		#endif
		hKeyValues.GetString("top_winner", top_winner, sizeof(top_winner));
		#if defined DEBUG
			PrintToServer("color: %s", top_winner); // debuging
		#endif
		hKeyValues.GetString("top_nonwinner", top_nonwinner, sizeof(top_nonwinner));
		#if defined DEBUG
			PrintToServer("color: %s", top_nonwinner); // debuging
		#endif
		hKeyValues.GetString("top_footer", top_footer, sizeof(top_footer));
		#if defined DEBUG
			PrintToServer("color: %s", top_footer); // debuging
		#endif
		hKeyValues.Rewind();
	} else {
		//LogMessage("Could not load colors from path: %s", config_path);
		SetFailState("Could not load colors from path: %s", config_path);
		CloseHandle(hKeyValues);
		return;
	}

	if (hKeyValues.JumpToKey("hats"))
	{
		hKeyValues.GotoFirstSubKey();
		int index = 1;
		do
		{	
			hKeyValues.GetSectionName(buffer_temp, sizeof(buffer_temp));
			Format(hatsArray[index][hatname], 32, "%s", buffer_temp);	
			#if defined DEBUG
				PrintToServer("Name: %s", buffer_temp); // debuging
			#endif
			hKeyValues.GetString("model", buffer_temp, sizeof(buffer_temp));
			Format(hatsArray[index][model], 256, "%s", buffer_temp);
			#if defined DEBUG
				PrintToServer("Model: %s", buffer_temp); // debuging
			#endif
			hKeyValues.GetString("enabled", buffer_temp, sizeof(buffer_temp), "false");
			hatsArray[index][enabled] = StrEqual(buffer_temp, "true", false);
			#if defined DEBUG
				PrintToServer("Enabled: %s", buffer_temp); // debuging
			#endif
			hKeyValues.GetString("download", buffer_temp, sizeof(buffer_temp), "false");
			hatsArray[index][download] = StrEqual(buffer_temp, "true", false);
			#if defined DEBUG
				PrintToServer("Download: %s", buffer_temp); // debuging
			#endif
			hKeyValues.GetString("multifiles", buffer_temp, sizeof(buffer_temp), "false");
			hatsArray[index][multifiles] = StrEqual(buffer_temp, "true", false);
			#if defined DEBUG
				PrintToServer("Multifiles: %s", buffer_temp); // debuging
			#endif
			hatsArray[index][height] = hKeyValues.GetFloat("height", 90.0);
			
			hKeyValues.GetVector("angles", buffer_float);
			hatsArray[index][angles] = buffer_float;

			hatsArray[index][size] = hKeyValues.GetFloat("size", 2.0);
			#if defined DEBUG
				PrintToServer("height: %f, size: %f", hatsArray[index][height], hatsArray[index][size]); // debuging
			#endif
			hatsArray[index][downloadArray] = CreateArray(20);
			for(int i = 0; i < 20; i++)	{
				Format(buffer_temp, 256, "download_%d", i);
				hKeyValues.GetString(buffer_temp, buffer_temp, sizeof(buffer_temp), "");
				if(strlen(buffer_temp)==0) continue;
				//ResizeArray(hatsArray[index][downloadArray], 5);
				PushArrayString(hatsArray[index][downloadArray], buffer_temp);
				 #if defined DEBUG
					PrintToServer("PushArrayString: %s", buffer_temp); // debuging
				#endif
			}
			index++;
		}
		while (hKeyValues.GotoNextKey());
		hKeyValues.GoBack();
	}
	else
	{
		//LogMessage("Could not load hats from path: %s", config_path);
		SetFailState("Could not load hats from path: %s", config_path);
		CloseHandle(hKeyValues);
		return;
	}

	CloseHandle(hKeyValues);

	for (int index = 1; index < 128; index++) {
		if(strlen(hatsArray[index][model])!=0 && hatsArray[index][enabled]) {
			if(sm_top_defenders_download_enabled.BoolValue) {
				AddFileToDownloadsTable(hatsArray[index][model]);
				#if defined DEBUG
					PrintToServer("AddFileToDownloadsTable: %s", hatsArray[index][model]); // debug
				#endif
			}
			PrecacheModel(hatsArray[index][model], true);
			#if defined DEBUG
				PrintToServer("Precache model: %s", hatsArray[index][model]); // debuging
			#endif
			for(int i=0; i<GetArraySize(hatsArray[index][downloadArray]); i++ ) {
				GetArrayString(hatsArray[index][downloadArray], i, buffer_temp, sizeof(buffer_temp));
				if(strlen(buffer_temp)==0) continue;
				/* if(StrContains(buffer_temp, ".vmt", false)!=-1) {
					PrecacheModel(buffer_temp, true);
					#if defined DEBUG
						PrintToServer("Precache: %s", buffer_temp); // debuging
					#endif
				} */
				if(sm_top_defenders_download_enabled.BoolValue) {
					AddFileToDownloadsTable(buffer_temp);
				}
				#if defined DEBUG
					PrintToServer("AddFileToDownloadsTable: %s", buffer_temp); // debuging
				#endif
			}
		}
	}
}

public void OnMapStart() 
{
	if(!sm_top_defenders_enabled.BoolValue) return;

	resetDamangesArrays();
	LoadConfigHats();
}

public void OnClientDisconnect_Post(int client)
{
	damangeArray[client][playerid] = client;
	damangeArray[client][damange] = 0;
	damangeArray[client][hits] = 0;
	damangeArray[client][kills] = 0;
	timer_client[client] = INVALID_HANDLE;
	ClientHasHat[client] = false;
	cooldowntime[client] = 0.0;
	entity_client[client] = INVALID_ENT_REFERENCE;
}
	
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if(!sm_top_defenders_enabled.BoolValue) return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!client || !attacker) return;
	int damage = GetEventInt(event, "dmg_health");
	damangeArray[attacker][damange] += damage;
	damangeArray[attacker][hits] += 1;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(!sm_top_defenders_enabled.BoolValue) return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!client || !attacker) return;
	damangeArray[attacker][kills] += 1;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(!sm_top_defenders_enabled.BoolValue) return;

	resetPermissionArrays();

	char buffer_temp[256];
	bool loop = true;
	int myindex = 0;

	do {
		loop=false;
		myindex++;
		/* SORTING LOOP */
		for(int client = 1; client < MaxClients - myindex; client++) {
			if(damangeArray[client][damange] < damangeArray[client + 1][damange]) {
				tempArray[1]=damangeArray[client];
				damangeArray[client]=damangeArray[client + 1];
				damangeArray[client + 1] = tempArray[1];
				loop = true;
				}
			}
	} while (loop);

	char top_text[128];
	
	for(int index = 1; index <= sm_top_defenders_top_list.IntValue; index++) {
		if(damangeArray[index][damange]>=sm_top_defenders_minium_damage.IntValue || index==sm_top_defenders_top_list.IntValue) {
			if(index==1) {
				CPrintToChatAll(top_header);
				PrintToConsoleAll(top_header);
			}
			if(damangeArray[index][damange]>=sm_top_defenders_minium_damage.IntValue) {
				if(index<=sm_top_defenders_winners.IntValue){ /* top 1 */
					top_text=top_winner; 
					ClientHasHat[damangeArray[index][playerid]]=true;
				} else { /* top 2-5 */
					top_text=top_nonwinner; 
				}

				ReplaceString(top_text, sizeof(top_text), "{INDEX}", toString(index), true);
				Format(buffer_temp, sizeof(buffer_temp), "%N", damangeArray[index][playerid], true);
				ReplaceString(top_text, sizeof(top_text), "{NAME}", buffer_temp, true);
				ReplaceString(top_text, sizeof(top_text), "{DAMANGE}", toString(damangeArray[index][damange]), true);
				ReplaceString(top_text, sizeof(top_text), "{HITS}", toString(damangeArray[index][hits]), true);
				ReplaceString(top_text, sizeof(top_text), "{KILLS}", toString(damangeArray[index][kills]), true);
				CPrintToChatAll(top_text);
				PrintToConsoleAll(top_text);
			}
			if(index==sm_top_defenders_top_list.IntValue) {
				CPrintToChatAll(top_footer);	
				PrintToConsoleAll(top_footer);	
			}
			} else if (index==1) break;
		} 
	
	for(int client = 1; client <= MaxClients; client++)
		if(IsClientInGame(client) && ClientHasHat[client] && sm_top_defenders_hats_enabled.BoolValue) {
			CPrintToChat(client, "%s {green}Congrats!{default} You have been granted permission to {lightred}!hat", TAG_COLOR);
		}
	
	resetDamangesArrays(); 
}

stock void resetPermissionArrays(){
	for(int client = 1; client <= MaxClients; client++) {
		ClientHasHat[client]=false;
	}
}

stock void resetDamangesArrays(){
	for(int client = 1; client <= MaxClients; client++) {
		timer_client[client]=INVALID_HANDLE;
		entity_client[client] = INVALID_ENT_REFERENCE;
		damangeArray[client][playerid]=client;
		cooldowntime[client]=0.0;
		damangeArray[client][damange] = 0;
		damangeArray[client][kills] = 0;
		damangeArray[client][hits] = 0;
	}
}

public void CreateHat(int client, int indexhat)
{	
	if(!sm_top_defenders_enabled.BoolValue || !IsPlayerAlive(client)) return;

	RemoveHat(client);
	timer_client[client] = CreateTimer(sm_top_defenders_hide_timer.FloatValue, Timer_Ladder, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	float hatOrigin[3], hatAngles[3], hForward[3], hRight[3], hUp[3];
	GetClientAbsOrigin(client, hatOrigin);
	GetClientAbsAngles(client, hatAngles);
	GetAngleVectors(hatAngles, hForward, hRight, hUp);

	hatOrigin[0] += 0.0;
	hatOrigin[1] += 0.0;
	hatOrigin[2] += hatsArray[indexhat][height];
	
	hatAngles[0] += hatsArray[indexhat][angles][0];
	hatAngles[1] += hatsArray[indexhat][angles][1];
	hatAngles[2] += hatsArray[indexhat][angles][2];

	int entity = CreateEntityByName("prop_dynamic_override");
	entity_client[client]=EntIndexToEntRef(entity);

	char target[64];
	Format(target, 64, "client%d", client);
	DispatchKeyValue(client, "targetname", target);
	DispatchKeyValue(entity, "spawnflags", "256");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "DisableShadows", "1");
	DispatchKeyValue(entity, "model", hatsArray[indexhat][model]);
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", hatsArray[indexhat][size]);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	DispatchSpawn(entity);	
	AcceptEntityInput(entity, "TurnOn", entity, entity, 0);
	TeleportEntity(entity, hatOrigin, hatAngles, NULL_VECTOR); 

	SetVariantString(target);
	AcceptEntityInput(entity, "SetParent", entity, entity, 0);
}

public Action reloadHats(int client, int args)
{
	CReplyToCommand(client, "Hat config reloaded!");
	LoadConfigHats();
	return Plugin_Handled;
}

public Action HatCommand(int client, int args)
{
	if(!sm_top_defenders_enabled.BoolValue || !sm_top_defenders_hats_enabled.BoolValue) return Plugin_Handled;
	#if defined DEBUG 
	 	Menu_Hats(client);
	#endif
	if(!ClientHasHat[client]) {
		CReplyToCommand(client, "%s You are {lightred}not{default} one of the {blue}top %d defenders{default}", TAG_COLOR, sm_top_defenders_winners.IntValue);
		return Plugin_Handled;
	}
	/*
	if(GetClientMenu(client) != MenuSource_None){
		CReplyToCommand(client, "%s You have already opened a menu. Close it before you can open this menu.", TAG_COLOR);
		return Plugin_Handled;
	}
	*/
	Menu_Hats(client);
	return Plugin_Handled;
}

void Menu_Hats(int client)
{
	Menu menu = CreateMenu(MenuHandler_Menu_Hats);
	menu.SetTitle("Choose !hat");
	char menu_text[32];
	char hat_id[32];
	menu.AddItem("0", "None (remove)");
	for (int index = 1; index < 128; index++) {
		if(hatsArray[index][enabled]) 	{
			Format(menu_text, sizeof(menu_text), "%s", hatsArray[index][hatname]);
			Format(hat_id, sizeof(hat_id), "%d", index);
			menu.AddItem(hat_id, menu_text);
		}
	}
	if(menu.ItemCount>7) {
		menu.ExitBackButton = true;
	}
	/* 
	menu.Display(client, MENU_TIME_FOREVER); 
	*/
	menu.Display(client, 20);
}

public int MenuHandler_Menu_Hats(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_End:
			delete(menu);
		/*
		case MenuAction_Cancel:
			CPrintToChat(client, "%s You have close the {lightred}!hat{default} menu", TAG_COLOR);
		*/
		case MenuAction_Select:
		{
			char sOption[32];
			menu.GetItem(param, sOption, sizeof(sOption));
			int target = StringToInt(sOption);
			#if defined DEBUG 
	 			CreateHat(client, target);  // debuging
			#endif
			if (!ClientHasHat[client] || !sm_top_defenders_enabled.BoolValue || !sm_top_defenders_hats_enabled.BoolValue || !IsPlayerAlive(client)) {
				CPrintToChat(client, "%s {lightred}Your permissions have expired", TAG_COLOR);
				delete(menu);
			} else if (target == 0) {
				RemoveHat(client);
			} else {
				CreateHat(client, target);
				CPrintToChat(client, "%s You have chosen {lightred}%s{default}", TAG_COLOR, hatsArray[target][hatname]);
			}
		}
	}
}

stock void RemoveHat(int client)
{	
	cooldowntime[client] = 0.0;
	int entity = EntRefToEntIndex(entity_client[client]);
	if(entity == INVALID_ENT_REFERENCE) return;
	
	AcceptEntityInput(entity, "Kill");
	entity_client[client] = INVALID_ENT_REFERENCE;
}

public Action Timer_Ladder(Handle timer, any client){
	int entity = EntRefToEntIndex(entity_client[client]);
	if(!IsClientConnected(client) || !sm_top_defenders_enabled.BoolValue || !sm_top_defenders_hats_enabled.BoolValue || !ClientHasHat[client]|| GetClientTeam(client) == CS_TEAM_SPECTATOR ){
		#if defined DEBUG 
	 		return Plugin_Handled;  // debuging
		#endif
		RemoveHat(client);		
		KillTimer(timer);
		return Plugin_Stop;
	} else if(entity_client[client] == INVALID_ENT_REFERENCE  || !IsValidEdict(entity)  || timer_client[client]!=timer) {
		KillTimer(timer);
		return Plugin_Stop;
	} else 	if(!IsPlayerAlive(client)) {
		AcceptEntityInput(entity, "TurnOff", entity, entity, 0);
	} else {
		AcceptEntityInput(entity, "TurnOn", entity, entity, 0);
	}

	float fAngles[3];
	GetClientEyeAngles(client, fAngles);
	if ((GetEntityMoveType(client) == MOVETYPE_LADDER || fAngles[0] <= sm_top_defenders_hide_angle.FloatValue) && sm_top_defenders_hide_enabled.BoolValue) {  
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 0,0,0,100);
			cooldowntime[client] = GetGameTime();
		} else if(!(cooldowntime[client] + sm_top_defenders_hide_cooldown.FloatValue > GetGameTime())) {
			SetEntityRenderMode(entity, RENDER_NORMAL);
			SetEntityRenderColor(entity, 255, 255, 255, 255);
		}
	return Plugin_Handled;
}

stock bool IsValidClient(int client, bool nobots = false )
{ 
	if ( !( 1 <= client <= MaxClients ) || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
		return false; 
	return IsClientInGame(client); 
}  

stock void PrintToConsoleAll(const char[] format, any...) 
{
	char text[192];
	VFormat(text, sizeof(text), format, 2);
	/* Removes color variables */
	char removecolor[][] = {"{default}", "{darkred}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}", "{lime}", "{lightred}", "{purple}", "{grey}", "{orange}", "{bluegrey}", "{lightblue}", "{darkblue}", "{grey2}", "{orchid}", "{lightred2}"};
	for(int color = 0; color < sizeof(removecolor); color++ ) {
		ReplaceString(text, sizeof(text), removecolor[color], "", false);
	}
	for(int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client)) {
			PrintToConsole(client, text);
		}
}  

stock char toString(int digi)
{ 
	char text[50];
	IntToString(digi, text, sizeof(text));
	/* 
	Format(text, sizeof(text), "%d", digi); 
	*/
	return text; 
}  
