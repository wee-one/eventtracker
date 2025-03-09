addon.name      = 'eventtracker';
addon.author    = 'weeone';
addon.version   = '0.1';
addon.desc      = 'tracks players at LS events';
addon.link      = 'na';

require('common');
local settings = require('settings');
local imgui = require('imgui');
local chat = require('chat');
local zones = require('zones');
local jobs = require('jobs');
local logdate = os.date("%Y-%m-%d")
local defaultConfig = T{
	showAlliance = true
}
local config = settings.load(defaultConfig);
local playerName = '';
local dkpTimer = os.clock();
local members = {};
local maxDkp = 0;
local cycles = 0;
local eventRunning = false;
local nextDkp = 0;
local eventType = '';
local alliance = '';
local red = {1.0, 0.0, 0.0, 1.0};
local snapshotName = '';

-- Default Settings

--[[
* Prints the addon help information.
*
* @param {boolean} isError - Flag if this function was invoked due to an error.
--]]

ashita.events.register('d3d_present', 'present_cb', function ()
	local windowSize = 200;
	imgui.SetNextWindowBgAlpha(0.5);
    imgui.SetNextWindowSize({ windowSize, -1, }, ImGuiCond_Always);
	if (imgui.Begin('eventtracker', true, bit.bor(ImGuiWindowFlags_NoDecoration))) then
		nextDkp = math.floor(dkpTimer - os.clock());
		local mins = math.floor(nextDkp / 60);
		local secs = nextDkp % 60;
		local strSecs = (secs < 10) and '0'..tostring(secs) or tostring(secs);
		
		imgui.Text('Event: ')
		imgui.SameLine();
		if eventType ~= '' then
			imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize(eventType));
			imgui.Text(eventType)
		else
			imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize('Required'));
			imgui.TextColored(red, 'Required');
		end;
		imgui.Text('Alliance: ')
		imgui.SameLine();
		if alliance ~= '' then
			imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize(alliance));
			imgui.Text(alliance)
		else
			imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize('Required'));
			imgui.TextColored(red, 'Required');
		end
		imgui.Text('Checks: ');
		imgui.SameLine();
		imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize(tostring(maxDkp)));
		imgui.Text(tostring(maxDkp));
		
		if eventRunning then
			imgui.Text('Next Check: ')
			imgui.SameLine();
			imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize('6:00'));
			imgui.Text(tostring(mins) .. ':' .. strSecs)
		else
			imgui.Text('Event not started')
		end;
		
		if config.showAlliance then
			imgui.Separator();
			imgui.Separator();
			for key,value in pairs(members) do
				if key ~= '' then
					imgui.Text(key)
					imgui.SameLine();
					imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - imgui.GetStyle().FramePadding.x - imgui.CalcTextSize(tostring(value)));
					imgui.Text(tostring(value))
					imgui.Separator();
				end;
			end;
		end;
		if (nextDkp <= 0 and eventRunning) then
			getDkp();
		end;
	end;
end);

function getDkp()
	local party = AshitaCore:GetMemoryManager():GetParty();
	cycles = cycles +1;
	if cycles > 1 then
		maxDkp = cycles-1;
		-- loop through the alliance
		for i = 0, 17 do
			local found = false;
			if party:GetMemberIsActive(i) ~= 0 then
				local partyMember = party:GetMemberName(i);
				-- loop over who's been recorded
				for key, value in pairs(members) do
					if partyMember == key then
						members[key] = members[key]+1;
						found = true;
					end;
				end;
				-- if someone was added to the alliance start recording them
				if not found and partyMember ~= '' then
					members[partyMember] = 1;
				end;
			end;
		end
		-- write log
		local header = true;
		for key, value in pairs(members) do
			local line = key .. ',' .. value .. ',' .. eventType .. ',' .. alliance .. ',' .. maxDkp
			write_to_file(playerName, eventType, alliance, maxDkp, line,header);
			header=false;
		end;
		-- create master
			write_master(playerName, eventType, alliance, maxDkp);
	end;
	dkpTimer = os.clock() + 360;
	
	
	
end;

function get_party()
    local party = AshitaCore:GetMemoryManager():GetParty();
    playerName = party:GetMemberName(0);
	
    for i = 0, 17 do
        if party:GetMemberIsActive(i) ~= 0 then
			local partyMember = party:GetMemberName(i);
			if partyMember ~= '' then
				members[partyMember] = 0;
			end;
		end;
	end;
end
local function print_help(isError)
    -- Print the help header..
    if (isError) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message('Available commands:')));
    end

    local cmds = T{
        { '/event /et help','Displays the addons help information.' },
		{ '/event /et start','Starts the event. Alliance will be scanned every 6 minutes.' },
		{ '/event /et snapshot [name] or ss [name]','REQUIRED: Defines the event taking place. i.e. Dynamis, Sky, etc' },
		{ '/event /et type [name]','REQUIRED: Defines the event taking place. i.e. Dynamis, Sky, etc' },
		{ '/event /et alliance [name]','REQUIRED: Defines the alliance name. i.e. Main, outside, 1, 2, etc' },
		{ '/event /et showalliance','Toggles the alliance visibility.' },
    };

    -- Print the command list..
    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end
 

