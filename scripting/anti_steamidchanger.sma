#include <amxmodx>
#include <amxmisc>
#include <reapi>

new const WHITE_LIST_FILE[] = "settings/settings_asc_whitelist.ini";

enum client_info_struct {
    CLIENT_IP[MAX_IP_LENGTH],
    CLIENT_STEAMID[MAX_AUTHID_LENGTH]
};

new Array: g_aClientsInfo;
new g_iClients;

new Array: g_aWhiteList;
new g_iWhiteList;

new Array: g_aPunishCache;
new g_iPunishCache;

new g_iReasonCvar;
new g_szReason[47];

new g_iCommandCvar;
new g_szPunishmentCommand[32];

new g_iAddWhiteFlagCvar;
new g_iAddWhiteFlag;

new g_szCfg[MAX_RESOURCE_PATH_LENGTH];

public plugin_init()    {
    register_plugin("Anti steamid changer", "1.0.1", "m4ts");

    load_white_list();

    g_iReasonCvar = create_cvar(
        "asc_reason",
        "SteamID Changer",
        _,
        "Reason to punish"
    );

    g_iCommandCvar = create_cvar(
        "asc_command",
        "fb_ban 44640 #userid#",
        _,
        "Punishment command"
    );

    g_iAddWhiteFlagCvar = create_cvar(
        "asc_flags",
        "l",
        _,
        "Flag for access to the asc_add_white command (adding IP to the whitelist)"
    );

    AutoExecConfig(true, "anti_steamid_change", "punishments");

    RegisterHookChain(RH_Cvar_DirectSet, "RH_Cvar_DirectSet_Post", 1);
}

public RH_Cvar_DirectSet_Post(pcvar, const value[]) {
    if (pcvar == g_iReasonCvar) {
        copy(g_szReason, charsmax(g_szReason), value);
    }
    else if (pcvar == g_iCommandCvar)    {
        copy(g_szPunishmentCommand, charsmax(g_szPunishmentCommand), value);
    }
    else if (pcvar == g_iAddWhiteFlagCvar)    {
        g_iAddWhiteFlag = read_flags(value);

        register_concmd("asc_clear_cache", "concmd_clear_cache", g_iAddWhiteFlag, _, 1);
        register_concmd("asc_add_white", "concmd_add_white", g_iAddWhiteFlag, "<name|steamid|userid>", 1);
    }
}

public concmd_clear_cache(id, level)   {
    if (!access(id, level)) {
        server_print("[ASC] No have access to that command");

        return PLUGIN_HANDLED;
    }

    new destroy = ArrayDestroy(g_aPunishCache);

    server_print("[ASC] %s punishments cache. Total [%d]", destroy ? "Succesfully cleared" : "No had a", g_iPunishCache);

    g_iPunishCache = 0;

    return PLUGIN_HANDLED;
}

public concmd_add_white(id, level)  {
    if (!access(id, level)) {
        server_print("[ASC] No have access to that command");

        return PLUGIN_HANDLED;
    }

    new szArg[MAX_AUTHID_LENGTH];
    read_argv(1, szArg, MAX_AUTHID_LENGTH - 1);

    new player = cmd_target(id, szArg, CMDTARGET_NO_BOTS);

    if (!player)    {
        server_print("[ASC] No players find yet");

        return PLUGIN_HANDLED;
    }

    new szIp[MAX_IP_LENGTH];
    get_user_ip(player, szIp, MAX_IP_LENGTH - 1, 1);

    if (g_iWhiteList && ArrayFindString(g_aWhiteList, szIp) != -1)  {
        server_print("[ASC] This player already have immunity");

        return PLUGIN_HANDLED;
    }

    new file, buffer[64];

    formatex(buffer, charsmax(buffer), "%s    ; %n", szIp, player);

    new iExists = file_exists(g_szCfg);
    file = fopen(g_szCfg, iExists ? "at" : "wt");

    if (!iExists)   {
        fputs(file, "; Anti SteamID Changer - whitelist");
        fputs(file, "; Formatting file is - <ip> ; comment");
    }

    if (!file)  {
        server_print("[ASC] White list file read error");

        return PLUGIN_HANDLED;
    }

    new bSuccess = fputs(file, buffer);
    server_print("[ASC] Player %n (%s) %s added to white list", player, szIp, bSuccess ? "successfully" : "failure");

    if (!g_aWhiteList)  {
        g_aWhiteList = ArrayCreate(MAX_IP_LENGTH + 1, 1);
    }

    ArrayPushString(g_aWhiteList, szIp);

    fclose(file);

    return PLUGIN_HANDLED;
}

