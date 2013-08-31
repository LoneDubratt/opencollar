//OpenCollar - getavi
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

// parameters/syntax for linked messages
//
// incoming message = TARGET|FROM|USER|AUTH|TYPE|LOOK4|EXCLUDE
// TARGET    = string;    recipient of message, script id
// FROM        = string;    sending script id
// USER        = key;        uuid of the menu-user/requesting agent
// AUTH        = integer;    requesting user's auth
// TYPE        = string;    requesting script's usage, determines what to be done with name(s) retrieved
// LOOK4    = string;    partial or full name to look for
// EXCLUDE    = string;    name(s) to exclude in search, separated by commas
//
// outgoing message = TARGET|USER|AUTH|DO|TYPE|FOUND
// FOUND    = key;        name of selected agent
//
// llLinkedMessage(LINK_THIS, FIND_AGENT, message, REQUEST_KEY)
// REQUEST_KEY = llGenerateKey() generated by requesting script

key g_kWearer;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer FIND_AGENT = -9005;

//dialog handler
key g_kMenuID;
key g_kDialoger; //the person using the dialog.
integer g_iDialogerAuth; //auth of the person using the dialog

// message handler
key REQUEST_KEY;    // Request Key, generated by initiating script
key USER;            // Requesting agent uuid
integer AUTH;        // Requesting agent's auth
string REQ;            // Requesting script id
string TYPE;        // requesting for what use?
list AVIS;            // List of Avis in region, matching requested criteria

string g_sScript;

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else
    {
        llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
}

list FindAvis(string in, list ex)
{
    list out = llGetAgentList(AGENT_LIST_REGION, []);
    string name;
    integer i = llGetListLength(out) - 1;
    while(~i)
    {
        name = llKey2Name(llList2Key(out, i));
        if (llSubStringIndex(llToLower(name), llToLower(in)) == -1)
            out = llDeleteSubList(out, i, i);
        i--;
    }
    Debug("first pass results: " + llList2CSV(out));
    i = llGetListLength(out) - 1;
    while (~i) // kill exclusions
    {
        if (~llListFindList(ex, [llList2String(out, i)]))
            out = llDeleteSubList(out, i, i);
        i--;
    }
    Debug("second pass results: " + llList2CSV(out));
    return out;
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" 
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
}

NamesMenu(list lAvs)
{
    string sPrompt = "Select an avatar to add";
    g_kMenuID = Dialog(USER, sPrompt, lAvs, [], 0, AUTH);
}

SendResult(key found)
{
    string out = llDumpList2String([REQ, g_sScript, USER, AUTH, TYPE, found], "|");
    llMessageLinked(LINK_THIS, FIND_AGENT, out, REQUEST_KEY);
}

default
{
    on_rez(integer r)
    {
        llResetScript();
    }
    state_entry()
    {
        g_sScript = llStringTrim(llList2String(llParseString2List(llGetScriptName(), ["-"], []), 1), STRING_TRIM) + "_";
        g_kWearer = llGetOwner();
        AVIS = [];
    }
    link_message(integer link, integer num, string mess, key id)
    {
        integer i;
        list params = llParseString2List(mess, ["|"], []);
        if (num == DIALOG_RESPONSE && id == g_kMenuID)
        {
            key user = (key)llList2String(params, 0);
            string name = llList2String(params, 1);
            integer auth = (integer)llList2String(params, 3);
            if (name == "Yes")
            {
                SendResult(llList2Key(AVIS, 0));
                return;
            }
            else if (name == "No") return;
            for (; i < llGetListLength(AVIS); i++)
            {
                key avi = llList2Key(AVIS, i);
                if (avi == name)
                {
                    SendResult(avi);
                    return;
                }
            }
            // if we got here, something went wrong
            Debug("Button clicked did not match any buttons made");
        }
        else if (num != FIND_AGENT) return;
        if (llList2String(params, 0) != g_sScript) return;
        REQUEST_KEY = id;
        REQ = llList2String(params, 1);
        USER = (key)llList2String(params, 2);
        AUTH = (integer)llList2String(params, 3);
        TYPE = llList2String(params, 4);
        string find = llList2String(params, 5);
        if (find == " ") find = "";
        list excl = llParseString2List(llList2String(params, 6), [","], []);
        AVIS = FindAvis(find, excl);
        i = llGetListLength(AVIS);
        if (!i)
        {
            mess = "Could not find any avatars ";
            if (find != "") mess += "starting with \"" + find + "\" ";
            Notify(USER, mess + "in the region", FALSE);
        }
        else if (i == 1 && llList2Key(AVIS, 0) == USER)
        {
            g_kMenuID = Dialog(USER, "You are the only one in this region. Add yourself?", ["Yes", "No"], [], 0, AUTH);
        }
        else NamesMenu(AVIS);
    }
}
