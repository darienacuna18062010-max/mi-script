--[[
	ClientInfoCollector.lua  ·  HARDENED v4.1 (DELTA-COMPATIBLE)
	Target: Roblox GAME CLIENT (DELTA, Synapse, KRNL, Fluxus, Solara, Wave, etc.)
	SOLO LECTURA. No modifica entorno, no usa hooks, no usa HttpGet.

	Cambios específicos para DELTA:
	  - Detección automática de DELTA vía identifyexecutor().
	  - Espera robusta de LocalPlayer (DELTA inyecta antes de que exista).
	  - Prioridad a gethui() sobre CoreGui (DELTA móvil bloquea CoreGui).
	  - FetchProductInfo desactivado en DELTA (lento/inestable en móvil).
	  - Confirmación de inyección con identifyexecutor().
]]

--================================================================
-- [0] BOOTSTRAP + DELTA DETECTION
--================================================================

local ENV = _G
do
	local ok, e = pcall(function()
		if type(getgenv) == "function" then
			return getgenv()
		end
		return nil
	end)
	if ok and type(e) == "table" then
		ENV = e
	end
end

-- Detectar executor
local EXECUTOR_NAME = "Unknown"
do
	local ok, name = pcall(function()
		if type(identifyexecutor) == "function" then
			local n = identifyexecutor()
			return n
		end
		return nil
	end)
	if ok and type(name) == "string" then
		EXECUTOR_NAME = name
	end
end

local IS_DELTA = (EXECUTOR_NAME:lower():find("delta") ~= nil)

-- Polyfills
do
	if type(table) ~= "table" then table = {} end
	if type(table.pack) ~= "function" then
		table.pack = function(...)
			return { n = select("#", ...), ... }
		end
	end
end

do
	if type(table.unpack) ~= "function" then
		local u = (rawget and rawget(_G, "unpack")) or unpack
		if type(u) == "function" then
			table.unpack = u
		else
			table.unpack = function(t, i, j)
				i = i or 1
				j = j or #t
				return t[i], t[i+1], t[i+2], t[i+3], t[i+4], t[i+5], t[i+6], t[i+7]
			end
		end
	end
end

do
	if type(math) ~= "table" then math = {} end
	if type(math.clamp) ~= "function" then
		math.clamp = function(v, mn, mx)
			if v < mn then return mn end
			if v > mx then return mx end
			return v
		end
	end
end

local CLOCK = (function()
	if type(os) == "table" and type(os.clock) == "function" then
		local ok, v = pcall(os.clock)
		if ok and type(v) == "number" then return os.clock end
	end
	if type(tick) == "function" then return tick end
	if type(time) == "function" then return time end
	return function() return 0 end
end)()

local WAIT = (function()
	if type(task) == "table" and type(task.wait) == "function" then
		return function(t) pcall(task.wait, t) end
	end
	if type(wait) == "function" then
		return function(t) pcall(wait, t) end
	end
	return function(t)
		t = t or 0
		local t0 = CLOCK()
		while CLOCK() - t0 < t do end
	end
end)()

local SPAWN = (function()
	if type(task) == "table" and type(task.spawn) == "function" then
		return function(fn, ...)
			local ok, co = pcall(task.spawn, fn, ...)
			if ok then return co end
			return nil
		end
	end
	if type(spawn) == "function" then
		return function(fn, ...)
			local ok, co = pcall(spawn, fn, ...)
			if ok then return co end
			return nil
		end
	end
	return function(fn, ...)
		local co = coroutine.create(fn)
		pcall(coroutine.resume, co, ...)
		return co
	end
end)()

local WARN = (function()
	if type(warn) == "function" then return warn end
	if type(print) == "function" then return print end
	return function() end
end)()

--================================================================
-- [1] CONFIG (adaptado para DELTA)
--================================================================

local CONFIG = {
	PrintReport        = true,
	PrintFormat        = "table",
	Verbose            = false,
	FpsSampleSeconds   = 2,
	WorkspaceScanLimit = 3000,
	ScanYieldEvery     = 200,
	CollectorTimeout   = 5,
	-- DELTA: GetProductInfo es lento/inestable en móvil → desactivado
	FetchProductInfo   = not IS_DELTA,
	EnableCache        = true,
	EnableDiff         = true,
	EnablePeers        = true,
	EnableHardware     = true,
	EnableExtended     = true,
	Silent             = false,
}

local BUDGET = {
	Experience      = 3000,
	Player          = 300,
	Character       = 400,
	Device          = 300,
	Display         = 200,
	Network         = 400,
	Memory          = 400,
	Locale          = 200,
	Lighting        = 300,
	Misc            = 500,
	Peers           = 800,
	Hardware        = 600,
	WorkspaceCensus = 3000,
	Performance     = 5000,
}

