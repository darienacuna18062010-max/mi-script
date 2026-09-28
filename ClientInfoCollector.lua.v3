--[[ ClientInfoCollector.lua · DEEP SCAN v7.2 (STANDALONE FIXED)
Target: Roblox GAME CLIENT
Modo: SOLO LECTURA. 100+ módulos de auditoría forense.
Fix: Solucionado error "HttpGet: attempt to call a nil value"
Standalone: No requiere cargador externo.
]]

--================================================================
-- [0] BOOTSTRAP Y UTILIDADES
--================================================================
local ENV = _G
do
    local ok, e = pcall(function() if type(getgenv) == "function" then return getgenv() end end)
    if ok and type(e) == "table" then ENV = e end
end

local EXECUTOR_NAME, EXECUTOR_VERSION = "Unknown", "Unknown"
do
    local ok, n, v = pcall(function()
        if type(identifyexecutor) == "function" then return identifyexecutor() end
        if type(getexecutorname) == "function" then return getexecutorname() end
    end)
    if ok then
        EXECUTOR_NAME = type(n) == "string" and n or EXECUTOR_NAME
        EXECUTOR_VERSION = type(v) == "string" and v or EXECUTOR_VERSION
    end
end

local IS_DELTA = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("delta") ~= nil)
local IS_SYNAPSE = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("synapse") ~= nil)
local IS_KRNL = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("krnl") ~= nil)
local IS_FLUXUS = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("fluxus") ~= nil)
local IS_SOLARA = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("solara") ~= nil)
local IS_WAVE = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("wave") ~= nil)
local IS_SCRIPTWARE = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("scriptware") ~= nil)
local IS_ELECTRON = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("electron") ~= nil)
local IS_HYDROGEN = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("hydrogen") ~= nil)
local IS_AWP = (type(EXECUTOR_NAME) == "string" and EXECUTOR_NAME:lower():find("awp") ~= nil)

do
    if type(table) ~= "table" then table = {} end
    if type(table.pack) ~= "function" then table.pack = function(...) return { n = select("#", ...), ... } end end
    if type(table.unpack) ~= "function" then
        local u = (rawget and rawget(_G, "unpack")) or unpack
        if type(u) == "function" then table.unpack = u end
    end
    if type(math) ~= "table" then math = {} end
    if type(math.clamp) ~= "function" then
        math.clamp = function(v, mn, mx) if v < mn then return mn end if v > mx then return mx end return v end
    end
end

local CLOCK = (function()
    if type(os) == "table" and type(os.clock) == "function" then
        local ok, v = pcall(os.clock); if ok and type(v) == "number" then return os.clock end
    end
    if type(tick) == "function" then return tick end
    if type(time) == "function" then return time end
    return function() return 0 end
end)()

local function safeGetService(name)
    local ok, service = pcall(function() return game:GetService(name) end)
    return ok and service or nil
end

local function safeCall(obj, method, ...)
    if not obj then return nil end
    local ok, result = pcall(function() return obj[method](obj, ...) end)
    return ok and result or nil
end

local function safeProp(obj, prop)
    if not obj then return nil end
    local ok, val = pcall(function() return obj[prop] end)
    if ok then
        if type(val) == "EnumItem" then return val.Name end
        if type(val) == "Instance" then return val.Name or val.ClassName end
        return val
    end
    return nil
end

local function safeCount(instance)
    if not instance then return 0 end
    local ok, n = pcall(function() local c = 0; for _ in pairs(instance:GetChildren()) do c = c + 1 end; return c end)
    return ok and n or 0
end

local function safeClass(instance)
    if not instance then return nil end
    local ok, c = pcall(function() return instance.ClassName end)
    return ok and c or nil
end

--================================================================
-- [1] MÓDULOS DE AUDITORÍA (1-100)
--================================================================

-- [1] Información del Ejecutor
local function collectExecutorInfo()
    local info = { name = EXECUTOR_NAME, version = EXECUTOR_VERSION,
        flags = { isDelta = IS_DELTA, isSynapse = IS_SYNAPSE, isKrnl = IS_KRNL,
            isFluxus = IS_FLUXUS, isSolara = IS_SOLARA, isWave = IS_WAVE,
            isScriptWare = IS_SCRIPTWARE, isElectron = IS_ELECTRON,
            isHydrogen = IS_HYDROGEN, isAwp = IS_AWP },
        globals = {}, functions = {}, envTables = {} }
    local envTables = { _G = _G, shared = shared }
    if type(getgenv) == "function" then local ok, g = pcall(getgenv); if ok then envTables.getgenv = g end end
    for name, tbl in pairs(envTables) do
        if type(tbl) == "table" then
            local funcCount, keyCount = 0, 0
            for k, v in pairs(tbl) do
                keyCount = keyCount + 1
                if type(v) == "function" then funcCount = funcCount + 1 end
                if type(k) == "string" and (k:lower():find("exec") or k:lower():find("syn") or k:lower():find("delta") or k:lower():find("krnl") or k:lower():find("fluxus")) then
                    info.globals[k] = tostring(v):sub(1, 120)
                end
            end
            info.envTables[name] = { totalKeys = keyCount, functions = funcCount }
        end
    end
    local executorFunctions = {
        "identifyexecutor","getexecutorname","getgenv","getrenv","getreg","getgc","getinstances",
        "getnilinstances","getloadedmodules","getscripts","getrunningscripts","getscriptbytecode",
        "getscripthash","getscriptclosure","getsenv","getmenv","gettenv","getthreadidentity",
        "setthreadidentity","getconnections","firetouchinterest","fireclickdetector",
        "fireproximityprompt","sethiddenproperty","gethiddenproperty","setsimulationradius",
        "getsimulationradius","getrawmetatable","setrawmetatable","hookmetamethod","hookfunction",
        "replaceclosure","restorefunction","clonefunction","getfunctionhash","getcallbackvalue",
        "setcallbackvalue","getscriptable","setscriptable","isreadonly","setreadonly",
        "makereadonly","makewritable","getnamecallmethod","setnamecallmethod","getcallingscript",
        "checkcaller","newcclosure","islclosure","iscclosure","is_sirhurt_closure",
        "is_synapse_function","is_protosmasher_closure","is_krnl_closure","is_fluxus_closure",
        "is_delta_closure","is_arcturus_closure","is_vega_closure","is_oxygen_closure",
        "is_elysian_closure","is_evon_closure","is_swift_closure","is_scriptware_closure",
        "is_wearedevs_closure","is_sentinel_closure","is_valyse_closure","is_nihon_closure",
        "is_proto_closure","gethui","protectgui","getupvalue","setupvalue","getconstants",
        "getinfo","getregistry","compareinstances","cloneref","getspecialinfo","getcustomasset",
        "writefile","readfile","appendfile","delfile","makefolder","delfolder","listfiles",
        "isfile","isfolder","setfpscap","getfpscap","queue_on_teleport","setclipboard",
        "getclipboard","loadstring","getscriptfunction","isvalidlevel","getlevel","setlevel",
    }
    for _, funcName in ipairs(executorFunctions) do
        local fn = ENV[funcName] or _G[funcName]
        if type(fn) == "function" then info.functions[funcName] = "Present" end
    end
    return info
end

-- [2] Métricas de Rendimiento
local function collectStatsInfo()
    local Stats = safeGetService("Stats")
    if not Stats then return { available = false } end
    local info = { available = true }
    for _, m in ipairs({"GetTotalMemoryUsageMb","GetMemoryUsageMbAllCategories","GetMemoryUsageMbForTag","GetHarmonyQualityLevel","GetMemoryCategoryNames","ResetHarmonyMemoryTarget"}) do
        info[m] = safeCall(Stats, m)
    end
    for _, p in ipairs({"DataReceiveKbps","DataSendKbps","FrameTime","ContactsCount","MemoryTrackingEnabled","HarmonyMemoryTarget","InstanceCount"}) do
        local v = safeProp(Stats, p); if v ~= nil then info[p] = v end
    end
    return info
end

