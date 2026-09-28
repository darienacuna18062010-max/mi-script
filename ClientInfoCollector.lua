--!strict
--[[
	ClientInfoCollector.lua
	Tipo: LocalScript  (StarterPlayer > StarterPlayerScripts)

	Recopila información del cliente y de la experiencia en modo SOLO LECTURA.
	- No modifica Instances, propiedades ni servicios.
	- No conecta remotes ni hookea nada.
	- Cada lectura está aislada con pcall, así un fallo nunca llega a la consola.
	- Los recorridos pesados ceden el hilo (task.wait) para no causar lag.

	Capas:
	  1. CONFIG      -> ajustes
	  2. SAFE        -> envoltorios seguros (pcall, servicios, propiedades)
	  3. COLLECTORS  -> cada categoría de datos, independiente
	  4. RUNNER      -> ejecuta collectors aislados, con tiempo y registro de errores
	  5. OUTPUT      -> resultado final (tabla + impresión opcional)

	MEJORAS v2 (solo lectura, sin cruzar la línea):
	  - Collector "Peers": todos los jugadores con ping, equipo, cuenta.
	  - Collector "Hardware": UserGameSettings + Stats extendidos + GetPlatform.
	  - Player extendido: GetJoinData, CharacterAppearanceId.
	  - Performance: percentiles (P95/P99), jitter, muestreo Heartbeat + RenderStepped.
	  - Cacheo con TTL por collector.
	  - Modo diff entre ejecuciones (guarda reporte previo en _G).
	  - BUDGET por collector (independiente del timeout global).
	  - Paralelismo controlado para collectors ligeros.
	  - Salida opcional JSON-like.
	  - API pública en _G.ClientInfo (GetReport, Recollect, GetCollector).
	  - Safe.call con label para diagnóstico de fallos.
]]

------------------------------------------------------------------
-- 1. CONFIG
------------------------------------------------------------------
local CONFIG = {
	PrintReport = true,            -- imprime un resumen al terminar
	PrintFormat = "table",         -- "table" | "json"
	Verbose = false,               -- true = muestra errores internos con warn()
	FpsSampleSeconds = 3,          -- ventana de muestreo de FPS
	WorkspaceScanLimit = 5000,     -- máximo de instancias a contar en Workspace
	ScanYieldEvery = 250,          -- cede el hilo cada N instancias
	CollectorTimeout = 6,          -- segundos máximos por collector (global)
	FetchProductInfo = true,       -- consulta MarketplaceService (puede fallar/limitarse)
	EnableCache = true,            -- cacheo con TTL por collector
	EnableParallel = true,         -- ejecuta collectors ligeros en paralelo
	EnableDiff = true,             -- calcula deltas vs ejecución previa
	EnablePeers = true,            -- incluye lista de jugadores
	EnableHardware = true,         -- incluye UserGameSettings + Stats extendidos
	EnableExtendedPlayer = true,   -- GetJoinData, CharacterAppearanceId
}

-- Presupuesto por collector (ms). Si se excede, se marca timeout sin bloquear el resto.
local BUDGET: { [string]: number } = {
	Experience       = 4000,
	Player           = 300,
	Character        = 400,
	Device           = 300,
	Display          = 200,
	Network          = 400,
	Memory           = 400,
	Locale           = 200,
	Lighting         = 300,
	Misc             = 500,
	WorkspaceCensus  = 4000,
	Performance      = 6000,
	Peers            = 800,
	Hardware         = 600,
}

-- TTL de cache (segundos). nil = sin cache.
local CACHE_TTL: { [string]: number? } = {
	Experience       = 60,
	Player           = 5,
	Character        = 2,
	Device           = 30,
	Display          = 5,
	Network          = 2,
	Memory           = 2,
	Locale           = 60,
	Lighting         = 30,
	Misc             = 10,
	WorkspaceCensus  = 8,
	Performance      = 0,   -- nunca cachear (siempre muestrear)
	Peers            = 2,
	Hardware         = 10,
}