function write_to_file(playername, eventType, alliance, maxDkp, line, header)
    local path = AshitaCore:GetInstallPath() .. '\\addons\\eventtracker\\logs\\'..eventType .. '_' .. logdate..'\\';
	local master = eventType + '_' + playername + '_' + alliance  + '.csv';
    local logfile = eventType + '_' + playername + '_' + alliance + '_' + maxDkp + '.csv';
	ashita.fs.create_dir(path);
	
	local filename = io.open((path .. logfile), 'a');
    if (filename ~= nil) then
		if header then
			filename:write('Player,Checks,Event,Alliance,Total Checks\n');
		end;
		filename:write(line .. '\n');
        filename:close();
	else
        print(chat.header(addon.name):append(chat.message('Could not write to file: ' .. path .. logfile)));
    end
	--os.remove(path .. master);
	
end;
function write_master(playername, eventType, alliance, maxDkp)
	local path = AshitaCore:GetInstallPath() .. '\\addons\\eventtracker\\logs\\'..eventType .. '_' .. logdate..'\\';
	local master = 'master_' + eventType + '_' + playername + '_' + alliance  + '.csv';
	local logfile = eventType + '_' + playername + '_' + alliance + '_' + maxDkp + '.csv';
	local source = io.open(path .. logfile, "r")
	local fileContents = source:read("*a")
	source:close();
	
	local outfile = io.open(path .. master, "w")
	outfile:write(fileContents)
	outfile:close()
end;

function save_snapshot(playername, snapshotName, eventType, alliance, maxDkp, line, header )
	local path = AshitaCore:GetInstallPath() .. '\\addons\\eventtracker\\logs\\'..eventType .. '_' .. logdate..'\\snapshots\\';
	local snapshotFile = 'snapshot_' + snapshotName + '_' + eventType + '_' + playername + '_' + alliance  + '.csv';
	ashita.fs.create_dir(path);
	local filename = io.open((path .. snapshotFile), 'a');
	if (filename ~= nil) then
		if header then
			filename:write('Player,Checks,Snapshot,Event,Alliance,Total Checks\n');
		end;
		filename:write(line .. '\n');
        filename:close();
	else
        print(chat.header(addon.name):append(chat.message('Could not write to file: ' .. path .. logfile)));
    end
	
end;
--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load','load_cb', function ()
    get_party();
end);

--[[
* event: unload
* desc : Event called when the addon is being unloaded.
--]]
ashita.events.register('unload','unload_cb', function ()
    -- does nothing for now
	-- todo: save logging preferences
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command','command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/eventtracker' and args[1] ~= '/event' and args[1] ~= '/et')) then
        return;
    end

    -- Block all eventtracker related commands..
    e.blocked = true;

    -- Handle: /eventtracker help - Shows the addon help.
    if (#args == 2 and args[2]:any('help')) then
        print_help(false);
        return;
    end
	
	
	-- Handle: /eventtracker type - sets the event type.
    if (#args == 3 and args[2]:any('type')) then
       eventType = args[3];
        return;
    end
	-- Handle: /eventtracker alliance - sets the event type.
    if (#args == 3 and args[2]:any('alliance')) then
       alliance = args[3];
        return;
    end
	
	-- Handle: /eventtracker snapshot - sets the event type.
    if (#args == 3 and (args[2]:any('ss') or args[2]:any('snapshot'))) then
	local party = AshitaCore:GetMemoryManager():GetParty();
       snapshotName = args[3];
	   local header = true;
		for i = 0, 17 do
			if party:GetMemberIsActive(i) ~= 0 then
				local partyMember = party:GetMemberName(i);
				local line = partyMember .. ',' .. tostring(members[partyMember]) .. ',' .. snapshotName .. ',' .. eventType .. ',' .. alliance .. ',' .. maxDkp
				save_snapshot(playerName, snapshotName, eventType, alliance, maxDkp, line, header);
			end;
			header=false;
		end;
		print('Snapshot ' .. snapshotName .. ' saved.');
        return;
    end

    -- Handle: /eventtracker start Starts the event tracker
    if (#args == 2 and args[2]:any('start')) then
		if (eventType ~= '' and alliance ~= '') then
			eventRunning = true;
			getDkp();
		else
			print('You must set the event name and alliance name before starting the event.');
		end;
		return
    end
	if (#args == 4 and args[2]:any('start')) then
			eventType = args[3];
			alliance = args[4];
			eventRunning = true;
			getDkp();
		
		return
    end
	if (#args == 2 and args[2]:any('stop')) then
		eventType = '';
		alliance = '';
		eventRunning = false;
		return
    end
	-- Handle: /showalliance toggles the alliance view
	if (#args == 2 and args[2]:any('showalliance')) then --turns alliance on/off
        if (config.showAlliance == true) then
			config.showAlliance = false;
		else
			config.showAlliance = true;
		end

		settings.save();
        return;
    end

    -- Unhandled: Print help information..
    print_help(true);
end);