-- [3] Entrada y Dispositivo
local function collectInputInfo()
    local UIS = safeGetService("UserInputService")
    if not UIS then return { available = false } end
    local info = { available = true }
    for _, p in ipairs({"KeyboardEnabled","GamepadEnabled","TouchEnabled","MouseEnabled","GyroscopeEnabled","AccelerometerEnabled","VREnabled","ModalEnabled","MouseIconEnabled","IsUsingCamera","IsUsingMicrophone"}) do
        info[p] = safeProp(UIS, p)
    end
    for _, p in ipairs({"MouseBehavior","MouseDeltaSensitivity","PreferredInput","OnScreenKeyboardPosition","OnScreenKeyboardSize","OnScreenKeyboardVisible","LastInputType","LastInputTypeChanged"}) do
        local v = safeProp(UIS, p); if v ~= nil then info[p] = v end
    end
    local gamepads = safeCall(UIS, "GetConnectedGamepads")
    if gamepads then info.ConnectedGamepads = #gamepads end
    info.CapsLockEnabled = safeCall(UIS, "GetFocusedTextBox") ~= nil
    return info
end

-- [4] GUI y Pantalla
local function collectGuiInfo()
    local GuiService = safeGetService("GuiService")
    local CoreGui = safeGetService("CoreGui")
    local StarterGui = safeGetService("StarterGui")
    local info = { available = true }
    if GuiService then
        for _, p in ipairs({"IsTenFootInterface","MenuIsOpen","AutoSelectGuiEnabled"}) do info[p] = safeProp(GuiService, p) end
        info.TopbarInset = safeCall(GuiService, "GetGuiInset")
    end
    if CoreGui then info.CoreGuiChildren = safeCount(CoreGui) end
    if StarterGui then info.StarterGuiChildren = safeCount(StarterGui) end
    return info
end

-- [5] Logs y Errores
local function collectLogInfo()
    local LogService = safeGetService("LogService")
    if not LogService then return { available = false } end
    local info = { available = true }
    local ok, history = pcall(function() return LogService:GetLogHistory() end)
    if ok and type(history) == "table" then
        info.LogCount = #history
        local suspicious, errors, warnings = {}, {}, {}
        for _, entry in ipairs(history) do
            if type(entry) == "table" and type(entry.message) == "string" then
                local msg = entry.message:lower()
                if entry.messageType == Enum.MessageType.MessageError then table.insert(errors, entry.message:sub(1, 200)) end
                if entry.messageType == Enum.MessageType.MessageWarning then table.insert(warnings, entry.message:sub(1, 200)) end
                if msg:find("executor") or msg:find("synapse") or msg:find("delta") or msg:find("krnl") or msg:find("fluxus") or msg:find("script") then
                    table.insert(suspicious, entry.message:sub(1, 200))
                end
            end
        end
        info.SuspiciousLogs, info.RecentErrors, info.RecentWarnings = suspicious, errors, warnings
    end
    return info
end

-- [6] Red y Servicios
local function collectNetworkInfo()
    local HttpService, TeleportService, MarketplaceService, Players = safeGetService("HttpService"), safeGetService("TeleportService"), safeGetService("MarketplaceService"), safeGetService("Players")
    local info = { available = true }
    if HttpService then
        info.HttpEnabled = safeCall(HttpService, "HttpEnabled")
        info.GameId, info.PlaceId, info.JobId = game.GameId, game.PlaceId, game.JobId
    end
    if TeleportService then info.TeleportData = safeCall(TeleportService, "GetLocalPlayerTeleportData") end
    if MarketplaceService and Players and Players.LocalPlayer then
        info.PlayerMembership = safeCall(MarketplaceService, "GetUserMembership", Players.LocalPlayer.UserId)
    end
    return info
end

-- [7] Almacenamiento
local function collectStorageInfo()
    local AppStorage, MemStorage = safeGetService("AppStorageService"), safeGetService("MemStorageService")
    local info = { available = true }
    if AppStorage then info.AppStorageItems = safeCall(AppStorage, "GetItems") end
    if MemStorage then info.MemStorageItems = safeCall(MemStorage, "GetItems") end
    return info
end

-- [8] GC y Closures
local function collectGCInfo()
    local info = { available = true }
    if type(getgc) == "function" then
        local ok, gc = pcall(getgc, true)
        if ok and type(gc) == "table" then
            local funcCount, tableCount = 0, 0
            for _, v in ipairs(gc) do
                if type(v) == "function" then funcCount = funcCount + 1
                elseif type(v) == "table" then tableCount = tableCount + 1 end
            end
            info.GCFunctionCount, info.GCTableCount = funcCount, tableCount
        end
    end
    if type(getinstances) == "function" then local ok, v = pcall(getinstances); if ok then info.TotalInstances = #v end end
    if type(getnilinstances) == "function" then local ok, v = pcall(getnilinstances); if ok then info.NilInstancesCount = #v end end
    if type(getloadedmodules) == "function" then local ok, v = pcall(getloadedmodules); if ok then info.LoadedModulesCount = #v end end
    if type(getscripts) == "function" then local ok, v = pcall(getscripts); if ok then info.ScriptsCount = #v end end
    if type(getrunningscripts) == "function" then local ok, v = pcall(getrunningscripts); if ok then info.RunningScriptsCount = #v end end
    return info
end

-- [9] Metatablas y Hooks
local function collectMetatableInfo()
    local info = { available = true }
    if type(getrawmetatable) == "function" then
        local ok, mt = pcall(getrawmetatable, game)
        if ok and type(mt) == "table" then
            info.GameMetatable = {}
            for k, v in pairs(mt) do if type(k) == "string" then info.GameMetatable[k] = type(v) end end
        end
        local cp = safeGetService("ContentProvider")
        if cp then
            local ok2, mt2 = pcall(getrawmetatable, cp)
            if ok2 and type(mt2) == "table" then
                info.ContentProviderMetatable = {}
                for k, v in pairs(mt2) do if type(k) == "string" then info.ContentProviderMetatable[k] = type(v) end end
            end
        end
    end
    if type(checkcaller) == "function" then local ok, r = pcall(checkcaller); if ok then info.CheckCallerResult = r end end
    if type(getnamecallmethod) == "function" then local ok, m = pcall(getnamecallmethod); if ok then info.NamecallMethod = tostring(m) end end
    return info
end

-- [10] Detección de Inyección
local function collectInjectionInfo()
    local info = { available = true }
    if type(getscripts) == "function" then
        local ok, scripts = pcall(getscripts)
        if ok and type(scripts) == "table" then
            local injected = {}
            for _, script in ipairs(scripts) do
                local ok2, name = pcall(function() return script.Name end)
                if ok2 and name and (name:lower():find("dex") or name:lower():find("inject") or name:lower():find("hook") or name:lower():find("spy")) then
                    table.insert(injected, name)
                end
            end
            info.InjectedScripts = injected
        end
    end
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local ok, infoFunc = pcall(function() return debug.getinfo(getfenv, "S") end)
        if ok and type(infoFunc) == "table" then info.GetFenvNativeInfo = infoFunc end
    end
    local ok2 = pcall(function() return getfenv(9999) end)
    info.GetFenvOutOfRangeError = not ok2
    return info
end

-- [11] VR y Gamepad
local function collectVRInfo()
    local VRService, GamepadService = safeGetService("VRService"), safeGetService("GamepadService")
    local info = { available = true }
    if VRService then
        for _, p in ipairs({"VREnabled","VRDeviceName","VRSessionState","UserCFrameEnabled"}) do info[p] = safeProp(VRService, p) end
    end
    if GamepadService then info.GamepadCount = safeCall(GamepadService, "GetGamepadCount") end
    return info
end

-- [12] Texto y Localización
local function collectTextInfo()
    local TextService, LocalizationService = safeGetService("TextService"), safeGetService("LocalizationService")
    local info = { available = true }
    if TextService then info.SystemLocale = safeCall(TextService, "GetSystemLocale") end
    if LocalizationService then
        info.RobloxLocaleId = safeProp(LocalizationService, "RobloxLocaleId")
        info.SystemLocaleId = safeProp(LocalizationService, "SystemLocaleId")
    end
    return info
end

-- [13] Políticas
local function collectPolicyInfo()
    local PolicyService, Players = safeGetService("PolicyService"), safeGetService("Players")
    local info = { available = true }
    if PolicyService and Players and Players.LocalPlayer then
        local ok, policies = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer) end)
        if ok then info.PlayerPolicies = policies end
    end
    return info
end

-- [14] Chat y Voz
local function collectChatInfo()
    local TextChatService, Chat, VoiceChatService, Players = safeGetService("TextChatService"), safeGetService("Chat"), safeGetService("VoiceChatService"), safeGetService("Players")
    local info = { available = true }
    if TextChatService then
        info.ChatVersion = safeProp(TextChatService, "ChatVersion")
        info.CreateDefaultTextChannels = safeProp(TextChatService, "CreateDefaultTextChannels")
    end
    if Chat then info.ChatLoadDefaultChat = safeProp(Chat, "LoadDefaultChat") end
    if VoiceChatService and Players and Players.LocalPlayer then
        info.VoiceChatEnabled = safeCall(VoiceChatService, "IsVoiceEnabledForUserIdAsync", Players.LocalPlayer.UserId)
    end
    return info