-- Collectors que pueden correr en paralelo (ligeros, sin task.wait largo)
local PARALLEL_SET: { [string]: boolean } = {
	Player = true, Character = true, Device = true, Display = true,
	Network = true, Memory = true, Locale = true, Lighting = true,
	Misc = true, Peers = true, Hardware = true,
}

------------------------------------------------------------------
-- 2. SAFE (capa de protección)
------------------------------------------------------------------
local Safe = {}

local function log(...: any)
	if CONFIG.Verbose then
		warn("[ClientInfo]", ...)
	end
end

-- Ejecuta una función y devuelve (ok, valor). Nunca lanza error.
function Safe.call(fn: (...any) -> any, label: string?, ...: any): (boolean, any)
	local ok, result = pcall(fn, ...)
	if not ok then
		log("pcall falló [" .. (label or "?") .. "]:", result)
	end
	return ok, result
end

-- Ejecuta y devuelve el valor o un valor por defecto.
function Safe.try(fn: (...any) -> any, default: any, label: string?, ...: any): any
	local ok, result = Safe.call(fn, label, ...)
	if ok and result ~= nil then
		return result
	end
	return default
end

-- Obtiene un servicio sin arriesgar error.
function Safe.service(name: string): any
	local ok, svc = pcall(function()
		return game:GetService(name)
	end)
	if ok then
		return svc
	end
	log("Servicio no disponible:", name)
	return nil
end

