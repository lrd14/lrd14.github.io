-- Universal gameplay tools and per-game tools in one Severe UI window.
-- Offset dump scripts are not included. Every toggle starts off.

local severe_src = game:HttpGet("https://raw.githubusercontent.com/okdude42/ui-lib/refs/heads/main/SevereLib.lua")
severe_src = string.gsub(severe_src, "\r\n", "\n")
local severe_hook_at = [[    function windowObj:setvalue(name, value)
        State[name] = value
        State["Target_"..name] = value
    end]]
local severe_hook_i, severe_hook_j = string.find(severe_src, severe_hook_at, 1, true)
if severe_hook_i then
	severe_src = string.sub(severe_src, 1, severe_hook_j) .. [[

    function windowObj:gettext(name)
        return InputBuffers[name] or ""
    end
    function windowObj:settext(name, value)
        InputBuffers[name] = tostring(value or "")
    end]] .. string.sub(severe_src, severe_hook_j + 1)
else
	gurp.log("hub: name box hook missing")
end
local severeui = loadstring(severe_src)()

local sdk
repeat
	sdk = gurp.sdk
	if not sdk then
		gurp.wait(0.1)
	end
until sdk

local mem = gurp.memory
local ZERO = { x = 0, y = 0, z = 0 }

local OFF_PARENT = gurp.get_offset("Instance", "Parent")
local OFF_SEAT = gurp.get_offset("Humanoid", "SeatPart")
local OFF_HEALTH = gurp.get_offset("Humanoid", "Health")
local OFF_POS = gurp.get_offset("Primitive", "Position")
local OFF_LIN = gurp.get_offset("Primitive", "AssemblyLinearVelocity")
local OFF_ANG = gurp.get_offset("Primitive", "AssemblyAngularVelocity")
local OFF_FLAGS = gurp.get_offset("Primitive", "Flags")
local OFF_SIZE = gurp.get_offset("Primitive", "Size")
local COLLIDE_BIT = gurp.get_offset("PrimitiveFlags", "CanCollide") or 8
local TOUCH_BIT = gurp.get_offset("PrimitiveFlags", "CanTouch") or 16

local window = severeui:createwindow({
	Title = "gurp",
	Version = "hub",
	Keybind = "RightShift",
	ConfigFolder = "gurp-hub",
	CustomResolution = Vector2.new(640, 460),
	DPIScale = 1.0,
	CompactSettings = false,
	DefaultTab = "Universal",
	TabAlignment = "Center",
	DefaultColor = Color3.fromRGB(28, 27, 31),
	DefaultAccent = Color3.fromRGB(85, 135, 62),
	DefaultUITransparency = 0.75,
	DefaultSnowfall = false,
	DefaultScale = 1.0,
	DefaultFont = 5,
})

window:setvalue("Transparent", true)
window:setvalue("UITrans", 0.75)

local tab_universal = window:createtab("Universal")
local tab_prison = window:createtab("Prison Life")
local tab_mm2 = window:createtab("MM2")
local tab_kat = window:createtab("Kat")
local tab_diffuse = window:createtab("Diffuse")

local function set_text(el, text)
	if el and el.Txt then
		el.Txt.Text = text
	end
end

local function valid(obj)
	return obj ~= nil and obj ~= 0
end

local function write_vec3(addr, v)
	if not valid(addr) or not v then
		return false
	end
	local a = mem.write_f32(addr + 0, v.x or 0)
	local b = mem.write_f32(addr + 4, v.y or 0)
	local c = mem.write_f32(addr + 8, v.z or 0)
	return a and b and c
end

local function primitive_of(part)
	if not valid(part) then
		return nil
	end
	local prim = sdk.primitive(part)
	if not valid(prim) then
		return nil
	end
	return prim
end