local CACHE_TTL = {
	Experience      = 60,
	Player          = 5,
	Character       = 2,
	Device          = 30,
	Display         = 5,
	Network         = 2,
	Memory          = 2,
	Locale          = 60,
	Lighting        = 30,
	Misc            = 10,
	Peers           = 2,
	Hardware        = 10,
	WorkspaceCensus = 8,
	Performance     = 0,
}

--================================================================
-- [2] SAFE
--================================================================

local Safe = {}

local function log(...)
	if CONFIG.Verbose and not CONFIG.Silent then
		pcall(WARN, "[CIC]", ...)
	end
end

function Safe.str(v)
	local ok, s = pcall(tostring, v)
	if ok and type(s) == "string" then return s end
	local ok2, s2 = pcall(function()
		return type(v) == "table" and "table" or "?"
	end)
	return ok2 and s2 or "?"
end

function Safe.round(n, decimals)
	if type(n) ~= "number" then return 0 end
	if n ~= n then return 0 end
	if n == math.huge or n == -math.huge then return 0 end
	local m = 10 ^ (decimals or 0)
	local r = math.floor(n * m + 0.5) / m
	if r ~= r then return 0 end
	return r
end

function Safe.call(fn, label, ...)
	if type(fn) ~= "function" then
		log("Safe.call: no función [" .. Safe.str(label) .. "]")
		return false, "not a function"
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return fn(table.unpack(args, 1, args.n))
	end)
	if not ok then
		log("pcall falló [" .. Safe.str(label) .. "]:", result)
	end
	return ok, result
end

function Safe.try(fn, default, label, ...)
	local ok, result = Safe.call(fn, label, ...)
	if ok and result ~= nil then return result end
	return default
end

function Safe.get(instance, prop, default)
	if instance == nil then return default end
	local ok, value = pcall(function()
		return instance[prop]
	end)
	if ok and value ~= nil then return value end
	return default
end

function Safe.methodRef(instance, method)
	if instance == nil then return nil end
	local ok, fn = pcall(function()
		return instance[method]
	end)
	if ok and type(fn) == "function" then return fn end
	return nil
end

function Safe.method(instance, method, default, ...)
	local fn = Safe.methodRef(instance, method)
	if not fn then return default end
	local args = table.pack(...)
	local ok, value = pcall(function()
		return fn(instance, table.unpack(args, 1, args.n))
	end)
	if ok and value ~= nil then return value end
	return default
end

function Safe.flag(instance, prop)
	return Safe.get(instance, prop, false) == true
end

function Safe.methodAsync(instance, method, default, timeout, ...)
	local fn = Safe.methodRef(instance, method)
	if not fn then return default end
	local args = table.pack(...)
	local result, done = nil, false
	SPAWN(function()
		local ok, v = pcall(function()
			return fn(instance, table.unpack(args, 1, args.n))
		end)
		if ok then result = v end
		done = true
	end)
	local t0 = CLOCK()
	timeout = timeout or 2
	while not done and (CLOCK() - t0) < timeout do
		WAIT(0.05)
	end
	if done and result ~= nil then return result end
	return default
end

--================================================================
-- [3] SERVICES (con espera robusta para DELTA)
--================================================================

local function getService(name)
	local ok, svc = pcall(function()
		return game:GetService(name)
	end)
	if ok and svc ~= nil then return svc end
	local ok2, svc2 = pcall(function()
		return game:FindService(name)
	end)
	if ok2 and svc2 ~= nil then return svc2 end
	return nil
end

local Players             = getService("Players")
local RunService          = getService("RunService")
local UserInputService    = getService("UserInputService")
local GuiService          = getService("GuiService")
local Stats               = getService("Stats")
local Workspace           = getService("Workspace")
local LocalizationService = getService("LocalizationService")
local MarketplaceService  = getService("MarketplaceService")
local Lighting            = getService("Lighting")
local SoundService        = getService("SoundService")
local TextChatService     = getService("TextChatService")
local Teams               = getService("Teams")

-- DELTA: espera robusta de LocalPlayer (inyecta antes de que exista)
local LocalPlayer = nil
do
	if Players then
		LocalPlayer = Safe.get(Players, "LocalPlayer", nil)
		if not LocalPlayer then
			-- Esperar hasta 10 segundos (DELTA a veces tarda)
			local t0 = CLOCK()
			while not LocalPlayer and (CLOCK() - t0) < 10 do
				WAIT(0.25)
				LocalPlayer = Safe.get(Players, "LocalPlayer", nil)
			end
		end
	end
end

-- UserGameSettings (opcional en executors)
local UserGameSettings = Safe.try(function()
	return UserSettings():GetService("UserGameSettings")
end, nil, "UserGameSettings")