end

-- [15] CoreScripts
local function collectCoreInfo()
    local info = { available = true }
    if type(getloadedmodules) == "function" then
        local ok, modules = pcall(getloadedmodules)
        if ok and type(modules) == "table" then
            local coreModules = {}
            for _, module in ipairs(modules) do
                local ok2, name = pcall(function() return module.Name end)
                if ok2 and name then table.insert(coreModules, name) end
            end
            info.LoadedCoreModules = coreModules
        end
    end
    return info
end

-- [16] UserSettings
local function collectUserSettingsInfo()
    local info = { available = true }
    local ok, us = pcall(function() return UserSettings() end)
    if ok and us then
        local ok2, gs = pcall(function() return us:GetService("UserGameSettings") end)
        if ok2 and gs then
            for _, p in ipairs({"SavedQualityLevel","MasterVolume","CameraMode","ComputerCameraMovementMode","ComputerMovementMode","ControlMode","RotationType","GamepadCameraSensitivity","MouseSensitivity","OnScreenKeyboardPosition"}) do
                local v = safeProp(gs, p); if v ~= nil then info[p] = v end
            end
        end
    end
    return info
end

-- [17] Servicios Adicionales
local function collectAdditionalServices()
    local info = { available = true }
    local services = {"AnalyticsService","AssetService","BadgeService","CollectionService","ContentProvider","ContextActionService","DataStoreService","Debris","GamePassService","GroupService","HttpService","LocalizationService","LogService","MarketplaceService","MessagingService","PathfindingService","PhysicsService","Players","ReplicatedFirst","ReplicatedStorage","SoundService","StarterGui","StarterPack","StarterPlayer","TeleportService","TextChatService","TextService","TweenService","UserInputService","VRService","Workspace"}
    for _, s in ipairs(services) do
        local svc = safeGetService(s)
        if svc then
            info[s] = { exists = true, className = safeClass(svc) }
        else info[s] = { exists = false } end
    end
    return info
end

-- [18] Rendimiento
local function collectPerformanceInfo()
    local RunService, Stats = safeGetService("RunService"), safeGetService("Stats")
    local info = { available = true }
    if RunService then
        info.IsClient, info.IsServer, info.IsStudio = safeProp(RunService, "IsClient"), safeProp(RunService, "IsServer"), safeProp(RunService, "IsStudio")
    end
    if Stats then
        info.FrameTime = safeProp(Stats, "FrameTime")
        info.DataReceiveKbps = safeProp(Stats, "DataReceiveKbps")
        info.DataSendKbps = safeProp(Stats, "DataSendKbps")
        info.ContactsCount = safeProp(Stats, "ContactsCount")
    end
    return info
end

-- [19] Memoria Detallada
local function collectMemoryInfo()
    local Stats = safeGetService("Stats")
    if not Stats then return { available = false } end
    local info = { available = true }
    info.TotalMemoryMb = safeCall(Stats, "GetTotalMemoryUsageMb")
    info.AllCategories = safeCall(Stats, "GetMemoryUsageMbAllCategories")
    info.CategoryNames = safeCall(Stats, "GetMemoryCategoryNames")
    info.HarmonyQuality = safeCall(Stats, "GetHarmonyQualityLevel")
    info.MemoryTrackingEnabled = safeProp(Stats, "MemoryTrackingEnabled")
    return info
end

-- [20] Scripts y Bytecode
local function collectScriptInfo()
    local info = { available = true }
    if type(getscripts) == "function" then
        local ok, scripts = pcall(getscripts)
        if ok and type(scripts) == "table" then
            info.TotalScripts = #scripts
            local names = {}
            for i, script in ipairs(scripts) do
                if i <= 50 then
                    local ok2, name = pcall(function() return script.Name end)
                    if ok2 and name then table.insert(names, name) end
                end
            end
            info.SampleScriptNames = names
        end
    end
    if type(getscripthash) == "function" then
        local ok, scripts = pcall(getscripts)
        if ok and type(scripts) == "table" and #scripts > 0 then
            local ok2, hash = pcall(getscripthash, scripts[1])
            if ok2 then info.FirstScriptHash = hash end
        end
    end
    return info
end

-- [21] Red Profunda + LocalPlayer
local function collectNetworkDeepInfo()
    local info = { available = true }
    local NetworkClient = safeGetService("NetworkClient")
    if NetworkClient then
        info.NetworkClientExists = true
        info.NetworkClientProps = {}
        for _, p in ipairs({"ConnectionState","NetworkOwner","Ping"}) do info.NetworkClientProps[p] = safeProp(NetworkClient, p) end
    end
    local Players = safeGetService("Players")
    if Players and Players.LocalPlayer then
        local lp = Players.LocalPlayer
        info.LocalPlayerName = safeProp(lp, "Name")
        info.LocalPlayerDisplayName = safeProp(lp, "DisplayName")
        info.LocalPlayerUserId = safeProp(lp, "UserId")
        info.LocalPlayerAccountAge = safeProp(lp, "AccountAge")
        info.LocalPlayerMembershipType = safeProp(lp, "MembershipType")
        info.LocalPlayerTeam = safeProp(lp, "Team")
        info.LocalPlayerNeutral = safeProp(lp, "Neutral")
    end
    return info
end

-- [22] Workspace
local function collectWorkspaceInfo()
    local Workspace = safeGetService("Workspace")
    local info = { available = true }
    if Workspace then
        info.CurrentCamera = safeProp(Workspace, "CurrentCamera") and "Present" or nil
        info.Gravity = safeProp(Workspace, "Gravity")
        info.FallenPartsDestroyHeight = safeProp(Workspace, "FallenPartsDestroyHeight")
        info.StreamingEnabled = safeProp(Workspace, "StreamingEnabled")
        info.TerrainChildren = safeCount(Workspace.Terrain)
        info.WorkspaceChildren = safeCount(Workspace)
        local Lighting = safeGetService("Lighting")
        if Lighting then
            info.LightingTechnology = safeProp(Lighting, "Technology")
            info.Ambient, info.OutdoorAmbient = safeProp(Lighting, "Ambient"), safeProp(Lighting, "OutdoorAmbient")
            info.Brightness, info.ClockTime = safeProp(Lighting, "Brightness"), safeProp(Lighting, "ClockTime")
            info.GeographicLatitude = safeProp(Lighting, "GeographicLatitude")
            info.FogColor, info.FogEnd, info.FogStart = safeProp(Lighting, "FogColor"), safeProp(Lighting, "FogEnd"), safeProp(Lighting, "FogStart")
            info.GlobalShadows = safeProp(Lighting, "GlobalShadows")
            info.EnvironmentDiffuseScale = safeProp(Lighting, "EnvironmentDiffuseScale")
            info.EnvironmentSpecularScale = safeProp(Lighting, "EnvironmentSpecularScale")
            info.ExposureCompensation = safeProp(Lighting, "ExposureCompensation")
            info.ShadowSoftness = safeProp(Lighting, "ShadowSoftness")
        end
    end
    return info
end

-- [23] Cámara
local function collectCameraInfo()
    local Workspace = safeGetService("Workspace")
    local info = { available = true }
    if Workspace and Workspace.CurrentCamera then
        local cam = Workspace.CurrentCamera
        info.CameraType = safeProp(cam, "CameraType")
        info.CameraSubject = safeProp(cam, "CameraSubject")
        info.FieldOfView = safeProp(cam, "FieldOfView")
        info.ViewportSize = tostring(safeProp(cam, "ViewportSize"))
        info.CFrame = tostring(safeProp(cam, "CFrame"))
        info.Focus = tostring(safeProp(cam, "Focus"))
        info.NearPlaneZ = safeProp(cam, "NearPlaneZ")
    end
    return info
end

-- [24] Ratón
local function collectMouseInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local mouse = safeCall(Players.LocalPlayer, "GetMouse")
        if mouse then
            info.Hit = tostring(safeProp(mouse, "Hit"))
            info.Target = safeProp(mouse, "Target")
            info.X, info.Y = safeProp(mouse, "X"), safeProp(mouse, "Y")
            info.ViewSizeX, info.ViewSizeY = safeProp(mouse, "ViewSizeX"), safeProp(mouse, "ViewSizeY")
        end
    end
    return info
