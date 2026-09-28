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
]]

------------------------------------------------------------------
-- 1. CONFIG
------------------------------------------------------------------
local CONFIG = {
	PrintReport = true,          -- imprime un resumen al terminar
	Verbose = false,             -- true = muestra errores internos con warn()
	FpsSampleSeconds = 3,        -- ventana de muestreo de FPS
	WorkspaceScanLimit = 20000,  -- máximo de instancias a contar en Workspace
	ScanYieldEvery = 500,        -- cede el hilo cada N instancias
	CollectorTimeout = 8,        -- segundos máximos por collector
	FetchProductInfo = true,     -- consulta MarketplaceService (puede fallar/limitarse)
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
function Safe.call(fn: (...any) -> any, ...: any): (boolean, any)
	local ok, result = pcall(fn, ...)
	if not ok then
		log("pcall falló:", result)
	end
	return ok, result
end

-- Ejecuta y devuelve el valor o un valor por defecto.
function Safe.try(fn: (...any) -> any, default: any, ...: any): any
	local ok, result = Safe.call(fn, ...)
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

-- Convierte a string de manera segura (para enums, vectores, etc.).
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
		end, false),
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
			end, "N/A")
		end
	end

	return info
end

-- Jugador local
Collectors.Player = function()
	if not LocalPlayer then
		return { Available = false }
	end
	return {
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
	end
	if root then
		local pos = Safe.get(root, "Position")
		if pos then
			data.Position = string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
		end
	end
	data.AccessoryCount = #Safe.try(function()
		return char:GetChildren()
	end, {})
	return data
end

-- Dispositivo y entrada
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

	return {
		PlatformGuess = platform,
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
	}
end

-- Pantalla y cámara
Collectors.Display = function()
	local cam = Workspace and Safe.get(Workspace, "CurrentCamera")
	local vp = cam and Safe.get(cam, "ViewportSize")
	local topLeft, bottomRight = Vector2.zero, Vector2.zero
	if GuiService then
		topLeft = Safe.method(GuiService, "GetGuiInset", Vector2.zero) or Vector2.zero
	end
	return {
		ViewportSize = vp and string.format("%dx%d", vp.X, vp.Y) or "N/A",
		FieldOfView = cam and Safe.round(Safe.get(cam, "FieldOfView", 0), 1) or nil,
		CameraType = cam and Safe.str(Safe.get(cam, "CameraType")) or "N/A",
		CameraSubject = cam and Safe.str(Safe.get(cam, "CameraSubject")) or "N/A",
		GuiInsetTopLeft = Safe.str(topLeft),
		SafeAreaLike = Safe.str(bottomRight),
		MenuIsOpen = Safe.get(GuiService, "MenuIsOpen"),
	}
end