-- DELTA: obtener GUI parent seguro (aunque no creamos GUIs, por si acaso)
local GUI_PARENT = nil
do
	-- Prioridad: gethui() > CoreGui > PlayerGui
	local ok1, h = pcall(function() return gethui() end)
	if ok1 and h then
		GUI_PARENT = h
	else
		local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok2 and cg then
			GUI_PARENT = cg
		elseif LocalPlayer then
			local ok3, pg = pcall(function()
				return LocalPlayer:WaitForChild("PlayerGui", 5)
			end)
			if ok3 then GUI_PARENT = pg end
		end
	end
end

local CAPS = {
	HasHeartbeat     = RunService and Safe.methodRef(RunService, "Heartbeat") ~= nil,
	HasRenderStepped = RunService and Safe.methodRef(RunService, "RenderStepped") ~= nil,
	HasGetPlatform   = UserInputService and Safe.methodRef(UserInputService, "GetPlatform") ~= nil,
	HasStats         = Stats ~= nil,
	HasGameSettings  = UserGameSettings ~= nil,
	HasTeams         = Teams ~= nil,
	HasTextChat      = TextChatService ~= nil,
	HasGuiParent     = GUI_PARENT ~= nil,
}

--================================================================
-- [4] COLLECTORS
--================================================================

local Collectors = {}

Collectors.Experience = function()
	local info = {
		PlaceId      = Safe.get(game, "PlaceId", 0),
		GameId       = Safe.get(game, "GameId", 0),
		PlaceVersion = Safe.get(game, "PlaceVersion", 0),
		JobId        = Safe.get(game, "JobId", ""),
		CreatorId    = Safe.get(game, "CreatorId", 0),
		CreatorType  = Safe.str(Safe.get(game, "CreatorType", "?")),
		IsStudio     = Safe.method(RunService, "IsStudio", false),
		Executor     = EXECUTOR_NAME,
		IsDelta      = IS_DELTA,
	}
	info.JobId = (info.JobId ~= "" and info.JobId) or "N/A"
	local privId = Safe.get(game, "PrivateServerId", "")
	local privOwner = Safe.get(game, "PrivateServerOwnerId", 0)
	info.IsPrivateServer  = privId ~= ""
	info.IsReservedServer = privOwner ~= 0 and privId ~= ""
	info.IsClient         = Safe.method(RunService, "IsClient", true)
	info.IsRunning        = Safe.method(RunService, "IsRunning", true)
	if CONFIG.FetchProductInfo and MarketplaceService and info.PlaceId ~= 0 then
		local product = Safe.methodAsync(MarketplaceService, "GetProductInfo", nil, 3, info.PlaceId)
		if type(product) == "table" then
			info.Name        = Safe.get(product, "Name")
			info.Description = Safe.get(product, "Description")
			info.Created     = Safe.get(product, "Created")
			info.Updated     = Safe.get(product, "Updated")
			local creator = Safe.get(product, "Creator")
			if type(creator) == "table" or type(creator) == "userdata" then
				info.CreatorName = Safe.get(creator, "Name", "N/A")
			end
		end
	end
	return info
end

Collectors.Player = function()
	if not LocalPlayer then return { Available = false } end
	local data = {
		Name            = Safe.get(LocalPlayer, "Name"),
		DisplayName     = Safe.get(LocalPlayer, "DisplayName"),
		UserId          = Safe.get(LocalPlayer, "UserId"),
		AccountAgeDays  = Safe.get(LocalPlayer, "AccountAge"),
		MembershipType  = Safe.str(Safe.get(LocalPlayer, "MembershipType")),
		LocaleId        = Safe.get(LocalPlayer, "LocaleId"),
		Team            = Safe.str(Safe.get(LocalPlayer, "Team", "Ninguno")),
		Neutral         = Safe.get(LocalPlayer, "Neutral"),
		CameraMode      = Safe.str(Safe.get(LocalPlayer, "CameraMode")),
		GameplayPaused  = Safe.get(LocalPlayer, "GameplayPaused"),
		CharacterLoaded = Safe.get(LocalPlayer, "Character") ~= nil,
		FollowUserId    = Safe.get(LocalPlayer, "FollowUserId"),
	}
	if CONFIG.EnableExtended then
		data.CharacterAppearanceId = Safe.get(LocalPlayer, "CharacterAppearanceId")
		if Safe.methodRef(LocalPlayer, "GetJoinData") then
			local jd = Safe.method(LocalPlayer, "GetJoinData", nil)
			if type(jd) == "table" then
				data.JoinData = {
					SourcePlaceId   = Safe.get(jd, "SourcePlaceId"),
					SourceGameId    = Safe.get(jd, "SourceGameId"),
					HasTeleportData = Safe.get(jd, "TeleportData") ~= nil,
					MembershipType  = Safe.str(Safe.get(jd, "MembershipType")),
				}
			end
		end
	end
	return data
end

