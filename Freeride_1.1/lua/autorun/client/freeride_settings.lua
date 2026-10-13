-- Freeride settings integration for SkateGM 9.0.
-- This patches the existing 9.0 settings object at runtime instead of replacing
-- SkateGM's cl_settings.lua, so new SkateGM settings remain intact.

if SERVER then return end

local patched=false

local BIND_KEYS={
	{"A",KEY_A},{"B",KEY_B},{"C",KEY_C},{"D",KEY_D},{"E",KEY_E},{"F",KEY_F},{"G",KEY_G},{"H",KEY_H},
	{"I",KEY_I},{"J",KEY_J},{"K",KEY_K},{"L",KEY_L},{"M",KEY_M},{"N",KEY_N},{"O",KEY_O},{"P",KEY_P},
	{"Q",KEY_Q},{"R",KEY_R},{"S",KEY_S},{"T",KEY_T},{"U",KEY_U},{"V",KEY_V},{"W",KEY_W},{"X",KEY_X},
	{"Y",KEY_Y},{"Z",KEY_Z},
	{"0",KEY_0},{"1",KEY_1},{"2",KEY_2},{"3",KEY_3},{"4",KEY_4},{"5",KEY_5},{"6",KEY_6},{"7",KEY_7},{"8",KEY_8},{"9",KEY_9},
	{"SPACE",KEY_SPACE},{"LSHIFT",KEY_LSHIFT},{"RSHIFT",KEY_RSHIFT},{"LCONTROL",KEY_LCONTROL},{"RCONTROL",KEY_RCONTROL},
	{"LALT",KEY_LALT},{"RALT",KEY_RALT},{"ENTER",KEY_ENTER},{"BACKSPACE",KEY_BACKSPACE},{"TAB",KEY_TAB},
	{"UP",KEY_UP},{"DOWN",KEY_DOWN},{"LEFT",KEY_LEFT},{"RIGHT",KEY_RIGHT},
	{"INSERT",KEY_INSERT},{"DELETE",KEY_DELETE},{"HOME",KEY_HOME},{"END",KEY_END},{"PAGEUP",KEY_PAGEUP},{"PAGEDOWN",KEY_PAGEDOWN},
	{"CAPSLOCK",KEY_CAPSLOCK},{"F1",KEY_F1},{"F2",KEY_F2},{"F3",KEY_F3},{"F4",KEY_F4},{"F5",KEY_F5},{"F6",KEY_F6},
	{"F7",KEY_F7},{"F8",KEY_F8},{"F9",KEY_F9},{"F10",KEY_F10},{"F11",KEY_F11},{"F12",KEY_F12},
}

local BIND_IDS={
	"move_forward","move_backward","move_left","move_right",
	"stick_up","stick_down","stick_left","stick_right",
	"button_a","button_b","jump","shift","button_f","button_z","button_c",
	"trigger_left","trigger_right","ctrl","alt",
	"dpad_up","dpad_down","dpad_left","dpad_right","enter","menu_back",
	"freecam","camera_cycle","respawn",
}

local DEFAULTS={
	move_forward=KEY_W,move_backward=KEY_S,move_left=KEY_A,move_right=KEY_D,
	stick_right=KEY_RIGHT,stick_left=KEY_LEFT,stick_up=KEY_UP,stick_down=KEY_DOWN,
	button_a=KEY_X,button_b=KEY_V,jump=KEY_SPACE,shift=KEY_LSHIFT,button_f=KEY_F,
	button_z=KEY_Z,button_c=KEY_C,dpad_up=KEY_I,dpad_down=KEY_K,dpad_left=KEY_U,dpad_right=KEY_O,
	enter=KEY_ENTER,ctrl=KEY_LCONTROL,alt=KEY_LALT,menu_back=KEY_BACKSPACE,
	trigger_left=KEY_Q,trigger_right=KEY_E,respawn=KEY_R,freecam=KEY_L,camera_cycle=KEY_B,
}

local function cvString(name,default)
	local c=GetConVar(name)
	return c and c:GetString() or tostring(default or "")
end