-- Rendimiento (muestreo breve de FPS)
Collectors.Performance = function()
	local frames, elapsed = 0, 0
	local minDt, maxDt = math.huge, 0
	local conn: RBXScriptConnection? = nil

	if RunService then
		local ok, c = pcall(function()
			return RunService.Heartbeat:Connect(function(dt)
				frames += 1
				elapsed += dt
				if dt < minDt then
					minDt = dt
				end
				if dt > maxDt then
					maxDt = dt
				end
			end)
		end)
		if ok then
			conn = c
		end
	end

	task.wait(CONFIG.FpsSampleSeconds)

	if conn then
		pcall(function()
			conn:Disconnect()
		end)
	end

	local avgFps = elapsed > 0 and frames / elapsed or 0
	return {
		SampleSeconds = CONFIG.FpsSampleSeconds,
		AvgFPS = Safe.round(avgFps, 1),
		MinFPS = maxDt > 0 and Safe.round(1 / maxDt, 1) or 0,
		MaxFPS = (minDt ~= math.huge and minDt > 0) and Safe.round(1 / minDt, 1) or 0,
		Frames = frames,
		PhysicsFPS = Safe.round(Safe.method(Workspace, "GetRealPhysicsFPS", 0), 1),
		QualityLevel = Safe.str(Safe.try(function()
			return UserSettings():GetService("UserGameSettings").SavedQualityLevel
		end, "?")),
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
	end
	data.PlayersInServer = Players and #Safe.try(function()
		return Players:GetPlayers()
	end, {}) or 0
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
		end, 0)
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

	-- Top 10 clases
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

	return {
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
end

-- Iluminación
Collectors.Lighting = function()
	if not Lighting then
		return { Available = false }
	end
	return {
		Technology = Safe.str(Safe.get(Lighting, "Technology")),
		ClockTime = Safe.round(Safe.get(Lighting, "ClockTime", 0), 2),
		Brightness = Safe.get(Lighting, "Brightness"),
		GlobalShadows = Safe.get(Lighting, "GlobalShadows"),
		FogEnd = Safe.get(Lighting, "FogEnd"),
		EnvironmentDiffuseScale = Safe.get(Lighting, "EnvironmentDiffuseScale"),
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
		AmbientReverb = Safe.str(Safe.get(SoundService, "AmbientReverb")),
		Teams = teamNames,
		LocalTimeUTC = os.date("!%Y-%m-%d %H:%M:%S"),
		ClientAgeSeconds = Safe.round(time(), 1),
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
	"WorkspaceCensus",
	"Performance", -- al final: bloquea unos segundos para muestrear
}

------------------------------------------------------------------
-- 4. RUNNER (aislamiento por collector, timeout y registro de fallos)
------------------------------------------------------------------
local function runCollector(name: string, fn: () -> any): (any, string?)
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

	local t0 = os.clock()
	while not finished do
		if os.clock() - t0 > CONFIG.CollectorTimeout then
			errMsg = "timeout"
			pcall(task.cancel, thread)
			break
		end
		task.wait(0.05)
	end

	return result, errMsg
end

local function collectAll()
	local report: { [string]: any } = {}
	local meta = { Errors = {}, Timings = {} }

	local startAll = os.clock()
	for _, name in ipairs(ORDER) do
		local fn = Collectors[name]
		if fn then
			local t0 = os.clock()
			local data, err = runCollector(name, fn)
			meta.Timings[name] = Safe.round((os.clock() - t0) * 1000, 1) -- ms
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
				table.insert(lines, indent .. "  - " .. Safe.str(item))
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
				table.insert(lines, string.format("%s  %s: %s", indent, Safe.str(k), Safe.str(v[k])))
			end
		end
		return table.concat(lines, "\n")
	end
	return Safe.str(v)
end

local function printReport(report: { [string]: any })
	local out = { "========== CLIENT INFO REPORT ==========" }
	for _, name in ipairs(ORDER) do
		local section = report[name]
		if section ~= nil then
			table.insert(out, string.format("\n[%s]", name))
			if type(section) == "table" then
				local keys = {}
				for k in pairs(section) do
					table.insert(keys, k)
				end
				table.sort(keys, function(a, b)
					return Safe.str(a) < Safe.str(b)
				end)
				for _, k in ipairs(keys) do
					local val = section[k]
					if type(val) == "table" then
						table.insert(out, string.format("  %s:", Safe.str(k)))
						table.insert(out, formatValue(val, "  "))
					else
						table.insert(out, string.format("  %s: %s", Safe.str(k), Safe.str(val)))
					end
				end
			end
		end
	end
	local meta = report._Meta
	table.insert(out, string.format("\n[Meta] Total: %s ms", Safe.str(meta.TotalMs)))
	for name, err in pairs(meta.Errors) do
		table.insert(out, string.format("  (omitido) %s -> %s", name, err))
	end
	table.insert(out, "========================================")
	print(table.concat(out, "\n"))
end

------------------------------------------------------------------
-- MAIN
------------------------------------------------------------------
task.spawn(function()
	-- Espera segura a que el juego cargue (sin bloquear indefinidamente)
	if not game:IsLoaded() then
		local t0 = os.clock()
		while not game:IsLoaded() and os.clock() - t0 < 30 do
			task.wait(0.25)
		end
	end

	-- Espera opcional al personaje (máx. 10 s, sin error si no aparece)
	if LocalPlayer and not Safe.get(LocalPlayer, "Character") then
		local t0 = os.clock()
		while not Safe.get(LocalPlayer, "Character") and os.clock() - t0 < 10 do
			task.wait(0.25)
		end
	end

	local ok, report = pcall(collectAll)
	if not ok then
		log("Fallo global:", report)
		return
	end

	-- Deja el resultado accesible para otros LocalScripts sin tocar nada del juego:
	-- se guarda en _G (tabla local del cliente).
	pcall(function()
		(_G :: any).ClientInfoReport = report
	end)

	if CONFIG.PrintReport then
		pcall(printReport, report)
	end
end)