public client_putinserver(id)   {
    new szIp[MAX_IP_LENGTH];
    get_user_ip(id, szIp, MAX_IP_LENGTH - 1, 1);

    if (g_iPunishCache) {
        if (ArrayFindString(g_aPunishCache, szIp) != -1)    {
            server_cmd("kick #%d %s", get_user_userid(id), g_szReason);

            return;
        }
    }

    if (g_iClients && !is_user_hltv(id)) {
        new szOutput[client_info_struct], bool: bGotcha, iItemId;

        for (new i; i < g_iClients; i++)    {
            ArrayGetArray(g_aClientsInfo, i, szOutput, sizeof szOutput);

            if (equal(szOutput[CLIENT_IP], szIp))   {
                bGotcha = true;
                iItemId = i;

                break;
            }
        }

        if (bGotcha)    {
            new szAuthid[MAX_AUTHID_LENGTH];
            get_user_authid(id, szAuthid, MAX_AUTHID_LENGTH - 1);

            if (!equal(szAuthid, szOutput[CLIENT_STEAMID])) {
                client_punishment(id);

                ArrayDeleteItem(g_aClientsInfo, iItemId);
                g_iClients--;

                if (!g_aPunishCache)    {
                    g_aPunishCache = ArrayCreate(MAX_IP_LENGTH + 1, 1);
                }

                ArrayPushString(g_aPunishCache, szIp);
                g_iPunishCache++;
            }
        }
    }
}

public client_disconnected(id)  {
    if (is_user_bot(id))    {
        return;
    }

    if (!g_aClientsInfo)    {
        g_aClientsInfo = ArrayCreate(client_info_struct);
    }

    new szInput[client_info_struct];

    get_user_ip(id, szInput[CLIENT_IP], MAX_IP_LENGTH - 1, 1);
    get_user_authid(id, szInput[CLIENT_STEAMID], MAX_AUTHID_LENGTH - 1);

    if (g_iWhiteList)   {
        if (ArrayFindString(g_aWhiteList, szInput[CLIENT_IP]) != -1)    {
            return;
        }
    }

    ArrayPushArray(g_aClientsInfo, szInput);
    g_iClients++;
}

stock client_punishment(id)    {
    new szIp[MAX_IP_LENGTH], szAuthid[MAX_AUTHID_LENGTH];

    get_user_ip(id, szIp, MAX_IP_LENGTH - 1, 1);
    get_user_authid(id, szAuthid, MAX_AUTHID_LENGTH - 1);

    replace_string(g_szPunishmentCommand, charsmax(g_szPunishmentCommand), "#userid#", fmt("#%d", get_user_userid(id)), false);
    replace_string(g_szPunishmentCommand, charsmax(g_szPunishmentCommand), "#ip#", szIp, false);
    replace_string(g_szPunishmentCommand, charsmax(g_szPunishmentCommand), "#authid#", szAuthid, false);

    if (contain(g_szPunishmentCommand, "banip") != -1 || contain(g_szPunishmentCommand, "banid") != -1) {
        server_cmd("%s; writeip; writeid", g_szPunishmentCommand);
        server_exec();

        return;
    }

    server_cmd("%s %s", g_szPunishmentCommand, g_szReason);
    server_exec();
}

stock load_white_list() {
    get_configsdir(g_szCfg, MAX_RESOURCE_PATH_LENGTH - 1);
    add(g_szCfg, charsmax(g_szCfg), fmt("/%s", WHITE_LIST_FILE));

    if (!file_exists(g_szCfg))    {
        log_error(AMX_ERR_NATIVE, "File %s is not exists", g_szCfg);

        return;
    }

    new file = fopen(g_szCfg, "rt");

    if (!file)  {
        log_error(AMX_ERR_NATIVE, "File %s open error", g_szCfg);

        return;
    }

    g_aWhiteList = ArrayCreate(MAX_IP_LENGTH + 1, 1);

    new buffer[64], szIp[MAX_IP_LENGTH];

    while (!feof(file)) {
        fgets(file, buffer, charsmax(buffer));

        if (buffer[0] == EOS || buffer[0] == ';')   {
            continue;
        }

        delete_comment(buffer);
        trim(buffer);

        parse(buffer, szIp, charsmax(szIp));

        g_iWhiteList++;
        ArrayPushString(g_aWhiteList, szIp);
    }

    log_amx("Successfully loaded whitelist, count : %d", g_iWhiteList);

    fclose(file);
}

new const COMMENTS[] =   {
    '#', ';'
};

new const QUOTE = '^"';

stock delete_comment(szString[])    {
    new len = strlen(szString);
    new bool: bInQuotes;

    for (new i; i < len; i++)   {
        if (szString[i] == QUOTE)    {
            bInQuotes = !bInQuotes;
        }

        if (bInQuotes)  {
            continue;
        }

        for (new c; c < sizeof COMMENTS; c++)   {
            if (szString[i] == COMMENTS[c]) {
                szString[i] = EOS;

                break;
            }
        }
    }
}