end

-- [25] Personaje del Jugador
local function collectCharacterInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local char = Players.LocalPlayer.Character
        if char then
            info.Exists = true
            info.Name = safeProp(char, "Name")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            info.Humanoid = humanoid ~= nil
            if humanoid then
                info.Health = safeProp(humanoid, "Health")
                info.MaxHealth = safeProp(humanoid, "MaxHealth")
                info.WalkSpeed = safeProp(humanoid, "WalkSpeed")
                info.JumpPower = safeProp(humanoid, "JumpPower")
                info.JumpHeight = safeProp(humanoid, "JumpHeight")
                info.UseJumpPower = safeProp(humanoid, "UseJumpPower")
                info.HipHeight = safeProp(humanoid, "HipHeight")
                info.RigType = safeProp(humanoid, "RigType")
                info.MoveDirection = tostring(safeProp(humanoid, "MoveDirection"))
                info.DisplayDistanceType = safeProp(humanoid, "DisplayDistanceType")
                info.HealthDisplayDistance = safeProp(humanoid, "HealthDisplayDistance")
                info.NameDisplayDistance = safeProp(humanoid, "NameDisplayDistance")
                info.AutoRotate = safeProp(humanoid, "AutoRotate")
                info.AutoJumpEnabled = safeProp(humanoid, "AutoJumpEnabled")
                info.EvaluateStateMachine = safeProp(humanoid, "EvaluateStateMachine")
                info.BreakJointsOnDeath = safeProp(humanoid, "BreakJointsOnDeath")
            end
            info.Head = char:FindFirstChild("Head") ~= nil
            info.HumanoidRootPart = char:FindFirstChild("HumanoidRootPart") ~= nil
            info.Torso = char:FindFirstChild("Torso") ~= nil or char:FindFirstChild("UpperTorso") ~= nil
            info.PrimaryPart = safeProp(char, "PrimaryPart")
        else
            info.Exists = false
        end
    end
    return info
end

-- [26] Audio
local function collectSoundInfo()
    local SoundService = safeGetService("SoundService")
    local info = { available = true }
    if SoundService then
        for _, p in ipairs({"AmbientReverb","DistanceFactor","DopplerScale","RespectFilteringEnabled","RolloffScale"}) do
            local v = safeProp(SoundService, p); if v ~= nil then info[p] = v end
        end
    end
    return info
end

-- [27] Física
local function collectPhysicsInfo()
    local PhysicsService = safeGetService("PhysicsService")
    local info = { available = true }
    if PhysicsService then
        local ok, groups = pcall(function() return PhysicsService:GetCollisionGroups() end)
        if ok then info.CollisionGroups = groups end
        local ok2, layers = pcall(function() return PhysicsService:GetCollisionGroupNames() end)
        if ok2 then info.CollisionGroupNames = layers end
    end
    return info
end

-- [28] Terreno
local function collectTerrainInfo()
    local Workspace = safeGetService("Workspace")
    local info = { available = true }
    if Workspace and Workspace.Terrain then
        local t = Workspace.Terrain
        info.WaterColor = safeProp(t, "WaterColor")
        info.WaterWaveSize = safeProp(t, "WaterWaveSize")
        info.WaterWaveSpeed = safeProp(t, "WaterWaveSpeed")
        info.WaterReflectance = safeProp(t, "WaterReflectance")
        info.WaterTransparency = safeProp(t, "WaterTransparency")
    end
    return info
end

-- [29] ReplicatedStorage
local function collectReplicatedStorageInfo()
    local RS = safeGetService("ReplicatedStorage")
    local info = { available = true }
    if RS then
        info.ChildCount = safeCount(RS)
        local children = {}
        local ok, ch = pcall(function() return RS:GetChildren() end)
        if ok then
            for i, c in ipairs(ch) do
                if i <= 30 then table.insert(children, { name = c.Name, class = c.ClassName }) end
            end
        end
        info.SampleChildren = children
    end
    return info
end

-- [30] ReplicatedFirst
local function collectReplicatedFirstInfo()
    local RF = safeGetService("ReplicatedFirst")
    local info = { available = true }
    if RF then info.ChildCount = safeCount(RF) end
    return info
end

-- [31] ContextActionService Bindings
local function collectContextActionInfo()
    local CAS = safeGetService("ContextActionService")
    local info = { available = true }
    if CAS then
        local ok, bindings = pcall(function() return CAS:GetAllBoundActionInfo() end)
        if ok and type(bindings) == "table" then
            info.BindingCount = 0
            for _ in pairs(bindings) do info.BindingCount = info.BindingCount + 1 end
        end
    end
    return info
end

-- [32] CollectionService Tags
local function collectTagsInfo()
    local CS = safeGetService("CollectionService")
    local info = { available = true }
    if CS then
        local ok, tags = pcall(function() return CS:GetAllTags() end)
        if ok and type(tags) == "table" then info.TotalTags = #tags; info.Tags = tags end
    end
    return info
end

-- [33] Badges
local function collectBadgeInfo()
    local BadgeService, Players = safeGetService("BadgeService"), safeGetService("Players")
    local info = { available = true }
    if BadgeService and Players and Players.LocalPlayer then
        info.PlayerUserId = Players.LocalPlayer.UserId
    end
    return info
end

-- [34] Avatar / HumanoidDescription
local function collectAvatarInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local lp = Players.LocalPlayer
        local ok, desc = pcall(function() return lp:GetJoinData() end)
        if ok then info.JoinData = desc end
        local ok2, hd = pcall(function() return Players:GetHumanoidDescriptionFromUserId(lp.UserId) end)
        if ok2 and hd then
            info.HumanoidDescription = {
                HeightScale = hd.HeightScale, WidthScale = hd.WidthScale,
                HeadScale = hd.HeadScale, BodyTypeScale = hd.BodyTypeScale,
                ProportionScale = hd.ProportionScale,
            }
        end
    end
    return info
end

-- [35] Network Ownership
local function collectNetworkOwnershipInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer and Players.LocalPlayer.Character then
        local char = Players.LocalPlayer.Character
        for _, part in ipairs(char:GetChildren()) do
            local ok, owner = pcall(function() return part:GetNetworkOwner() end)
            if ok and owner then info[part.Name] = owner.Name end
        end
    end
    return info
end

