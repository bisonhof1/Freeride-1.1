-- Freeride compatibility layer for SkateGM 9.0
-- Based on SkateGM 9.0 cl_keyboard.lua, with configurable keyboard controls,
-- Mouse Flickit, freecam, and first-person camera modes restored.

local virtualPad=CreateClientConVar("skategm_virtual_pad","0",true,false,"Keyboard as a virtual controller inside SkateGM",0,1)
local cvKeyboard=CreateClientConVar("skategm_keyboard","1",true,false,"Keyboard and mouse controls while skating (a controller always works too)",0,1)
local K={keys={},release=false}

-- Mouse Flickit
local mouseFlickit=CreateClientConVar("skategm_mouse_flickit","1",true,false,"Hold Mouse 1 to control the Flick-it right stick",0,1)
local mouseScale=CreateClientConVar("skategm_mouse_flickit_sensitivity","0.015",true,false,"Mouse Flickit sensitivity",0.001,0.1)
local mouseDeadzone=CreateClientConVar("skategm_mouse_flickit_deadzone","0",true,false,"Mouse Flickit radial deadzone",0,0.5)
local mouseCircular=CreateClientConVar("skategm_mouse_flickit_circular","0",true,false,"Circular right stick boundary (experimental)",0,1)
local mouseRX,mouseRY=0,0

local function flickHeld()
	return mouseFlickit:GetBool() and input.IsMouseDown(MOUSE_LEFT)
end

local function flickAxes()
	local dz=math.Clamp(mouseDeadzone:GetFloat(),0,0.5)
	if dz<=0 then return mouseRX,mouseRY end
	local magnitude=math.sqrt(mouseRX*mouseRX+mouseRY*mouseRY)
	if magnitude<=dz then return 0,0 end
	local output=math.Clamp((magnitude-dz)/(1-dz),0,1)
	return mouseRX/magnitude*output,mouseRY/magnitude*output
end

-- Free camera + first-person cameras
local freecamConVar=CreateClientConVar("skategm_mouse_freecam","0",true,false,"Enable mouse free camera",0,1)
local camMode=CreateClientConVar("skategm_fp_mode","0",true,false,"Camera mode: 0 third person, 1 stabilized first person, 2 realistic first person",0,2)
local camMotion=CreateClientConVar("skategm_fp_motion","35",true,false,"Stabilized first-person movement intensity",0,100)
local fpLook=CreateClientConVar("skategm_fp_freelook","1",true,false,"Mouse look in first person",0,1)
local fpSens=CreateClientConVar("skategm_fp_look_sensitivity","1",true,false,"First-person mouse look sensitivity",0.1,4)
local fpHorizontal=CreateClientConVar("skategm_fp_horizontal_limit","110",true,false,"First-person horizontal look limit",30,180)
local fpVertical=CreateClientConVar("skategm_fp_vertical_limit","80",true,false,"First-person vertical look limit",30,89)
local fpCenter=CreateClientConVar("skategm_fp_auto_center","0",true,false,"Automatically return first-person look to center",0,1)
local fpCenterSpeed=CreateClientConVar("skategm_fp_center_speed","2",true,false,"First-person auto-center speed",0.2,10)
K.fpYaw,K.fpPitch=0,0