Collectors.Character = function()
	local char = LocalPlayer and Safe.get(LocalPlayer, "Character")
	if not char or Safe.get(char, "Parent") == nil then
		return { Available = false }
	end
	local hum  = Safe.method(char, "FindFirstChildOfClass", nil, "Humanoid")
	local root = Safe.get(char, "PrimaryPart") or Safe.method(char, "FindFirstChild", nil, "HumanoidRootPart")
	local data = { Available = true, Name = Safe.get(char, "Name") }
	if hum then
		data.Health       = Safe.round(Safe.get(hum, "Health", 0), 1)
		data.MaxHealth    = Safe.round(Safe.get(hum, "MaxHealth", 0), 1)
		data.WalkSpeed    = Safe.get(hum, "WalkSpeed")
		data.JumpPower    = Safe.get(hum, "JumpPower")
		data.JumpHeight   = Safe.get(hum, "JumpHeight")
		data.RigType      = Safe.str(Safe.get(hum, "RigType"))
		data.State        = Safe.str(Safe.method(hum, "GetState", "?"))
		data.HipHeight    = Safe.get(hum, "HipHeight")
		data.StateEnabled = Safe.method(hum, "GetStateEnabled", nil)
	end
	if root then
		local pos = Safe.get(root, "Position")
		if pos and type(pos) == "userdata" then
			local ok, s = pcall(function()
				return string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
			end)
			if ok then data.Position = s end
		end
	end
	local accs, tools = {}, {}
	local children = Safe.method(char, "GetChildren", {})
	if type(children) == "table" then
		for _, child in ipairs(children) do
			local cn = Safe.get(child, "ClassName", "")
			if cn == "Accessory" then
				table.insert(accs, {
					Name = Safe.get(child, "Name"),
					Type = Safe.str(Safe.get(child, "AccessoryType")),
				})
			elseif cn == "Tool" then
				table.insert(tools, Safe.get(child, "Name"))
			end
		end
	end
	data.Accessories   = accs
	data.ToolsEquipped = tools
	return data
end

Collectors.Device = function()
	local uis = UserInputService
	local platform = "Desconocida"
	if uis then
		if Safe.flag(uis, "TouchEnabled") and not Safe.flag(uis, "KeyboardEnabled") then
			platform = "Móvil/Tablet"
		elseif Safe.flag(uis, "GamepadEnabled") and not Safe.flag(uis, "KeyboardEnabled") then
			platform = "Consola/Gamepad"
		elseif Safe.flag(uis, "KeyboardEnabled") then
			platform = "PC"
		end
		if Safe.flag(uis, "VREnabled") then platform = "VR" end
	end
	local data = {
		PlatformGuess        = platform,
		TouchEnabled         = Safe.get(uis, "TouchEnabled"),
		KeyboardEnabled      = Safe.get(uis, "KeyboardEnabled"),
		MouseEnabled         = Safe.get(uis, "MouseEnabled"),
		GamepadEnabled       = Safe.get(uis, "GamepadEnabled"),
		GyroscopeEnabled     = Safe.get(uis, "GyroscopeEnabled"),
		AccelerometerEnabled = Safe.get(uis, "AccelerometerEnabled"),
		VREnabled            = Safe.get(uis, "VREnabled"),
		MouseBehavior        = Safe.str(Safe.get(uis, "MouseBehavior")),
		MouseIconEnabled     = Safe.get(uis, "MouseIconEnabled"),
	}
	if CAPS.HasGetPlatform then
		data.PlatformNative = Safe.method(uis, "GetPlatform", "?")
	end
	if Safe.methodRef(uis, "GetLastInputType") then
		data.LastInputType = Safe.str(Safe.method(uis, "GetLastInputType", "?"))
	end
	if Safe.methodRef(GuiService, "IsTenFootInterface") then
		data.IsTenFootInterface = Safe.method(GuiService, "IsTenFootInterface", false)
	end
	local pads = Safe.method(uis, "GetConnectedGamepads", {})
	if type(pads) == "table" then data.GamepadsConnected = #pads end
	return data
end

Collectors.Display = function()
	local cam = Workspace and Safe.get(Workspace, "CurrentCamera")
	local vp  = cam and Safe.get(cam, "ViewportSize")
	local topLeft = Vector2.zero
	if GuiService then
		topLeft = Safe.method(GuiService, "GetGuiInset", Vector2.zero) or Vector2.zero
	end
	return {
		ViewportSize          = vp and string.format("%dx%d", vp.X, vp.Y) or "N/A",
		FieldOfView           = cam and Safe.round(Safe.get(cam, "FieldOfView", 0), 1) or nil,
		CameraType            = cam and Safe.str(Safe.get(cam, "CameraType")) or "N/A",
		CameraSubject         = cam and Safe.str(Safe.get(cam, "CameraSubject")) or "N/A",
		GuiInsetTopLeft       = Safe.str(topLeft),
		MenuIsOpen            = Safe.get(GuiService, "MenuIsOpen"),
		PreferredTransparency = Safe.get(GuiService, "PreferredTransparency"),
		ReducedMotionEnabled  = Safe.get(GuiService, "ReducedMotionEnabled"),
	}