-- [36] Jerarquía de Instancias
local function collectInstanceHierarchyInfo()
    local info = { available = true }
    info.GameChildren = safeCount(game)
    info.WorkspaceDescendants = 0
    local Workspace = safeGetService("Workspace")
    if Workspace then
        local ok, count = pcall(function() return #Workspace:GetDescendants() end)
        if ok then info.WorkspaceDescendants = count end
    end
    local Players = safeGetService("Players")
    if Players then
        local ok2, count2 = pcall(function() return #Players:GetDescendants() end)
        if ok2 then info.PlayersDescendants = count2 end
    end
    return info
end

-- [37] Sandboxing
local function collectSandboxingInfo()
    local info = { available = true }
    info.RawEqualWorks = rawequal and rawequal({}, {}) == false
    info.RawGetWorks = rawget ~= nil
    info.RawSetWorks = rawset ~= nil
    info.TypeWorks = type(1) == "number"
    info.PairsWorks = pairs ~= nil
    info.NextWorks = next ~= nil
    info.SelectWorks = select("#", 1, 2, 3) == 3
    info.PcallWorks = pcall ~= nil
    info.XpcallWorks = xpcall ~= nil
    info.LoadstringAvailable = type(loadstring) == "function"
    info.LoadAvailable = type(load) == "function"
    info.SetfenvAvailable = type(setfenv) == "function"
    info.GetfenvAvailable = type(getfenv) == "function"
    info.NewproxyAvailable = type(newproxy) == "function"
    info.DebugAvailable = type(debug) == "table"
    info.CoroutineAvailable = type(coroutine) == "table"
    info.StringAvailable = type(string) == "table"
    info.TableAvailable = type(table) == "table"
    info.MathAvailable = type(math) == "table"
    info.IoAvailable = type(io) == "table"
    info.OsAvailable = type(os) == "table"
    return info
end

-- [38] Integridad de Librerías
local function collectLibraryIntegrityInfo()
    local info = { available = true }
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        for _, fn in ipairs({print, warn, error, pcall, xpcall, require, tostring, tonumber, type, rawget, rawset, rawequal, rawlen, getmetatable, setmetatable, select, next, pairs, ipairs}) do
            if type(fn) == "function" then
                local ok, inf = pcall(debug.getinfo, fn, "S")
                if ok and type(inf) == "table" and inf.what then
                    info["_" .. tostring(fn):sub(1, 20)] = inf.what
                end
            end
        end
    end
    return info
end

-- [39] Metatablas Comunes
local function collectCommonMetatablesInfo()
    local info = { available = true }
    local targets = {
        game = game, workspace = safeGetService("Workspace"),
        string = string, table = table, math = math,
        debug = debug, coroutine = coroutine,
    }
    for name, obj in pairs(targets) do
        if obj then
            local ok, mt = pcall(function() return getmetatable(obj) end)
            if ok and mt then
                info[name] = {}
                for k, v in pairs(mt) do if type(k) == "string" then info[name][k] = type(v) end end
            end
        end
    end
    return info
end

-- [40] Capacidades del Ejecutor
local function collectExecutorCapabilities()
    local info = { available = true }
    local caps = {
        "writefile","readfile","appendfile","delfile","makefolder","delfolder","listfiles",
        "isfile","isfolder","loadfile","dofile","setclipboard","getclipboard","queue_on_teleport",
        "request","http_request","syn_request","getcustomasset","setfpscap","getfpscap",
        "getthreadidentity","setthreadidentity","getscriptbytecode","getscriptfunction",
        "loadstring","getsenv","getmenv","gettenv","getscripthash","getcustomasset",
    }
    for _, c in ipairs(caps) do
        if type(ENV[c]) == "function" or type(_G[c]) == "function" then info[c] = true end
    end
    return info
end

-- [41] Anti-Cheat
local function collectAntiCheatInfo()
    local info = { available = true }
    local ReplicatedStorage = safeGetService("ReplicatedStorage")
    if ReplicatedStorage then
        local acNames = {}
        local ok, children = pcall(function() return ReplicatedStorage:GetDescendants() end)
        if ok then
            for _, child in ipairs(children) do
                local name = child.Name:lower()
                if name:find("anticheat") or name:find("anti_cheat") or name:find("byfron") or name:find("hyperion") or name:find("detect") or name:find("guard") then
                    table.insert(acNames, child.Name)
                end
            end
        end
        info.SuspiciousInstances = acNames
    end
    return info
end

-- [42] Versión de Roblox
local function collectRobloxVersionInfo()
    local info = { available = true }
    local ok, v = pcall(function() return game:GetService("RunService"):IsStudio() end)
    info.IsStudio = ok and v or false
    local ok2, v2 = pcall(function() return game:GetService("RunService"):IsClient() end)
    info.IsClient = ok2 and v2 or false
    local ok3, v3 = pcall(function() return game:GetService("RunService"):IsServer() end)
    info.IsServer = ok3 and v3 or false
    if type(version) == "function" then local okv, vv = pcall(version); if okv then info.version = vv end end
    return info
end

-- [43] Timers y Clock
local function collectClockInfo()
    local info = { available = true }
    if type(os) == "table" then
        if type(os.time) == "function" then local ok, t = pcall(os.time); if ok then info.os_time = t end end
        if type(os.clock) == "function" then local ok, c = pcall(os.clock); if ok then info.os_clock = c end end
        if type(os.date) == "function" then local ok, d = pcall(os.date); if ok then info.os_date = d end end
    end
    if type(tick) == "function" then local ok, t = pcall(tick); if ok then info.tick = t end end
    if type(time) == "function" then local ok, t = pcall(time); if ok then info.time = t end end
    if type(elapsedTime) == "function" then local ok, t = pcall(elapsedTime); if ok then info.elapsedTime = t end end
    return info
end

-- [44] Platform Info
local function collectPlatformInfo()
    local info = { available = true }
    local GuiService = safeGetService("GuiService")
    if GuiService then info.IsTenFootInterface = safeProp(GuiService, "IsTenFootInterface") end
    local UIS = safeGetService("UserInputService")
    if UIS then
        if UIS.TouchEnabled then info.Platform = "Mobile/Tablet" end
        if UIS.KeyboardEnabled and UIS.MouseEnabled then info.Platform = "Desktop" end
        if UIS.GamepadEnabled and not UIS.KeyboardEnabled then info.Platform = "Console" end
        if UIS.VREnabled then info.Platform = "VR" end
    end
    return info
end

-- [45] User Agent
local function collectUserAgentInfo()
    local info = { available = true }
    local Players = safeGetService("Players")
    if Players then
        info.MaxPlayers = safeProp(Players, "MaxPlayers")
        info.NumPlayers = safeProp(Players, "NumPlayers")
        info.PreferredPlayers = safeProp(Players, "PreferredPlayers")
        info.RespawnTime = safeProp(Players, "RespawnTime")
        info.CharacterAutoLoads = safeProp(Players, "CharacterAutoLoads")
    end
    return info
end

-- [46] TextChat Channels
local function collectTextChatChannelsInfo()
    local TCS = safeGetService("TextChatService")
    local info = { available = true }
    if TCS then
        local ok, channels = pcall(function() return TCS:GetChannels() end)
        if ok and type(channels) == "table" then
            info.ChannelCount = #channels
            local names = {}
            for _, ch in ipairs(channels) do
                local ok2, n = pcall(function() return ch.Name end)
                if ok2 then table.insert(names, n) end
            end
            info.ChannelNames = names
        end
    end
    return info
end

-- [47] AssetService
local function collectAssetInfo()
    local AssetService = safeGetService("AssetService")
    local info = { available = true }
    if AssetService then info.Exists = true end
    return info
end

-- [48] GamePass
local function collectGamePassInfo()
    local MarketplaceService = safeGetService("MarketplaceService")
    local info = { available = true }
    if MarketplaceService then info.Exists = true end
    return info
end

-- [49] Detección de Exploits
local function collectExploitDetection()
    local info = { available = true }
    local knownExploits = {
        "Dex", "SimpleSpy", "Rspy", "Hydroxide", "Infinite Yield", "Owl Hub",
        "Kavo", "IY", "DarkDex", "Remote Spy", "Server Spy", "Ghost",
    }
    local CoreGui = safeGetService("CoreGui")
    if CoreGui then
        local found = {}
        local ok, children = pcall(function() return CoreGui:GetDescendants() end)
        if ok then
            for _, c in ipairs(children) do
                local name = tostring(c.Name)
                for _, exploit in ipairs(knownExploits) do
                    if name:lower():find(exploit:lower()) then
                        table.insert(found, name)
                        break
                    end
                end
            end
        end
        info.DetectedExploits = found
    end
    return info
end

-- [50] System Perf
local function collectSystemPerfInfo()
    local info = { available = true }
    local Stats = safeGetService("Stats")
    if Stats then
        local ok, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
        if ok then info.MemoryUsageMb = mem end
        local ok2, all = pcall(function() return Stats:GetMemoryUsageMbAllCategories() end)
        if ok2 then info.MemoryAllCategories = all end
    end
    return info
end

-- [51] Service Names
local function collectServiceNamesInfo()
    local info = { available = true }
    local names = {}
    local ok = pcall(function()
        for _, svc in ipairs(game:GetChildren()) do
            if svc.ClassName == "DataModel" or svc:IsA("ServiceProvider") then
                table.insert(names, svc.Name)
            end
        end
    end)
    if ok then info.Services = names end
    return info
end

-- [52] Global Hooks
local function collectGlobalHooksInfo()
    local info = { available = true }
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local hooks = {}
        for _, name in ipairs({"print","warn","error","require","pcall","xpcall"}) do
            local fn = ENV[name] or _G[name]
            if type(fn) == "function" then
                local ok, inf = pcall(debug.getinfo, fn, "S")
                if ok and type(inf) == "table" then
                    hooks[name] = { what = inf.what, source = tostring(inf.source):sub(1, 80) }
                end
            end
        end
        info.GlobalHooks = hooks
    end
    return info
end

-- [53] Rate Limit
local function collectRateLimitInfo()
    local info = { available = true }
    local Players = safeGetService("Players")
    if Players and Players.LocalPlayer then
        local lp = Players.LocalPlayer
        local ok, ping = pcall(function() return lp:GetNetworkPing() end)
        if ok then info.NetworkPing = ping end
    end
    return info
end

-- [54] Window
local function collectWindowInfo()
    local info = { available = true }
    local UIS = safeGetService("UserInputService")
    if UIS then
        local ok, size = pcall(function() return UIS:GetMouseLocation() end)
        if ok and size then info.MouseLocation = { X = size.X, Y = size.Y } end
    end
    return info
end

-- [55] StarterPlayer
local function collectStarterPlayerInfo()
    local SP = safeGetService("StarterPlayer")
    local info = { available = true }
    if SP then
        for _, p in ipairs({"CharacterWalkSpeed","CharacterJumpPower","CharacterMaxSlopeAngle","CharacterUseJumpPower","EnableMouseLockOption","LoadCharacterAppearance","CameraMaxZoomDistance","CameraMinZoomDistance","CameraMode","DevCameraOcclusionMode","DevComputerCameraMovementMode","DevComputerMovementMode","DevTouchCameraMovementMode","DevTouchMovementMode","EnableDynamicHeads"}) do
            local v = safeProp(SP, p); if v ~= nil then info[p] = v end
        end
    end
    return info
end

-- [56] AdService
local function collectAdInfo()
    local info = { available = true }
    if safeGetService("AdService") then info.Exists = true end
    return info
end

-- [57] HapticService
local function collectHapticInfo()
    local HapticService = safeGetService("HapticService")
    local info = { available = true }
    if HapticService then
        info.Exists = true
        local ok, motors = pcall(function() return HapticService:GetMotorNames() end)
        if ok then info.MotorNames = motors end
    end
    return info
end

-- [58] Network Stats
local function collectNetworkStats()
    local info = { available = true }
    local Stats = safeGetService("Stats")
    if Stats then
        info.DataReceiveKbps = safeProp(Stats, "DataReceiveKbps")
        info.DataSendKbps = safeProp(Stats, "DataSendKbps")
    end
    return info
end

-- [59] Group
local function collectGroupInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local lp = Players.LocalPlayer
        local ok, groupId = pcall(function() return lp:GetAttribute("GroupId") end)
        if ok then info.GroupId = groupId end
    end
    return info
end

-- [60] Threads
local function collectThreadInfo()
    local info = { available = true }
    info.MainThread = tostring(coroutine.running())
    info.IsMainThread = coroutine.isyieldable and coroutine.isyieldable() or false
    return info
end

-- [61] Lua Memory
local function collectLuaMemoryInfo()
    local info = { available = true }
    if type(collectgarbage) == "function" then
        local ok, count = pcall(collectgarbage, "count")
        if ok then info.LuaMemoryKB = count; info.LuaMemoryMB = count / 1024 end
    end
    return info
end

-- [62] Identity
local function collectIdentityInfo()
    local info = { available = true }
    if type(getthreadidentity) == "function" then
        local ok, id = pcall(getthreadidentity); if ok then info.ThreadIdentity = id end
    end
    if type(getidentity) == "function" then
        local ok, id = pcall(getidentity); if ok then info.Identity = id end
    end
    if type(getlevel) == "function" then
        local ok, lvl = pcall(getlevel); if ok then info.Level = lvl end
    end
    return info
end

-- [63] Script Perf
local function collectScriptPerfInfo()
    local info = { available = true }
    if type(getscripts) == "function" then
        local ok, scripts = pcall(getscripts)
        if ok and type(scripts) == "table" then
            local withBytecode = 0
            for _, s in ipairs(scripts) do
                if type(getscriptbytecode) == "function" then
                    local ok2 = pcall(getscriptbytecode, s)
                    if ok2 then withBytecode = withBytecode + 1 end
                end
            end
            info.ScriptsWithBytecode = withBytecode
        end
    end
    return info
end

-- [64] Remotes
local function collectRemoteInfo()
    local RS = safeGetService("ReplicatedStorage")
    local info = { available = true }
    if RS then
        local remotes = {}
        local ok, desc = pcall(function() return RS:GetDescendants() end)
        if ok then
            for _, child in ipairs(desc) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("BindableEvent") or child:IsA("BindableFunction") then
                    table.insert(remotes, { name = child.Name, class = child.ClassName })
                    if #remotes >= 50 then break end
                end
            end
        end
        info.RemoteCount = #remotes
        info.SampleRemotes = remotes
    end
    return info
end

-- [65] StarterGui Deep
local function collectStarterGuiDeepInfo()
    local SG = safeGetService("StarterGui")
    local info = { available = true }
    if SG then
        info.ScreenOrientation = safeProp(SG, "ScreenOrientation")
        info.ShowDevelopmentGui = safeProp(SG, "ShowDevelopmentGui")
        info.ResetPlayerGuiOnSpawn = safeProp(SG, "ResetPlayerGuiOnSpawn")
    end
    return info
end

-- [66] Sound Deep
local function collectSoundDeepInfo()
    local SS = safeGetService("SoundService")
    local info = { available = true }
    if SS then
        info.AmbientReverb = safeProp(SS, "AmbientReverb")
        info.DistanceFactor = safeProp(SS, "DistanceFactor")
        info.DopplerScale = safeProp(SS, "DopplerScale")
        info.RolloffScale = safeProp(SS, "RolloffScale")
        info.RespectFilteringEnabled = safeProp(SS, "RespectFilteringEnabled")
    end
    return info
end

-- [67] Debris
local function collectDebrisInfo()
    local info = { available = true }
    if safeGetService("Debris") then info.Exists = true end
    return info
end

-- [68] TweenService
local function collectTweenInfo()
    local info = { available = true }
    if safeGetService("TweenService") then info.Exists = true end
    return info
end

-- [69] Pathfinding
local function collectPathfindingInfo()
    local info = { available = true }
    if safeGetService("PathfindingService") then info.Exists = true end
    return info
end

-- [70] ProximityPrompts
local function collectProximityInfo()
    local info = { available = true }
    local Workspace = safeGetService("Workspace")
    if Workspace then
        local ok, prompts = pcall(function() return Workspace:GetDescendants() end)
        if ok then
            local count = 0
            for _, c in ipairs(prompts) do
                if c:IsA("ProximityPrompt") then count = count + 1 end
            end
            info.ProximityPromptCount = count
        end
    end
    return info
end

-- [71] ClickDetectors
local function collectClickDetectorInfo()
    local info = { available = true }
    local Workspace = safeGetService("Workspace")
    if Workspace then
        local ok, det = pcall(function() return Workspace:GetDescendants() end)
        if ok then
            local count = 0
            for _, c in ipairs(det) do
                if c:IsA("ClickDetector") then count = count + 1 end
            end
            info.ClickDetectorCount = count
        end
    end
    return info
end

-- [72] Particles
local function collectParticleInfo()
    local info = { available = true }
    local Workspace = safeGetService("Workspace")
    if Workspace then
        local ok, desc = pcall(function() return Workspace:GetDescendants() end)
        if ok then
            local counts = { ParticleEmitter = 0, Trail = 0, Beam = 0, Fire = 0, Smoke = 0, Sparkles = 0 }
            for _, c in ipairs(desc) do
                if counts[c.ClassName] then counts[c.ClassName] = counts[c.ClassName] + 1 end
            end
            info.EffectCounts = counts
        end
    end
    return info
end

-- [73] GuiObjects
local function collectGuiObjectInfo()
    local info = { available = true }
    local Players = safeGetService("Players")
    if Players and Players.LocalPlayer then
        local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            local ok, desc = pcall(function() return pg:GetDescendants() end)
            if ok then
                local count = 0
                for _, c in ipairs(desc) do
                    if c:IsA("GuiObject") then count = count + 1 end
                end
                info.PlayerGuiObjects = count
            end
        end
    end
    return info
end

-- [74] Animations
local function collectAnimationInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer and Players.LocalPlayer.Character then
        local char = Players.LocalPlayer.Character
        local animator = char:FindFirstChildOfClass("Animator")
        if animator then
            local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
            if ok and type(tracks) == "table" then
                info.PlayingTracks = #tracks
                local names = {}
                for _, t in ipairs(tracks) do
                    if t.Animation then table.insert(names, t.Animation.Name) end
                end
                info.TrackNames = names
            end
        end
    end
    return info
end

-- [75] Network Ping
local function collectNetworkPing()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local ok, ping = pcall(function() return Players.LocalPlayer:GetNetworkPing() end)
        if ok then info.Ping = ping end
    end
    return info
end

-- [76] Avatar Loaded
local function collectAvatarLoadedInfo()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local ok, loaded = pcall(function() return Players.LocalPlayer:GetAttribute("AvatarLoaded") end)
        info.AvatarLoaded = ok and loaded or nil
    end
    return info
end

-- [77] Streaming
local function collectStreamingInfo()
    local Workspace = safeGetService("Workspace")
    local info = { available = true }
    if Workspace then
        info.StreamingEnabled = safeProp(Workspace, "StreamingEnabled")
        info.StreamingMinRadius = safeProp(Workspace, "StreamingMinRadius")
        info.StreamingTargetRadius = safeProp(Workspace, "StreamingTargetRadius")
        info.StreamingIntegrityMode = safeProp(Workspace, "StreamingIntegrityMode")
        info.StreamOutBehavior = safeProp(Workspace, "StreamOutBehavior")
    end
    return info
end

-- [78] Save / Persistence
local function collectSaveInfo()
    local info = { available = true }
    local ok, ps = pcall(function() return game:GetService("Players") end)
    if ok and ps then
        info.CharacterAutoLoads = ps.CharacterAutoLoads
        info.RespawnTime = ps.RespawnTime
    end
    return info
end

-- [79] Developer Product
local function collectDeveloperInfo()
    local MPS = safeGetService("MarketplaceService")
    local info = { available = true }
    if MPS then
        local ok, info2 = pcall(function() return MPS:GetProductInfo(game.PlaceId) end)
        if ok and info2 then info.GameProductInfo = info2 end
    end
    return info
end

-- [80] Game Mode
local function collectGameModeInfo()
    local info = { available = true }
    info.GameId = game.GameId
    info.PlaceId = game.PlaceId
    info.JobId = game.JobId
    info.PlaceVersion = game.PlaceVersion
    info.CreatorId = game.CreatorId
    info.CreatorType = tostring(game.CreatorType)
    info.GameName = game.Name
    return info
end

-- [81] Game Attributes
local function collectGameAttributes()
    local info = { available = true }
    local attrs = {}
    local ok, all = pcall(function() return game:GetAttributes() end)
    if ok and type(all) == "table" then
        for k, v in pairs(all) do attrs[k] = tostring(v) end
    end
    info.GameAttributes = attrs
    return info
end

-- [82] Player Attributes
local function collectPlayerAttributes()
    local Players = safeGetService("Players")
    local info = { available = true }
    if Players and Players.LocalPlayer then
        local attrs = {}
        local ok, all = pcall(function() return Players.LocalPlayer:GetAttributes() end)
        if ok and type(all) == "table" then
            for k, v in pairs(all) do attrs[k] = tostring(v) end
        end
        info.PlayerAttributes = attrs
    end
    return info
end

-- [83] Workspace Tags
local function collectWorkspaceTags()
    local Workspace = safeGetService("Workspace")
    local info = { available = true }
    if Workspace then
        local ok, tags = pcall(function() return Workspace:GetTags() end)
        if ok then info.WorkspaceTags = tags end
    end
    return info
end

-- [84] Debug Func Info
local function collectDebugFuncInfo()
    local info = { available = true }
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local checks = { "getfenv", "setfenv", "loadstring", "load", "require", "pcall", "xpcall", "print", "warn", "error" }
        info.NativeFuncs = {}
        for _, name in ipairs(checks) do
            local fn = ENV[name] or _G[name]
            if type(fn) == "function" then
                local ok, inf = pcall(debug.getinfo, fn, "S")
                if ok and type(inf) == "table" then
                    info.NativeFuncs[name] = { what = inf.what, name = inf.name, source = tostring(inf.source):sub(1, 80) }
                end
            end
        end
    end
    return info
end

-- [85] Keybindings
local function collectKeybindings()
    local UIS = safeGetService("UserInputService")
    local info = { available = true }
    if UIS then
        local keys = {}
        for _, k in ipairs({"W","A","S","D","Space","Shift","Q","E","R","F","G","H","Z","X","C","V","B","N","M"}) do
            local ok, isDown = pcall(function() return UIS:IsKeyDown(Enum.KeyCode[k]) end)
            if ok then keys[k] = isDown end
        end
        info.KeyStates = keys
    end
    return info
end

-- [86] Input States
local function collectInputStates()
    local UIS = safeGetService("UserInputService")
    local info = { available = true }
    if UIS then
        info.InputBegan = UIS.InputBegan ~= nil
        info.InputChanged = UIS.InputChanged ~= nil
        info.InputEnded = UIS.InputEnded ~= nil
        info.TouchStarted = UIS.TouchStarted ~= nil
        info.TouchMoved = UIS.TouchMoved ~= nil
        info.TouchEnded = UIS.TouchEnded ~= nil
        info.InputFired = UIS.InputFired ~= nil
    end
    return info
end

-- [87] Physics Perf
local function collectPhysicsPerf()
    local info = { available = true }
    local Stats = safeGetService("Stats")
    if Stats then info.ContactsCount = safeProp(Stats, "ContactsCount") end
    return info
end

-- [88] Heap
local function collectHeapInfo()
    local info = { available = true }
    if type(collectgarbage) == "function" then
        local ok, count = pcall(collectgarbage, "count")
        if ok then info.Kilobytes = count; info.Megabytes = count / 1024 end
    end
    return info
end

-- [89] Global Vars
local function collectGlobalVars()
    local info = { available = true }
    local whitelist = {
        "game","workspace","script","Enum","Instance","Vector3","Vector2","CFrame",
        "Color3","BrickColor","UDim","UDim2","Ray","Region3","TweenInfo","NumberRange",
        "NumberSequence","ColorSequence","Rect","Faces","Axes","Random","Tick",
    }
    local present = {}
    for _, name in ipairs(whitelist) do
        if _G[name] then present[name] = true end
    end
    info.Present = present
    return info
end

-- [90] Meta Modifications
local function collectMetaModifications()
    local info = { available = true }
    if type(getrawmetatable) == "function" then
        local targets = { "game", "workspace" }
        info.Modified = {}
        for _, name in ipairs(targets) do
            local obj = name == "game" and game or safeGetService("Workspace")
            if obj then
                local ok, mt = pcall(getrawmetatable, obj)
                if ok and mt then
                    local metaCount = 0
                    for _ in pairs(mt) do metaCount = metaCount + 1 end
                    info.Modified[name] = metaCount
                end
            end
        end
    end
    return info
end

-- [91] Time Sources
local function collectTimeSources()
    local info = { available = true }
    if type(time) == "function" then local ok, t = pcall(time); if ok then info.time = t end end
    if type(tick) == "function" then local ok, t = pcall(tick); if ok then info.tick = t end end
    if type(elapsedTime) == "function" then local ok, t = pcall(elapsedTime); if ok then info.elapsedTime = t end end
    if type(os) == "table" and type(os.clock) == "function" then local ok, t = pcall(os.clock); if ok then info.os_clock = t end end
    if type(os) == "table" and type(os.time) == "function" then local ok, t = pcall(os.time); if ok then info.os_time = t end end
    if type(DateTime) == "table" and type(DateTime.now) == "function" then
        local ok, d = pcall(function() return DateTime.now().UnixTimestampMillis end)
        if ok then info.DateTimeNow = d end
    end
    return info
end

-- [92] Upvalues
local function collectUpvalueInfo()
    local info = { available = true }
    if type(debug) == "table" and type(debug.getupvalue) == "function" and type(getgc) == "function" then
        local ok, gc = pcall(getgc, true)
        if ok and type(gc) == "table" then
            local upvalueCount = 0
            for i, fn in ipairs(gc) do
                if i > 100 then break end
                if type(fn) == "function" then
                    pcall(function()
                        for j = 1, 5 do
                            local n = debug.getupvalue(fn, j)
                            if n then upvalueCount = upvalueCount + 1 end
                        end
                    end)
                end
            end
            info.SampleUpvalues = upvalueCount
        end
    end
    return info
end

-- [93] Sandbox Verification
local function collectSandboxVerification()
    local info = { available = true }
    info.IsSandboxed = false
    local ok = pcall(function() return getfenv(0) end)
    info.CanGetEnv0 = ok
    local ok2 = pcall(function() return setfenv(0, {}) end)
    info.CanSetEnv0 = ok2
    return info
end

-- [94] Executor Modules
local function collectExecutorModules()
    local info = { available = true }
    if type(getloadedmodules) == "function" then
        local ok, mods = pcall(getloadedmodules)
        if ok and type(mods) == "table" then
            local modNames = {}
            for _, m in ipairs(mods) do
                local ok2, n = pcall(function() return m.Name end)
                if ok2 and n then table.insert(modNames, n) end
            end
            info.ModuleNames = modNames
        end
    end
    return info
end

-- [95] Thread Guards
local function collectThreadGuards()
    local info = { available = true }
    local ok, id = pcall(function() return getthreadidentity and getthreadidentity() or nil end)
    info.Identity = ok and id or nil
    local ok2, caller = pcall(function() return checkcaller and checkcaller() or nil end)
    info.IsCaller = ok2 and caller or nil
    return info
end

-- [96] Shared Info
local function collectSharedInfo()
    local info = { available = true }
    if type(shared) == "table" then
        local count = 0
        for k, v in pairs(shared) do
            count = count + 1
            if type(v) == "function" then
                info[tostring(k)] = "function"
            elseif type(v) == "table" then
                info[tostring(k)] = "table"
            else
                info[tostring(k)] = tostring(v):sub(1, 80)
            end
        end
        info._TotalCount = count
    end
    return info
end

-- [97] Frame Stats
local function collectFrameStats()
    local info = { available = true }
    local Stats = safeGetService("Stats")
    if Stats then
        info.FrameTime = safeProp(Stats, "FrameTime")
        info.RenderCPUFrameTime = safeProp(Stats, "RenderCPUFrameTime")
        info.RenderGPUFrameTime = safeProp(Stats, "RenderGPUFrameTime")
        info.HeartbeatTime = safeProp(Stats, "HeartbeatTime")
        info.PhysicsStepTime = safeProp(Stats, "PhysicsStepTime")
    end
    return info
end

-- [98] Fingerprint
local function collectFingerprintInfo()
    local info = { available = true }
    local HttpService = safeGetService("HttpService")
    if HttpService and type(HttpService.GenerateGUID) == "function" then
        local ok, guid = pcall(function() return HttpService:GenerateGUID(false) end)
        if ok then info.RobloxGUID = guid end
    end
    return info
end

-- [99] Instance Classes
local function collectInstanceClassInfo()
    local info = { available = true }
    local classes = { "Instance", "Part", "Model", "Folder", "Script", "LocalScript", "ModuleScript",
        "Sound", "Animation", "MeshPart", "UnionOperation", "WedgePart", "SpawnLocation" }
    for _, name in ipairs(classes) do
        if _G[name] then info[name] = "Present" end
    end
    return info
end

-- [100] Client State
local function collectClientState()
    local info = { available = true }
    info.UptimeSeconds = CLOCK()
    info.Timestamp = os.time and os.time() or 0
    info.RobloxVersion = (type(version) == "function") and select(1, version()) or "Unknown"
    return info
end

--================================================================
-- [2] RECOPILACIÓN Y REPORTE FINAL
--================================================================

local function collectAllInfo()
    local t0 = CLOCK()
    local report = {
        timestamp = (os.date and os.date("!%Y-%m-%dT%H:%M:%SZ")) or "Unknown",
        scanTimeMs = nil,
        executor = collectExecutorInfo(),
        stats = collectStatsInfo(),
        input = collectInputInfo(),
        gui = collectGuiInfo(),
        logs = collectLogInfo(),
        network = collectNetworkInfo(),
        storage = collectStorageInfo(),
        gc = collectGCInfo(),
        metatable = collectMetatableInfo(),
        injection = collectInjectionInfo(),
        vr = collectVRInfo(),
        text = collectTextInfo(),
        policy = collectPolicyInfo(),
        chat = collectChatInfo(),
        core = collectCoreInfo(),
        userSettings = collectUserSettingsInfo(),
        additionalServices = collectAdditionalServices(),
        performance = collectPerformanceInfo(),
        memory = collectMemoryInfo(),
        scripts = collectScriptInfo(),
        networkDeep = collectNetworkDeepInfo(),
        workspace = collectWorkspaceInfo(),
        camera = collectCameraInfo(),
        mouse = collectMouseInfo(),
        character = collectCharacterInfo(),
        sound = collectSoundInfo(),
        physics = collectPhysicsInfo(),
        terrain = collectTerrainInfo(),
        replicatedStorage = collectReplicatedStorageInfo(),
        replicatedFirst = collectReplicatedFirstInfo(),
        contextAction = collectContextActionInfo(),
        tags = collectTagsInfo(),
        badges = collectBadgeInfo(),
        avatar = collectAvatarInfo(),
        networkOwnership = collectNetworkOwnershipInfo(),
        hierarchy = collectInstanceHierarchyInfo(),
        sandboxing = collectSandboxingInfo(),
        libraryIntegrity = collectLibraryIntegrityInfo(),
        commonMetatables = collectCommonMetatablesInfo(),
        executorCapabilities = collectExecutorCapabilities(),
        antiCheat = collectAntiCheatInfo(),
        robloxVersion = collectRobloxVersionInfo(),
        clock = collectClockInfo(),
        platform = collectPlatformInfo(),
        userAgent = collectUserAgentInfo(),
        textChat = collectTextChatChannelsInfo(),
        asset = collectAssetInfo(),
        gamepass = collectGamePassInfo(),
        exploitDetection = collectExploitDetection(),
        systemPerf = collectSystemPerfInfo(),
        serviceNames = collectServiceNamesInfo(),
        globalHooks = collectGlobalHooksInfo(),
        rateLimit = collectRateLimitInfo(),
        window = collectWindowInfo(),
        starterPlayer = collectStarterPlayerInfo(),
        ad = collectAdInfo(),
        haptic = collectHapticInfo(),
        networkStats = collectNetworkStats(),
        group = collectGroupInfo(),
        threads = collectThreadInfo(),
        luaMemory = collectLuaMemoryInfo(),
        identity = collectIdentityInfo(),
        scriptPerf = collectScriptPerfInfo(),
        remotes = collectRemoteInfo(),
        starterGuiDeep = collectStarterGuiDeepInfo(),
        soundDeep = collectSoundDeepInfo(),
        debris = collectDebrisInfo(),
        tween = collectTweenInfo(),
        pathfinding = collectPathfindingInfo(),
        proximity = collectProximityInfo(),
        clickDetectors = collectClickDetectorInfo(),
        particles = collectParticleInfo(),
        guiObjects = collectGuiObjectInfo(),
        animations = collectAnimationInfo(),
        networkPing = collectNetworkPing(),
        avatarLoaded = collectAvatarLoadedInfo(),
        streaming = collectStreamingInfo(),
        save = collectSaveInfo(),
        developer = collectDeveloperInfo(),
        gameMode = collectGameModeInfo(),
        gameAttributes = collectGameAttributes(),
        playerAttributes = collectPlayerAttributes(),
        workspaceTags = collectWorkspaceTags(),
        debugFuncInfo = collectDebugFuncInfo(),
        keybindings = collectKeybindings(),
        inputStates = collectInputStates(),
        physicsPerf = collectPhysicsPerf(),
        heap = collectHeapInfo(),
        globalVars = collectGlobalVars(),
        metaMods = collectMetaModifications(),
        timeSources = collectTimeSources(),
        upvalues = collectUpvalueInfo(),
        sandboxVerify = collectSandboxVerification(),
        executorModules = collectExecutorModules(),
        threadGuards = collectThreadGuards(),
        sharedInfo = collectSharedInfo(),
        frameStats = collectFrameStats(),
        fingerprint = collectFingerprintInfo(),
        instanceClasses = collectInstanceClassInfo(),
        clientState = collectClientState(),
    }
    report.scanTimeMs = (CLOCK() - t0) * 1000
    return report
end

local function printReport(report, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    for key, value in pairs(report) do
        if type(value) == "table" then
            print(prefix .. tostring(key) .. ":")
            printReport(value, indent + 1)
        else
            print(prefix .. tostring(key) .. " = " .. tostring(value))
        end
    end
end

local finalReport = collectAllInfo()

print("==================================================")
print("  REPORTE DE AUDITORIA FORENSE ULTRA v7.2         ")
print("  Modulos: 100+                                   ")
print("==================================================")
printReport(finalReport)
print("==================================================")
print("  FIN DEL REPORTE FORENSE                         ")
print("==================================================")

-- Exportación JSON Segura (Opcional)
local HttpService = safeGetService("HttpService")
if HttpService and type(HttpService.JSONEncode) == "function" then
    local ok, json = pcall(function() return HttpService:JSONEncode(finalReport) end)
    if ok then
        print("\n[JSON Export] Longitud: " .. #json .. " caracteres")
    end
end

return finalReport