-- Configurable keyboard mappings. Existing Freeride ConVar names are kept so
-- users do not lose their old binds when upgrading.
K.BINDS={}
K.BIND_DEFS={}
local function Bind(id,label,default,description)
	K.BINDS[id]=CreateClientConVar("skategm_bind_"..id,tostring(default),true,false,description or (label.." key code"))
	K.BIND_DEFS[#K.BIND_DEFS+1]={id=id,label=label,default=default}
end

Bind("move_forward","Forward",KEY_W)
Bind("move_backward","Backward",KEY_S)
Bind("move_left","Left",KEY_A)
Bind("move_right","Right",KEY_D)
Bind("stick_right","Right stick: right",KEY_RIGHT)
Bind("stick_left","Right stick: left",KEY_LEFT)
Bind("stick_up","Right stick: up",KEY_UP)
Bind("stick_down","Right stick: down",KEY_DOWN)
Bind("button_a","Action 1 (A)",KEY_X)
Bind("button_b","Action 2 (B)",KEY_V)
Bind("jump","Jump / A",KEY_SPACE)
Bind("shift","Controller Y",KEY_LSHIFT)
Bind("button_f","Controller X",KEY_F)
Bind("button_z","Left bumper",KEY_Z)
Bind("button_c","Right bumper",KEY_C)
Bind("dpad_up","D-pad up",KEY_I)
Bind("dpad_down","D-pad down",KEY_K)
Bind("dpad_left","D-pad left",KEY_U)
Bind("dpad_right","D-pad right",KEY_O)
Bind("enter","Start / Enter",KEY_ENTER)
Bind("ctrl","Right stick click",KEY_LCONTROL)
Bind("alt","Left Alt action",KEY_LALT)
Bind("menu_back","Menu back",KEY_BACKSPACE)
Bind("trigger_left","Left trigger",KEY_Q)
Bind("trigger_right","Right trigger",KEY_E)
Bind("respawn","Respawn",KEY_R)
Bind("freecam","Toggle Freecam",KEY_L)
Bind("camera_cycle","Cycle camera mode",KEY_B)

function K.Key(id)
	local cv=K.BINDS[id]
	return cv and cv:GetInt() or -1
end

function K.Enabled() return cvKeyboard:GetBool() end

function K.Uses(code)
	if not code or not K.Enabled() then return false end
	for _,cv in pairs(K.BINDS) do if cv:GetInt()==code then return true end end
	return false
end

function K.Blocked(S)
	if not (gui and vgui) then return true end
	return (S.InputBlockWanted and S.InputBlockWanted()) or gui.IsGameUIVisible() or vgui.CursorVisible() or (system.HasFocus and not system.HasFocus())
end

function K.Menu() return SKATEGM_UI~=nil and SKATEGM_UI.open~=nil end

function K.Read(state,blocked,menu)
	local function held(k) return k and k>=0 and not blocked and input.IsKeyDown(k) end
	local b=0

	-- Freeride controls: keyboard movement behaves like the left analog stick.
	-- W/S are forward/backward at all times while skating; they are NOT
	-- converted into SkateGM 9.0 push/brake button inputs.
	for _,v in ipairs({
		{K.Key("button_a"),0x1000},
		{K.Key("button_b"),0x2000},
		{K.Key("jump"),0x1000},
		{K.Key("shift"),0x4000},
		{K.Key("button_f"),0x8000},
		{K.Key("button_z"),0x100},
		{K.Key("button_c"),0x200},
		{K.Key("dpad_up"),1},
		{K.Key("dpad_down"),2},
		{K.Key("dpad_left"),4},
		{K.Key("dpad_right"),8},
		{K.Key("enter"),0x10},
		{K.Key("ctrl"),0x80},
	}) do
		if held(v[1]) then b=bit.bor(b,v[2]) end
	end

	local function axis(positive,negative)
		return (held(positive) and 1 or 0)-(held(negative) and 1 or 0)
	end
	local lx,ly,rx,ry=
		axis(K.Key("move_right"),K.Key("move_left")),
		axis(K.Key("move_forward"),K.Key("move_backward")),
		axis(K.Key("stick_right"),K.Key("stick_left")),
		axis(K.Key("stick_up"),K.Key("stick_down"))

	if not blocked and flickHeld() then
		rx,ry=flickAxes()
	end

	if held(K.Key("alt")) then
		local items=ITEMS and ITEMS.client and ITEMS.client.MyArena and ITEMS.client.MyArena()
		if items then b=bit.bor(b,0x0040) else ry=ry*.5 end
	end

	if menu or (state and (state:find("Biped",1,true) or state=="OffBoardPushing")) then
		-- Keep W/S as the left stick here too; Space remains the A action.
		if held(K.Key("jump")) then b=bit.bor(b,0x1000) end
		if menu and held(K.Key("menu_back")) then b=bit.bor(b,0x2000) end
	end

	local lt,rt=held(K.Key("trigger_left")) and 1 or 0,held(K.Key("trigger_right")) and 1 or 0
	return {b,lt,rt,lx,ly,rx,ry},b~=0 or lx~=0 or ly~=0 or rx~=0 or ry~=0 or lt~=0 or rt~=0
end

function K.RightStickHeld(lb,rx,ry,click,holding)
	if lb then return true end
	return holding and (rx~=0 or ry~=0 or click)
end

function K.WithoutRightStick(values)
	local b=values[1]
	K.rsHeld=K.RightStickHeld(bit.band(b,0x100)~=0,values[6],values[7],bit.band(b,0x80)~=0,K.rsHeld)
	if not K.rsHeld then return values end
	return {bit.band(b,bit.bnot(0x80)),values[2],values[3],values[4],values[5],0,0}
end

function K.Step(S,p,dt)
	if not K.Enabled() then
		skategm.Step(dt,true,0,0,0,0,0,0,0)
		S.keyboardActive=false
		S.keyboardButtons=0
		local lb=bit.band(p.padButtons or 0,0x100)~=0
		S.flickitInput={x=lb and 0 or (p.padRX or 0),y=lb and 0 or (p.padRY or 0)}
		return
	end
	local blocked=K.Blocked(S)
	local values,active=K.Read(p.state,blocked)
	active=active or (not blocked and flickHeld())
	values=K.WithoutRightStick(values)
	local useKeyboard=(virtualPad:GetBool() and not K.hardware) or active or K.release
	if active then K.owner="keyboard" end
	K.release=active
	skategm.Step(dt,not useKeyboard,unpack(values))
	S.keyboardActive=active
	S.keyboardButtons=useKeyboard and values[1] or 0
	S.flickitInput={x=blocked and 0 or (useKeyboard and values[6] or p.padRX or 0),
		y=blocked and 0 or (useKeyboard and values[7] or p.padRY or 0)}
end

function K.Shortcuts(S)
	if not flickHeld() or K.Blocked(S) or S.phase~="on" then
		mouseRX,mouseRY=0,0
	end
	if not K.Enabled() then K.look=nil return end
	local blocked=K.Blocked(S)
	local function edge(key)
		if not key or key<0 then return false end
		local down=input.IsKeyDown(key)
		local changed=down and not K.keys[key]
		K.keys[key]=down
		return changed and not blocked
	end

	if edge(K.Key("camera_cycle")) and S.phase=="on" then
		local nextMode=(camMode:GetInt()+1)%3
		RunConsoleCommand("skategm_fp_mode",tostring(nextMode))
		K.fpSmooth=nil
		K.fpYaw,K.fpPitch=0,0
		K.look=nil
		print("[Freeride] Camera: "..({"Third Person","First Person - Stabilized","First Person - Realistic"})[nextMode+1])
	end

	if edge(K.Key("respawn")) and S.phase=="on" then S.Respawn() end

	if edge(K.Key("freecam")) and S.phase=="on" then
		local enabling=not freecamConVar:GetBool()
		RunConsoleCommand("skategm_mouse_freecam",enabling and "1" or "0")
		K.look=nil
		print("[Freeride] Freecam "..(enabling and "ON" or "OFF"))
	end

	if S.phase~="on" then K.look=nil end
end

function K.Mouse(S,x,y)
	if K.Enabled() and S.phase=="on" and not K.Blocked(S) and flickHeld() then
		local scale=math.Clamp(mouseScale:GetFloat(),0.001,0.1)
		local nx=math.Clamp(mouseRX+x*scale,-1,1)
		local ny=math.Clamp(mouseRY-y*scale,-1,1)
		if mouseCircular:GetBool() then
			local length=math.sqrt(nx*nx+ny*ny)
			if length>1 then nx,ny=nx/length,ny/length end
		end
		mouseRX,mouseRY=nx,ny
		return
	end

	if K.Enabled() and S.phase=="on" and not K.Blocked(S) and not S.viewOverride and camMode:GetInt()>0 then
		if fpLook:GetBool() and not flickHeld() then
			local sensitivity=GetConVar("sensitivity")
			local sens=(sensitivity and sensitivity:GetFloat() or 1)*.022*fpSens:GetFloat()
			K.fpYaw=math.Clamp((K.fpYaw or 0)-x*sens,-fpHorizontal:GetFloat(),fpHorizontal:GetFloat())
			K.fpPitch=math.Clamp((K.fpPitch or 0)-y*sens,-fpVertical:GetFloat(),fpVertical:GetFloat())
		end
		return
	end

	if not K.Enabled() or S.phase~="on" or K.Blocked(S) or S.viewOverride or not freecamConVar:GetBool() then return end
	if x==0 and y==0 then return end
	if not K.look then K.cameraWarningUntil=RealTime()+5 end
	local a=K.look or (S.view and S.view.angles) or LocalPlayer():EyeAngles()
	local sensitivity=GetConVar("sensitivity")
	local sens=(sensitivity and sensitivity:GetFloat() or 1)*.022
	K.look=Angle(math.Clamp(a.p+y*sens,-55,70),math.NormalizeAngle(a.y-x*sens),0)
end

-- First-person camera uses SkateGM's interpolated skeleton, so it follows the
-- same pose that is actually being rendered and stays attached during bails.
function K.Camera(S,pos,ang)
	local mode=camMode:GetInt()
	local pose=S.renderP or S.P
	if mode>0 and S.phase=="on" and pose and pose.HEAD then
		local head=pose.HEAD
		local neck=pose.NECK1 or pose.NECK or pose.SPINE3 or pose.SPINE or pose.HIPS
		local up=neck and (head-neck) or Vector(0,0,1)
		if up:LengthSqr()<0.01 then up=Vector(0,0,1) end
		up:Normalize()

		local right=pose.RIGHTSHOULDER and pose.LEFTSHOULDER and (pose.RIGHTSHOULDER-pose.LEFTSHOULDER) or nil
		if right then right=right-up*right:Dot(up) end
		local forward
		if right and right:LengthSqr()>0.01 then
			right:Normalize()
			forward=up:Cross(right)
		end
		if not forward or forward:LengthSqr()<0.01 then
			forward=K.fpLastForward or ang:Forward()
			forward=forward-up*forward:Dot(up)
		end
		if forward:LengthSqr()<0.01 then
			forward=up:Cross(Vector(1,0,0))
			if forward:LengthSqr()<0.01 then forward=up:Cross(Vector(0,1,0)) end
		end
		forward:Normalize()
		K.fpLastForward=forward

		local targetPos=head+up*4+forward*7
		local base=forward:AngleEx(up)
		local targetAng
		if mode==2 then
			targetAng=Angle(base.p,base.y,base.r)
		else
			local intensity=math.Clamp(camMotion:GetFloat()/100,0,1)
			local horizontal=Vector(forward.x,forward.y,0)
			if horizontal:LengthSqr()<0.001 then
				local bf=base:Forward()
				horizontal=Vector(bf.x,bf.y,0)
			end
			local yaw=horizontal:LengthSqr()>0.001 and horizontal:Angle().y or base.y
			targetAng=Angle(math.Clamp(base.p*intensity*0.30,-65,65),yaw,math.Clamp(base.r*intensity*0.25,-55,55))
		end

		if fpCenter:GetBool() and not flickHeld() then
			local factor=math.exp(-math.Clamp(FrameTime(),0,0.1)*fpCenterSpeed:GetFloat())
			K.fpYaw=(K.fpYaw or 0)*factor
			K.fpPitch=(K.fpPitch or 0)*factor
		end
		targetAng:RotateAroundAxis(targetAng:Up(),K.fpYaw or 0)
		targetAng:RotateAroundAxis(targetAng:Right(),K.fpPitch or 0)

		if mode==1 then
			local rate=1-math.exp(-math.Clamp(FrameTime(),0,0.1)*16)
			if not K.fpSmooth or K.fpSmooth.mode~=mode then
				K.fpSmooth={ang=targetAng,mode=mode}
			else
				K.fpSmooth.ang=LerpAngle(rate,K.fpSmooth.ang,targetAng)
			end
			targetAng=K.fpSmooth.ang
		else
			K.fpSmooth=nil
		end
		return targetPos,targetAng
	end

	K.fpSmooth=nil
	K.fpLastForward=nil
	if not K.look or not S.renderP or not S.renderP.HIPS then return pos,ang end
	local target=S.renderP.HIPS+Vector(0,0,18)
	local distance=math.Clamp((pos-target):Length(),60,250)
	local desired=target-K.look:Forward()*distance
	local tr=util.TraceHull({start=target,endpos=desired,mins=Vector(-5,-5,-5),maxs=Vector(5,5,5),filter={LocalPlayer(),S.skater},mask=MASK_SOLID})
	return tr.Hit and (tr.HitPos+tr.HitNormal*2) or desired,K.look
end

function K.VirtualPad(S)
	if not K.Enabled() then return end
	if K.hardware and K.owner~="keyboard" then return end
	if not virtualPad:GetBool() and K.owner~="keyboard" then return end
	local blocked=gui.IsGameUIVisible() or (system.HasFocus and not system.HasFocus())
	local v,active=K.Read(S.pose and S.pose.state,blocked,K.Menu())
	if active then K.owner="keyboard" end
	return {buttons=v[1],lt=v[2],rt=v[3],lx=v[4],ly=v[5],rx=v[6],ry=v[7]}
end

function K.Decorate(S,p)
	if type(p)~="table" then return p end
	K.hardware=p.pad==true
	if K.hardware and ((p.padButtons or 0)~=0 or math.abs(p.padLX or 0)>.2 or math.abs(p.padLY or 0)>.2 or math.abs(p.padRX or 0)>.2 or math.abs(p.padRY or 0)>.2 or (p.padLT or 0)>.2 or (p.padRT or 0)>.2) then
		K.owner="hardware"
		K.look=nil
	end
	if K.hardware or not virtualPad:GetBool() then return p end
	local v=K.Read(p.state,K.Blocked(S))
	p.pad=true
	p.padButtons,p.padLT,p.padRT,p.padLX,p.padLY,p.padRX,p.padRY=unpack(v)
	return p
end

function K.IsKeyboard()
	return K.owner=="keyboard" or (K.owner~="hardware" and not K.hardware)
end

surface.CreateFont("skategm_camera_warning_title",{font="Bahnschrift",size=22,weight=600,extended=true})
surface.CreateFont("skategm_camera_warning_hint",{font="Bahnschrift",size=18,weight=400,extended=true})
hook.Add("HUDPaint","skategm_mouse_camera_warning",function()
	local S=SkateGM
	if not S or S.phase~="on" or not K.look or not S.renderP or not S.renderP.HIPS then return end
	local remaining=(K.cameraWarningUntil or 0)-RealTime()
	if remaining<=0 then return end
	local fade=math.Clamp(remaining,0,1)
	local alpha=math.floor(255*fade*fade*(3-2*fade))
	if S.viewOverride or K.Blocked(S) or (SKATEGM_UI and SKATEGM_UI.Busy()) then return end
	if S.replay and (S.replay.on or S.replay.hudHidden) then return end
	local hud=GetConVar("cl_drawhud")
	if hud and not hud:GetBool() then return end
	local title="Free mouse camera enabled"
	local hint="Press your Freecam key to disable"
	local x,y=20,20
	draw.SimpleText(title,"skategm_camera_warning_title",x,y,Color(255,205,100,alpha))
	draw.SimpleText(hint,"skategm_camera_warning_hint",x,y+26,Color(235,235,235,alpha))
end)

return K