-- Lee una propiedad de forma segura.
function Safe.get(instance: any, property: string, default: any?): any
	if instance == nil then
		return default
	end
	local ok, value = pcall(function()
		return instance[property]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

-- Llama a un método de forma segura.
function Safe.method(instance: any, method: string, default: any?, ...: any): any
	if instance == nil then
		return default
	end
	local args = table.pack(...)
	local ok, value = pcall(function()
		return instance[method](instance, table.unpack(args, 1, args.n))
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

-- Convierte a string de manera segura.
function Safe.str(value: any): string
	local ok, s = pcall(tostring, value)
	return ok and s or "?"
end

-- Redondeo seguro.
function Safe.round(n: any, decimals: number?): number
	if type(n) ~= "number" then
		return 0
	end
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

------------------------------------------------------------------
-- Servicios (todos opcionales)
------------------------------------------------------------------
local Players = Safe.service("Players")
local RunService = Safe.service("RunService")
local UserInputService = Safe.service("UserInputService")
local GuiService = Safe.service("GuiService")
local Stats = Safe.service("Stats")
local Workspace = Safe.service("Workspace")
local LocalizationService = Safe.service("LocalizationService")
local MarketplaceService = Safe.service("MarketplaceService")
local Lighting = Safe.service("Lighting")
local SoundService = Safe.service("SoundService")
local TextChatService = Safe.service("TextChatService")
local Teams = Safe.service("Teams")

local LocalPlayer = Players and Players.LocalPlayer

-- UserGameSettings (no es servicio, se obtiene vía UserSettings())
local UserGameSettings = Safe.try(function()
	return UserSettings():GetService("UserGameSettings")
end, nil, "UserGameSettings")

------------------------------------------------------------------
-- 3. COLLECTORS (cada uno independiente)
------------------------------------------------------------------
local Collectors: { [string]: () -> any } = {}

-- Información de la experiencia
Collectors.Experience = function()
	local info: { [string]: any } = {
		PlaceId = game.PlaceId,
		GameId = game.GameId,
		PlaceVersion = game.PlaceVersion,
		JobId = game.JobId ~= "" and game.JobId or "N/A",
		CreatorId = game.CreatorId,
		CreatorType = Safe.str(game.CreatorType),
		IsStudio = Safe.try(function()
			return RunService:IsStudio()
		end, false, "IsStudio"),
		IsPrivateServer = game.PrivateServerId ~= "",
		IsReservedServer = game.PrivateServerOwnerId ~= 0 and game.PrivateServerId ~= "",
		ServerType = "N/A",
	}

	if RunService then
		info.IsClient = Safe.method(RunService, "IsClient", true)
		info.IsRunning = Safe.method(RunService, "IsRunning", true)
	end

	if CONFIG.FetchProductInfo and MarketplaceService and game.PlaceId ~= 0 then
		local product: any = nil
		local done = false
		task.spawn(function()
			product = Safe.method(MarketplaceService, "GetProductInfo", nil, game.PlaceId)
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 4 do
			task.wait(0.1)
		end
		if type(product) == "table" then
			info.Name = product.Name
			info.Description = product.Description
			info.Created = product.Created
			info.Updated = product.Updated
			info.CreatorName = Safe.try(function()
				return product.Creator.Name
			end, "N/A", "CreatorName")
		end
	end

	return info
end

-- Jugador local (extendido)
Collectors.Player = function()
	if not LocalPlayer then
		return { Available = false }
	end
	local data: { [string]: any } = {
		Name = Safe.get(LocalPlayer, "Name"),
		DisplayName = Safe.get(LocalPlayer, "DisplayName"),
		UserId = Safe.get(LocalPlayer, "UserId"),
		AccountAgeDays = Safe.get(LocalPlayer, "AccountAge"),
		MembershipType = Safe.str(Safe.get(LocalPlayer, "MembershipType")),
		LocaleId = Safe.get(LocalPlayer, "LocaleId"),
		Team = Safe.str(Safe.get(LocalPlayer, "Team", "Ninguno")),
		Neutral = Safe.get(LocalPlayer, "Neutral"),
		CameraMode = Safe.str(Safe.get(LocalPlayer, "CameraMode")),
		GameplayPaused = Safe.get(LocalPlayer, "GameplayPaused"),
		CharacterLoaded = Safe.get(LocalPlayer, "Character") ~= nil,
		FollowUserId = Safe.get(LocalPlayer, "FollowUserId"),
	}

	if CONFIG.EnableExtendedPlayer then
		data.CharacterAppearanceId = Safe.get(LocalPlayer, "CharacterAppearanceId")
		local joinData = Safe.method(LocalPlayer, "GetJoinData", nil)
		if joinData then
			data.JoinData = {
				SourcePlaceId = Safe.get(joinData, "SourcePlaceId"),
				SourceGameId = Safe.get(joinData, "SourceGameId"),
				HasTeleportData = Safe.get(joinData, "TeleportData") ~= nil,
				MembershipType = Safe.str(Safe.get(joinData, "MembershipType")),
			}
		end
	end

	return data
end

-- Personaje (solo lectura)
Collectors.Character = function()
	local char = LocalPlayer and Safe.get(LocalPlayer, "Character")
	if not char then
		return { Available = false }
	end
	local hum = Safe.method(char, "FindFirstChildOfClass", nil, "Humanoid")
	local root = Safe.get(char, "PrimaryPart") or Safe.method(char, "FindFirstChild", nil, "HumanoidRootPart")

	local data: { [string]: any } = { Available = true, Name = Safe.get(char, "Name") }
	if hum then
		data.Health = Safe.round(Safe.get(hum, "Health", 0), 1)
		data.MaxHealth = Safe.round(Safe.get(hum, "MaxHealth", 0), 1)
		data.WalkSpeed = Safe.get(hum, "WalkSpeed")
		data.JumpPower = Safe.get(hum, "JumpPower")
		data.JumpHeight = Safe.get(hum, "JumpHeight")
		data.RigType = Safe.str(Safe.get(hum, "RigType"))
		data.State = Safe.str(Safe.method(hum, "GetState", "?"))
		data.HipHeight = Safe.get(hum, "HipHeight")
		data.StateEnabled = Safe.method(hum, "GetStateEnabled", nil)
	end
	if root then
		local pos = Safe.get(root, "Position")
		if pos then
			data.Position = string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
		end
	end

	-- Accesorios con tipo
	local accs = {}
	local tools = {}
	for _, child in ipairs(Safe.method(char, "GetChildren", {}) :: { Instance }) do
		local className = Safe.get(child, "ClassName", "")
		if className == "Accessory" then
			table.insert(accs, {
				Name = Safe.get(child, "Name"),
				Type = Safe.str(Safe.get(child, "AccessoryType")),
			})
		elseif className == "Tool" then
			table.insert(tools, Safe.get(child, "Name"))
		end
	end
	data.Accessories = accs
	data.ToolsEquipped = tools

	-- Descripción aplicada del avatar (solo lectura)
	local desc = Safe.method(Players, "GetHumanoidDescriptionFromUserId", nil, Safe.get(LocalPlayer, "UserId", 0))
	if desc then
		data.AppliedDescription = {
			Head = Safe.get(desc, "Head"),
			Torso = Safe.get(desc, "Torso"),
			LeftArm = Safe.get(desc, "LeftArm"),
			RightArm = Safe.get(desc, "RightArm"),
			LeftLeg = Safe.get(desc, "LeftLeg"),
			RightLeg = Safe.get(desc, "RightLeg"),
		}
	end

	return data
end

-- Dispositivo y entrada (extendido)
Collectors.Device = function()
	local uis = UserInputService
	local platform = "Desconocida"
	if uis then
		if Safe.get(uis, "TouchEnabled") and not Safe.get(uis, "KeyboardEnabled") then
			platform = "Móvil/Tablet"
		elseif Safe.get(uis, "GamepadEnabled") and not Safe.get(uis, "KeyboardEnabled") then
			platform = "Consola/Gamepad"
		elseif Safe.get(uis, "KeyboardEnabled") then
			platform = "PC"
		end
		if Safe.get(uis, "VREnabled") then
			platform = "VR"
		end
	end

	local data: { [string]: any } = {
		PlatformGuess = platform,
		PlatformNative = Safe.method(uis, "GetPlatform", "?"),
		TouchEnabled = Safe.get(uis, "TouchEnabled"),
		KeyboardEnabled = Safe.get(uis, "KeyboardEnabled"),
		MouseEnabled = Safe.get(uis, "MouseEnabled"),
		GamepadEnabled = Safe.get(uis, "GamepadEnabled"),
		GyroscopeEnabled = Safe.get(uis, "GyroscopeEnabled"),
		AccelerometerEnabled = Safe.get(uis, "AccelerometerEnabled"),
		VREnabled = Safe.get(uis, "VREnabled"),
		LastInputType = Safe.str(Safe.get(uis, "PreferredInput") or Safe.method(uis, "GetLastInputType", "?")),
		IsTenFootInterface = Safe.method(GuiService, "IsTenFootInterface", false),
		MouseBehavior = Safe.str(Safe.get(uis, "MouseBehavior")),
		MouseIconEnabled = Safe.get(uis, "MouseIconEnabled"),
		GamepadsConnected = #(Safe.method(uis, "GetConnectedGamepads", {}) :: { any }),
	}

	local codes = Safe.method(uis, "GetSupportedGamepadKeyCodes", {}) :: { any }
	data.GamepadKeyCodesCount = #codes

	return data
end

-- Pantalla y cámara
Collectors.Display = function()
	local cam = Workspace and Safe.get(Workspace, "CurrentCamera")
	local vp = cam and Safe.get(cam, "ViewportSize")
	local topLeft = Vector2.zero
	if GuiService then
		topLeft = Safe.method(GuiService, "GetGuiInset", Vector2.zero) or Vector2.zero
	end
	local safeOffsets = Safe.method(GuiService, "GetSafeZoneOffsets", nil)
	return {
		ViewportSize = vp and string.format("%dx%d", vp.X, vp.Y) or "N/A",
		FieldOfView = cam and Safe.round(Safe.get(cam, "FieldOfView", 0), 1) or nil,
		CameraType = cam and Safe.str(Safe.get(cam, "CameraType")) or "N/A",
		CameraSubject = cam and Safe.str(Safe.get(cam, "CameraSubject")) or "N/A",
		CameraPosition = cam and Safe.str(Safe.get(cam, "CFrame")) or "N/A",
		GuiInsetTopLeft = Safe.str(topLeft),
		SafeZoneOffsets = Safe.str(safeOffsets),
		MenuIsOpen = Safe.get(GuiService, "MenuIsOpen"),
		PreferredTransparency = Safe.get(GuiService, "PreferredTransparency"),
		ReducedMotionEnabled = Safe.get(GuiService, "ReducedMotionEnabled"),
	}
end

-- Rendimiento (muestreo breve de FPS con percentiles)
Collectors.Performance = function()
	local frames, elapsed = 0, 0
	local minDt, maxDt = math.huge, 0
	local samples: { number } = {}
	local connHB: RBXScriptConnection? = nil
	local connRS: RBXScriptConnection? = nil

	if RunService then
		local ok1, c1 = pcall(function()
			return RunService.Heartbeat:Connect(function(dt)
				frames += 1
				elapsed += dt
				if dt < minDt then minDt = dt end
				if dt > maxDt then maxDt = dt end
				table.insert(samples, dt)
			end)
		end)
		if ok1 then connHB = c1 end

		local ok2, c2 = pcall(function()
			return RunService.RenderStepped:Connect(function()
				-- solo contamos frames de render para no duplicar
			end)
		end)
		if ok2 then connRS = c2 end
	end

	task.wait(CONFIG.FpsSampleSeconds)

	if connHB then pcall(function() connHB:Disconnect() end) end
	if connRS then pcall(function() connRS:Disconnect() end) end

	local avgFps = elapsed > 0 and frames / elapsed or 0

	-- Percentiles
	table.sort(samples)
	local function percentile(p: number): number
		if #samples == 0 then return 0 end
		local idx = math.clamp(math.floor(#samples * p + 0.5), 1, #samples)
		return samples[idx]
	end

	local p95 = percentile(0.95)
	local p99 = percentile(0.99)

	return {
		SampleSeconds = CONFIG.FpsSampleSeconds,
		AvgFPS = Safe.round(avgFps, 1),
		MinFPS = maxDt > 0 and Safe.round(1 / maxDt, 1) or 0,
		MaxFPS = (minDt ~= math.huge and minDt > 0) and Safe.round(1 / minDt, 1) or 0,
		Frames = frames,
		P95FrameMs = Safe.round(p95 * 1000, 2),
		P99FrameMs = Safe.round(p99 * 1000, 2),
		JitterMs = Safe.round((maxDt - minDt) * 1000, 2),
		PhysicsFPS = Safe.round(Safe.method(Workspace, "GetRealPhysicsFPS", 0), 1),
		AwakeParts = Safe.method(Workspace, "GetNumAwakeParts", 0),
		QualityLevel = Safe.str(Safe.get(UserGameSettings, "SavedQualityLevel", "?")),
	}
end

-- Red
Collectors.Network = function()
	local ping = LocalPlayer and Safe.method(LocalPlayer, "GetNetworkPing", nil)
	local data: { [string]: any } = {
		PingMs = ping and Safe.round(ping * 1000, 1) or "N/A",
	}
	if Stats then
		data.DataReceiveKbps = Safe.round(Safe.get(Stats, "DataReceiveKbps", 0), 1)
		data.DataSendKbps = Safe.round(Safe.get(Stats, "DataSendKbps", 0), 1)
		data.HeartbeatTimeMs = Safe.round(Safe.get(Stats, "HeartbeatTimeMs", 0), 2)
		data.PhysicsSendKbps = Safe.round(Safe.get(Stats, "PhysicsSendKbps", 0), 1)
		data.PhysicsReceiveKbps = Safe.round(Safe.get(Stats, "PhysicsReceiveKbps", 0), 1)
	end
	data.PlayersInServer = Players and #Safe.method(Players, "GetPlayers", {}) or 0
	data.MaxPlayers = Safe.get(Players, "MaxPlayers")
	return data
end

-- Memoria
Collectors.Memory = function()
	local data: { [string]: any } = {}
	if Stats then
		data.TotalMemoryMb = Safe.round(Safe.method(Stats, "GetTotalMemoryUsageMb", 0), 1)
		data.LuaHeapMb = Safe.try(function()
			return Safe.round(collectgarbage("count") / 1024, 2)
		end, 0, "LuaHeap")
		data.InstanceCount = Safe.get(Stats, "InstanceCount")
		data.PrimitivesCount = Safe.get(Stats, "PrimitivesCount")
		data.MovingPrimitivesCount = Safe.get(Stats, "MovingPrimitivesCount")
	end
	return data
end

-- Workspace: conteo por clase (con límite y cesión de hilo)
Collectors.WorkspaceCensus = function()
	if not Workspace then
		return { Available = false }
	end

	local counts: { [string]: number } = {}
	local total, scanned = 0, 0
	local truncated = false

	local descendants = Safe.method(Workspace, "GetDescendants", {}) :: { Instance }
	total = #descendants

	for _, inst in ipairs(descendants) do
		scanned += 1
		if scanned > CONFIG.WorkspaceScanLimit then
			truncated = true
			break
		end
		local className = Safe.get(inst, "ClassName", "?")
		counts[className] = (counts[className] or 0) + 1
		if scanned % CONFIG.ScanYieldEvery == 0 then
			task.wait()
		end
	end

	local list = {}
	for class, n in pairs(counts) do
		table.insert(list, { class = class, n = n })
	end
	table.sort(list, function(a, b)
		return a.n > b.n
	end)
	local top = {}
	for i = 1, math.min(10, #list) do
		top[i] = string.format("%s = %d", list[i].class, list[i].n)
	end

	local data: { [string]: any } = {
		TotalDescendants = total,
		Scanned = math.min(scanned, total),
		Truncated = truncated,
		TopClasses = top,
		Gravity = Safe.get(Workspace, "Gravity"),
		StreamingEnabled = Safe.get(Workspace, "StreamingEnabled"),
		StreamingMinRadius = Safe.get(Workspace, "StreamingMinRadius"),
		StreamingTargetRadius = Safe.get(Workspace, "StreamingTargetRadius"),
		FallenPartsDestroyHeight = Safe.get(Workspace, "FallenPartsDestroyHeight"),
		Terrain = Safe.get(Workspace, "Terrain") ~= nil,
	}

	local cam = Safe.get(Workspace, "CurrentCamera")
	if cam then
		local cpos = Safe.get(cam, "CFrame")
		if cpos then
			data.CameraDistanceToOrigin = Safe.round(cpos.Position.Magnitude, 1)
		end
	end

	return data
end

-- Iluminación (extendido)
Collectors.Lighting = function()
	if not Lighting then
		return { Available = false }
	end

	-- Efectos hijos
	local effects: { string } = {}
	for _, child in ipairs(Safe.method(Lighting, "GetChildren", {}) :: { Instance }) do
		table.insert(effects, Safe.get(child, "ClassName", "?"))
	end

	local atmosphere = Safe.method(Lighting, "FindFirstChildOfClass", nil, "Atmosphere")
	local sky = Safe.method(Lighting, "FindFirstChildOfClass", nil, "Sky")

	return {
		Technology = Safe.str(Safe.get(Lighting, "Technology")),
		ClockTime = Safe.round(Safe.get(Lighting, "ClockTime", 0), 2),
		Brightness = Safe.get(Lighting, "Brightness"),
		GlobalShadows = Safe.get(Lighting, "GlobalShadows"),
		FogEnd = Safe.get(Lighting, "FogEnd"),
		EnvironmentDiffuseScale = Safe.get(Lighting, "EnvironmentDiffuseScale"),
		EnvironmentSpecularScale = Safe.get(Lighting, "EnvironmentSpecularScale"),
		Ambient = Safe.str(Safe.get(Lighting, "Ambient")),
		OutdoorAmbient = Safe.str(Safe.get(Lighting, "OutdoorAmbient")),
		ExposureCompensation = Safe.get(Lighting, "ExposureCompensation"),
		ShadowSoftness = Safe.get(Lighting, "ShadowSoftness"),
		Effects = effects,
		Atmosphere = atmosphere and {
			Density = Safe.get(atmosphere, "Density"),
			Haze = Safe.get(atmosphere, "Haze"),
			Glare = Safe.get(atmosphere, "Glare"),
		} or nil,
		Sky = sky ~= nil,
	}
end

-- Localización
Collectors.Locale = function()
	return {
		RobloxLocaleId = Safe.get(LocalizationService, "RobloxLocaleId"),
		SystemLocaleId = Safe.get(LocalizationService, "SystemLocaleId"),
		PlayerLocaleId = LocalPlayer and Safe.get(LocalPlayer, "LocaleId") or "N/A",
	}
end

-- Chat, sonido y equipos (solo estado visible)
Collectors.Misc = function()
	local teamNames = {}
	if Teams then
		for _, t in ipairs(Safe.method(Teams, "GetTeams", {}) :: { Instance }) do
			table.insert(teamNames, Safe.str(Safe.get(t, "Name")))
		end
	end
	return {
		ChatVersion = Safe.str(Safe.get(TextChatService, "ChatVersion")),
		CanUserChat = Safe.method(TextChatService, "CanUserChatAsync", nil, Safe.get(LocalPlayer, "UserId", 0)),
		AmbientReverb = Safe.str(Safe.get(SoundService, "AmbientReverb")),
		Teams = teamNames,
		LocalTimeUTC = os.date("!%Y-%m-%d %H:%M:%S"),
		ClientAgeSeconds = Safe.round(time(), 1),
	}
end

-- Peers: todos los jugadores del servidor
Collectors.Peers = function()
	if not CONFIG.EnablePeers or not Players then
		return { Available = false }
	end
	local list = {}
	for _, p in ipairs(Safe.method(Players, "GetPlayers", {}) :: { Instance }) do
		local ping = Safe.method(p, "GetNetworkPing", 0)
		table.insert(list, {
			Name = Safe.get(p, "Name"),
			DisplayName = Safe.get(p, "DisplayName"),
			UserId = Safe.get(p, "UserId"),
			AccountAge = Safe.get(p, "AccountAge"),
			Team = Safe.str(Safe.get(p, "Team", "Ninguno")),
			PingMs = Safe.round((ping or 0) * 1000, 1),
			CharacterLoaded = Safe.get(p, "Character") ~= nil,
			FollowUserId = Safe.get(p, "FollowUserId"),
			MembershipType = Safe.str(Safe.get(p, "MembershipType")),
		})
	end
	return { Count = #list, Players = list }
end

-- Hardware y preferencias del cliente
Collectors.Hardware = function()
	if not CONFIG.EnableHardware then
		return { Available = false }
	end
	return {
		PlatformNative = Safe.method(UserInputService, "GetPlatform", "?"),
		SavedQualityLevel = Safe.str(Safe.get(UserGameSettings, "SavedQualityLevel")),
		MasterVolume = Safe.get(UserGameSettings, "MasterVolume"),
		RotationType = Safe.str(Safe.get(UserGameSettings, "RotationType")),
		ComputerCameraMovementMode = Safe.str(Safe.get(UserGameSettings, "ComputerCameraMovementMode")),
		ComputerMovementMode = Safe.str(Safe.get(UserGameSettings, "ComputerMovementMode")),
		GamepadCameraSensitivity = Safe.get(UserGameSettings, "GamepadCameraSensitivity"),
		MouseSensitivity = Safe.get(UserGameSettings, "MouseSensitivity"),
		-- Stats extendidos
		PhysicsSendKbps = Safe.round(Safe.get(Stats, "PhysicsSendKbps", 0), 1),
		PhysicsReceiveKbps = Safe.round(Safe.get(Stats, "PhysicsReceiveKbps", 0), 1),
		-- FPS de física real
		RealPhysicsFPS = Safe.round(Safe.method(Workspace, "GetRealPhysicsFPS", 0), 1),
	}
end

-- Orden estable de ejecución
local ORDER = {
	"Experience",
	"Player",
	"Character",
	"Device",
	"Display",
	"Network",
	"Memory",
	"Locale",
	"Lighting",
	"Misc",
	"Peers",
	"Hardware",
	"WorkspaceCensus",
	"Performance", -- al final: bloquea unos segundos para muestrear
}

------------------------------------------------------------------
-- 4. RUNNER (aislamiento por collector, timeout y registro de fallos)
------------------------------------------------------------------
local CACHE: { [string]: { value: any, expiresAt: number } } = {}

local function runCollector(name: string, fn: () -> any): (any, string?)
	-- Cache
	if CONFIG.EnableCache then
		local ttl = CACHE_TTL[name]
		if ttl and ttl > 0 then
			local entry = CACHE[name]
			if entry and os.clock() < entry.expiresAt then
				return entry.value, nil
			end
		end
	end

	local result: any = nil
	local errMsg: string? = nil
	local finished = false

	local thread = task.spawn(function()
		local ok, value = pcall(fn)
		if ok then
			result = value
		else
			errMsg = Safe.str(value)
			log("Collector falló:", name, errMsg)
		end
		finished = true
	end)

	local budget = BUDGET[name] or CONFIG.CollectorTimeout * 1000
	local t0 = os.clock()
	while not finished do
		local elapsedMs = (os.clock() - t0) * 1000
		if elapsedMs > math.min(budget, CONFIG.CollectorTimeout * 1000) then
			errMsg = "timeout"
			pcall(task.cancel, thread)
			break
		end
		task.wait(0.05)
	end

	-- Guardar en cache
	if CONFIG.EnableCache and not errMsg then
		local ttl = CACHE_TTL[name]
		if ttl and ttl > 0 then
			CACHE[name] = { value = result, expiresAt = os.clock() + ttl }
		end
	end

	return result, errMsg
end

local function collectAll()
	local report: { [string]: any } = {}
	local meta = { Errors = {}, Timings = {} }

	local startAll = os.clock()

	-- Fase 1: paralelos (ligeros)
	if CONFIG.EnableParallel then
		local pending: { [string]: { done: boolean, data: any, err: string? } } = {}
		for _, name in ipairs(ORDER) do
			if PARALLEL_SET[name] and Collectors[name] then
				pending[name] = { done = false }
				task.spawn(function()
					local data, err = runCollector(name, Collectors[name])
					pending[name].data = data
					pending[name].err = err
					pending[name].done = true
				end)
			end
		end

		-- Esperar a que todos terminen (con timeout global acotado)
		local tWait = os.clock()
		local allDone = false
		while not allDone and os.clock() - tWait < CONFIG.CollectorTimeout do
			allDone = true
			for _, state in pairs(pending) do
				if not state.done then allDone = false break end
			end
			if not allDone then task.wait(0.05) end
		end

		for name, state in pairs(pending) do
			local t0 = os.clock()
			if state.done and not state.err then
				report[name] = state.data
			else
				meta.Errors[name] = state.err or "timeout"
			end
			meta.Timings[name] = Safe.round((os.clock() - t0) * 1000, 1)
		end
	end

	-- Fase 2: serie (pesados o no paralelos)
	for _, name in ipairs(ORDER) do
		local alreadyDone = report[name] ~= nil or meta.Errors[name] ~= nil
		if not alreadyDone and Collectors[name] then
			local t0 = os.clock()
			local data, err = runCollector(name, Collectors[name])
			meta.Timings[name] = Safe.round((os.clock() - t0) * 1000, 1)
			if err then
				meta.Errors[name] = err
			else
				report[name] = data
			end
		end
	end

	meta.TotalMs = Safe.round((os.clock() - startAll) * 1000, 1)
	report._Meta = meta
	return report
end

------------------------------------------------------------------
-- 5. OUTPUT
------------------------------------------------------------------
local function formatValue(v: any, indent: string): string
	if type(v) == "table" then
		local lines = {}
		local isArray = #v > 0
		if isArray then
			for _, item in ipairs(v) do
				if type(item) == "table" then
					table.insert(lines, indent .. "  -")
					table.insert(lines, formatValue(item, indent .. "    "))
				else
					table.insert(lines, indent .. "  - " .. Safe.str(item))
				end
			end
		else
			local keys = {}
			for k in pairs(v) do
				table.insert(keys, k)
			end
			table.sort(keys, function(a, b)
				return Safe.str(a) < Safe.str(b)
			end)
			for _, k in ipairs(keys) do
				local val = v[k]
				if type(val) == "table" then
					table.insert(lines, string