end

Collectors.Performance = function()
	local frames, elapsed = 0, 0
	local minDt, maxDt = math.huge, 0
	local samples = {}
	local connHB = nil
	if CAPS.HasHeartbeat then
		local ok, c = pcall(function()
			return RunService.Heartbeat:Connect(function(dt)
				if type(dt) ~= "number" then return end
				frames = frames + 1
				elapsed = elapsed + dt
				if dt < minDt then minDt = dt end
				if dt > maxDt then maxDt = dt end
				if #samples < 3000 then
					samples[#samples + 1] = dt
				end
			end)
		end)
		if ok then connHB = c end
	end
	WAIT(CONFIG.FpsSampleSeconds)
	if connHB then
		pcall(function() connHB:Disconnect() end)
	end
	local avgFps = elapsed > 0 and (frames / elapsed) or 0
	table.sort(samples)
	local function pct(p)
		if #samples == 0 then return 0 end
		local idx = math.clamp(math.floor(#samples * p + 0.5), 1, #samples)
		return samples[idx]
	end
	return {
		SampleSeconds = CONFIG.FpsSampleSeconds,
		AvgFPS        = Safe.round(avgFps, 1),
		MinFPS        = maxDt > 0 and Safe.round(1 / maxDt, 1) or 0,
		MaxFPS        = (minDt ~= math.huge and minDt > 0) and Safe.round(1 / minDt, 1) or 0,
		Frames        = frames,
		P95FrameMs    = Safe.round(pct(0.95) * 1000, 2),
		P99FrameMs    = Safe.round(pct(0.99) * 1000, 2),
		JitterMs      = Safe.round((maxDt - minDt) * 1000, 2),
		PhysicsFPS    = Safe.round(Safe.method(Workspace, "GetRealPhysicsFPS", 0), 1),
		AwakeParts    = Safe.method(Workspace, "GetNumAwakeParts", 0),
		QualityLevel  = Safe.str(Safe.get(UserGameSettings, "SavedQualityLevel", "?")),
	}
end

Collectors.Network = function()
	local ping = LocalPlayer and Safe.method(LocalPlayer, "GetNetworkPing", nil)
	local data = {
		PingMs = ping and Safe.round(ping * 1000, 1) or "N/A",
	}
	if CAPS.HasStats then
		data.DataReceiveKbps    = Safe.round(Safe.get(Stats, "DataReceiveKbps", 0), 1)
		data.DataSendKbps       = Safe.round(Safe.get(Stats, "DataSendKbps", 0), 1)
		data.HeartbeatTimeMs    = Safe.round(Safe.get(Stats, "HeartbeatTimeMs", 0), 2)
		data.PhysicsSendKbps    = Safe.round(Safe.get(Stats, "PhysicsSendKbps", 0), 1)
		data.PhysicsReceiveKbps = Safe.round(Safe.get(Stats, "PhysicsReceiveKbps", 0), 1)
	end
	if Players then
		local pl = Safe.method(Players, "GetPlayers", {})
		if type(pl) == "table" then data.PlayersInServer = #pl end
		data.MaxPlayers = Safe.get(Players, "MaxPlayers")
	end
	return data
end

Collectors.Memory = function()
	local data = {}
	if CAPS.HasStats then
		data.TotalMemoryMb         = Safe.round(Safe.method(Stats, "GetTotalMemoryUsageMb", 0), 1)
		data.InstanceCount         = Safe.get(Stats, "InstanceCount")
		data.PrimitivesCount       = Safe.get(Stats, "PrimitivesCount")
		data.MovingPrimitivesCount = Safe.get(Stats, "MovingPrimitivesCount")
	end
	data.LuaHeapMb = Safe.try(function()
		return Safe.round(collectgarbage("count") / 1024, 2)
	end, 0, "LuaHeap")
	return data
end

Collectors.WorkspaceCensus = function()
	if not Workspace then return { Available = false } end
	local counts = {}
	local total, scanned = 0, 0
	local truncated = false
	local descendants = Safe.method(Workspace, "GetDescendants", {})
	if type(descendants) ~= "table" then
		return { Available = false, Reason = "no descendants" }
	end
	total = #descendants
	for _, inst in ipairs(descendants) do
		scanned = scanned + 1
		if scanned > CONFIG.WorkspaceScanLimit then
			truncated = true
			break
		end
		local cn = Safe.get(inst, "ClassName", "?")
		counts[cn] = (counts[cn] or 0) + 1
		if scanned % CONFIG.ScanYieldEvery == 0 then
			WAIT()
		end
	end
	local list = {}
	for class, n in pairs(counts) do
		list[#list + 1] = { class = class, n = n }
	end
	table.sort(list, function(a, b) return a.n > b.n end)
	local top = {}
	for i = 1, math.min(10, #list) do
		top[i] = string.format("%s = %d", list[i].class, list[i].n)
	end
	local data = {
		TotalDescendants = total,
		Scanned          = math.min(scanned, total),
		Truncated        = truncated,
		TopClasses       = top,
		Gravity          = Safe.get(Workspace, "Gravity"),
		StreamingEnabled = Safe.get(Workspace, "StreamingEnabled"),
		Terrain          = Safe.get(Workspace, "Terrain") ~= nil,
	}
	local cam = Safe.get(Workspace, "CurrentCamera")
	if cam then
		local cf = Safe.get(cam, "CFrame")
		if cf and type(cf) == "userdata" then
			local ok, mag = pcall(function() return cf.Position.Magnitude end)
			if ok then data.CameraDistanceToOrigin = Safe.round(mag, 1) end
		end
	end
	return data
end

Collectors.Lighting = function()
	if not Lighting then return { Available = false } end
	local effects = {}
	local children = Safe.method(Lighting, "GetChildren", {})
	if type(children) == "table" then
		for _, c in ipairs(children) do
			effects[#effects + 1] = Safe.get(c, "ClassName", "?")
		end
	end
	local atmo = Safe.method(Lighting, "FindFirstChildOfClass", nil, "Atmosphere")
	local sky  = Safe.method(Lighting, "FindFirstChildOfClass", nil, "Sky")
	return {
		Technology           = Safe.str(Safe.get(Lighting, "Technology")),
		ClockTime            = Safe.round(Safe.get(Lighting, "ClockTime", 0), 2),
		Brightness           = Safe.get(Lighting, "Brightness"),
		GlobalShadows        = Safe.get(Lighting, "GlobalShadows"),
		FogEnd               = Safe.get(Lighting, "FogEnd"),
		Ambient              = Safe.str(Safe.get(Lighting, "Ambient")),
		OutdoorAmbient       = Safe.str(Safe.get(Lighting, "OutdoorAmbient")),
		ExposureCompensation = Safe.get(Lighting, "ExposureCompensation"),
		ShadowSoftness       = Safe.get(Lighting, "ShadowSoftness"),
		Effects              = effects,
		Atmosphere           = atmo and {
			Density = Safe.get(atmo, "Density"),
			Haze    = Safe.get(atmo, "Haze"),
			Glare   = Safe.get(atmo, "Glare"),
		} or nil,
		Sky = sky ~= nil,
	}
end

Collectors.Locale = function()
	return {
		RobloxLocaleId = Safe.get(LocalizationService, "RobloxLocaleId"),
		SystemLocaleId = Safe.get(LocalizationService, "SystemLocaleId"),
		PlayerLocaleId = LocalPlayer and Safe.get(LocalPlayer, "LocaleId") or "N/A",
	}
end

Collectors.Misc = function()
	local teamNames = {}
	if CAPS.HasTeams then
		local ts = Safe.method(Teams, "GetTeams", {})
		if type(ts) == "table" then
			for _, t in ipairs(ts) do
				teamNames[#teamNames + 1] = Safe.str(Safe.get(t, "Name"))
			end
		end
	end
	local utc = "?"
	pcall(function()
		utc = os.date("!%Y-%m-%d %H:%M:%S")
	end)
	local clientAge = 0
	local ok = pcall(function() clientAge = time() end)
	if not ok then clientAge = 0 end
	return {
		ChatVersion      = Safe.str(Safe.get(TextChatService, "ChatVersion")),
		AmbientReverb    = Safe.str(Safe.get(SoundService, "AmbientReverb")),
		Teams            = teamNames,
		LocalTimeUTC     = utc,
		ClientAgeSeconds = Safe.round(clientAge, 1),
		GuiParentType    = CAPS.HasGuiParent and (IS_DELTA and "gethui()" or "CoreGui") or "none",
	}
end

Collectors.Peers = function()
	if not CONFIG.EnablePeers or not Players then
		return { Available = false }
	end
	local list = {}
	local players = Safe.method(Players, "GetPlayers", {})
	if type(players) ~= "table" then
		return { Available = false }
	end
	for _, p in ipairs(players) do
		local ping = Safe.method(p, "GetNetworkPing", 0)
		list[#list + 1] = {
			Name            = Safe.get(p, "Name"),
			DisplayName     = Safe.get(p, "DisplayName"),
			UserId          = Safe.get(p, "UserId"),
			AccountAge      = Safe.get(p, "AccountAge"),
			Team            = Safe.str(Safe.get(p, "Team", "Ninguno")),
			PingMs          = Safe.round((ping or 0) * 1000, 1),
			CharacterLoaded = Safe.get(p, "Character") ~= nil,
			FollowUserId    = Safe.get(p, "FollowUserId"),
			MembershipType  = Safe.str(Safe.get(p, "MembershipType")),
		}
	end
	return { Count = #list, Players = list }
end

Collectors.Hardware = function()
	if not CONFIG.EnableHardware then
		return { Available = false }
	end
	return {
		SavedQualityLevel          = Safe.str(Safe.get(UserGameSettings, "SavedQualityLevel")),
		MasterVolume               = Safe.get(UserGameSettings, "MasterVolume"),
		RotationType               = Safe.str(Safe.get(UserGameSettings, "RotationType")),
		ComputerCameraMovementMode = Safe.str(Safe.get(UserGameSettings, "ComputerCameraMovementMode")),
		ComputerMovementMode       = Safe.str(Safe.get(UserGameSettings, "ComputerMovementMode")),
		GamepadCameraSensitivity   = Safe.get(UserGameSettings, "GamepadCameraSensitivity"),
		MouseSensitivity           = Safe.get(UserGameSettings, "MouseSensitivity"),
		PhysicsSendKbps            = Safe.round(Safe.get(Stats, "PhysicsSendKbps", 0), 1),
		PhysicsReceiveKbps         = Safe.round(Safe.get(Stats, "PhysicsReceiveKbps", 0), 1),
		RealPhysicsFPS             = Safe.round(Safe.method(Workspace, "GetRealPhysicsFPS", 0), 1),
	}
end

local ORDER = {
	"Experience", "Player", "Character", "Device", "Display",
	"Network", "Memory", "Locale", "Lighting", "Misc",
	"Peers", "Hardware", "WorkspaceCensus", "Performance",
}

--================================================================
-- [6] RUNNER
--================================================================

local CACHE = {}

local function runCollector(name, fn)
	if CONFIG.EnableCache then
		local ttl = CACHE_TTL[name]
		if ttl and ttl > 0 then
			local entry = CACHE[name]
			if entry and CLOCK() < entry.expiresAt then
				return entry.value, nil
			end
		end
	end
	local result, errMsg = nil, nil
	local finished = false
	local co = coroutine.create(function()
		local ok, v = pcall(fn)
		if ok then result = v
		else errMsg = Safe.str(v) end
		finished = true
	end)
	local okResume = pcall(coroutine.resume, co)
	if not okResume then
		errMsg = "resume failed"
		finished = true
	end
	local budget = BUDGET[name] or (CONFIG.CollectorTimeout * 1000)
	local cap = CONFIG.CollectorTimeout * 1000
	if budget > cap then budget = cap end
	local t0 = CLOCK()
	while not finished do
		local elapsedMs = (CLOCK() - t0) * 1000
		if elapsedMs > budget then
			errMsg = "timeout"
			break
		end
		WAIT(0.05)
	end
	if CONFIG.EnableCache and not errMsg then
		local ttl = CACHE_TTL[name]
		if ttl and ttl > 0 then
			CACHE[name] = { value = result, expiresAt = CLOCK() + ttl }
		end
	end
	return result, errMsg
end

local function collectAll()
	local report = {}
	local meta = { Errors = {}, Timings = {} }
	local startAll = CLOCK()
	for _, name in ipairs(ORDER) do
		local fn = Collectors[name]
		if type(fn) == "function" then
			local t0 = CLOCK()
			local data, err = runCollector(name, fn)
			meta.Timings[name] = Safe.round((CLOCK() - t0) * 1000, 1)
			if err then
				meta.Errors[name] = err
			else
				report[name] = data
			end
		end
	end
	meta.TotalMs = Safe.round((CLOCK() - startAll) * 1000, 1)
	if CONFIG.EnableDiff and type(ENV) == "table" then
		local prev = ENV.__CIC_Report_v41
		if type(prev) == "table"
			and type(prev.Performance) == "table"
			and type(report.Performance) == "table" then
			local prevMem  = (type(prev.Memory) == "table" and prev.Memory.TotalMemoryMb) or 0
			local curMem   = (type(report.Memory) == "table" and report.Memory.TotalMemoryMb) or 0
			local prevInst = (type(prev.WorkspaceCensus) == "table" and prev.WorkspaceCensus.TotalDescendants) or 0
			local curInst  = (type(report.WorkspaceCensus) == "table" and report.WorkspaceCensus.TotalDescendants) or 0
			meta.Delta = {
				FPS       = Safe.round((report.Performance.AvgFPS or 0) - (prev.Performance.AvgFPS or 0), 1),
				MemoryMb  = Safe.round(curMem - prevMem, 1),
				Instances = curInst - prevInst,
			}
		end
	end
	report._Meta = meta
	return report
end

--================================================================
-- [7] OUTPUT
--================================================================

local function fmtValue(v, indent)
	if type(v) ~= "table" then
		return Safe.str(v)
	end
	local lines = {}
	local isArray = #v > 0
	if isArray then
		for _, item in ipairs(v) do
			if type(item) == "table" then
				lines[#lines + 1] = indent .. "  -"
				lines[#lines + 1] = fmtValue(item, indent .. "    ")
			else
				lines[#lines + 1] = indent .. "  - " .. Safe.str(item)
			end
		end
	else
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			return Safe.str(a) < Safe.str(b)
		end)
		for _, k in ipairs(keys) do
			local val = v[k]
			if type(val) == "table" then
				lines[#lines + 1] = string.format("%s  %s:", indent, Safe.str(k))
				lines[#lines + 1] = fmtValue(val, indent .. "  ")
			else
				lines[#lines + 1] = string.format("%s  %s: %s", indent, Safe.str(k), Safe.str(val))
			end
		end
	end
	return table.concat(lines, "\n")
end

local function toJSON(v)
	if type(v) == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
	end
	if type(v) == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "null"
		end
		return tostring(v)
	end
	if type(v) == "boolean" then
		return v and "true" or "false"
	end
	if type(v) == "nil" then return "null" end
	if type(v) == "table" then
		local isArr = true
		local n = 0
		for k in pairs(v) do
			if type(k) ~= "number" then isArr = false break end
			n = n + 1
		end
		if isArr and n == #v then
			local parts = {}
			for _, item in ipairs(v) do
				parts[#parts + 1] = toJSON(item)
			end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			local parts = {}
			for k, val in pairs(v) do
				parts[#parts + 1] = '"' .. Safe.str(k) .. '":' .. toJSON(val)
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return '"' .. Safe.str(v) .. '"'
end

local function printTable(report)
	local out = { "========== CLIENT INFO REPORT ==========" }
	for _, name in ipairs(ORDER) do
		local section = report[name]
		if section ~= nil then
			out[#out + 1] = string.format("\n[%s]", name)
			if type(section) == "table" then
				local keys = {}
				for k in pairs(section) do keys[#keys + 1] = k end
				table.sort(keys, function(a, b)
					return Safe.str(a) < Safe.str(b)
				end)
				for _, k in ipairs(keys) do
					local val = section[k]
					if type(val) == "table" then
						out[#out + 1] = string.format("  %s:", Safe.str(k))
						out[#out + 1] = fmtValue(val, "  ")
					else
						out[#out + 1] = string.format("  %s: %s", Safe.str(k), Safe.str(val))
					end
				end
			end
		end
	end
	local meta = report._Meta
	if meta then
		out[#out + 1] = string.format("\n[Meta] Total: %s ms", Safe.str(meta.TotalMs))
		for name, err in pairs(meta.Errors) do
			out[#out + 1] = string.format("  (omitido) %s -> %s", name, Safe.str(err))
		end
		if meta.Delta then
			out[#out + 1] = string.format("  Delta FPS: %s | Mem: %s MB | Inst: %s",
				Safe.str(meta.Delta.FPS),
				Safe.str(meta.Delta.MemoryMb),
				Safe.str(meta.Delta.Instances))
		end
	end
	out[#out + 1] = "========================================"
	pcall(print, table.concat(out, "\n"))
end

local function printJSON(report)
	local ok, json = pcall(toJSON, report)
	if ok then
		pcall(print, json)
	else
		pcall(print, '{"error":"json serialization failed"}')
	end
end

--================================================================
-- [8] MAIN
--================================================================

local function main()
	-- DELTA: esperar a que LocalPlayer esté disponible (ya se esperó arriba)
	-- Si aún no hay LocalPlayer, esperar un poco más
	if not LocalPlayer and Players then
		local t0 = CLOCK()
		while not LocalPlayer and (CLOCK() - t0) < 5 do
			WAIT(0.25)
			LocalPlayer = Safe.get(Players, "LocalPlayer", nil)
		end
	end

	-- Esperar personaje (opcional, acotado)
	if LocalPlayer and Safe.get(LocalPlayer, "Character") == nil then
		local t0 = CLOCK()
		while Safe.get(LocalPlayer, "Character") == nil
			and (CLOCK() - t0) < 5 do
			WAIT(0.25)
		end
	end

	local ok, report = pcall(collectAll)
	if not ok then
		log("Fallo global:", report)
		return
	end

	pcall(function()
		ENV.__CIC_Report_v41 = report
		ENV.ClientInfo = {
			GetReport    = function() return report end,
			Recollect    = function(cat)
				if Collectors[cat] then
					return runCollector(cat, Collectors[cat])
				end
				return nil, "unknown collector"
			end,
			GetCollector = function(n) return Collectors[n] end,
			ClearCache   = function() CACHE = {} end,
			Version      = "v4.1-delta",
			Executor     = EXECUTOR_NAME,
			IsDelta      = IS_DELTA,
			Config       = CONFIG,
		}
	end)

	if CONFIG.PrintReport and not CONFIG.Silent then
		if CONFIG.PrintFormat == "json" then
			printJSON(report)
		elseif CONFIG.PrintFormat == "table" then
			printTable(report)
		end
	end
end

SPAWN(function()
	pcall(main)
end)