local function cvNumber(name,default)
	return tonumber(cvString(name,default)) or default
end

local function keyName(code)
	for _,entry in ipairs(BIND_KEYS) do if entry[2]==code then return entry[1] end end
	return "UNBOUND"
end

local function patchSettings()
	if patched then return true end
	if not (SKATEGM_UI and SKATEGM_UI.settings and SKATEGM_UI.List) then return false end
	local UI=SKATEGM_UI
	local SET=UI.settings
	local List=UI.List
	if not (SET.MainPage and SET.CameraPage and SET.BoolRow and SET.ChoiceRow and SET.NumberRow and SET.Think and SET.Press) then return false end

	local BoolRow,ChoiceRow,NumberRow=SET.BoolRow,SET.ChoiceRow,SET.NumberRow
	local function Percent(v) return string.format("%.0f%%",v*100) end

	SET.MouseFlickitPage=function()
		return {title="Mouse Flickit",rows={
			BoolRow("Enable Mouse Flickit (hold Mouse 1)","skategm_mouse_flickit"),
			NumberRow("Mouse sensitivity","skategm_mouse_flickit_sensitivity",0.003,0.025,0.001,function(v) return string.format("%.3f",v) end),
			NumberRow("Mouse deadzone","skategm_mouse_flickit_deadzone",0,0.25,0.01,Percent),
			BoolRow("Circular stick limit (experimental)","skategm_mouse_flickit_circular"),
			BoolRow("Show Flick-it HUD","skategm_flickit_hud"),
			BoolRow("Show Flickit trail","skategm_flickit_hud_trail"),
			BoolRow("Show deadzone ring","skategm_flickit_hud_deadzone"),
			BoolRow("Freecam enabled","skategm_mouse_freecam"),
		}}
	end

	local function BindRow(id,label)
		local cvname="skategm_bind_"..id
		return {
			label=label,
			value=function()
				if SET.freerideBinding and SET.freerideBinding.id==id then return "PRESS KEY..." end
				return keyName(cvNumber(cvname,-1))
			end,
			run=function()
				SET.freerideBinding={id=id,ready=false}
				SET.Say("Release all keys, then press a key. ESC cancels.")
			end,
		}
	end

	local function BindingThink()
		local b=SET.freerideBinding
		if not b then return end
		local any=false
		for _,entry in ipairs(BIND_KEYS) do if input.IsKeyDown(entry[2]) then any=true break end end
		if input.IsKeyDown(KEY_ESCAPE) then
			if b.ready then SET.freerideBinding=nil SET.Say("Keybind cancelled") end
			return
		end
		if not b.ready then
			if not any then b.ready=true end
			return
		end
		for _,entry in ipairs(BIND_KEYS) do
			if input.IsKeyDown(entry[2]) then
				local conflict
				for _,other in ipairs(BIND_IDS) do
					if other~=b.id and cvNumber("skategm_bind_"..other,-1)==entry[2] then conflict=other break end
				end
				if conflict then
					SET.Say(entry[1].." is already assigned to "..conflict..". Choose another key.")
					b.ready=false
				else
					RunConsoleCommand("skategm_bind_"..b.id,tostring(entry[2]))
					SET.Say("Assigned "..entry[1])
					SET.freerideBinding=nil
				end
				return
			end
		end
	end

	function SET.FreerideKeybindPage(title,definitions)
		local rows={}
		for _,v in ipairs(definitions) do rows[#rows+1]=BindRow(v[1],v[2]) end
		return {title=title,rows=rows}
	end

	SET.FreerideKeybindsPage=function()
		return {title="Keybinds (keyboard only)",rows={
			{label="Movement",page=function() return SET.FreerideKeybindPage("Movement",{
				{"move_forward","Forward"},{"move_backward","Backward"},{"move_left","Left"},{"move_right","Right"},
				{"stick_up","Right stick up"},{"stick_down","Right stick down"},{"stick_left","Right stick left"},{"stick_right","Right stick right"},
			}) end},
			{label="Tricks & Actions",page=function() return SET.FreerideKeybindPage("Tricks & Actions",{
				{"jump","Jump / A"},{"shift","Controller Y"},{"button_f","Controller X"},
				{"button_z","Left bumper"},{"button_c","Right bumper / interact"},
				{"trigger_left","Left trigger"},{"trigger_right","Right trigger"},{"ctrl","Right stick click / rocket"},{"alt","Item / Left Alt action"},
			}) end},
			{label="D-pad & Menu",page=function() return SET.FreerideKeybindPage("D-pad & Menu",{
				{"dpad_up","D-pad Up"},{"dpad_down","D-pad Down"},{"dpad_left","D-pad Left"},{"dpad_right","D-pad Right"},
				{"enter","Start / Enter"},{"menu_back","Menu back"},
			}) end},
			{label="Camera & System",page=function() return SET.FreerideKeybindPage("Camera & System",{
				{"camera_cycle","Cycle camera mode"},{"freecam","Toggle Freecam"},{"respawn","Respawn"},
			}) end},
			{label="Reset all keybinds",run=function()
				for id,key in pairs(DEFAULTS) do RunConsoleCommand("skategm_bind_"..id,tostring(key)) end
				SET.Say("Freeride keybinds reset")
			end},
		}}
	end

	-- Keep every 9.0 camera setting, then append Freeride camera options.
	local OriginalCameraPage=SET.CameraPage
	SET.CameraPage=function()
		local page=OriginalCameraPage()
		local rows=page.rows or {}
		rows[#rows+1]=List.Heading("Freeride")
		rows[#rows+1]=ChoiceRow("Camera mode","skategm_fp_mode",{"Third Person","First Person - Stabilized","First Person - Realistic"},nil,0)
		rows[#rows+1]=NumberRow("Stabilized motion","skategm_fp_motion",0,100,5,function(v) return string.format("%d%%",v) end)
		rows[#rows+1]=BoolRow("First-person mouse look","skategm_fp_freelook")
		rows[#rows+1]=NumberRow("First-person look sensitivity","skategm_fp_look_sensitivity",0.1,4,0.1,function(v) return string.format("%.1fx",v) end)
		rows[#rows+1]=NumberRow("Horizontal look limit","skategm_fp_horizontal_limit",30,180,5,function(v) return string.format("%d°",v) end)
		rows[#rows+1]=NumberRow("Vertical look limit","skategm_fp_vertical_limit",30,89,1,function(v) return string.format("%d°",v) end)
		rows[#rows+1]=BoolRow("Auto-center first-person view","skategm_fp_auto_center")
		rows[#rows+1]=NumberRow("Auto-center speed","skategm_fp_center_speed",0.2,10,0.2,function(v) return string.format("%.1f",v) end)
		return page
	end

	-- Add Freeride pages without replacing SkateGM 9.0's MainPage implementation.
	local OriginalMainPage=SET.MainPage
	SET.MainPage=function()
		local page=OriginalMainPage()
		local rows=page.rows or {}
		local cameraIndex=3
		for i,row in ipairs(rows) do if row.label=="Camera" then cameraIndex=i break end end
		table.insert(rows,cameraIndex+1,{label="Mouse Flickit",page=SET.MouseFlickitPage,sub="mouse tricks, sensitivity, deadzone"})
		table.insert(rows,cameraIndex+2,{label="Keyboard Only",page=SET.FreerideKeybindsPage,sub="press a key to rebind keyboard actions"})
		return page
	end

	local OriginalThink=SET.Think
	SET.Think=function(...)
		BindingThink()
		return OriginalThink(...)
	end

	local OriginalPress=SET.Press
	SET.Press=function(btn)
		if SET.freerideBinding then return end
		return OriginalPress(btn)
	end

	local OriginalClose=SET.Close
	SET.Close=function(...)
		SET.freerideBinding=nil
		return OriginalClose(...)
	end

	patched=true
	print("[Freeride] SkateGM 9.0 settings integration loaded")
	return true
end

hook.Add("Think","Freeride_SkateGM90_SettingsPatch",function()
	if patchSettings() then hook.Remove("Think","Freeride_SkateGM90_SettingsPatch") end
end)