local function players_list()
	local out = {}
	local players_service = sdk.players_service()
	if not valid(players_service) then
		return out
	end
	local local_player = gurp.get_localplayer()
	local local_name = valid(local_player) and (sdk.name(local_player) or "") or ""
	local children = sdk.children(players_service)
	if type(children) ~= "table" then
		return out
	end
	for i = 1, #children do
		local p = children[i]
		if valid(p) and p ~= local_player and sdk.class_name(p) == "Player" then
			local name = sdk.name(p) or ""
			if local_name == "" or name ~= local_name then
				out[#out + 1] = p
			end
		end
	end
	return out
end

local function norm(s)
	s = string.lower(tostring(s or ""))
	return string.gsub(s, "_", "")
end

local function find_player_named(name)
	if not name or name == "" or name == "None" then
		return nil
	end
	local list = players_list()
	for i = 1, #list do
		if tostring(sdk.name(list[i]) or "") == name then
			return list[i]
		end
	end
	local q = norm(name)
	for i = 1, #list do
		local p = list[i]
		local nm = tostring(sdk.name(p) or "")
		local dn = sdk.display_name and tostring(sdk.display_name(p) or "") or ""
		if string.find(norm(nm), q, 1, true) or (dn ~= "" and string.find(norm(dn), q, 1, true)) then
			return p
		end
	end
	return nil
end

local function character_of(player)
	local ch = sdk.character(player)
	if valid(ch) then
		return ch
	end
	local workspace = gurp.get_workspace()
	local name = sdk.name(player)
	if valid(workspace) and name and name ~= "" then
		ch = sdk.find_child(workspace, name)
		if valid(ch) then
			return ch
		end
	end
	return nil
end

local function get_hrp(character)
	if not valid(character) then
		return nil
	end
	local hrp = sdk.find_child(character, "HumanoidRootPart")
	if valid(hrp) then
		return hrp
	end
	return nil
end

local function local_character()
	local lp = gurp.get_localplayer()
	if not valid(lp) then
		return nil
	end
	local ch = sdk.character(lp)
	if valid(ch) then
		return ch
	end
	return nil
end

local function local_hrp()
	return get_hrp(local_character())
end

-- Universal: noclip others
local BODY_PARTS = {
	"Head", "HumanoidRootPart", "RootPart", "Torso",
	"UpperTorso", "LowerTorso",
	"Left Arm", "Right Arm", "Left Leg", "Right Leg",
	"LeftArm", "RightArm", "LeftLeg", "RightLeg",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
	"Handle",
}

local function disable_part(part)
	if not valid(part) or not OFF_FLAGS then
		return false
	end
	local prim = primitive_of(part)
	if not prim then
		return false
	end
	local current = mem.read_u32(prim + OFF_FLAGS)
	if not current then
		return false
	end
	local next_flags = current & ~COLLIDE_BIT
	if next_flags == current then
		return true
	end
	return mem.write_u32(prim + OFF_FLAGS, next_flags) == true
end

local function strip_character(character)
	if not valid(character) then
		return
	end
	for i = 1, #BODY_PARTS do
		disable_part(sdk.find_child(character, BODY_PARTS[i]))
	end
	local kids = sdk.children(character)
	if not kids then
		return
	end
	for i = 1, #kids do
		local child = kids[i]
		if valid(child) then
			disable_part(child)
			disable_part(sdk.find_child(child, "Handle"))
		end
	end
end

local function tick_noclip()
	local list = players_list()
	for i = 1, #list do
		strip_character(character_of(list[i]))
	end
end

-- Universal: hitbox
local function tick_hitbox(size)
	if not OFF_SIZE then
		return
	end
	size = tonumber(size) or 10
	local list = players_list()
	for i = 1, #list do
		local character = character_of(list[i])
		local head = valid(character) and sdk.find_child(character, "Head") or nil
		local prim = primitive_of(head)
		if prim then
			local addr = prim + OFF_SIZE
			mem.write_f32(addr + 0, size)
			mem.write_f32(addr + 4, size)
			mem.write_f32(addr + 8, size)
		end
	end
end

-- Universal: anti-fling
local AF_LINEAR = 200
local AF_ANGULAR = 5000
local af = {
	latched = false,
	armed = false,
	last_save = 0,
	saved_pos = nil,
	reason = "",
	release = false,
	was_on = false,
}

local function af_read_vec3(part, off)
	local prim = primitive_of(part)
	if not prim or not off then
		return nil
	end
	local x = mem.read_f32(prim + off)
	local y = mem.read_f32(prim + off + 4)
	local z = mem.read_f32(prim + off + 8)
	if x == nil or y == nil or z == nil then
		return nil
	end
	return { x = x, y = y, z = z }
end

local function af_mag(v)
	if not v then
		return 0
	end
	return math.sqrt((v.x or 0) ^ 2 + (v.y or 0) ^ 2 + (v.z or 0) ^ 2)
end

local function af_save()
	local hrp = local_hrp()
	local p = valid(hrp) and sdk.position(hrp) or nil
	if not p then
		return false
	end
	af.saved_pos = { x = p.x or 0, y = p.y or 0, z = p.z or 0 }
	return true
end

local function af_zero(hrp, repeats)
	for _ = 1, repeats do
		local prim = primitive_of(hrp)
		if prim and OFF_LIN then
			write_vec3(prim + OFF_LIN, ZERO)
		end
		if prim and OFF_ANG then
			write_vec3(prim + OFF_ANG, ZERO)
		end
	end
end

local function af_burst_pos(hrp, pos, repeats)
	local prim = primitive_of(hrp)
	if not prim or not OFF_POS or not pos then
		return
	end
	for _ = 1, repeats do
		write_vec3(prim + OFF_POS, pos)
	end
end

local function af_freeze()
	local hrp = local_hrp()
	if not valid(hrp) then
		return
	end
	if af.saved_pos then
		af_burst_pos(hrp, af.saved_pos, 100)
	end
	af_zero(hrp, 100)
	if af.saved_pos then
		af_burst_pos(hrp, af.saved_pos, 100)
	end
	af_zero(hrp, 100)
end

local function af_restore()
	local hrp = local_hrp()
	if not valid(hrp) then
		return
	end
	af_zero(hrp, 150)
	if af.saved_pos then
		af_burst_pos(hrp, af.saved_pos, 300)
	end
	af_zero(hrp, 150)
end

local function af_status()
	if af.latched then
		return "Latched (" .. af.reason .. ")"
	end
	if af.armed then
		return "Armed"
	end
	return "Off"
end

local function tick_antifling(enabled)
	if af.release or (not enabled and af.was_on) then
		if af.latched then
			af_restore()
		end
		af.latched = false
		af.armed = false
		af.release = false
	end
	af.was_on = enabled
	if not enabled then
		return
	end
	af.armed = true
	if af.latched then
		af_freeze()
		return
	end
	local now = gurp.time_ms() or 0
	if now - af.last_save >= 50 then
		af_save()
		af.last_save = now
	end
	local hrp = local_hrp()
	if not valid(hrp) then
		return
	end
	local lin = af_read_vec3(hrp, OFF_LIN)
	local ang = af_read_vec3(hrp, OFF_ANG)
	local reason = nil
	if lin and af_mag(lin) >= AF_LINEAR then
		reason = "linear"
	elseif ang and af_mag(ang) >= AF_ANGULAR then
		reason = "angular"
	end
	if reason then
		if not af.saved_pos then
			af_save()
		end
		af.latched = true
		af.reason = reason
		gurp.log("Anti-fling latched (" .. reason .. ")")
		af_freeze()
	end
end

-- Universal: fling chase
local fling = {
	chasing = false,
	name = "None",
	player = nil,
	origin = nil,
	stop = false,
	start = false,
}

local function fling_clear(hrp, repeats)
	local prim = primitive_of(hrp)
	if not prim then
		return
	end
	for _ = 1, repeats do
		if OFF_LIN then
			write_vec3(prim + OFF_LIN, ZERO)
		end
		if OFF_ANG then
			write_vec3(prim + OFF_ANG, ZERO)
		end
	end
end

local function pause(seconds)
	seconds = tonumber(seconds) or 0
	if coroutine.isyieldable() then
		coroutine.yield(seconds)
	else
		gurp.wait(seconds)
	end
end

local function fling_restore()
	if not fling.origin then
		return
	end
	fling.restoring = true
	local restore_pos = { x = fling.origin.x, y = fling.origin.y, z = fling.origin.z }
	for _ = 1, 40 do
		local hrp = local_hrp()
		if valid(hrp) then
			fling_clear(hrp, 20)
			local prim = primitive_of(hrp)
			if prim and OFF_POS then
				write_vec3(prim + OFF_POS, restore_pos)
			end
			fling_clear(hrp, 20)
		end
		pause(0.025)
	end
	fling.origin = nil
	fling.restoring = false
end

local request_stop_car = false

local function stop_fling(reason)
	if fling.chasing or fling.origin then
		fling.chasing = false
		fling_restore()
		gurp.log("Fling stopped" .. (reason and (": " .. reason) or ""))
	end
	fling.chasing = false
end

local function start_fling()
	local player = fling.pick
	if not valid(player) then
		if (fling.match_count or 0) > 1 then
			fling.name = "More than one match"
		else
			fling.name = "No match"
		end
		return
	end
	local hrp = local_hrp()
	local pos = valid(hrp) and sdk.position(hrp) or nil
	if not pos then
		fling.name = "No local root"
		return
	end
	if car_hunting() then
		request_stop_car = true
	end
	af.release = true
	window:setvalue("AntiFling", false)
	fling.origin = { x = pos.x or 0, y = pos.y or 0, z = pos.z or 0 }
	fling.player = player
	fling.name = tostring(sdk.name(player) or fling.query or "")
	fling.chasing = true
	gurp.log("Fling chasing " .. fling.name)
end

local function tick_fling()
	if not fling.chasing then
		return
	end
	if not valid(fling.player) then
		fling.player = find_player_named(fling.name)
	end
	local target_hrp = get_hrp(character_of(fling.player))
	local hrp = local_hrp()
	if not valid(target_hrp) or not valid(hrp) then
		stop_fling("lost target")
		return
	end
	local tpos = sdk.position(target_hrp)
	if not tpos then
		return
	end
	local prim = primitive_of(hrp)
	if prim and OFF_POS then
		local goal = { x = tpos.x or 0, y = tpos.y or 0, z = tpos.z or 0 }
		for _ = 1, 500 do
			write_vec3(prim + OFF_POS, goal)
		end
	end
	if prim and OFF_ANG then
		write_vec3(prim + OFF_ANG, {
			x = math.random(-180000, 180000),
			y = math.random(-180000, 180000),
			z = math.random(-180000, 180000),
		})
	end
end

-- Car kick. Same writes as carkick.lua. Needs Workspace.CarContainer.
local PREDICTION = 0.22
local PRED_SPEED_CAP = 250
local FLING_SPEED = 150000
local TRACK_ANG = 8000
local HIT_RANGE = 30
local POS_STICK = 2

local car = {
	hunting = false,
	captured = nil,
	status = "Type a target, sit in the car, then hunt.",
	start = false,
	stop = false,
	panic = false,
}

function car_hunting()
	return car.hunting
end

local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function sane_pos(x, y, z)
	if not finite(x) or not finite(y) or not finite(z) then
		return false
	end
	return math.abs(x) < 100000 and math.abs(y) < 100000 and math.abs(z) < 100000
end

local function parent_of(inst)
	if not valid(inst) or not OFF_PARENT then
		return nil
	end
	local p = mem.read_u64(inst + OFF_PARENT)
	if not valid(p) then
		return nil
	end
	return p
end

local function health_of(humanoid)
	if not valid(humanoid) or not OFF_HEALTH then
		return 100
	end
	local h = mem.read_f32(humanoid + OFF_HEALTH)
	if not h or h ~= h then
		return 100
	end
	return h
end

local function clear_touch(part)
	if not valid(part) or not OFF_FLAGS then
		return
	end
	local prim = primitive_of(part)
	if not prim then
		return
	end
	local current = mem.read_u32(prim + OFF_FLAGS)
	if not current then
		return
	end
	if current % (TOUCH_BIT * 2) >= TOUCH_BIT then
		mem.write_u32(prim + OFF_FLAGS, current - TOUCH_BIT)
	end
end

local function disable_collide(part)
	if not valid(part) then
		return
	end
	local prim = primitive_of(part)
	if not prim or not OFF_FLAGS then
		return
	end
	local current = mem.read_u32(prim + OFF_FLAGS)
	if not current then
		return
	end
	if current % (COLLIDE_BIT * 2) >= COLLIDE_BIT then
		mem.write_u32(prim + OFF_FLAGS, current - COLLIDE_BIT)
	end
end

local BASEPART = {
	Part = true, MeshPart = true, WedgePart = true, CornerWedgePart = true,
	TrussPart = true, Seat = true, VehicleSeat = true, SpawnLocation = true,
	UnionOperation = true, NegateOperation = true, PartOperation = true,
}

local function is_basepart(inst)
	local cn = sdk.class_name(inst)
	if not cn then
		return false
	end
	if BASEPART[cn] then
		return true
	end
	return string.sub(cn, -4) == "Part"
end

local function collect_parts(root, out, seen)
	if not valid(root) then
		return
	end
	local stack = { root }
	local n = 0
	while #stack > 0 and #out < 180 and n < 400 do
		local inst = table.remove(stack)
		if valid(inst) and not seen[inst] then
			seen[inst] = true
			n = n + 1
			if is_basepart(inst) then
				local prim = primitive_of(inst)
				if prim and not seen[prim] then
					seen[prim] = true
					out[#out + 1] = prim
				end
			end
			local kids = sdk.children(inst)
			if kids then
				for i = 1, #kids do
					local child = kids[i]
					if valid(child) and not seen[child] then
						stack[#stack + 1] = child
					end
				end
			end
		end
	end
end

local function read_prim_pos(prim)
	if not valid(prim) or not OFF_POS then
		return nil
	end
	local addr = prim + OFF_POS
	local x = mem.read_f32(addr)
	local y = mem.read_f32(addr + 4)
	local z = mem.read_f32(addr + 8)
	if not sane_pos(x, y, z) then
		return nil
	end
	return x, y, z
end

local function zero_linear(prim)
	if not OFF_LIN or not valid(prim) then
		return
	end
	local lin = prim + OFF_LIN
	mem.write_f32(lin, 0)
	mem.write_f32(lin + 4, 0)
	mem.write_f32(lin + 8, 0)
end

local function noclip_local(character)
	if not valid(character) then
		return
	end
	local stack = { character }
	local seen = {}
	local n = 0
	while #stack > 0 and n < 160 do
		local inst = table.remove(stack)
		if valid(inst) and not seen[inst] then
			seen[inst] = true
			n = n + 1
			if primitive_of(inst) then
				disable_collide(inst)
			end
			local kids = sdk.children(inst)
			if kids then
				for i = 1, #kids do
					local child = kids[i]
					if valid(child) and not seen[child] then
						stack[#stack + 1] = child
					end
				end
			end
		end
	end
end

local function car_from_seat(seat)
	local workspace = gurp.get_workspace()
	if not valid(workspace) or not valid(seat) then
		return nil
	end
	local container = sdk.find_child(workspace, "CarContainer")
	if not valid(container) then
		return nil
	end
	local obj = seat
	for _ = 1, 16 do
		local par = parent_of(obj)
		if par == container then
			return obj
		end
		if not valid(par) or par == workspace then
			return nil
		end
		obj = par
	end
	return nil
end

local function stop_car(reason)
	car.hunting = false
	car.captured = nil
	if reason and reason ~= "" then
		car.status = reason
	end
end

local function begin_car()
	if fling.chasing or fling.origin then
		stop_fling("car kick")
	end
	af.release = true
	window:setvalue("AntiFling", false)
	local selected = car.pick
	local local_char = local_character()
	local local_humanoid = valid(local_char) and sdk.find_child_of_class(local_char, "Humanoid") or nil
	local local_root = get_hrp(local_char)
	if not valid(local_humanoid) or not OFF_SEAT then
		car.status = "Sit in a car first."
		return
	end
	local seat = mem.read_u64(local_humanoid + OFF_SEAT)
	if not valid(seat) then
		car.status = "Sit in a car first."
		return
	end
	local vehicle = car_from_seat(seat)
	if not valid(vehicle) then
		car.status = "Car layer detect failed."
		return
	end
	local wheels = sdk.find_child(vehicle, "Wheels")
	local wheel_kids = valid(wheels) and sdk.children(wheels) or nil
	local wheel = wheel_kids and wheel_kids[4] or nil
	if not valid(selected) then
		if (car.match_count or 0) > 1 then
			car.status = "More than one match."
		else
			car.status = "No match."
		end
		return
	end
	local target_char = character_of(selected)
	local target_root = get_hrp(target_char)
	local target_humanoid = valid(target_char) and sdk.find_child_of_class(target_char, "Humanoid") or nil
	if not valid(target_char) or not valid(target_root) or not valid(wheel) or not valid(local_root) then
		car.status = "Target not found."
		return
	end
	local parts = {}
	local seen = {}
	collect_parts(vehicle, parts, seen)
	collect_parts(local_char, parts, seen)
	local seat_prim = primitive_of(seat)
	local ax, ay, az = read_prim_pos(seat_prim)
	if not ax then
		car.status = "Could not read the seat."
		return
	end
	local shaped = {}
	for i = 1, #parts do
		local prim = parts[i]
		local x, y, z = read_prim_pos(prim)
		if x then
			shaped[#shaped + 1] = { prim, x - ax, y - ay, z - az }
		end
	end
	local wx, wy, wz = read_prim_pos(primitive_of(wheel))
	if not wx then
		car.status = "Could not read the wheel."
		return
	end
	local seats = {}
	local seat_seen = {}
	local stack = { vehicle }
	local n = 0
	while #stack > 0 and n < 400 do
		local inst = table.remove(stack)
		if valid(inst) and not seat_seen[inst] then
			seat_seen[inst] = true
			n = n + 1
			local cn = sdk.class_name(inst)
			if cn == "Seat" or cn == "VehicleSeat" then
				seats[#seats + 1] = inst
			end
			local kids = sdk.children(inst)
			if kids then
				for i = 1, #kids do
					local child = kids[i]
					if valid(child) and not seat_seen[child] then
						stack[#stack + 1] = child
					end
				end
			end
		end
	end
	car.captured = {
		local_char = local_char,
		local_humanoid = local_humanoid,
		local_root = local_root,
		target_char = target_char,
		target_root = target_root,
		target_humanoid = target_humanoid,
		wheel = wheel,
		car = vehicle,
		seat = seat,
		shaped = shaped,
		seats = seats,
		wheel_ox = wx - ax,
		wheel_oy = wy - ay,
		wheel_oz = wz - az,
		name = tostring(sdk.name(selected) or car.query or ""),
	}
	car.hunting = true
	car.status = "Hunting " .. car.captured.name
	gurp.log("carkick hunting " .. car.captured.name)
end

local function tick_car()
	local c = car.captured
	if not c then
		stop_car("Hunt stopped.")
		return
	end
	if not valid(c.target_char) or not valid(c.target_root) or not valid(c.wheel) or not valid(c.car)
		or not valid(c.local_char) or not valid(c.local_root) then
		stop_car("Target lost.")
		return
	end
	if valid(c.target_humanoid) and health_of(c.target_humanoid) <= 0 then
		stop_car("Target died.")
		return
	end
	if valid(c.local_humanoid) and health_of(c.local_humanoid) <= 0 then
		stop_car("You died.")
		return
	end
	noclip_local(c.local_char)
	local pos = sdk.position(c.target_root)
	local vel = sdk.velocity(c.target_root)
	local wheel_pos = sdk.position(c.wheel)
	local wheel_prim = primitive_of(c.wheel)
	if not pos or not wheel_pos or not valid(wheel_prim) or not OFF_POS then
		return
	end
	vel = vel or ZERO
	local vx = vel.x or 0
	local vy = vel.y or 0
	local vz = vel.z or 0
	if not finite(vx) or math.abs(vx) > PRED_SPEED_CAP then
		vx = math.max(-PRED_SPEED_CAP, math.min(PRED_SPEED_CAP, finite(vx) and vx or 0))
	end
	if not finite(vy) or math.abs(vy) > PRED_SPEED_CAP then
		vy = math.max(-PRED_SPEED_CAP, math.min(PRED_SPEED_CAP, finite(vy) and vy or 0))
	end
	if not finite(vz) or math.abs(vz) > PRED_SPEED_CAP then
		vz = math.max(-PRED_SPEED_CAP, math.min(PRED_SPEED_CAP, finite(vz) and vz or 0))
	end
	local pred_x = (pos.x or 0) + vx * PREDICTION
	local pred_y = (pos.y or 0) + vy * PREDICTION
	local pred_z = (pos.z or 0) + vz * PREDICTION
	if not sane_pos(pred_x, pred_y, pred_z) or not sane_pos(wheel_pos.x, wheel_pos.y, wheel_pos.z) then
		return
	end
	if c.wheel_ox == nil then
		return
	end
	local nx = pred_x - c.wheel_ox
	local ny = pred_y - c.wheel_oy
	local nz = pred_z - c.wheel_oz
	if not sane_pos(nx, ny, nz) then
		return
	end
	local shaped = c.shaped
	local wheel_hit = primitive_of(c.wheel)
	if shaped then
		for _ = 1, POS_STICK do
			for i = 1, #shaped do
				local s = shaped[i]
				local prim = s[1]
				if valid(prim) then
					local addr = prim + OFF_POS
					mem.write_f32(addr, nx + s[2])
					mem.write_f32(addr + 4, ny + s[3])
					mem.write_f32(addr + 8, nz + s[4])
				end
			end
		end
		for i = 1, #shaped do
			local prim = shaped[i][1]
			if prim ~= wheel_hit then
				zero_linear(prim)
			end
		end
	end
	if c.seats then
		for i = 1, #c.seats do
			clear_touch(c.seats[i])
		end
	end
	if valid(c.target_humanoid) and OFF_SEAT then
		mem.write_u64(c.target_humanoid + OFF_SEAT, 0)
	end
	local pdx = pred_x - (pos.x or 0)
	local pdy = pred_y - (pos.y or 0)
	local pdz = pred_z - (pos.z or 0)
	local touching = pdx * pdx + pdy * pdy + pdz * pdz <= HIT_RANGE * HIT_RANGE
	if valid(wheel_hit) and OFF_LIN and OFF_ANG then
		local lin = wheel_hit + OFF_LIN
		local ang = wheel_hit + OFF_ANG
		local lv = touching and FLING_SPEED or 0
		local av = touching and FLING_SPEED or TRACK_ANG
		for _ = 1, 12 do
			mem.write_f32(lin, lv)
			mem.write_f32(lin + 4, lv)
			mem.write_f32(lin + 8, lv)
			mem.write_f32(ang, av)
			mem.write_f32(ang + 4, av)
			mem.write_f32(ang + 8, av)
		end
	end
end

-- Prison Life backpack gun mods
local GUN_KEYS = { "SpreadRadius", "FireRate", "ReloadTime", "AutoFire", "AccurateRange", "StoredAmmo" }
local gun_seen = {}
local gun_backpack = 0

local function gun_find(inst, key)
	if not valid(inst) or not sdk.attribute_find then
		return nil
	end
	return sdk.attribute_find(inst, key, false, 1024)
end

local function gun_targets(inst)
	local targets = {}
	local any = false
	for i = 1, #GUN_KEYS do
		local key = GUN_KEYS[i]
		local has = gun_find(inst, key) and true or false
		targets[key] = has
		any = any or has
	end
	return any, targets
end

local function gun_apply(inst, targets)
	if targets.SpreadRadius then
		sdk.attribute_set_f32(inst, "SpreadRadius", 0.0, false, 128)
	end
	if targets.FireRate then
		sdk.attribute_set_f32(inst, "FireRate", 0.065, false, 128)
	end
	if targets.StoredAmmo then
		sdk.attribute_set_f32(inst, "StoredAmmo", 100, false, 128)
	end
	if targets.AutoFire then
		sdk.attribute_set_bool(inst, "AutoFire", true, false, 128)
	end
	if targets.AccurateRange then
		sdk.attribute_set_f32(inst, "AccurateRange", 1000.0, false, 128)
		sdk.attribute_set_u32(inst, "AccurateRange", 1000, false, 128)
	end
end

local gun_status = "Off"

local function tick_guns()
	local lp = gurp.get_localplayer()
	local backpack = valid(lp) and sdk.find_child(lp, "Backpack") or 0
	if not valid(backpack) then
		gun_status = "No backpack"
		gun_seen = {}
		gun_backpack = 0
		return
	end
	if backpack ~= gun_backpack then
		gun_seen = {}
		gun_backpack = backpack
	end
	local kids = sdk.children(backpack) or {}
	local present = {}
	local tuned = 0
	for i = 1, #kids do
		local child = kids[i]
		if valid(child) then
			present[child] = true
			local has, targets = gun_targets(child)
			if has then
				if not gun_seen[child] then
					for _ = 1, 30 do
						gun_apply(child, targets)
					end
					gun_seen[child] = true
					gurp.log("prison gun: " .. tostring(sdk.name(child)))
				else
					gun_apply(child, targets)
				end
				tuned = tuned + 1
			end
		end
	end
	for addr, _ in pairs(gun_seen) do
		if not present[addr] then
			gun_seen[addr] = nil
		end
	end
	gun_status = "Tuning " .. tostring(tuned) .. " items"
end

-- MM2 role and forcefield marks
local function mm2_exists(parent, name)
	if not valid(parent) then
		return false
	end
	local obj = sdk.find_child(parent, name)
	return valid(obj)
end

local function mm2_role(player)
	local backpack = sdk.find_child(player, "Backpack")
	local character = character_of(player)
	local function has_knife(root)
		return mm2_exists(root, "Knife") or mm2_exists(root, "knife") or mm2_exists(root, "MM2Knife")
	end
	local function has_gun(root)
		return mm2_exists(root, "Sheriff's Gun") or mm2_exists(root, "ClassicSheriffRevolver") or mm2_exists(root, "Gun")
	end
	if has_knife(backpack) or has_knife(character) then
		return "Murderer"
	end
	if has_gun(backpack) or has_gun(character) then
		return "Sheriff"
	end
	return nil
end

-- Kat crates
local kat = {
	status = "Off",
}

local function kat_is_part(inst)
	if not valid(inst) then
		return false
	end
	local cn = sdk.class_name(inst)
	if not cn then
		return false
	end
	if cn == "Part" or cn == "MeshPart" or cn == "UnionOperation"
		or cn == "WedgePart" or cn == "CornerWedgePart" or cn == "TrussPart" then
		return true
	end
	return string.sub(cn, -4) == "Part"
end

local function kat_anchor(model)
	if kat_is_part(model) then
		return model
	end
	local kids = sdk.children(model)
	if not kids then
		return nil
	end
	for i = 1, #kids do
		if kat_is_part(kids[i]) then
			return kids[i]
		end
	end
	for i = 1, #kids do
		local child = kids[i]
		if valid(child) then
			local grand = sdk.children(child)
			if grand then
				for j = 1, #grand do
					if kat_is_part(grand[j]) then
						return grand[j]
					end
				end
			end
		end
	end
	return nil
end

local function kat_pickups()
	local workspace = gurp.get_workspace()
	if not valid(workspace) then
		return nil
	end
	local world_ignore = sdk.find_child(workspace, "WorldIgnore")
	if not valid(world_ignore) then
		return nil
	end
	local pickups = sdk.find_child(world_ignore, "Pickups")
	if not valid(pickups) then
		return nil
	end
	return pickups
end

local function kat_leg()
	local char = local_character()
	if not valid(char) then
		return nil
	end
	local names = { "Left Leg", "LeftLowerLeg", "LeftUpperLeg", "LeftFoot" }
	for i = 1, #names do
		local part = sdk.find_child(char, names[i])
		if valid(part) then
			return part
		end
	end
	return nil
end

local function kat_write(part, x, y, z)
	local prim = primitive_of(part)
	if not prim or not OFF_POS then
		return
	end
	local addr = prim + OFF_POS
	for _ = 1, 6 do
		mem.write_f32(addr, x)
		mem.write_f32(addr + 4, y)
		mem.write_f32(addr + 8, z)
	end
	if OFF_LIN then
		local lin = prim + OFF_LIN
		mem.write_f32(lin, 0)
		mem.write_f32(lin + 4, 0)
		mem.write_f32(lin + 8, 0)
	end
end

local function kat_points(pickups)
	local out = {}
	local children = sdk.children(pickups) or {}
	for i = 1, #children do
		local model = children[i]
		if valid(model) and sdk.class_name(model) == "Model" then
			local part = kat_anchor(model)
			local pos = part and sdk.position(part) or nil
			if pos then
				out[#out + 1] = { model = model, x = pos.x, y = pos.y, z = pos.z }
			end
		end
	end
	return out
end

local function kat_nearest(points, from)
	local best = nil
	local best_d = nil
	for i = 1, #points do
		local p = points[i]
		local dx = (p.x or 0) - (from.x or 0)
		local dy = (p.y or 0) - (from.y or 0)
		local dz = (p.z or 0) - (from.z or 0)
		local d = dx * dx + dy * dy + dz * dz
		if not best_d or d < best_d then
			best = p
			best_d = d
		end
	end
	return best
end

local function set_desync(on)
	if gurp.set_desync then
		gurp.set_desync(on == true)
	end
end

local function kat_character_parts(character)
	local parts = {}
	local seen = {}
	local function add(part)
		if valid(part) and not seen[part] and primitive_of(part) then
			seen[part] = true
			parts[#parts + 1] = part
		end
	end
	for i = 1, #BODY_PARTS do
		add(sdk.find_child(character, BODY_PARTS[i]))
	end
	local kids = sdk.children(character)
	if kids then
		for i = 1, #kids do
			if kat_is_part(kids[i]) then
				add(kids[i])
			end
		end
	end
	return parts
end

local function kat_snapshot(parts)
	local snap = {}
	for i = 1, #parts do
		local pos = sdk.position(parts[i])
		if pos then
			snap[#snap + 1] = { part = parts[i], x = pos.x, y = pos.y, z = pos.z }
		end
	end
	return snap
end

local function kat_shift(snap, dx, dy, dz)
	for i = 1, #snap do
		local s = snap[i]
		kat_write(s.part, s.x + (dx or 0), s.y + (dy or 0), s.z + (dz or 0))
	end
end

local function kat_still_collecting()
	return window:getvalue("CrateCollect") == true
end

local function kat_crate_alive(model, pickups)
	if not valid(model) or not valid(pickups) then
		return false
	end
	local children = sdk.children(pickups) or {}
	for i = 1, #children do
		if children[i] == model then
			local part = kat_anchor(model)
			return part ~= nil and sdk.position(part) ~= nil
		end
	end
	return false
end

local function kat_crate_pos(model)
	local part = kat_anchor(model)
	return part and sdk.position(part) or nil
end

local function kat_write_for(snap, dx, dy, dz, seconds)
	local until_t = os.clock() + seconds
	while os.clock() < until_t do
		kat_shift(snap, dx, dy, dz)
		pause(0.02)
	end
end

local function kat_collect_once()
	local character = local_character()
	local hrp = get_hrp(character)
	local pickups = kat_pickups()
	local points = pickups and kat_points(pickups) or {}
	local origin = valid(hrp) and sdk.position(hrp) or nil
	local target = origin and kat_nearest(points, origin) or nil
	if not target or not valid(target.model) then
		return false
	end
	set_desync(true)
	pause(0.1)
	if not kat_still_collecting() then
		set_desync(false)
		return false
	end
	character = local_character()
	hrp = get_hrp(character)
	origin = valid(hrp) and sdk.position(hrp) or nil
	pickups = kat_pickups()
	if not origin or not kat_crate_alive(target.model, pickups) then
		set_desync(false)
		return false
	end
	local snap = kat_snapshot(kat_character_parts(character))
	local give_up = os.clock() + 8
	while kat_still_collecting() and os.clock() < give_up and kat_crate_alive(target.model, pickups) do
		local pos = kat_crate_pos(target.model) or target
		kat_shift(snap, pos.x - origin.x, pos.y - origin.y, pos.z - origin.z)
		pause(0.02)
		pickups = kat_pickups()
	end
	kat_write_for(snap, 0, 0, 0, 1.0)
	pause(0.1)
	set_desync(false)
	return true
end

local function kat_stop()
	set_desync(false)
end

-- Diffuse Division wallbang
local diffuse_status = "Not applied"

local function diffuse_wallbang()
	local workspace = gurp.get_workspace()
	local map = valid(workspace) and sdk.find_child(workspace, "Map") or nil
	local ignore = valid(workspace) and sdk.find_child(workspace, "IgnoreParts") or nil
	if not valid(map) or not valid(ignore) or not OFF_PARENT then
		diffuse_status = "Map or IgnoreParts missing"
		return
	end
	mem.write_u64(map + OFF_PARENT, ignore)
	diffuse_status = "Map parent set to IgnoreParts"
	gurp.log(diffuse_status)
end

-- World marks stay in the Drawing list so the menu flush does not erase them.
local esp_pool = {}
local esp_used = 0

local function esp_reset()
	esp_used = 0
end

local function esp_finish()
	for i = esp_used + 1, #esp_pool do
		esp_pool[i].mark.Visible = false
		esp_pool[i].label.Visible = false
	end
end

local function esp_mark(x, y, z, text, r, g, b)
	local screen = gurp.draw.world_to_screen(x, y, z)
	if not screen then
		return
	end
	esp_used = esp_used + 1
	local slot = esp_pool[esp_used]
	if not slot then
		slot = {
			mark = Drawing.new("Circle"),
			label = Drawing.new("Text"),
		}
		slot.mark.Filled = true
		slot.mark.Radius = 4
		slot.mark.ZIndex = 1
		slot.label.Size = 13
		slot.label.Center = true
		slot.label.ZIndex = 2
		esp_pool[esp_used] = slot
	end
	slot.mark.Visible = true
	slot.mark.Position = Vector2.new(screen.x, screen.y)
	slot.mark.Color = Color3.new(r, g, b)
	slot.mark.Transparency = 1
	slot.label.Visible = true
	slot.label.Text = text
	slot.label.Position = Vector2.new(screen.x, screen.y - 16)
	slot.label.Color = Color3.new(r, g, b)
	slot.label.Transparency = 1
end

-- UI
window:createlabel(tab_universal, "ANY GAME", 1)
window:createtoggle(tab_universal, {
	Name = "Noclip others",
	StateKey = "NoclipOthers",
	Col = 1,
	Default = false,
})
window:createtoggle(tab_universal, {
	Name = "Head hitbox",
	StateKey = "Hitbox",
	Col = 1,
	Default = false,
})
window:createslider(tab_universal, {
	Name = "Head size",
	StateKey = "HeadSize",
	Col = 1,
	Min = 1,
	Max = 25,
	Default = 10,
	Step = 1,
})
window:createseparator(tab_universal, 1)
window:createlabel(tab_universal, "ANTI FLING", 1)
window:createtoggle(tab_universal, {
	Name = "Anti-fling",
	StateKey = "AntiFling",
	Col = 1,
	Default = false,
})
window:createbutton(tab_universal, {
	Name = "Release anti-fling",
	Col = 1,
	Callback = function()
		af.release = true
		window:setvalue("AntiFling", false)
	end,
})
local label_af = window:createtextlabel(tab_universal, "Anti-fling: Off", 1)
window:createseparator(tab_universal, 1)
window:createlabel(tab_universal, "TARGET", 1)
local fling_box = window:createbutton(tab_universal, {
	Name = "Type a name",
	Col = 1,
	IsInput = true,
	InputKey = "FlingTarget",
})
window:createbutton(tab_universal, {
	Name = "Start fling",
	Col = 1,
	Half = "Left",
	SameRow = true,
	Callback = function()
		fling.start = true
	end,
})
window:createbutton(tab_universal, {
	Name = "Stop fling",
	Col = 1,
	Half = "Right",
	Callback = function()
		fling.stop = true
	end,
})
local label_fling = window:createtextlabel(tab_universal, "Fling: idle", 1)

window:createlabel(tab_prison, "BACKPACK GUNS", 1)
window:createtextlabel(tab_prison, "Zero spread, fast fire, autofire, ammo, range.", 1)
window:createtoggle(tab_prison, {
	Name = "Gun mods",
	StateKey = "PrisonGuns",
	Col = 1,
	Default = false,
})
local label_guns = window:createtextlabel(tab_prison, "Off", 1)
window:createseparator(tab_prison, 1)
window:createlabel(tab_prison, "CAR KICK", 1)
window:createtextlabel(tab_prison, "Sit in the car first.", 1)
local car_box = window:createbutton(tab_prison, {
	Name = "Type a name",
	Col = 1,
	IsInput = true,
	InputKey = "CarTarget",
})
window:createbutton(tab_prison, {
	Name = "Hunt",
	Col = 1,
	Half = "Left",
	SameRow = true,
	Callback = function()
		car.start = true
	end,
})
window:createbutton(tab_prison, {
	Name = "Stop",
	Col = 1,
	Half = "Right",
	Callback = function()
		car.stop = true
	end,
})
window:createbutton(tab_prison, {
	Name = "Panic",
	Col = 1,
	Callback = function()
		car.panic = true
	end,
})
local label_car = window:createtextlabel(tab_prison, car.status, 1)

window:createlabel(tab_mm2, "MARKS", 1)
window:createtoggle(tab_mm2, {
	Name = "Murderer and sheriff",
	StateKey = "MM2Roles",
	Col = 1,
	Default = false,
})
local label_mm2 = window:createtextlabel(tab_mm2, "Off", 1)

window:createlabel(tab_kat, "CRATES", 1)
window:createtoggle(tab_kat, {
	Name = "Crate ESP",
	StateKey = "CrateESP",
	Col = 1,
	Default = false,
})
window:createtoggle(tab_kat, {
	Name = "Auto collect",
	StateKey = "CrateCollect",
	Col = 1,
	Default = false,
})
local label_kat = window:createtextlabel(tab_kat, "Off", 1)

window:createlabel(tab_diffuse, "WALLBANG", 1)
window:createtextlabel(tab_diffuse, "Parents Map under IgnoreParts.", 1)
window:createbutton(tab_diffuse, {
	Name = "Apply wallbang",
	Col = 1,
	Callback = function()
		diffuse_wallbang()
	end,
})
local label_diffuse = window:createtextlabel(tab_diffuse, diffuse_status, 1)

if window.settext then
	window:settext("FlingTarget", "")
	window:settext("CarTarget", "")
end

local function box_text(el)
	if not el or not el.Txt then
		return "", false
	end
	local text = tostring(el.Txt.Text or "")
	local focused = string.sub(text, -1) == "|"
	if focused then
		text = string.sub(text, 1, -2)
	end
	if el.BaseText and text == el.BaseText then
		return "", focused
	end
	return text, focused
end

local function best_match(query)
	local q = norm(query)
	if q == "" then
		return nil, 0
	end
	local best, best_rank, count = nil, 99, 0
	local list = players_list()
	for i = 1, #list do
		local p = list[i]
		local nm = norm(sdk.name(p) or "")
		local dn = sdk.display_name and norm(sdk.display_name(p) or "") or ""
		local rank = nil
		if nm == q or (dn ~= "" and dn == q) then
			rank = 1
		elseif (#q > 0 and (string.sub(nm, 1, #q) == q or (dn ~= "" and string.sub(dn, 1, #q) == q))) then
			rank = 2
		elseif string.find(nm, q, 1, true) or (dn ~= "" and string.find(dn, q, 1, true)) then
			rank = 3
		end
		if rank and rank < best_rank then
			best, best_rank, count = p, rank, 1
		elseif rank and rank == best_rank then
			count = count + 1
		end
	end
	if count ~= 1 then
		return nil, count
	end
	return best, 1
end

local function sync_box(el, key)
	local text, focused = box_text(el)
	local player, count = best_match(text)
	if valid(player) and not focused and window.settext then
		local full = tostring(sdk.name(player) or "")
		if full ~= "" and full ~= text then
			window:settext(key, full)
			text = full
		end
	end
	return text, player, count
end

local function match_line(text, player, count)
	if text == "" then
		return "Type part of a name"
	end
	if valid(player) then
		return tostring(sdk.name(player) or text)
	end
	if count > 1 then
		return tostring(count) .. " matches"
	end
	return "No match"
end

math.randomseed(gurp.time_ms() or os.time())

local threads = {}

local function spawn_thread(name, fn)
	threads[#threads + 1] = { name = name, co = coroutine.create(fn), at = 0 }
end

local function poll_threads()
	local now = os.clock()
	for i = 1, #threads do
		local th = threads[i]
		if now >= th.at and coroutine.status(th.co) ~= "dead" then
			local ok, wait_for = coroutine.resume(th.co)
			if not ok then
				local msg = tostring(wait_for)
				if not string.find(msg, "Lua environment reset", 1, true) then
					gurp.log("thread " .. th.name .. ": " .. msg)
				end
				th.at = now + 1
			else
				th.at = os.clock() + (tonumber(wait_for) or 0)
			end
		end
	end
end

spawn_thread("noclip", function()
	while true do
		if window:getvalue("NoclipOthers") then
			tick_noclip()
			pause(0.1)
		else
			pause(0.2)
		end
	end
end)

spawn_thread("hitbox", function()
	while true do
		if window:getvalue("Hitbox") then
			tick_hitbox(window:getvalue("HeadSize"))
			pause(0.1)
		else
			pause(0.2)
		end
	end
end)

spawn_thread("antifling", function()
	while true do
		local on = window:getvalue("AntiFling") == true
		tick_antifling(on)
		if af.latched then
			pause(0.001)
		elseif on then
			pause(0.02)
		else
			pause(0.1)
		end
	end
end)

spawn_thread("fling", function()
	while true do
		if fling.stop then
			fling.stop = false
			stop_fling("manual")
		end
		if fling.start then
			fling.start = false
			start_fling()
		end
		if fling.chasing then
			tick_fling()
			pause(0.001)
		else
			pause(0.05)
		end
	end
end)

spawn_thread("car", function()
	while true do
		if request_stop_car or car.stop then
			request_stop_car = false
			car.stop = false
			stop_car("Hunt stopped.")
		end
		if car.panic then
			car.panic = false
			local char = local_character()
			local humanoid = valid(char) and sdk.find_child_of_class(char, "Humanoid") or nil
			stop_car("Panic reset.")
			if valid(humanoid) and OFF_HEALTH then
				mem.write_f32(humanoid + OFF_HEALTH, 0)
			end
		end
		if car.start then
			car.start = false
			begin_car()
		end
		if car.hunting then
			tick_car()
			pause(0)
		else
			pause(0.05)
		end
	end
end)

spawn_thread("guns", function()
	while true do
		if window:getvalue("PrisonGuns") then
			tick_guns()
			pause(0.1)
		else
			gun_status = "Off"
			pause(0.2)
		end
	end
end)

spawn_thread("crates", function()
	while true do
		local collect_on = window:getvalue("CrateCollect") == true
		local crates_on = window:getvalue("CrateESP") == true
		if collect_on then
			local pickups = kat_pickups()
			local points = pickups and kat_points(pickups) or {}
			if not pickups then
				kat.status = "Pickups folder not found"
				kat_stop()
			elseif not valid(local_hrp()) or #points == 0 then
				kat.status = "Waiting (" .. tostring(#points) .. " crates)"
				kat_stop()
			else
				kat.status = "Collecting"
				kat_collect_once()
			end
			pause(0.05)
		else
			kat_stop()
			if crates_on then
				local pickups = kat_pickups()
				local points = pickups and kat_points(pickups) or {}
				kat.status = pickups and (tostring(#points) .. " crates") or "Pickups folder not found"
			else
				kat.status = "Off"
			end
			pause(0.1)
		end
	end
end)

gurp.log("gurp hub ready")

while true do
	local fling_text, fling_player, fling_count = sync_box(fling_box, "FlingTarget")
	fling.query = fling_text
	fling.pick = fling_player
	fling.match_count = fling_count
	local car_text, car_player, car_count = sync_box(car_box, "CarTarget")
	car.query = car_text
	car.pick = car_player
	car.match_count = car_count

	poll_threads()

	local roles_on = window:getvalue("MM2Roles") == true
	local crates_on = window:getvalue("CrateESP") == true
	local points = {}
	local pickups = crates_on and kat_pickups() or nil
	if pickups then
		points = kat_points(pickups)
	end

	esp_reset()
	local marked = 0
	if roles_on then
		local list = players_list()
		for i = 1, #list do
			local player = list[i]
			local role = mm2_role(player)
			local text = nil
			local r, g, b = 1, 1, 1
			if role == "Murderer" then
				text = role
				r, g, b = 1, 0.25, 0.25
			elseif role == "Sheriff" then
				text = role
				r, g, b = 0.4, 0.75, 1
			end
			if text then
				local head = sdk.find_child(character_of(player), "Head")
				local pos = valid(head) and sdk.position(head) or nil
				if pos then
					esp_mark(pos.x, pos.y, pos.z, text, r, g, b)
					marked = marked + 1
				end
			end
		end
	end
	if crates_on then
		for i = 1, #points do
			local pos = points[i]
			esp_mark(pos.x, pos.y, pos.z, "Crate", 1, 0.75, 0.2)
		end
	end
	esp_finish()

	set_text(label_af, "Anti-fling: " .. af_status())
	set_text(label_fling, "Fling: " .. match_line(fling.query, fling.pick, fling.match_count or 0))
	if fling.chasing then
		set_text(label_fling, "Fling: " .. fling.name)
	end
	set_text(label_guns, gun_status)
	if roles_on then
		set_text(label_mm2, "Marked " .. tostring(marked))
	else
		set_text(label_mm2, "Off")
	end
	set_text(label_kat, kat.status)
	if car.hunting then
		set_text(label_car, car.status)
	elseif car.query ~= "" then
		set_text(label_car, match_line(car.query, car.pick, car.match_count or 0))
	elseif car.status ~= "Type a target, sit in the car, then hunt." then
		set_text(label_car, car.status)
	else
		set_text(label_car, "Type part of a name")
	end
	set_text(label_diffuse, diffuse_status)

	if car.hunting or fling.chasing or fling.restoring or af.latched then
		gurp.wait(0)
	elseif window:getvalue("AntiFling") then
		gurp.wait(0.02)
	else
		gurp.wait(0.03)
	end
end
