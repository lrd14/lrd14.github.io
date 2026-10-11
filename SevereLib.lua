local modules = {}
local loaded = {}
local function import(name)
    local cached = loaded[name]
    if cached ~= nil then
        return cached
    end
    local build = modules[name]
    if not build then
        error("module is missing: " .. tostring(name))
    end
    local value = build(import)
    loaded[name] = value
    return value
end
modules["core/anim"] = function(...)

local import: (string) -> any = ...
local Util: typeof(require("./util")) = import("core/util")

local Anim = {}

type Map = { [string]: any }

function Anim.ease(state: Map, from: number, to: number, dt: number, speed: number): number
    if state.HighPerformanceMode then
        return to
    end
    local start, goal, step = Util.finite(from, 0), Util.finite(to, 0), Util.finite(dt, 0.01)
    return start + (goal - start) * (1 - math.exp(-speed * step))
end

function Anim.spring(state: Map, current: number, target: number, velocity: number, dt: number, stiffness: number, damping: number): (number, number)
    if state.HighPerformanceMode then
        return target, 0
    end
    local force = -stiffness * (current - target) - damping * velocity
    local nextVelocity = velocity + force * dt
    return current + nextVelocity * dt, nextVelocity
end

return Anim
end
modules["core/util"] = function(...)

local Util = {}

local WHITE = Color3.new(1, 1, 1)

function Util.finite(value: any, fallback: number?): number
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback or 0
    end
    return value
end

function Util.vector(value: Vector2?, fallback: Vector2?): Vector2
    if not value then
        return fallback or Vector2.new(0, 0)
    end
    return Vector2.new(Util.finite(value.X), Util.finite(value.Y))
end

function Util.lerp(from: number, to: number, alpha: number): number
    local start = Util.finite(from)
    return start + (Util.finite(to) - start) * Util.finite(alpha)
end

function Util.lerpVector(from: Vector2, to: Vector2, alpha: number): Vector2
    return Vector2.new(from.X + (to.X - from.X) * alpha, from.Y + (to.Y - from.Y) * alpha)
end

function Util.lerpColor(from: Color3?, to: Color3?, alpha: number): Color3
    if not from or not to then
        return WHITE
    end
    return Color3.new(from.R + (to.R - from.R) * alpha, from.G + (to.G - from.G) * alpha, from.B + (to.B - from.B) * alpha)
end

function Util.lighten(color: Color3, amount: number): Color3
    return Color3.new(
        math.clamp(color.R + (1 - color.R) * amount, 0, 1),
        math.clamp(color.G + (1 - color.G) * amount, 0, 1),
        math.clamp(color.B + (1 - color.B) * amount, 0, 1)
    )
end

function Util.round(vector: Vector2): Vector2
    return Vector2.new(math.floor(vector.X + 0.5), math.floor(vector.Y + 0.5))
end

function Util.contains(point: Vector2, position: Vector2, size: Vector2): boolean
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function Util.toHex(color: any): string
    if type(color) == "string" then
        return color
    end
    local r = math.clamp(math.floor((color.R or 0) * 255), 0, 255)
    local g = math.clamp(math.floor((color.G or 0) * 255), 0, 255)
    local b = math.clamp(math.floor((color.B or 0) * 255), 0, 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

function Util.fromHex(text: any): Color3?
    if type(text) ~= "string" then
        return nil
    end
    local digits = string.gsub(text, "#", "")
    if #digits ~= 6 then
        return nil
    end
    local r = tonumber(string.sub(digits, 1, 2), 16)
    local g = tonumber(string.sub(digits, 3, 4), 16)
    local b = tonumber(string.sub(digits, 5, 6), 16)
    if r and g and b then
        return Color3.fromRGB(r, g, b)
    end
    return nil
end

function Util.read(object: any, key: string): any
    local ok, value = pcall(function()
        return object[key]
    end)
    if ok then
        return value
    end
    return nil
end

return Util
end
modules["modules/blocker"] = function(...)

local MOVEMENT_KEYS = {
    { Name = "W", Code = 0x57 },
    { Name = "A", Code = 0x41 },
    { Name = "S", Code = 0x53 },
    { Name = "D", Code = 0x44 },
    { Name = "Up", Code = 0x26 },
    { Name = "Down", Code = 0x28 },
    { Name = "Left", Code = 0x25 },
    { Name = "Right", Code = 0x27 },
    { Name = "Space", Code = 0x20 },
}
local MOVE_SLACK = 0.5
local IDLE_RELEASE = 1.0
local DEFAULT_INTERVAL = 0.016

local BlockWindow: any = {}
BlockWindow.__index = BlockWindow

local blocked = false

local function pressedKeys()
    local names = {}
    local ok, pressed = pcall(getpressedkeys)
    if ok and type(pressed) == "table" then
        for _, name in ipairs(pressed) do
            names[name] = true
        end
    end
    return names
end

local function syncMovementKeys(entering)
    local held = entering and {} or pressedKeys()
    for _, key in ipairs(MOVEMENT_KEYS) do
        if held[key.Name] then
            pcall(keypress, key.Code)
        else
            pcall(keyrelease, key.Code)
        end
    end
end

local function playerIsSteering(keys)
    local ok, rightDown = pcall(isrightpressed)
    if ok and rightDown == true then
        return true
    end
    for _, key in ipairs(MOVEMENT_KEYS) do
        if keys[key.Name] then
            return true
        end
    end
    return false
end

function BlockWindow.SetBlocked(state)
    local wanted = state == true
    if wanted == blocked then
        return
    end
    blocked = wanted
    pcall(block_roblox_window, wanted)
    syncMovementKeys(wanted)
end

function BlockWindow.Enable()
    BlockWindow.SetBlocked(true)
end

function BlockWindow.Disable()
    BlockWindow.SetBlocked(false)
end

function BlockWindow.Toggle()
    BlockWindow.SetBlocked(not blocked)
end

function BlockWindow.IsBlocked()
    return blocked
end

function BlockWindow.GetMousePosition(dpiScale)
    local scale = dpiScale or _G.DPIScale or 1
    local ok, position = pcall(getmouseposition)
    if ok and position then
        return position * scale
    end
    local service = game:GetService("UserInputService")
    local fallbackOk, fallback = pcall(function()
        return service:GetMouseLocation()
    end)
    if fallbackOk and fallback then
        return fallback * scale
    end
    return Vector2.new(0, 0)
end

function BlockWindow.IsMouseOver(position, size, mouse)
    local point = mouse or BlockWindow.GetMousePosition()
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function overAnyBounds(point, first, second)
    if type(first) == "table" and first[1] ~= nil then
        for _, bounds in ipairs(first) do
            if BlockWindow.IsMouseOver(bounds.Pos, bounds.Size, point) then
                return true
            end
        end
        return false
    end
    return first ~= nil and second ~= nil and BlockWindow.IsMouseOver(first, second, point)
end

function BlockWindow.New(options)
    local settings = options or {}
    local self = {
        GetBounds = settings.GetBounds,
        IsVisible = settings.IsVisible or function()
            return true
        end,
        IsOverControl = settings.IsOverControl,
        Enabled = settings.Enabled ~= false,
        Steering = settings.Steering ~= false,
        Interval = settings.Interval or DEFAULT_INTERVAL,
        LastMouse = nil,
        MovedAt = 0,
        Thread = nil,
    }
    return setmetatable(self, BlockWindow)
end

function BlockWindow:Update()
    if not self.Enabled or not self.IsVisible() then
        BlockWindow.SetBlocked(false)
        return
    end
    local mouse = BlockWindow.GetMousePosition()
    local now = os.clock()
    local last = self.LastMouse
    if not last or (mouse.X - last.X) ^ 2 + (mouse.Y - last.Y) ^ 2 > MOVE_SLACK * MOVE_SLACK then
        self.LastMouse = mouse
        self.MovedAt = now
    end

    local first, second = self.GetBounds()
    if not overAnyBounds(mouse, first, second) then
        BlockWindow.SetBlocked(false)
        return
    end
    if self.Steering and playerIsSteering(pressedKeys()) then
        BlockWindow.SetBlocked(false)
        return
    end
    local overControl = self.IsOverControl ~= nil and self.IsOverControl(mouse) == true
    local recent = now - self.MovedAt < IDLE_RELEASE
    BlockWindow.SetBlocked(overControl or recent)
end

function BlockWindow:Start()
    if self.Thread then
        return
    end
    self.Thread = task.spawn(function()
        while self.Thread do
            pcall(self.Update, self)
            task.wait(self.Interval)
        end
    end)
end

function BlockWindow:Stop()
    local thread = self.Thread
    self.Thread = nil
    if thread then
        pcall(task.cancel, thread)
    end
    BlockWindow.SetBlocked(false)
end

return BlockWindow
end
modules["modules/chat"] = function(...)

local OFFSETS_URL = "https://offsets.imtheo.lol/Offsets.hpp"
local PATTERN_NAMESPACE = "^%s*namespace%s+(%w+)%s*{"
local PATTERN_FIELD = "inline%s+constexpr%s+uintptr_t%s+(%w+)%s*=%s*(0x%x+)"
local DATA_MODEL_TYPE = "RBX::DataModel"
local CHAT_BAR_NAMESPACES = { "ChatInputBarConfiguration", "ChatInputBarConfig", "TextChatInputBarConfiguration" }
local FOCUS_FIELDS = { "IsFocused", "Focused", "IsActive", "Active" }

type Map = { [string]: any }

local function parse(text: string): Map
    local result: Map = {}
    local current: string? = nil
    for line in string.gmatch(text, "[^\n]+") do
        local namespace = string.match(line, PATTERN_NAMESPACE)
        if namespace then
            current = namespace
            result[namespace] = result[namespace] or {}
        elseif string.match(line, "^%s*}") then
            current = nil
        elseif current then
            local name, hex = string.match(line, PATTERN_FIELD)
            local value = hex and tonumber(hex)
            if name and value then
                result[current][name] = value
            end
        end
    end
    return result
end

local function trusted(candidate: Map): boolean
    local instance = candidate.Instance
    local parentOffset = instance and instance.Parent
    if type(parentOffset) ~= "number" then
        return false
    end
    local ok, result = pcall(function()
        local address = memory.readu64(workspace, parentOffset)
        if not address or address == 0 then
            return false
        end
        local parent = pointer_to_userdata(address)
        if not parent then
            return false
        end
        return parent == game or memory.rtti(parent, 0) == DATA_MODEL_TYPE
    end)
    return ok and result == true
end

local function loadOffsets(): Map?
    local ok, text = pcall(function()
        return game:HttpGet(OFFSETS_URL)
    end)
    if ok and type(text) == "string" then
        local latest = parse(text)
        if trusted(latest) then
            return latest
        end
    end
    return nil
end

local offsets = loadOffsets()

if not offsets then
    return nil
end

local userInputService: any = nil
local chatInputBar: any = nil

pcall(function()
    userInputService = game:GetService("UserInputService")
end)

pcall(function()
    local service = game:FindFirstChildOfClass("TextChatService")
    chatInputBar = service and service:FindFirstChild("ChatInputBarConfiguration")
end)

local function textBoxFocused(): boolean?
    local inputNames = offsets.UserInputService
    local stateNames = offsets.WindowInputState
    if not userInputService or type(inputNames) ~= "table" or type(stateNames) ~= "table" then
        return nil
    end
    local stateOffset = inputNames.WindowInputState
    local textBoxOffset = stateNames.CurrentTextBox
    if type(stateOffset) ~= "number" or type(textBoxOffset) ~= "number" then
        return nil
    end
    local ok, result = pcall(function()
        local state = memory.readu64(userInputService, stateOffset)
        if not state or state == 0 then
            return false
        end
        local textBox = memory.readu64(state + textBoxOffset)
        return textBox ~= nil and textBox ~= 0
    end)
    if not ok then
        return nil
    end
    return result == true
end

local function focusOffsetOf(names: Map): number?
    for _, field in ipairs(FOCUS_FIELDS) do
        if type(names[field]) == "number" then
            return names[field]
        end
    end
    return nil
end

local function chatBarFocused(): boolean?
    if not chatInputBar then
        return nil
    end
    for _, namespace in ipairs(CHAT_BAR_NAMESPACES) do
        local names = offsets[namespace]
        local focusOffset = if type(names) == "table" then focusOffsetOf(names) else nil
        if focusOffset then
            local ok, value = pcall(memory.readbool, chatInputBar, focusOffset)
            if ok then
                return value == true
            end
        end
    end
    return nil
end

local ChatCheck: Map = {}

ChatCheck.Offsets = offsets

function ChatCheck.IsTyping()
    local focused = textBoxFocused()
    if focused ~= nil then
        return focused
    end
    return chatBarFocused() == true
end

ChatCheck.IsChatFocused = ChatCheck.IsTyping

return ChatCheck :: any
end
modules["modules/keys"] = function(...)

local MODIFIER_PRIORITY = { "RightAlt", "LeftAlt", "RightCtrl", "LeftCtrl", "RightShift", "LeftShift" }
local POLL_RELEASE = 0.01
local POLL_CAPTURE = 0.005

local ALIASES = {
    MouseButton1 = "LeftMouse",
    Mouse1 = "LeftMouse",
    LButton = "LeftMouse",
    LeftButton = "LeftMouse",
    LeftMouseButton = "LeftMouse",
    MouseButton2 = "RightMouse",
    Mouse2 = "RightMouse",
    RButton = "RightMouse",
    RightButton = "RightMouse",
    RightMouseButton = "RightMouse",
    LShift = "LeftShift",
    RShift = "RightShift",
    LCtrl = "LeftCtrl",
    RCtrl = "RightCtrl",
    LeftControl = "LeftCtrl",
    RightControl = "RightCtrl",
    LControl = "LeftCtrl",
    RControl = "RightCtrl",
    Control = "Ctrl",
    LAlt = "LeftAlt",
    RAlt = "RightAlt",
    LeftMenu = "LeftAlt",
    RightMenu = "RightAlt",
}

type KeySet = { [string]: boolean? }
type Options = { [string]: any }

local KeybindInput = {}

local function normalize(key: any): string
    local name = tostring(key or "")
    return ALIASES[name] or name
end

local function dropGenericModifiers(keys: KeySet): KeySet
    if keys.LeftShift or keys.RightShift then
        keys.Shift = nil
    end
    if keys.LeftCtrl or keys.RightCtrl then
        keys.Ctrl = nil
        keys.Control = nil
    end
    if keys.LeftAlt or keys.RightAlt then
        keys.Alt = nil
    end
    return keys
end

local function readButton(read: () -> any): boolean
    local ok, down = pcall(read)
    return ok and down == true
end

local function keyboardSet(): KeySet
    local keys: KeySet = {}
    local ok, pressed = pcall(getpressedkeys)
    if ok and type(pressed) == "table" then
        for index = 1, #pressed do
            local key = normalize(pressed[index])
            if key ~= "" and key ~= "LeftMouse" and key ~= "RightMouse" then
                keys[key] = true
            end
        end
    end
    return dropGenericModifiers(keys)
end

local function inputSet(includeMouse: boolean?): KeySet
    local keys = keyboardSet()
    if includeMouse ~= false then
        if readButton(isleftpressed) then
            keys.LeftMouse = true
        end
        if readButton(isrightpressed) then
            keys.RightMouse = true
        end
    end
    return keys
end

local function anyDown(keys: KeySet): boolean
    return next(keys) ~= nil
end

local function findNew(keys: KeySet, previous: KeySet): string?
    for _, key in ipairs(MODIFIER_PRIORITY) do
        if keys[key] and not previous[key] then
            return key
        end
    end
    for key in pairs(keys) do
        if not previous[key] then
            return key
        end
    end
    return nil
end

local function timedOut(started: number, timeout: number?): boolean
    return timeout ~= nil and os.clock() - started >= timeout
end

local function captureSettings(options: Options?): (boolean, number?, string?)
    local settings: Options = options or {}
    local cancelKey = settings.CancelKey and normalize(settings.CancelKey) or nil
    return settings.Mouse ~= false, tonumber(settings.Timeout), cancelKey
end

local function awaitKey(options: Options?, isCancelled: () -> boolean): (string?, string?)
    local includeMouse, timeout, cancelKey = captureSettings(options)
    local started = os.clock()

    while not isCancelled() and anyDown(inputSet(includeMouse)) do
        if timedOut(started, timeout) then
            return nil, "timeout"
        end
        task.wait(POLL_RELEASE)
    end

    local previous: KeySet = {}
    while not isCancelled() do
        local keys = inputSet(includeMouse)
        local key = findNew(keys, previous)
        if key then
            if cancelKey and key == cancelKey then
                return nil, "cancelled"
            end
            return key
        end
        previous = keys
        if timedOut(started, timeout) then
            return nil, "timeout"
        end
        task.wait(POLL_CAPTURE)
    end
    return nil, "cancelled"
end

local function never(): boolean
    return false
end

function KeybindInput.Normalize(key: any): string
    return normalize(key)
end

function KeybindInput.GetPressed(includeMouse: boolean?): KeySet
    return inputSet(includeMouse)
end

function KeybindInput.IsDown(key: any): boolean
    local name = normalize(key)
    if name == "LeftMouse" then
        return readButton(isleftpressed)
    elseif name == "RightMouse" then
        return readButton(isrightpressed)
    end
    return keyboardSet()[name] == true
end

function KeybindInput.WaitForRelease(includeMouse: boolean?, timeout: number?): boolean
    local started = os.clock()
    while true do
        if not anyDown(inputSet(includeMouse)) then
            return true
        end
        if timedOut(started, timeout) then
            return false
        end
        task.wait(POLL_RELEASE)
    end
end

function KeybindInput.Capture(options: Options?): (string?, string?)
    return awaitKey(options, never)
end

function KeybindInput.CaptureAsync(callback: ((string?, string?) -> ())?, options: Options?): any
    local handle: any = { Cancelled = false }

    task.spawn(function()
        local key, reason = awaitKey(options, function()
            return handle.Cancelled
        end)
        if callback and not handle.Cancelled then
            callback(key, reason)
        end
    end)

    function handle:Cancel()
        self.Cancelled = true
    end

    return handle
end

function KeybindInput.New(defaultKey: any): any
    local object: any = {
        Key = normalize(defaultKey or "None"),
        PreviousDown = false,
    }

    function object:Set(key)
        self.Key = normalize(key)
    end

    function object:Get()
        return self.Key
    end

    function object:IsDown()
        return KeybindInput.IsDown(self.Key)
    end

    function object:Pressed()
        local down = self:IsDown()
        local pressed = down and not self.PreviousDown
        self.PreviousDown = down
        return pressed
    end

    function object:Capture(options)
        local key, reason = KeybindInput.Capture(options)
        if key then
            self.Key = key
        end
        return key, reason
    end

    function object:CaptureAsync(callback, options)
        return KeybindInput.CaptureAsync(function(key, reason)
            if key then
                self.Key = key
            end
            if callback then
                callback(key, reason)
            end
        end, options)
    end

    return object
end

return KeybindInput
end
modules["popups/builtin"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local Shared: typeof(require("./shared")) = import("popups/shared")
local State: typeof(require("../state/state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")
local View: typeof(require("../ui/view")) = import("ui/view")

local Builtin = {}

type Map = { [string]: any }

local theme = State.THEME
local TEXT_BASELINE = 6.5

local PERFORMANCE_LINES = {
    "If you continue, the script will unload the current",
    "UI and load a low end one which has no animations",
    "and some customization features removed to improve",
    "performance, this is only recommended if you have",
    "a low end device or low performance.",
}
local FONTS_PER_PAGE = 16
local FONT_PAGES = 2
local LAST_FONT = 31

local function square(win: Map, z: number, rounding: number?): any
    return win.Pool:square(true, theme.PanelBg, 0, z, rounding)
end

local function text(win: Map, z: number, center: boolean?): any
    return win.Pool:text("", 13, center, theme.TextMain, z)
end

local function slider(win: Map, label: string): Map
    return {
        Bg = square(win, 22, 16),
        FillBg = win.Pool:square(true, theme.BgBase, 0, 23, 8),
        Fill = win.Pool:square(true, theme.Accent, 0, 24, 8),
        ValBg = win.Pool:square(true, theme.BgBase, 0, 23, 12),
        ValTxt = win.Pool:text("0", 13, true, theme.TextMain, 25),
        Txt = win.Pool:text(label, 13, false, theme.TextMain, 25),
    }
end

local function pair(win: Map, z: number): Map
    return { Bg = square(win, z, 16), Txt = text(win, z + 1, true) }
end

local function confirmRow(env: Map, parts: Map, popupName: string, onConfirm: () -> ())
    local win, view, popup, alpha = env.Win, env.View, env.Popup, env.Alpha
    local gap, height = 15, 28
    local width = (popup.Width - gap * 3) / 2
    local y = popup.Height - 45
    local yesPosition, yesSize = Shared.button(win, view, popup, {
        Key = popupName .. "Yes", X = gap, Y = y, Width = width, Height = height, Label = "Confirm", Alpha = alpha,
        Bg = parts.YesBg, Txt = parts.YesTxt, Popup = popupName,
    })
    local noPosition, noSize = Shared.button(win, view, popup, {
        Key = popupName .. "No", X = gap * 2 + width, Y = y, Width = width, Height = height, Label = "Cancel", Alpha = alpha,
        Bg = parts.NoBg, Txt = parts.NoTxt, Popup = popupName,
    })
    win:region(yesPosition, yesSize, { Click = onConfirm })
    win:region(noPosition, noSize, { Click = function()
        win.State.TargetPopup = "None"
    end })
end

function Builtin.closeButton(env: Map, parts: Map, onClose: () -> ())
    local win, view, popup = env.Win, env.View, env.Popup
    local position, size = Shared.button(win, view, popup, {
        Key = "Close", X = 10, Y = popup.Height - 38, Width = popup.Width - 20, Height = 28, Label = "Close", Alpha = env.Alpha,
        Bg = parts.CloseBg, Txt = parts.CloseTxt, Speed = 18, Shrink = 0.05,
    })
    win:region(position, size, { Click = onClose })
end

function Builtin.lines(env: Map, parts: { any }, lines: { string }, firstY: number)
    local y = firstY
    for index, line in lines do
        local part = parts[index]
        if part then
            Shared.text(env.View, env.Popup, part, env.Popup.Width / 2, y - 7, line, true, env.View.Pal.TextSub, env.Alpha)
            part.ZIndex = 26
            y += 16
        end
    end
end

local function drawSliderRow(env: Map, row: Map, y: number, label: string, fraction: number, shown: string, key: string, onDrag: (number) -> ())
    local win, view, popup, alpha = env.Win, env.View, env.Popup, env.Alpha
    local state, pal = win.State, view.Pal
    local rawPosition = View.popupPosition(popup, 15, y)
    local rawSize = View.popupSize(popup, popup.Width - 30, 40)
    local hovered = Util.contains(view.Mouse, rawPosition, rawSize) and state.TargetPopup == state.ActivePopup
    local position, size, press, _ = view:press(rawPosition, rawSize, hovered, win.PopAnim[key .. "Press"], 0.02)
    position, size = Util.vector(position, rawPosition), Util.vector(size, rawSize)
    win.PopAnim[key .. "Press"] = press
    local hover = Anim.ease(state, win.PopAnim[key] or 0, if hovered then 1 else 0, view.Dt, 16)
    win.PopAnim[key] = hover

    row.Bg.Visible, row.Bg.Position, row.Bg.Size = true, position, size
    Pool.alpha(row.Bg, alpha)
    row.Bg.Color = pal.Panel
    local labelOffset = View.popupSize(popup, 12, 5)
    row.Txt.Visible = true
    row.Txt.Position = Vector2.new(position.X + labelOffset.X, position.Y + labelOffset.Y)
    Pool.alpha(row.Txt, alpha)
    row.Txt.Text, row.Txt.Color, row.Txt.Center = label, pal.TextMain, false
    Pool.size(row.Txt, 13 * view.TextScale * popup.Morph)

    local barWidth = size.X - View.popupSize(popup, 65, 0).X
    local barHeight = View.popupSize(popup, 0, 4).Y
    local barOffset = View.popupSize(popup, 12, 28)
    local barPosition = Vector2.new(position.X + barOffset.X, position.Y + barOffset.Y)
    row.FillBg.Visible, row.FillBg.Position, row.FillBg.Size = true, barPosition, Vector2.new(barWidth, barHeight)
    Pool.alpha(row.FillBg, alpha)
    row.FillBg.Color = pal.Main
    row.Fill.Visible, row.Fill.Position = true, barPosition
    row.Fill.Size = Vector2.new(math.max(1, barWidth * fraction), barHeight)
    Pool.alpha(row.Fill, alpha)
    row.Fill.Color = Util.lighten(state.AccentCol, 0.25 * hover)

    local valueSize = View.popupSize(popup, 35, 18)
    local valueOffset = Vector2.new(size.X - View.popupSize(popup, 45, 0).X, View.popupSize(popup, 0, 17).Y)
    local valuePosition = Vector2.new(position.X + valueOffset.X, position.Y + valueOffset.Y)
    local valueHovered = Util.contains(view.Mouse, valuePosition, valueSize) and state.TargetPopup == state.ActivePopup
    local shownPosition, shownSize, valuePress, valueFactor = view:press(valuePosition, valueSize, valueHovered, win.PopAnim[key .. "ValPress"], 0.05)
    win.PopAnim[key .. "ValPress"] = valuePress
    local valueHover = Anim.ease(state, win.PopAnim[key .. "Val"] or 0, if valueHovered then 1 else 0, view.Dt, 16)
    win.PopAnim[key .. "Val"] = valueHover
    row.ValBg.Visible, row.ValBg.Position, row.ValBg.Size = true, shownPosition, shownSize
    Pool.alpha(row.ValBg, alpha)
    row.ValBg.Color = Util.lerpColor(pal.Main, state.AccentCol, 0.15 * valueHover)
    row.ValTxt.Visible = true
    row.ValTxt.Position = Vector2.new(shownPosition.X + shownSize.X / 2, shownPosition.Y + shownSize.Y / 2 - TEXT_BASELINE * view.TextScale * valueFactor * popup.Morph)
    Pool.alpha(row.ValTxt, alpha)
    row.ValTxt.Text, row.ValTxt.Color, row.ValTxt.Center = shown, pal.TextMain, true
    Pool.size(row.ValTxt, 13 * view.TextScale * valueFactor * popup.Morph)

    win:region(position, size, { Drag = function(mouse: Vector2)
        onDrag(math.clamp((mouse.X - row.FillBg.Position.X) / math.max(0.001, row.FillBg.Size.X), 0, 1))
    end, Release = if key == "Amount" then function()
        win:generateSnow()
    end else nil })
end

local function snowfall(win: Map): Map
    local parts: Map = {
        TogBg = square(win, 22, 16),
        TogKnob = win.Pool:square(true, theme.TextSub, 0, 23, 16),
        TogTxt = text(win, 25),
        ColBtn = square(win, 22, 16),
        ColTxt = text(win, 25, true),
        Size = slider(win, "Size"),
        Speed = slider(win, "Speed"),
        Amount = slider(win, "Amount"),
        Trans = slider(win, "Transparency"),
        CloseBg = square(win, 22, 16),
        CloseTxt = text(win, 23, true),
    }
    return {
        Name = "Snowfall",
        Title = "Snowfall Config",
        Width = 280,
        Height = 350,
        Parts = parts,
        Draw = function(env: Map)
            local view, popup, alpha = env.View, env.Popup, env.Alpha
            local state, pal = win.State, view.Pal
            local top = 48
            local togglePosition, toggleSize = View.popupPosition(popup, popup.Width - 55, top + 2), View.popupSize(popup, 40, 20)
            win.PopAnim.Tog = Anim.ease(state, win.PopAnim.Tog or 0, if state.Snowfall then 1 else 0, view.Dt, 16)
            parts.TogBg.Visible, parts.TogBg.Position, parts.TogBg.Size = true, togglePosition, toggleSize
            Pool.alpha(parts.TogBg, alpha)
            parts.TogBg.Color = Util.lerpColor(pal.AccentOff, state.AccentCol, win.PopAnim.Tog)
            Shared.text(view, popup, parts.TogTxt, 15, top + 5, "Enabled", false, pal.TextMain, alpha)
            parts.TogKnob.Visible, parts.TogKnob.Size = true, View.popupSize(popup, 10, 10)
            Pool.alpha(parts.TogKnob, alpha)
            parts.TogKnob.Position = View.popupPosition(popup, popup.Width - 55 + Util.lerp(3, 27, win.PopAnim.Tog), top + 7)
            parts.TogKnob.Color = Util.lerpColor(theme.TextSub, pal.Main, win.PopAnim.Tog)

            local colorPosition = View.popupPosition(popup, popup.Width - 35, top + 32)
            local colorSize = View.popupSize(popup, 20, 20)
            local colorHovered = Util.contains(view.Mouse, colorPosition, colorSize) and state.TargetPopup == "Snowfall"
            local pressedPosition, pressedSize, press = view:press(colorPosition, colorSize, colorHovered, win.PopAnim.ColPress, 0.05)
            win.PopAnim.ColPress = press
            parts.ColBtn.Visible, parts.ColBtn.Position, parts.ColBtn.Size = true, pressedPosition, pressedSize
            Pool.alpha(parts.ColBtn, alpha)
            parts.ColBtn.Color = state.SnowCol
            Shared.text(view, popup, parts.ColTxt, 15, top + 35, "Color:", false, pal.TextMain, alpha)

            win:region(togglePosition, toggleSize, { Click = function()
                state.Snowfall = not state.Snowfall
            end })
            win:region(pressedPosition, pressedSize, { Click = function()
                state.LastClickedPos = Vector2.new(popup.Final.X + popup.Width - 35, popup.Final.Y + 80)
                state.LastClickedSize = Vector2.new(20, 20)
                win:openColorPopup("SnowCol", "Snowfall")
            end })

            local y = top + 65
            drawSliderRow(env, parts.Size, y, "Size", math.clamp((state.SnowSize - 1) / 4, 0, 1), string.format("%.1f", state.SnowSize), "Size", function(fraction: number)
                state.SnowSize = 1 + fraction * 4
            end)
            drawSliderRow(env, parts.Speed, y + 45, "Speed", math.clamp((state.SnowSpeed - 5) / 45, 0, 1), tostring(math.floor(state.SnowSpeed)), "Speed", function(fraction: number)
                state.SnowSpeed = 5 + fraction * 45
            end)
            drawSliderRow(env, parts.Amount, y + 90, "Amount", math.clamp((state.SnowAmount - 10) / 90, 0, 1), tostring(math.floor(state.SnowAmount)), "Amount", function(fraction: number)
                state.SnowAmount = math.floor(10 + fraction * 90)
            end)
            drawSliderRow(env, parts.Trans, y + 135, "Transparency", math.clamp(state.SnowTrans, 0, 1), string.format("%.2f", state.SnowTrans), "Trans", function(fraction: number)
                state.SnowTrans = fraction
            end)
            Builtin.closeButton(env, parts, function()
                state.TargetPopup = "None"
            end)
        end,
    }
end

local function colorPopup(win: Map): Map
    local parts: Map = {
        PreviewBg = square(win, 24, 16),
        PreviewColor = square(win, 25, 16),
        Apply = pair(win, 24),
        Reset = pair(win, 24),
        Hex = pair(win, 24),
    }
    for _, name in { "R", "G", "B" } do
        parts[name] = { Lbl = text(win, 25), Bg = square(win, 24, 8), Fill = square(win, 25, 8) }
    end
    local channels = {
        { Key = "R", Label = "Red", Y = 40, Fill = Color3.fromRGB(255, 75, 75), Mode = "R" },
        { Key = "G", Label = "Green", Y = 80, Fill = Color3.fromRGB(75, 255, 75), Mode = "G" },
        { Key = "B", Label = "Blue", Y = 120, Fill = Color3.fromRGB(75, 125, 255), Mode = "B" },
    }
    return {
        Name = "Color",
        Title = "Color Mixer",
        Width = 320,
        Height = 205,
        Parts = parts,
        Draw = function(env: Map)
            local view, popup, alpha = env.View, env.Popup, env.Alpha
            local state, pal = win.State, view.Pal
            local picker = win.Picker
            local previewPosition = View.popupPosition(popup, 15, 40)
            parts.PreviewBg.Visible, parts.PreviewBg.Position, parts.PreviewBg.Size = true, previewPosition, View.popupSize(popup, 110, 110)
            Pool.alpha(parts.PreviewBg, alpha)
            parts.PreviewBg.Color = pal.Panel
            parts.PreviewColor.Visible, parts.PreviewColor.Position, parts.PreviewColor.Size = true, View.popupPosition(popup, 19, 44), View.popupSize(popup, 102, 102)
            Pool.alpha(parts.PreviewColor, alpha)
            parts.PreviewColor.Color = picker.Color

            local sx, sw = 140, 165
            for _, channel in channels do
                local part = parts[channel.Key]
                local value: number = picker.Color[channel.Key]
                Shared.text(view, popup, part.Lbl, sx, channel.Y, channel.Label .. ": " .. math.floor(value * 255), false, pal.TextMain, alpha)
                part.Lbl.ZIndex = 25
                part.Bg.Visible, part.Bg.Position, part.Bg.Size = true, View.popupPosition(popup, sx, channel.Y + 18), View.popupSize(popup, sw, 10)
                Pool.alpha(part.Bg, alpha)
                part.Bg.Color = pal.Main
                part.Fill.Visible, part.Fill.Position = true, part.Bg.Position
                part.Fill.Size = View.popupSize(popup, math.max(1, sw * value), 10)
                Pool.alpha(part.Fill, alpha)
                part.Fill.Color = channel.Fill
            end

            local small, big = 50, 165
            local applyPosition, applySize = Shared.button(win, view, popup, {
                Key = "ColorApply", X = 15, Y = 165, Width = small, Height = 25, Label = "Apply", Alpha = alpha,
                Bg = parts.Apply.Bg, Txt = parts.Apply.Txt, Popup = "Color",
            })
            local resetPosition, resetSize = Shared.button(win, view, popup, {
                Key = "ColorReset", X = 15 + small + 10, Y = 165, Width = small, Height = 25, Label = "Reset", Alpha = alpha,
                Bg = parts.Reset.Bg, Txt = parts.Reset.Txt, Popup = "Color",
                BgColor = Util.lerpColor(pal.Panel, Color3.fromRGB(200, 70, 70), win.PopAnim.ColorReset or 0),
            })
            local hexLabel = if win.Focus == "Hex" then win.Buffers.Hex .. "|" else "#" .. string.upper((string.gsub(Util.toHex(picker.Color), "#", "")))
            local hexPosition, hexSize = Shared.button(win, view, popup, {
                Key = "ColorHex", X = 140, Y = 165, Width = big, Height = 25, Label = hexLabel, Alpha = alpha,
                Bg = parts.Hex.Bg, Txt = parts.Hex.Txt, Popup = "Color", TextColor = pal.TextMain,
                BgColor = Util.lerpColor(if win.Focus == "Hex" then pal.AccentOff else pal.Panel, state.AccentCol, 0.25 * (win.PopAnim.ColorHex or 0)),
            })

            local anyField = false
            for _, channel in channels do
                local bg = parts[channel.Key].Bg
                local position = Vector2.new(bg.Position.X, bg.Position.Y - 10)
                local size = Vector2.new(bg.Size.X, bg.Size.Y + 20)
                anyField = anyField or Util.contains(view.Mouse, position, size)
                win:region(position, size, { Drag = function(mouse: Vector2)
                    picker:setChannel(channel.Key, math.clamp((mouse.X - bg.Position.X) / math.max(0.001, bg.Size.X), 0, 1))
                end })
            end
            win:region(hexPosition, hexSize, { Click = function()
                win.Focus = "Hex"
                win.Buffers.Hex = (string.gsub(Util.toHex(picker.Color), "#", ""))
            end })
            win:region(applyPosition, applySize, { Click = function()
                picker:commit()
                win:closeColorPopup()
            end })
            win:region(resetPosition, resetSize, { Click = function()
                picker:reset()
            end })
            win.CommitOnPress = anyField or Util.contains(view.Mouse, hexPosition, hexSize) or Util.contains(view.Mouse, applyPosition, applySize)
                or Util.contains(view.Mouse, resetPosition, resetSize)
        end,
    }
end

local function confirmPopup(win: Map, name: string, title: string, width: number, height: number, lines: { string }?, onConfirm: () -> ()): Map
    local parts: Map = {
        Message = text(win, 25, true),
        YesBg = square(win, 22, 16),
        YesTxt = text(win, 25, true),
        NoBg = square(win, 22, 16),
        NoTxt = text(win, 25, true),
        Lines = {},
    }
    for _ = 1, 5 do
        table.insert(parts.Lines, text(win, 26, true))
    end
    return {
        Name = name,
        Title = title,
        Width = width,
        Height = height,
        Parts = parts,
        Draw = function(env: Map)
            local view, popup, alpha = env.View, env.Popup, env.Alpha
            if lines then
                Builtin.lines(env, parts.Lines, lines, 54)
            else
                Shared.text(view, popup, parts.Message, popup.Width / 2, 48, "Are you sure you want to delete\n'" .. tostring(win.State.SelectedConfig) .. "'?", true, view.Pal.TextMain, alpha)
            end
            confirmRow(env, parts, name, onConfirm)
        end,
    }
end

local function fontPopup(win: Map): Map
    local parts: Map = {
        Slots = {},
        PrevBg = square(win, 22, 12),
        PrevTxt = text(win, 23, true),
        NextBg = square(win, 22, 12),
        NextTxt = text(win, 23, true),
        Page = text(win, 23, true),
        CloseBg = square(win, 22, 16),
        CloseTxt = text(win, 23, true),
    }
    for _ = 1, FONTS_PER_PAGE do
        table.insert(parts.Slots, { Bg = square(win, 24, 12), Txt = text(win, 25, true) })
    end
    return {
        Name = "UIFont",
        Title = "Select Font",
        Width = 320,
        Height = 350,
        Parts = parts,
        Draw = function(env: Map)
            local view, popup, alpha = env.View, env.Popup, env.Alpha
            local state, pal = win.State, view.Pal
            local first = (state.PopFontPage - 1) * FONTS_PER_PAGE
            for slot = 1, FONTS_PER_PAGE do
                local part = parts.Slots[slot]
                local font = first + slot - 1
                if font <= LAST_FONT then
                    local column, row = (slot - 1) % 2, (slot - 1) // 2
                    local x, y = 15 + column * (popup.Width / 2), 45 + row * 28
                    local width, height = popup.Width / 2 - 25, 24
                    local position, size = View.popupPosition(popup, x, y), View.popupSize(popup, width, height)
                    local hovered = Util.contains(view.Mouse, position, size) and state.TargetPopup == "UIFont"
                    local key = "Font_" .. (first + slot)
                    win.PopAnim[key] = Anim.ease(state, win.PopAnim[key] or 0, if hovered then 1 else 0, view.Dt, 16)
                    local selected = tostring(font) == state.UIFont
                    part.Bg.Visible, part.Bg.Position, part.Bg.Size = true, position, size
                    Pool.alpha(part.Bg, alpha)
                    part.Bg.Color = if selected then state.AccentCol else Util.lerpColor(pal.Panel, pal.AccentOff, win.PopAnim[key])
                    part.Txt.Visible = true
                    part.Txt.Font = font
                    Pool.size(part.Txt, 13 * view.TextScale * popup.Morph)
                    part.Txt.Position = View.popupPosition(popup, x + width / 2, y + 5)
                    Pool.alpha(part.Txt, alpha)
                    part.Txt.Text = win.Pool.FONT_NAMES[font] or ("Font " .. font)
                    part.Txt.Color = if selected then pal.Main else pal.TextMain
                    win:region(position, size, { Click = function()
                        state.UIFont = tostring(font)
                    end })
                else
                    part.Bg.Visible, part.Txt.Visible = false, false
                end
            end
            local disabledColor, disabledText = Util.lerpColor(pal.Panel, pal.Main, 0.5), Color3.fromRGB(90, 90, 95)
            local function pager(key: string, bg: any, label: any, x: number, glyph: string, disabled: boolean, onClick: () -> ())
                win.PopAnim[key .. "Dis"] = Anim.ease(state, win.PopAnim[key .. "Dis"] or 0, if disabled then 1 else 0, view.Dt, 12)
                local rawPosition, rawSize = View.popupPosition(popup, x, popup.Height - 75), View.popupSize(popup, 28, 28)
                local hovered = not disabled and Util.contains(view.Mouse, rawPosition, rawSize) and state.TargetPopup == state.ActivePopup
                local position, size, press, factor = view:press(rawPosition, rawSize, hovered, win.PopAnim[key .. "Press"], 0.05)
                win.PopAnim[key .. "Press"] = press
                local hover = Anim.ease(state, win.PopAnim[key] or 0, if hovered then 1 else 0, view.Dt, 18)
                win.PopAnim[key] = hover
                bg.Visible, bg.Position, bg.Size = true, position, size
                Pool.alpha(bg, alpha)
                bg.Color = Util.lerpColor(Util.lerpColor(pal.Panel, state.AccentCol, hover), disabledColor, win.PopAnim[key .. "Dis"])
                label.Visible, label.Text, label.Center = true, glyph, true
                label.Position = Vector2.new(position.X + size.X / 2, position.Y + size.Y / 2 - TEXT_BASELINE * view.TextScale * popup.Morph)
                Pool.alpha(label, alpha)
                Pool.size(label, 13 * view.TextScale * factor * popup.Morph)
                label.Color = Util.lerpColor(Util.lerpColor(pal.TextMain, Color3.new(0, 0, 0), hover), disabledText, win.PopAnim[key .. "Dis"])
                win:region(position, size, { Click = onClick })
            end
            pager("FontPrev", parts.PrevBg, parts.PrevTxt, 10, "<", state.PopFontPage <= 1, function()
                if state.PopFontPage > 1 then
                    state.PopFontPage -= 1
                end
            end)
            pager("FontNext", parts.NextBg, parts.NextTxt, popup.Width - 38, ">", state.PopFontPage >= FONT_PAGES, function()
                if state.PopFontPage < FONT_PAGES then
                    state.PopFontPage += 1
                end
            end)
            parts.Page.Visible, parts.Page.Text, parts.Page.Center = true, state.PopFontPage .. "/" .. FONT_PAGES, true
            parts.Page.Position = View.popupPosition(popup, popup.Width / 2, popup.Height - 68.5)
            Pool.alpha(parts.Page, alpha)
            parts.Page.Color = pal.TextSub
            Pool.size(parts.Page, 13 * view.TextScale * popup.Morph)
            Builtin.closeButton(env, parts, function()
                state.TargetPopup = "None"
            end)
        end,
    }
end

function Builtin.create(win: Map): { [string]: Map }
    local builders: { [string]: () -> Map } = {
        Snowfall = function()
            return snowfall(win)
        end,
        Color = function()
            return colorPopup(win)
        end,
        DeleteConfirm = function()
            return confirmPopup(win, "DeleteConfirm", "Confirm", 280, 135, nil, function()
                win:deleteConfig(win.State.SelectedConfig)
                win.State.TargetPopup = "None"
            end)
        end,
        PerfUI = function()
            return confirmPopup(win, "PerfUI", "Warning", 340, 180, PERFORMANCE_LINES, function()
                win.State.HighPerformanceMode = true
                win.State.Snowfall = false
                win.State.TargetPopup = "None"
            end)
        end,
        UIFont = function()
            return fontPopup(win)
        end,
    }
    local definitions: { [string]: Map } = {}
    for name, build in builders do
        local definition, drawings = win.Pool:group(build)
        definition.Flat = drawings
        definitions[name] = definition
    end
    return definitions
end

Builtin.hide = Shared.hide

return Builtin
end
modules["popups/host"] = function(...)

local import: (string) -> any = ...
local Builtin: typeof(require("./builtin")) = import("popups/builtin")
local Chrome: typeof(require("../ui/chrome")) = import("ui/chrome")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local Shared: typeof(require("./shared")) = import("popups/shared")
local State: typeof(require("../state/state")) = import("state/state")
local View: typeof(require("../ui/view")) = import("ui/view")

local Host = {}
Host.__index = Host

type Map = { [string]: any }

local theme = State.THEME
local DEFAULT_SIZE = Vector2.new(240, 255)
local SHADOWED = { Configs = true, Customize = true }
local CUSTOM_LINE_LIMIT = 20
local OVERLAY_ALPHA = 0.4

function Host.new(win: Map)
    local pool = win.Pool
    local self = {
        Win = win,
        Definitions = Builtin.create(win),
        Custom = {} :: { [string]: Map },
        Overlay = pool:square(true, Color3.fromRGB(0, 0, 0), 0, 19, 0),
        Background = pool:square(true, theme.PanelBg, 0, 21, 24),
        Title = pool:text("Popup", 14, true, theme.Accent, 26),
        CloseBg = pool:square(true, theme.BgBase, 0, 22, 16),
        CloseTxt = pool:text("Close", 13, true, theme.TextMain, 23),
        Lines = {} :: { any },
        Shown = "None",
    }
    for _ = 1, CUSTOM_LINE_LIMIT do
        table.insert(self.Lines, pool:text("", 13, false, theme.TextMain, 26))
    end
    return setmetatable(self, Host)
end

type Self = typeof(Host.new({}))

function Host.define(self: Self, name: string, size: Vector2?, lines: { any }?)
    self.Custom[name] = { Size = size or Vector2.new(280, 300), Lines = lines or {} }
end

function Host.isKnown(self: Self, name: string): boolean
    return self.Custom[name] ~= nil or self.Definitions[name] ~= nil
end

function Host.size(self: Self, name: string): (number, number)
    local custom = self.Custom[name]
    if custom then
        return custom.Size.X, custom.Size.Y
    end
    local definition = self.Definitions[name]
    if definition then
        return definition.Width, definition.Height
    end
    return DEFAULT_SIZE.X, DEFAULT_SIZE.Y
end

function Host.hideContent(self: Self)
    Shared.hide(self.Lines)
    self.CloseBg.Visible, self.CloseTxt.Visible = false, false
    for _, definition in self.Definitions do
        Shared.hide(definition.Flat)
    end
end

function Host.hideAll(self: Self)
    self.Overlay.Visible, self.Background.Visible, self.Title.Visible = false, false, false
    Chrome.hideShadows(self.Win.Chrome.PopupShadows)
    self:hideContent()
end

local function drawCustom(self: Self, env: Map, name: string)
    local win = self.Win
    local custom = self.Custom[name]
    Builtin.lines(env, self.Lines, custom.Lines, 50)
    for index = #custom.Lines + 1, #self.Lines do
        self.Lines[index].Visible = false
    end
    Builtin.closeButton(env, { CloseBg = self.CloseBg, CloseTxt = self.CloseTxt }, function()
        win:leavePopup()
    end)
end

function Host.draw(self: Self, win: Map, view: Map, popup: Map)
    local state, pal = win.State, view.Pal
    local name: string = state.ActivePopup
    local morph = popup.Morph
    local alpha = morph * view.Intro
    local contentAlpha = Shared.alpha(win) * view.TextAlpha
    self.Overlay.Visible, self.Overlay.Position, self.Overlay.Size = true, view.Origin, view.Size
    Pool.alpha(self.Overlay, state.PopAlpha * OVERLAY_ALPHA * view.Intro)
    self.Overlay.Rounding = view.Corner
    self.Background.Visible, self.Background.Position, self.Background.Size = true, popup.Position, popup.Size
    Pool.alpha(self.Background, alpha)
    self.Background.Color = pal.Main

    if SHADOWED[name] and not state.HighPerformanceMode then
        Chrome.drawShadows(win.Chrome.PopupShadows, view, popup.Position, popup.Size, alpha, view.Corner)
    else
        Chrome.hideShadows(win.Chrome.PopupShadows)
    end

    local visible = contentAlpha > 0.01
    self.Title.Visible = visible
    if self.Shown ~= name then
        self.Shown = name
        self:hideContent()
    end
    if not visible then
        self:hideContent()
        return
    end
    self.Title.Position = View.popupPosition(popup, popup.Width / 2, 16)
    Pool.alpha(self.Title, contentAlpha)
    self.Title.Color = state.AccentCol
    self.Title.Font = if name == "UIFont" then 5 else view.Font
    self.Title.ZIndex = 26
    Pool.size(self.Title, 14 * view.TextScale * morph)

    local definition = self.Definitions[name]
    local env: Map = { Win = win, View = view, Popup = popup, Alpha = contentAlpha }
    if definition then
        self.Title.Text = definition.Title
        definition.Draw(env)
    elseif self.Custom[name] then
        self.Title.Text = name
        drawCustom(self, env, name)
    end
end

function Host.hideIdle(self: Self)
    if self.Shown ~= "None" then
        self.Shown = "None"
        self:hideAll()
    end
end

return Host
end
modules["popups/shared"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local Util: typeof(require("../core/util")) = import("core/util")
local View: typeof(require("../ui/view")) = import("ui/view")

local Shared = {}

type Map = { [string]: any }

local TEXT_BASELINE = 6.5
local BLACK = Color3.new(0, 0, 0)

function Shared.alpha(win: Map): number
    return math.clamp((win.State.PopAlpha - 0.2) * 1.25, 0, 1)
end

local function animation(win: Map, key: string): number
    return win.PopAnim[key] or 0
end

function Shared.button(win: Map, view: Map, popup: Map, spec: Map): (Vector2, Vector2)
    local state, pal = win.State, view.Pal
    local rawPosition = View.popupPosition(popup, spec.X, spec.Y)
    local rawSize = View.popupSize(popup, spec.Width, spec.Height)
    local hovered = Util.contains(view.Mouse, rawPosition, rawSize) and (spec.Enabled ~= false) and state.TargetPopup == (spec.Popup or state.ActivePopup)
    local position, size, press, factor = view:press(rawPosition, rawSize, hovered, win.PopAnim[spec.Key .. "Press"], spec.Shrink or 0.05)
    win.PopAnim[spec.Key .. "Press"] = press
    local hover = Anim.ease(state, animation(win, spec.Key), if hovered then 1 else 0, view.Dt, spec.Speed or 16)
    win.PopAnim[spec.Key] = hover
    local alpha = spec.Alpha
    spec.Bg.Visible, spec.Bg.Position, spec.Bg.Size = true, position, size
    Pool.alpha(spec.Bg, alpha)
    spec.Bg.Color = spec.BgColor or Util.lerpColor(pal.Panel, state.AccentCol, hover)
    spec.Txt.Visible = true
    spec.Txt.Text = spec.Label
    spec.Txt.Center = true
    spec.Txt.Font = view.Font
    spec.Txt.Position = Vector2.new(position.X + size.X / 2, position.Y + size.Y / 2 - TEXT_BASELINE * view.TextScale * popup.Morph)
    Pool.alpha(spec.Txt, alpha)
    spec.Txt.Color = spec.TextColor or Util.lerpColor(pal.TextMain, BLACK, hover)
    Pool.size(spec.Txt, 13 * view.TextScale * factor * popup.Morph)
    return position, size
end

function Shared.text(view: Map, popup: Map, text: any, x: number, y: number, label: string, center: boolean, color: Color3, alpha: number)
    text.Visible = true
    text.Text = label
    text.Center = center
    text.Position = View.popupPosition(popup, x, y)
    Pool.alpha(text, alpha)
    text.Color = color
    text.Font = view.Font
    Pool.size(text, 13 * view.TextScale * popup.Morph)
end

function Shared.hide(parts: { any })
    for _, part in parts do
        part.Visible = false
    end
end

return Shared
end
modules["render/canvas"] = function(...)

local Canvas = {}

local LINE = 1
local FILLED_RECT = 2
local FILLED_CIRCLE = 3

type Buffer = {
    count: number,
    kind: { number },
    a: { any },
    b: { any },
    color: { any },
    alpha: { number },
    value: { number },
}

local function newBuffer(): Buffer
    return { count = 0, kind = {}, a = {}, b = {}, color = {}, alpha = {}, value = {} }
end

local first, second = newBuffer(), newBuffer()
local published: Buffer = first
local back: Buffer = second

local function push(kind: number, a: any, b: any, color: Color3, alpha: number, value: number)
    local index = back.count + 1
    back.count = index
    back.kind[index] = kind
    back.a[index] = a
    back.b[index] = b
    back.color[index] = color
    back.alpha[index] = alpha
    back.value[index] = value
end

function Canvas.begin()
    back = if published == first then second else first
    back.count = 0
end

function Canvas.publish()
    published = back
end

function Canvas.clear()
    back = if published == first then second else first
    back.count = 0
    published = back
end

function Canvas.line(from: Vector2, to: Vector2, color: Color3, alpha: number, thickness: number)
    push(LINE, from, to, color, alpha, thickness)
end

function Canvas.filledRect(position: Vector2, size: Vector2, color: Color3, alpha: number)
    push(FILLED_RECT, position, size, color, alpha, 0)
end

function Canvas.filledCircle(center: Vector2, radius: number, color: Color3, alpha: number)
    push(FILLED_CIRCLE, center, nil, color, alpha, radius)
end

function Canvas.flush()
    local buffer = published
    local immediate = DrawingImmediate
    for index = 1, buffer.count do
        local kind = buffer.kind[index]
        if kind == LINE then
            immediate.Line(buffer.a[index], buffer.b[index], buffer.color[index], buffer.alpha[index], 1, buffer.value[index])
        elseif kind == FILLED_RECT then
            immediate.FilledRectangle(buffer.a[index], buffer.b[index], buffer.color[index], buffer.alpha[index])
        elseif kind == FILLED_CIRCLE then
            immediate.FilledCircle(buffer.a[index], buffer.value[index], buffer.color[index], buffer.alpha[index])
        end
    end
end

return Canvas
end
modules["render/pool"] = function(...)

local import: (string) -> any = ...
local State: typeof(require("../state/state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")

local Pool = {}
Pool.__index = Pool

local FONT_SAMPLE = "The quick brown fox jumps over the lazy dog 1234567890"
local FONT_COUNT = 32
local REFERENCE_FONT = 5
local REFERENCE_SIZE = 13

local alphaKey = "Transparency"
do
    local ok, probe = pcall(Drawing.new, "Square")
    if ok and probe then
        if not pcall(function()
            probe.Transparency = 1
        end) then
            alphaKey = "Opacity"
        end
        pcall(function()
            probe:Remove()
        end)
    end
end

Pool.FONT_NAMES = {
    [0] = "UI", "System", "Plex", "Monospace", "SourceSans", "Arial", "Cartoon", "Code",
    "Highway", "SciFi", "Arcade", "Fantasy", "Gotham", "Bodoni", "Garamond", "Nunito",
    "Oswald", "Roboto", "Ubuntu", "Play", "Jura", "Titillium", "Amatic", "Bebas",
    "Lobster", "Cabin", "Arimo", "Exo", "Josefin", "Orbitron", "Signika", "Syncopate",
} :: { [number]: string }

function Pool.measureFonts(): { [number]: number }
    local scales: { [number]: number } = {}
    for font = 0, FONT_COUNT - 1 do
        scales[font] = 1
    end
    local probe: any = nil
    pcall(function()
        probe = Drawing.new("Text")
        probe.Text = FONT_SAMPLE
        probe.Size = REFERENCE_SIZE
        probe.Font = REFERENCE_FONT
        local reference = probe.TextBounds
        for font = 0, FONT_COUNT - 1 do
            probe.Font = font
            local bounds = probe.TextBounds
            if bounds and bounds.X > 0 and bounds.Y > 0 then
                scales[font] = math.clamp(math.min(reference.X / bounds.X, reference.Y / bounds.Y), 0.3, 1.5)
            end
        end
    end)
    if probe then
        pcall(function()
            probe:Remove()
        end)
    end
    return scales
end

function Pool.new()
    return setmetatable({
        Objects = {} :: { any },
        TextSizes = {} :: { [any]: number },
        FontScales = Pool.measureFonts(),
        Font = 5,
        TextScale = -1,
        Group = nil :: { any }?,
    }, Pool)
end

type Self = typeof(Pool.new())

function Pool.alpha(drawing: any, value: number)
    drawing[alphaKey] = value
end

function Pool.size(drawing: any, size: number)
    pcall(function()
        drawing.Size = math.ceil(math.max(1, Util.finite(size, 13)))
    end)
end

function Pool.track(self: Self, object: any)
    table.insert(self.Objects, object)
    local group = self.Group
    if group then
        table.insert(group, object)
    end
end

function Pool.group(self: Self, build: () -> any): (any, { any })
    local list: { any } = {}
    self.Group = list
    local result = build()
    self.Group = nil
    return result, list
end

function Pool.square(self: Self, filled: boolean, color: Color3?, alpha: number?, zIndex: number?, rounding: number?): any
    local object = Drawing.new("Square")
    self:track(object)
    object.Filled = filled
    object.Color = color or State.THEME.PanelBg
    object[alphaKey] = alpha or 1
    object.Visible = false
    object.ZIndex = zIndex or 5
    if rounding then
        object.Rounding = rounding
    end
    return object
end

function Pool.text(self: Self, text: string, size: number?, center: boolean?, color: Color3?, zIndex: number?): any
    local object = Drawing.new("Text")
    self:track(object)
    object.Text = text
    object.Size = size or 13
    object.Color = color or State.THEME.TextMain
    object.Center = center or false
    object.Font = self.Font
    object.Outline = false
    object.Visible = false
    object[alphaKey] = 1
    object.ZIndex = zIndex or 6
    self.TextSizes[object] = size or 13
    return object
end

function Pool.scaleOf(self: Self, font: number): number
    return self.FontScales[font] or 1
end

function Pool.rescale(self: Self, textScale: number, font: number)
    if math.abs(self.TextScale - textScale) <= 0.001 and self.Font == font then
        return
    end
    self.TextScale, self.Font = textScale, font
    for object, baseSize in self.TextSizes do
        pcall(function()
            object.Size = math.max(1, baseSize * textScale)
            object.Font = font
        end)
    end
end

function Pool.destroy(self: Self)
    for _, object in self.Objects do
        pcall(function()
            object:Remove()
        end)
    end
    table.clear(self.Objects)
    table.clear(self.TextSizes)
end

return Pool
end
modules["state/configs"] = function(...)

local import: (string) -> any = ...
local State: typeof(require("./state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")

local Configs = {}
Configs.__index = Configs

type Map = { [string]: any }

local function encode(value: any): string
    local ok, text = pcall(function()
        return crypt.json.encode(value)
    end)
    if ok and type(text) == "string" then
        return text
    end
    return ""
end

local function decode(text: string): any
    local ok, value = pcall(function()
        return crypt.json.decode(text)
    end)
    if ok then
        return value
    end
    return nil
end

local function readJson(path: string): any
    if not isfile(path) then
        return nil
    end
    local ok, content = pcall(readfile, path)
    if not ok then
        return nil
    end
    return decode(content)
end

function Configs.new(folder: string)
    return setmetatable({
        Folder = folder,
        GamePath = folder .. "/default_game_" .. tostring(game.PlaceId),
        GlobalPath = folder .. "/default_global",
    }, Configs)
end

type Self = typeof(Configs.new(""))

function Configs.path(self: Self, name: string): string
    return self.Folder .. "/" .. name .. ".json"
end

local function collectNames(folder: string): { string }
    local names: { string } = {}
    local seen: { [string]: boolean } = {}
    pcall(function()
        if not isfolder(folder) then
            makefolder(folder)
        end
        for _, file in listfiles(folder) do
            local name = string.match(file, "([^/\\]+)%.[jJ][sS][oO][nN]$") or string.match(file, "([^/\\]+)%.txt$")
            if name and not string.match(name, "^default_") and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end)
    table.sort(names)
    return names
end

function Configs.list(self: Self): { string }
    local names = collectNames(self.Folder)
    if #names == 0 then
        table.insert(names, "None")
    end
    return names
end

function Configs.listWithNone(self: Self): { string }
    local names = self:list()
    if not table.find(names, "None") then
        table.insert(names, 1, "None")
    end
    return names
end

local function encodeValue(key: string, value: any): any
    if State.COLOR_KEYS[key] then
        return Util.toHex(value)
    elseif type(value) == "number" then
        return tostring(value)
    elseif type(value) == "boolean" then
        return if value then "true" else "false"
    end
    return value
end

function Configs.save(self: Self, name: string, state: Map, extraKeys: { string }, menuSize: Vector2): boolean
    state.MenuSizeX, state.MenuSizeY = menuSize.X, menuSize.Y
    local data: Map = {}
    for _, keys in { State.CONFIG_KEYS, extraKeys } do
        for _, key in keys do
            local value = state[key]
            if value ~= nil and (type(value) == "number" or type(value) == "boolean" or type(value) == "string" or type(value) == "table" or State.COLOR_KEYS[key]) then
                data[key] = encodeValue(key, value)
            end
        end
    end
    pcall(function()
        if not isfolder(self.Folder) then
            makefolder(self.Folder)
        end
    end)
    local text = encode(data)
    if text == "" then
        return false
    end
    return (pcall(writefile, self:path(name), text))
end

local function decodeValue(key: string, saved: any, current: any): any
    if State.COLOR_KEYS[key] then
        if type(saved) == "string" then
            return Util.fromHex(saved) or current
        elseif type(saved) == "table" and saved.R then
            return Color3.new(saved.R, saved.G, saved.B)
        end
        return current
    elseif type(current) == "number" then
        return tonumber(saved) or current
    elseif type(current) == "boolean" then
        return saved == true or saved == "true"
    end
    return saved
end

function Configs.load(self: Self, name: string, state: Map, extraKeys: { string }): boolean
    local path = self:path(name)
    if not isfile(path) then
        path = self.Folder .. "/" .. name .. ".txt"
    end
    local data = readJson(path)
    if type(data) ~= "table" then
        return false
    end
    for _, keys in { State.CONFIG_KEYS, extraKeys } do
        for _, key in keys do
            local saved = data[key]
            if saved ~= nil then
                local value = decodeValue(key, saved, state[key])
                state[key] = value
                if State.COLOR_KEYS[key] then
                    state["Target_" .. key] = value
                end
            end
        end
    end
    return true
end

local function removeFiles(paths: { string })
    for _, path in paths do
        if isfile(path) then
            pcall(delfile, path)
        end
    end
end

function Configs.clearDefaults(self: Self)
    removeFiles({
        self.GamePath .. ".json", self.GlobalPath .. ".json", self.GamePath .. ".txt", self.GlobalPath .. ".txt",
    })
end

function Configs.delete(self: Self, name: string, defaultName: string): boolean
    removeFiles({ self:path(name), self.Folder .. "/" .. name .. ".txt" })
    if defaultName == name then
        self:clearDefaults()
        return true
    end
    return false
end

function Configs.setDefault(self: Self, name: string)
    if name == "None" or name == "" then
        removeFiles({ self.GlobalPath .. ".json", self.GamePath .. ".json" })
        return
    end
    local text = encode({ Config = name, GameName = "All Games" })
    if text ~= "" and pcall(writefile, self.GlobalPath .. ".json", text) then
        removeFiles({ self.GamePath .. ".json" })
    end
end

local function nameIn(path: string, plain: boolean): string?
    if not isfile(path) then
        return nil
    end
    if plain then
        local ok, text = pcall(readfile, path)
        return if ok and type(text) == "string" and text ~= "" then text else nil
    end
    local data = readJson(path)
    return if type(data) == "table" and data.Config then tostring(data.Config) else nil
end

function Configs.startupName(self: Self): string?
    if isfile(self.GamePath .. ".json") then
        return nameIn(self.GamePath .. ".json", false)
    elseif isfile(self.GlobalPath .. ".json") then
        return nameIn(self.GlobalPath .. ".json", false)
    elseif isfile(self.GamePath .. ".txt") then
        return nameIn(self.GamePath .. ".txt", true)
    end
    return nameIn(self.GlobalPath .. ".txt", true)
end

function Configs.exists(self: Self, name: string): boolean
    return isfile(self:path(name))
end

return Configs
end
modules["state/state"] = function(...)

local State = {}

type Map = { [string]: any }

State.THEME = {
    BgBase = Color3.fromRGB(28, 27, 31),
    PanelBg = Color3.fromRGB(43, 41, 48),
    Accent = Color3.fromRGB(208, 188, 255),
    AccentOff = Color3.fromRGB(55, 52, 62),
    TextMain = Color3.fromRGB(230, 225, 229),
    TextSub = Color3.fromRGB(150, 147, 155),
    Outline = Color3.fromRGB(0, 0, 0),
}

State.DEFAULT_WIDTH = 580
State.DEFAULT_HEIGHT = 360

State.CONFIG_KEYS = {
    "UITrans", "ButtonTrans", "Transparent", "LightMode", "AccentCol", "MainCol", "AccentColAlpha", "MainColAlpha",
    "Snowfall", "SnowCol", "SnowSize", "SnowSpeed", "SnowAmount", "SnowTrans",
    "Keybind", "MenuSizeX", "MenuSizeY", "UIScale", "HighPerformanceMode", "UIFont", "AnimationsEnabled",
    "BlockRobloxWindow",
} :: { string }

State.COLOR_KEYS = {
    AccentCol = true,
    MainCol = true,
    SnowCol = true,
} :: { [string]: boolean }

State.ALPHA_KEYS = {
    AccentCol = "AccentColAlpha",
    MainCol = "MainColAlpha",
    SnowCol = "SnowTrans",
} :: { [string]: string }

function State.create(options: Map, width: number, height: number): Map
    local theme = State.THEME
    return {
        Visible = true,
        CurrentTab = options.DefaultTab,
        NextTab = nil,
        TabAlpha = 1,
        PopAlpha = 0,
        DropAlpha = 0,
        IntroAlpha = 0,
        ActivePopup = "None",
        TargetPopup = "None",
        PreviousPopup = nil,
        ActiveDropdown = nil,
        TargetDropdown = nil,
        Keybind = options.Keybind or "RightShift",
        DPIScale = options.DPIScale or 1.0,

        UITrans = options.DefaultUITransparency or 1,
        ButtonTrans = options.DefaultButtonTransparency or 1,
        Transparent = false,
        LightMode = false,
        UIScale = options.DefaultScale or 1.0,
        PopFontPage = 1,
        AccentCol = options.DefaultAccent or theme.Accent,
        MainCol = options.DefaultColor or theme.BgBase,

        Snowfall = options.DefaultSnowfall ~= false,
        SnowCol = options.DefaultSnowfallColor or Color3.new(1, 1, 1),
        SnowSize = options.DefaultSnowfallSize or 2,
        SnowSpeed = options.DefaultSnowfallSpeed or 20,
        SnowAmount = options.DefaultSnowfallAmount or 40,
        SnowTrans = options.DefaultSnowfallTrans or 0.4,

        AccentColAlpha = 1,
        MainColAlpha = 1,

        SelectedConfig = "None",
        DefaultConfigName = "None",
        MenuSizeX = width,
        MenuSizeY = height,
        UIFont = tostring(options.DefaultFont or 5),
        HighPerformanceMode = false,
        AnimationsEnabled = true,
        BlockRobloxWindow = options.BlockRobloxWindow ~= false,
        LightAlpha = 0,
        PopCloseHovAlpha = 0,

        LastClickedPos = Vector2.new(0, 0),
        LastClickedSize = Vector2.new(0, 0),
        LightRippleOrigin = Vector2.new(0, 0),
        LightRippleAnim = 0,
        LightRippleActive = false,
        IsReloading = false,
        ScrollOffsets = {},
        MaxScrollHeights = {},
    }
end

return State
end
modules["ui/chrome"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local Canvas: typeof(require("../render/canvas")) = import("render/canvas")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local State: typeof(require("../state/state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")

local Chrome = {}

type Map = { [string]: any }

local theme = State.THEME
local SHADOW_LAYERS = 12
local SHADOW_ALPHA = 0.08
local TAB_GAP = 5
local TAB_MAX_WIDTH = 65
local TAB_HEIGHT = 20
local TAB_TOP = 40
local SCROLL_WIDTH = 6
local SCROLL_TOP = 70
local TEXT_BASELINE = 6.5

function Chrome.new(win: Map): Map
    local pool = win.Pool
    local options = win.Options
    local parts: Map = {
        Shadows = {},
        PopupShadows = {},
    }
    for _ = 1, SHADOW_LAYERS do
        table.insert(parts.Shadows, pool:square(true, Color3.fromRGB(0, 0, 0), 0, 0, 24))
        table.insert(parts.PopupShadows, pool:square(true, Color3.fromRGB(0, 0, 0), 0, 20, 24))
    end
    parts.Base = pool:square(true, theme.BgBase, 1, 1, 24)
    parts.TopBar = pool:square(true, theme.BgBase, 1, 2, 24)
    parts.ScrollTrack = pool:square(true, theme.PanelBg, 0, 10, 8)
    parts.ScrollThumb = pool:square(true, theme.Accent, 0, 11, 8)
    parts.Title = pool:text(options.Title or "UI Lib by ok0f", 18, false, theme.Accent, 3)
    parts.Version = pool:text(options.Version or "v1", 13, true, theme.TextSub, 3)
    parts.VersionShadow = pool:text(options.Version or "v1", 13, true, Color3.new(0, 0, 0), 2)
    return parts
end

function Chrome.drawShadows(shadows: { any }, view: Map, position: Vector2, size: Vector2, alpha: number, corner: number)
    for index, shadow in shadows do
        shadow.Visible = true
        local spread = index * 1.5
        local grow = view:scale(Vector2.new(spread * 2, spread * 2))
        shadow.Size = Vector2.new(size.X + grow.X, size.Y + grow.Y)
        local back = view:scale(Vector2.new(spread, spread))
        local drop = view:scale(Vector2.new(0, 3))
        shadow.Position = Vector2.new(position.X - back.X + drop.X, position.Y - back.Y + drop.Y)
        Pool.alpha(shadow, SHADOW_ALPHA * (1 - index / SHADOW_LAYERS) * alpha)
        shadow.Rounding = corner + math.floor(spread / 2)
    end
end

function Chrome.hideShadows(shadows: { any })
    for _, shadow in shadows do
        shadow.Visible = false
    end
end

local function drawResizeCorner(view: Map, state: Map)
    local alpha = view.UITrans * (1 - state.PopAlpha)
    if alpha <= 0 then
        return
    end
    local ten = view:scale(Vector2.new(10, 10))
    local corner = Vector2.new(view.Origin.X + view.Size.X - ten.X, view.Origin.Y + view.Size.Y - ten.Y)
    local long = view:scale(Vector2.new(12, 0))
    local tall = view:scale(Vector2.new(0, 12))
    Canvas.line(corner, Vector2.new(corner.X - long.X, corner.Y - long.Y), state.AccentCol, alpha, 2)
    Canvas.line(corner, Vector2.new(corner.X - tall.X, corner.Y - tall.Y), state.AccentCol, alpha, 2)
    local four = view:scale(Vector2.new(4, 4))
    local inner = Vector2.new(corner.X - four.X, corner.Y - four.Y)
    local shortX = view:scale(Vector2.new(6, 0))
    local shortY = view:scale(Vector2.new(0, 6))
    Canvas.line(inner, Vector2.new(inner.X - shortX.X, inner.Y - shortX.Y), state.AccentCol, alpha, 2)
    Canvas.line(inner, Vector2.new(inner.X - shortY.X, inner.Y - shortY.Y), state.AccentCol, alpha, 2)
end

local function drawRipple(win: Map, view: Map, state: Map)
    if not state.LightRippleActive then
        return
    end
    state.LightRippleAnim += view.Dt * 1.2
    local progress = math.clamp(state.LightRippleAnim, 0, 1)
    if progress >= 1 then
        state.LightRippleActive = false
        return
    end
    Canvas.filledCircle(state.LightRippleOrigin or view.Mouse, progress * (win.MenuSize.X * 1.6), view.Pal.Main, state.IntroAlpha * view.UITrans)
end

function Chrome.drawFrame(win: Map, view: Map)
    local parts, state, pal = win.Chrome, win.State, view.Pal
    if not state.HighPerformanceMode then
        Chrome.drawShadows(parts.Shadows, view, view.Origin, view.Size, view.UITrans, view.Corner)
    else
        Chrome.hideShadows(parts.Shadows)
    end
    parts.Base.Visible, parts.TopBar.Visible = true, false
    parts.Base.Position, parts.Base.Size = view.Origin, view.Size
    Pool.alpha(parts.Base, view.UITrans)
    parts.Base.Color, parts.Base.Rounding = pal.Main, view.Corner
    parts.TopBar.Position = view.Origin
    parts.TopBar.Size = Util.round(Vector2.new(view.Size.X, 30 * state.IntroAlpha * view.GlobalScale))
    Pool.alpha(parts.TopBar, view.UITrans)
    parts.TopBar.Color, parts.TopBar.Rounding = pal.Main, view.Corner
    drawRipple(win, view, state)

    parts.Title.Visible = true
    parts.Title.Position = view:position(Vector2.new(win.MenuPos.X + 15, win.MenuPos.Y + 6))
    Pool.alpha(parts.Title, view.TextAlpha)
    parts.Title.Color = state.AccentCol
    parts.Version.Visible = true
    parts.Version.Position = view:position(Vector2.new(win.MenuPos.X + win.BaseWidth - 15, win.MenuPos.Y + 8))
    Pool.alpha(parts.Version, view.TextAlpha)
    parts.Version.Color = pal.TextSub
    parts.VersionShadow.Visible = true
    parts.VersionShadow.Position = Vector2.new(parts.Version.Position.X + 1, parts.Version.Position.Y + 1)
    Pool.alpha(parts.VersionShadow, view.TextAlpha * 0.5)
    drawResizeCorner(view, state)
end

function Chrome.drawSnow(win: Map, view: Map, popup: Map?)
    local state = win.State
    if not state.Snowfall or state.HighPerformanceMode then
        return
    end
    local color = Util.lerpColor(state.SnowCol, Color3.new(0, 0, 0), state.LightAlpha)
    local flakeSize = view:scale(Vector2.new(state.SnowSize, state.SnowSize))
    local top = view.Origin.Y + 30 * state.IntroAlpha * view.GlobalScale
    for _, flake in win.Snowflakes do
        flake.Y += state.SnowSpeed * flake.SpeedMult * view.Dt
        flake.X += math.sin(view.Now + flake.Sine) * view.Dt * 10
        if flake.Y > 100 then
            flake.Y, flake.X = 0, math.random(0, 100)
        end
        local x = view.Origin.X + flake.X / 100 * view.Size.X
        local y = view.Origin.Y + flake.Y / 100 * view.Size.Y
        local covered = popup ~= nil and x >= popup.Position.X and x <= popup.Position.X + popup.Size.X and y >= popup.Position.Y and y <= popup.Position.Y + popup.Size.Y
        if not covered and y > top and y < view.Origin.Y + view.Size.Y - 2 and x > view.Origin.X + 2 and x < view.Origin.X + view.Size.X - 2 then
            Canvas.filledRect(Vector2.new(x, y), flakeSize, color, view.UITrans * state.SnowTrans)
        end
    end
end

local function tabWidth(win: Map): number
    local count = math.max(1, #win.TabDrawings)
    return math.clamp(math.floor((win.BaseWidth - 30 - (count - 1) * TAB_GAP) / count), 10, TAB_MAX_WIDTH)
end

function Chrome.drawTabs(win: Map, view: Map)
    local state, pal = win.State, view.Pal
    local width = tabWidth(win)
    local total = 0
    for index in win.TabDrawings do
        total += width + (if index < #win.TabDrawings then TAB_GAP else 0)
    end
    local x = win.MenuPos.X + (win.BaseWidth - total) / 2
    local alignment = win.Options.TabAlignment
    if alignment == "Left" then
        x = win.MenuPos.X + 15
    elseif alignment == "Right" then
        x = win.MenuPos.X + win.BaseWidth - total - 15
    end
    local blocked = state.TargetPopup ~= "None" or state.TargetDropdown ~= nil
    for _, tab in win.TabDrawings do
        tab.Box.Visible, tab.Txt.Visible = true, true
        local rawPosition = view:position(Vector2.new(x, win.MenuPos.Y + TAB_TOP))
        local rawSize = view:scale(Vector2.new(width, TAB_HEIGHT))
        local active = state.CurrentTab == tab.Name
        local hovered = Util.contains(view.Mouse, rawPosition, rawSize) and not blocked
        local position, size, animation, factor = view:press(rawPosition, rawSize, hovered, tab.PressAnim, 0.06)
        tab.PressAnim = animation
        tab.Box.Size, tab.Box.Position = size, position
        Pool.alpha(tab.Box, view.ButtonTrans)
        tab.Anim = Anim.ease(state, tab.Anim, if active or hovered then 1 else 0, view.Dt, 18)
        tab.Box.Color = Util.lerpColor(pal.Main, state.AccentCol, 0.15 * tab.Anim)
        tab.Txt.Position = Vector2.new(position.X + size.X / 2, position.Y + size.Y / 2 - TEXT_BASELINE * view.TextScale)
        Pool.size(tab.Txt, 13 * view.TextScale * factor)
        Pool.alpha(tab.Txt, view.TextAlpha)
        tab.Txt.Center = true
        tab.Txt.Color = Util.lerpColor(pal.TextSub, state.AccentCol, if active then 1 else (if hovered then 0.5 else 0))
        x += width + TAB_GAP
        if view.LeftDown and not win.Interaction.Active and hovered and state.PopAlpha <= 0.005 then
            win:switchTab(tab.Name)
        end
    end
end

function Chrome.drawScrollbar(win: Map, view: Map, contentHeight: number)
    local state, parts, pal = win.State, win.Chrome, view.Pal
    local viewport = win.MenuSize.Y / view.GlobalScale - SCROLL_TOP - 15
    state.MaxScrollHeights[state.CurrentTab] = contentHeight
    if contentHeight <= viewport or state.PopAlpha > 0.01 then
        parts.ScrollTrack.Visible, parts.ScrollThumb.Visible = false, false
        return
    end
    parts.ScrollTrack.Visible, parts.ScrollThumb.Visible = true, true
    local trackX = win.BaseWidth - 10
    parts.ScrollTrack.Position = view:position(Vector2.new(win.MenuPos.X + trackX, win.MenuPos.Y + SCROLL_TOP))
    parts.ScrollTrack.Size = view:scale(Vector2.new(SCROLL_WIDTH, viewport))
    parts.ScrollTrack.Color = pal.Panel
    Pool.alpha(parts.ScrollTrack, view.ButtonTrans)
    local thumb = math.clamp((viewport / contentHeight) * viewport, 20, viewport)
    local ratio = (state.ScrollOffsets[state.CurrentTab] or 0) / (contentHeight - viewport)
    parts.ScrollThumb.Position = view:position(Vector2.new(win.MenuPos.X + trackX, win.MenuPos.Y + SCROLL_TOP + ratio * (viewport - thumb)))
    parts.ScrollThumb.Size = view:scale(Vector2.new(SCROLL_WIDTH, thumb))
    parts.ScrollThumb.Color = state.AccentCol
    Pool.alpha(parts.ScrollThumb, view.ButtonTrans)
end

function Chrome.hideAll(win: Map)
    local parts = win.Chrome
    Chrome.hideShadows(parts.Shadows)
    Chrome.hideShadows(parts.PopupShadows)
    for _, name in { "Base", "TopBar", "ScrollTrack", "ScrollThumb", "Title", "Version", "VersionShadow" } do
        parts[name].Visible = false
    end
    for _, tab in win.TabDrawings do
        tab.Box.Visible, tab.Txt.Visible = false, false
    end
end

return Chrome
end
modules["ui/dropdown"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local State: typeof(require("../state/state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")

local Dropdown = {}
Dropdown.__index = Dropdown

type Map = { [string]: any }

local theme = State.THEME
local ITEM_LIMIT = 32
local ITEM_HEIGHT = 22
local FAR = Vector2.new(99999, 99999)

function Dropdown.new(win: Map)
    local pool = win.Pool
    local self = {
        Win = win,
        Background = pool:square(true, theme.PanelBg, 0, 15, 16),
        Items = {} :: { Map },
    }
    for _ = 1, ITEM_LIMIT do
        table.insert(self.Items, {
            Bg = pool:square(true, theme.PanelBg, 0, 16, 12),
            Txt = pool:text("Option", 13, false, theme.TextMain, 17),
            Name = "Option",
            HoverAnim = 0,
        })
    end
    return setmetatable(self, Dropdown)
end

type Self = typeof(Dropdown.new({}))

function Dropdown.hide(self: Self)
    self.Background.Visible = false
    for _, item in self.Items do
        item.Bg.Visible, item.Txt.Visible = false, false
    end
end

local function selectItem(win: Map, element: Map, name: any)
    local state = win.State
    state[element.StateKey] = name
    if element.StateKey == "DefaultConfigName" then
        win.Configs:setDefault(tostring(name))
    end
    if element.Callback then
        element.Callback(name)
    end
    state.TargetDropdown = nil
end

function Dropdown.draw(self: Self, win: Map, view: Map)
    local state, pal = win.State, view.Pal
    local element = state.ActiveDropdown
    if state.DropAlpha <= 0.01 or not element then
        self:hide()
        return
    end
    local z = if element.Popup then 40 else 15
    local width = element.Bg.Size.X
    local scale = view.GlobalScale
    local intro = state.IntroAlpha or 1
    local itemHeight = ITEM_HEIGHT * scale
    local height = math.floor(Util.lerp(0, #element.Options * itemHeight + 4 * scale, state.DropAlpha))
    local background = self.Background
    background.Visible, background.ZIndex = true, z
    background.Size = Vector2.new(width, height * intro)
    Pool.alpha(background, state.DropAlpha * (state.UITrans or 1))
    background.Position = Vector2.new(element.Bg.Position.X, element.Bg.Position.Y + element.Bg.Size.Y + 2 * scale * intro)
    background.Color = pal.Panel

    for index, item in self.Items do
        local choice = element.Options[index]
        local offset = 2 * scale + (index - 1) * itemHeight
        if choice and offset < height - 5 * scale then
            item.Name = choice
            local position = Vector2.new(background.Position.X + 2 * scale * intro, background.Position.Y + offset * intro)
            local size = Vector2.new(width - 4 * scale * intro, 20 * scale * intro)
            local hovered = Util.contains(view.Mouse, position, size) and state.TargetDropdown == element
            item.HoverAnim = Anim.ease(state, item.HoverAnim or 0, if hovered then 1 else 0, view.Dt, 18)
            item.Bg.Visible, item.Bg.ZIndex, item.Bg.Size, item.Bg.Position = true, z + 1, size, position
            Pool.alpha(item.Bg, state.DropAlpha * (state.ButtonTrans or 1))
            item.Bg.Color = Util.lerpColor(pal.Panel, pal.AccentOff, item.HoverAnim)
            item.Txt.Visible, item.Txt.ZIndex = true, z + 2
            item.Txt.Position = Vector2.new(position.X + 10 * scale * intro, position.Y + 3 * scale * intro)
            item.Txt.Text = tostring(choice)
            Pool.alpha(item.Txt, state.DropAlpha * intro)
            item.Txt.Color = if tostring(choice) == tostring(state[element.StateKey]) then state.AccentCol else pal.TextMain
            Pool.size(item.Txt, 13 * view.TextScale)
            if state.TargetDropdown == element then
                win:region(position, size, { Click = function()
                    selectItem(win, element, choice)
                end })
            end
        else
            item.Bg.Visible, item.Txt.Visible = false, false
        end
    end
    if state.TargetDropdown then
        local hitBackground = false
        for _, item in self.Items do
            if item.Bg.Visible and Util.contains(view.Mouse, item.Bg.Position, item.Bg.Size) then
                hitBackground = true
            end
        end
        if not hitBackground and not Util.contains(view.Mouse, element.Bg.Position, element.Bg.Size) then
            win:region(Vector2.new(0, 0), FAR, { Click = function()
                state.TargetDropdown = nil
            end })
        end
    end
end

return Dropdown
end
modules["ui/elements"] = function(...)

local import: (string) -> any = ...
local State: typeof(require("../state/state")) = import("state/state")

local Elements = {}

type Map = { [string]: any }

local theme = State.THEME
local ARROW = "\u{25BC}"
local HEIGHTS = { Toggle = 30, Slider = 40, Button = 25, Dropdown = 25, Label = 18, TextLabel = 18, Separator = 1, Spacer = 10 }
local ROW_STEPS = { Toggle = 36, Slider = 46, Button = 31, Dropdown = 31, Label = 18, TextLabel = 18, Separator = 14, Spacer = 10 }

Elements.HEIGHTS = HEIGHTS

local function base(win: Map, kind: string, tabName: string?, options: Map): Map
    return {
        Type = kind,
        Tab = if options.Popup then nil else tabName,
        Popup = options.Popup,
        Col = options.Col or 1,
        Half = options.Half,
        SameRow = options.SameRow,
        CustomWidth = options.CustomWidth,
        CustomOffset = options.CustomOffset,
        Height = options.Height,
        HoverAnim = 0,
        DisabledAnim = 0,
    }
end

function Elements.height(el: Map): number
    if el.Type == "Button" or el.Type == "Dropdown" then
        return el.Height or HEIGHTS[el.Type]
    elseif el.Type == "Spacer" then
        return el.Height or HEIGHTS.Spacer
    end
    return HEIGHTS[el.Type] or 0
end

function Elements.rowStep(el: Map): number
    if (el.Type == "Button" or el.Type == "Dropdown") and el.Height then
        return el.Height + 6
    elseif el.Type == "Spacer" then
        return el.Height or ROW_STEPS.Spacer
    end
    return ROW_STEPS[el.Type] or 0
end

local function registerKey(win: Map, key: string, color: boolean?)
    if not table.find(win.ConfigKeys, key) then
        table.insert(win.ConfigKeys, key)
    end
    if color then
        win.ColorKeys[key] = true
    end
end

local function defaultValue(state: Map, key: string, value: any)
    if state[key] == nil then
        state[key] = value
    end
end

local function addSetButton(win: Map, el: Map, options: Map)
    if not options.SetIcon then
        return
    end
    local pool = win.Pool
    el.SetBtn = pool:square(true, theme.PanelBg, 0, 6, 16)
    el.SetTxt = pool:text(if options.SetIcon == "Question" then "?" else "...", 14, true, theme.TextMain, 7)
    el.SetCallback = options.SetCallback
    el.SetPopup = options.SetPopup
end

function Elements.toggle(win: Map, tabName: string, options: Map): Map
    local pool, state = win.Pool, win.State
    local key = options.StateKey or options.Name
    defaultValue(state, key, if options.Default ~= nil then options.Default else false)
    if state[key] == true and options.Callback then
        task.spawn(options.Callback, true)
    end
    registerKey(win, key)
    local el = base(win, "Toggle", tabName, options)
    el.Bg = pool:square(true, theme.PanelBg, 1, 5, 16)
    el.Txt = pool:text(options.Name, 13, false, theme.TextMain, 6)
    el.TogBg = pool:square(true, theme.AccentOff, 1, 6, 24)
    el.TogKnob = pool:square(true, theme.TextSub, 1, 7, 16)
    el.StateKey, el.BaseText = key, options.Name
    el.Anim, el.SubAnim, el.BtnHoverAnim = 0, 0, 0
    addSetButton(win, el, options)
    el.Callback = function(self: Map)
        state[self.StateKey] = not state[self.StateKey]
        if options.Callback then
            options.Callback(state[self.StateKey])
        end
    end
    table.insert(win.Elements, el)
    return el
end

function Elements.slider(win: Map, tabName: string, options: Map): Map
    local pool, state = win.Pool, win.State
    local key = options.StateKey or options.Name
    defaultValue(state, key, if options.Default ~= nil then options.Default else (options.Min or 0))
    registerKey(win, key)
    local el = base(win, "Slider", tabName, options)
    el.Bg = pool:square(true, theme.PanelBg, 1, 5, 16)
    el.FillBg = pool:square(true, theme.BgBase, 1, 6, 8)
    el.Fill = pool:square(true, theme.Accent, 1, 7, 8)
    el.Txt = pool:text(options.Name, 13, false, theme.TextMain, 6)
    el.ValBg = pool:square(true, theme.BgBase, 1, 6, 12)
    el.ValTxt = pool:text(tostring(state[key]), 13, true, theme.TextMain, 7)
    el.BaseText, el.StateKey, el.InputKey = options.Name, key, key
    el.Min, el.Max, el.Step, el.IsFloat = options.Min or 0, options.Max or 100, options.Step, options.IsFloat
    el.Anim, el.SubAnim, el.BtnHoverAnim = 0, 0, 0
    addSetButton(win, el, options)
    el.Callback = function(value: number)
        state[key] = value
        if options.Callback then
            options.Callback(value)
        end
    end
    table.insert(win.Elements, el)
    return el
end

function Elements.button(win: Map, tabName: string, options: Map): Map
    local pool = win.Pool
    local el = base(win, "Button", tabName, options)
    el.Bg = pool:square(true, theme.PanelBg, 1, 5, 16)
    el.Txt = pool:text(options.Name, 13, true, theme.TextMain, 6)
    el.BaseText, el.Callback = options.Name, options.Callback
    el.IsInput, el.InputKey, el.Align = options.IsInput, options.InputKey, options.Align
    table.insert(win.Elements, el)
    return el
end

function Elements.dropdown(win: Map, tabName: string, options: Map): Map
    local pool, state = win.Pool, win.State
    local key = options.StateKey or options.Name
    local choices = options.Options or {}
    defaultValue(state, key, if options.Default ~= nil then options.Default else (choices[1] or "None"))
    registerKey(win, key)
    local el = base(win, "Dropdown", tabName, options)
    el.Bg = pool:square(true, theme.PanelBg, 1, 5, 16)
    el.Txt = pool:text(options.Name .. ": " .. tostring(state[key]), 13, false, theme.TextMain, 6)
    el.Icon = pool:text(ARROW, 13, true, theme.TextSub, 6)
    el.Options, el.StateKey, el.BaseText, el.Callback = choices, key, options.Name, options.Callback
    el.SubAnim, el.BtnHoverAnim = 0, 0
    addSetButton(win, el, options)
    table.insert(win.Elements, el)
    return el
end

function Elements.color(win: Map, tabName: string, options: Map): Map
    local state = win.State
    local key = options.StateKey or options.Name
    defaultValue(state, key, options.Default or Color3.new(1, 1, 1))
    registerKey(win, key, true)
    return Elements.button(win, tabName, {
        Name = options.Name,
        Popup = options.Popup,
        Col = options.Col,
        Half = options.Half,
        CustomWidth = options.CustomWidth,
        CustomOffset = options.CustomOffset,
        SameRow = options.SameRow,
        Callback = function(button: Map?)
            win:openColor(key, button, options.Popup)
        end,
    })
end

function Elements.label(win: Map, tabName: string, text: string, column: number?, popup: string?, kind: string): Map
    local pool = win.Pool
    local el = base(win, kind, tabName, { Popup = popup, Col = column })
    el.Bg = pool:square(true, theme.BgBase, 0, 5, 0)
    el.Txt = pool:text(text, 13, false, if kind == "Label" then theme.Accent else theme.TextSub, 6)
    el.BaseText = text
    table.insert(win.Elements, el)
    return el
end

function Elements.separator(win: Map, tabName: string, column: number?, popup: string?): Map
    local el = base(win, "Separator", tabName, { Popup = popup, Col = column })
    el.Bg = win.Pool:square(true, theme.Outline, 0.4, 5, 0)
    table.insert(win.Elements, el)
    table.insert(win.Separators, el)
    return el
end

function Elements.hide(el: Map)
    if el.Bg then
        el.Bg.Visible = false
    end
    if el.Txt then
        el.Txt.Visible = false
    end
    for _, name in { "TogBg", "TogKnob", "FillBg", "Fill", "ValBg", "ValTxt", "Icon", "SetBtn", "SetTxt" } do
        local part = el[name]
        if part then
            part.Visible = false
        end
    end
end

return Elements
end
modules["ui/interaction"] = function(...)

local import: (string) -> any = ...
local Util: typeof(require("../core/util")) = import("core/util")

local Interaction = {}
Interaction.__index = Interaction

type Map = { [string]: any }

local FAR = Vector2.new(99999, 99999)
local MIN_WIDTH_SCALE = 0.65
local MAX_WIDTH_SCALE = 5.0
local SNAP_RANGE = 0.04
local OUTSIDE_CLOSE_ALPHA = 0.8

function Interaction.new(win: Map)
    return setmetatable({
        Win = win,
        Active = false,
        Region = nil :: Map?,
        Bounds = nil :: { Vector2 }?,
        Layers = { dropdown = {}, popup = {}, window = {} } :: { [string]: { Map } },
        Layer = "window",
    }, Interaction)
end

type Self = typeof(Interaction.new({}))

function Interaction.begin(self: Self)
    for _, list in self.Layers do
        table.clear(list)
    end
    self.Layer = "window"
end

function Interaction.region(self: Self, position: Vector2, size: Vector2, spec: Map)
    spec.Position, spec.Size = position, size
    table.insert(self.Layers[self.Layer], spec)
end

local function firstHit(list: { Map }, mouse: Vector2): Map?
    for _, region in list do
        if Util.contains(mouse, region.Position, region.Size) then
            return region
        end
    end
    return nil
end

local function start(self: Self, region: Map, mouse: Vector2)
    self.Active = true
    self.Region = region
    self.Bounds = nil
    if region.Click then
        self.Bounds = { region.Position, region.Size }
    end
    if region.Press then
        region.Press(mouse)
    end
end

local function popupPress(self: Self, view: Map, popup: Map): boolean
    local win = self.Win
    local state = win.State
    local overPopup = Util.contains(view.Mouse, popup.Position, popup.Size)
    if state.TargetPopup == "None" then
        if overPopup then
            start(self, { Shield = true }, view.Mouse)
            return true
        end
        return false
    end
    if win.CommitOnPress then
        win:applyInput()
    end
    local hit = firstHit(self.Layers.popup, view.Mouse)
    if hit then
        start(self, hit, view.Mouse)
    elseif overPopup then
        start(self, { Shield = true }, view.Mouse)
    elseif state.PopAlpha > OUTSIDE_CLOSE_ALPHA then
        start(self, { Click = function()
            win:leavePopup()
        end, Position = Vector2.new(0, 0), Size = FAR }, view.Mouse)
    end
    return true
end

function Interaction.press(self: Self, view: Map, popup: Map)
    local win = self.Win
    local state = win.State
    local mouse = view.Mouse
    if state.TargetDropdown then
        local hit = firstHit(self.Layers.dropdown, mouse)
        if hit then
            start(self, hit, view.Mouse)
            return
        end
    end
    if state.TargetPopup ~= "None" or (state.PopAlpha > 0.005 and Util.contains(mouse, popup.Position, popup.Size)) then
        popupPress(self, view, popup)
        return
    end
    local hit = firstHit(self.Layers.window, mouse)
    if hit then
        start(self, hit, view.Mouse)
    else
        win:applyInput()
    end
end

function Interaction.hold(self: Self, view: Map)
    local region = self.Region
    if region and region.Drag then
        if region.Drag(view.Mouse, view.Dt) == false then
            self.Active, self.Region = false, nil
        end
    end
end

function Interaction.release(self: Self, view: Map)
    local region = self.Region
    if region then
        if region.Click and self.Bounds and Util.contains(view.Mouse, self.Bounds[1], self.Bounds[2]) then
            table.insert(self.Win.PendingActions, region.Click)
        end
        if region.Release then
            region.Release()
        end
    end
    self.Active, self.Region, self.Bounds = false, nil, nil
end

function Interaction.windowDrag(win: Map): Map
    return {
        Press = function(mouse: Vector2)
            win.DragOffset = Vector2.new(win.MenuPos.X - mouse.X, win.MenuPos.Y - mouse.Y)
        end,
        Drag = function(mouse: Vector2, dt: number)
            win.TargetMenuPos = Vector2.new(mouse.X + win.DragOffset.X, mouse.Y + win.DragOffset.Y)
            local factor = 1 - math.exp(-28 * dt)
            win.MenuPos = Util.lerpVector(win.MenuPos, win.TargetMenuPos, factor)
        end,
    }
end

function Interaction.resize(win: Map, mouse: Vector2)
    local dragX = math.max(win.BaseWidth * MIN_WIDTH_SCALE, mouse.X - win.MenuPos.X)
    local scale = math.clamp(dragX / win.BaseWidth, MIN_WIDTH_SCALE, MAX_WIDTH_SCALE)
    if math.abs(scale - 1.0) < SNAP_RANGE then
        scale = 1.0
    end
    win.MenuSize = Vector2.new(win.BaseWidth * scale, win.BaseHeight * scale)
end

return Interaction
end
modules["ui/layout"] = function(...)

local import: (string) -> any = ...
local Elements: typeof(require("./elements")) = import("ui/elements")

local Layout = {}

type Map = { [string]: any }

local START_X, START_Y = 15, 70
local POPUP_START_X, POPUP_START_Y = 15, 45
local COLUMN_GAP = 15
local BOTTOM_MARGIN = 15
local VISIBLE_SLACK = 2
local FADE_START, FADE_SCALE = 0.2, 1.25

function Layout.new(win: Map, popupWidth: number)
    local columnWidth = (win.BaseWidth - 45) / 2
    return {
        Win = win,
        ColumnWidth = columnWidth,
        Columns = { START_Y, START_Y },
        PopupColumns = { POPUP_START_Y, POPUP_START_Y },
        PopupColumnWidth = popupWidth - 30,
    }
end

local function widthAndOffset(el: Map, columnWidth: number, columnX: number): (number, number)
    if el.CustomWidth then
        local offset = if el.CustomOffset then math.floor(columnWidth * el.CustomOffset) else 0
        return math.floor(columnWidth * el.CustomWidth), columnX + offset
    elseif el.Half == "Left" then
        return math.floor(columnWidth / 2 - 2.5), columnX
    elseif el.Half == "Right" then
        return math.floor(columnWidth / 2 - 2.5), columnX + math.floor(columnWidth / 2 + 2.5)
    end
    return columnWidth, columnX
end

local function placeInTab(self: Map, el: Map, placement: Map)
    local win = self.Win
    local state = win.State
    local column = el.Col
    local columnX = if column == 1 then win.MenuPos.X + START_X else win.MenuPos.X + START_X + self.ColumnWidth + COLUMN_GAP
    local width, x = widthAndOffset(el, self.ColumnWidth, columnX)
    local cursor = self.Columns[column]
    local scroll = state.ScrollOffsets[state.CurrentTab] or 0
    local top = win.MenuPos.Y + cursor - scroll
    local bottom = top + Elements.height(el)
    local viewTop = win.MenuPos.Y + START_Y
    local viewBottom = win.MenuPos.Y + win.MenuSize.Y / win.View.GlobalScale - BOTTOM_MARGIN
    placement.Visible = top >= viewTop - VISIBLE_SLACK and bottom <= viewBottom + VISIBLE_SLACK
    placement.Origin = Vector2.new(x, top)
    placement.Width = width
    el.UnscaledPos = placement.Origin
    if el.SetBtn then
        el.SetUnscaledPos = Vector2.new(placement.Origin.X + width - 30, placement.Origin.Y)
        el.SetUnscaledSize = Vector2.new(30, if el.Type == "Toggle" then 30 else 25)
    end
    if not el.SameRow then
        self.Columns[column] += Elements.rowStep(el)
    end
end

local function placeInPopup(self: Map, el: Map, placement: Map, popup: Map)
    local column = el.Col
    local width, x = widthAndOffset(el, self.PopupColumnWidth, POPUP_START_X)
    local localPosition = Vector2.new(x, self.PopupColumns[column])
    placement.Visible = true
    placement.Popup = true
    placement.Origin = localPosition
    placement.Width = width
    placement.Fade = math.clamp((self.Win.State.PopAlpha - FADE_START) * FADE_SCALE, 0, 1)
    el.UnscaledPos = popup.Final + localPosition
    if el.SetBtn then
        el.SetUnscaledPos = Vector2.new(popup.Final.X + localPosition.X + width - 30, popup.Final.Y + localPosition.Y)
        el.SetUnscaledSize = Vector2.new(30, if el.Type == "Toggle" then 30 else 25)
    end
    if not el.SameRow then
        self.PopupColumns[column] += Elements.rowStep(el)
    end
end

function Layout.place(self: Map, el: Map, popup: Map): Map?
    local state = self.Win.State
    local placement: Map = { Visible = false, Popup = false, Fade = 1, Origin = Vector2.new(0, 0), Width = 100 }
    if el.Tab and el.Tab == state.CurrentTab then
        placeInTab(self, el, placement)
        return placement
    elseif el.Popup and el.Popup == state.ActivePopup and state.PopAlpha > 0.01 then
        placeInPopup(self, el, placement, popup)
        return placement
    end
    return nil
end

function Layout.contentHeight(self: Map): number
    return math.max(self.Columns[1], self.Columns[2]) - START_Y
end

Layout.START_Y = START_Y
Layout.BOTTOM_MARGIN = BOTTOM_MARGIN

return Layout
end
modules["ui/palette"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local State: typeof(require("../state/state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")

local Palette = {}

type Map = { [string]: any }

export type Colors = {
    Main: Color3,
    Panel: Color3,
    AccentOff: Color3,
    TextMain: Color3,
    TextSub: Color3,
    Separator: Color3,
    Light: number,
}

local LIGHT_MAIN = Color3.new(0.97, 0.97, 0.97)
local LIGHT_PANEL = Color3.new(0.91, 0.91, 0.93)
local LIGHT_OFF = Color3.new(0.82, 0.82, 0.86)
local LIGHT_TEXT = Color3.new(0.05, 0.05, 0.07)
local LIGHT_SUB = Color3.new(0.30, 0.30, 0.35)
local DEFAULT_TOLERANCE = 0.01
local COLOR_GLIDE = 4.5

function Palette.glide(state: Map, colorKeys: { [string]: boolean }, dt: number)
    local factor = 1 - math.exp(-COLOR_GLIDE * dt)
    for key in colorKeys do
        local target = state["Target_" .. key]
        if not target then
            state["Target_" .. key] = state[key]
        elseif state[key] ~= target then
            state[key] = Util.lerpColor(state[key], target, factor)
        end
    end
end

local function separatorOf(main: Color3, accent: Color3): Color3
    local value = (main.R + main.G + main.B) / 3
    local target = if value > 0.5 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
    return Util.lerpColor(Util.lerpColor(main, target, 0.15), accent, 0.2)
end

function Palette.compute(state: Map, dt: number): Colors
    state.LightAlpha = Anim.ease(state, state.LightAlpha or (if state.LightMode then 1 else 0), if state.LightMode then 1 else 0, dt, 4.5)
    local light: number = state.LightAlpha
    local base = State.THEME
    local main: Color3 = state.MainCol
    local r, g, b = main.R, main.G, main.B
    local isLight = (r + g + b) / 3 > 0.5
    local panelShift = if isLight then -0.04 else 0.04
    local offShift = if isLight then -0.10 else 0.10
    local panel = Color3.new(math.clamp(r + panelShift, 0, 1), math.clamp(g + panelShift, 0, 1), math.clamp(b + panelShift, 0, 1))
    local off = Color3.new(math.clamp(r + offShift, 0, 1), math.clamp(g + offShift, 0, 1), math.clamp(b + offShift, 0, 1))

    local isDefault = math.abs(r - base.BgBase.R) < DEFAULT_TOLERANCE and math.abs(g - base.BgBase.G) < DEFAULT_TOLERANCE and math.abs(b - base.BgBase.B) < DEFAULT_TOLERANCE
    local text, sub = base.TextMain, base.TextSub
    if not isDefault then
        if 0.299 * r + 0.587 * g + 0.114 * b > 0.5 then
            text, sub = Color3.new(0.1, 0.1, 0.1), Color3.new(0.25, 0.25, 0.25)
        else
            text, sub = base.TextMain, Color3.new(0.75, 0.75, 0.75)
        end
    end
    local shownMain = Util.lerpColor(main, LIGHT_MAIN, light)
    return {
        Main = shownMain,
        Panel = Util.lerpColor(panel, LIGHT_PANEL, light),
        AccentOff = Util.lerpColor(off, LIGHT_OFF, light),
        TextMain = Util.lerpColor(text, LIGHT_TEXT, light),
        TextSub = Util.lerpColor(sub, LIGHT_SUB, light),
        Separator = separatorOf(shownMain, state.AccentCol),
        Light = light,
    }
end

return Palette
end
modules["ui/picker"] = function(...)

local import: (string) -> any = ...
local State: typeof(require("../state/state")) = import("state/state")
local Util: typeof(require("../core/util")) = import("core/util")

local Picker = {}
Picker.__index = Picker

type Map = { [string]: any }

function Picker.new(win: Map)
    return setmetatable({
        Win = win,
        Target = nil :: string?,
        Color = Color3.new(1, 1, 1),
        H = 0,
        S = 0,
        V = 1,
        Alpha = 1,
    }, Picker)
end

type Self = typeof(Picker.new({}))

function Picker.open(self: Self, target: string, color: Color3)
    local win = self.Win
    self.Target = target
    self.Color = color
    self.H, self.S, self.V = color:ToHSV()
    local alphaKey = State.ALPHA_KEYS[target]
    self.Alpha = if alphaKey then win.State[alphaKey] else 0
    win.Buffers.Hex = (string.gsub(Util.toHex(color), "#", ""))
end

function Picker.write(self: Self)
    local target = self.Target
    if not target then
        return
    end
    local state = self.Win.State
    state[target] = self.Color
    local alphaKey = State.ALPHA_KEYS[target]
    if alphaKey then
        state[alphaKey] = self.Alpha
    end
end

function Picker.setChannel(self: Self, channel: string, value: number)
    local color = self.Color
    local r, g, b = color.R, color.G, color.B
    if channel == "R" then
        r = value
    elseif channel == "G" then
        g = value
    else
        b = value
    end
    self.Color = Color3.new(r, g, b)
    self.H, self.S, self.V = self.Color:ToHSV()
    self.Win.Buffers.Hex = (string.gsub(Util.toHex(self.Color), "#", ""))
    self:write()
end

function Picker.commit(self: Self)
    local target = self.Target
    if target then
        local state = self.Win.State
        state[target] = self.Color
        state["Target_" .. target] = self.Color
    end
end

function Picker.reset(self: Self)
    local target = self.Target
    if not target then
        return
    end
    local theme = State.THEME
    local default = Color3.new(1, 1, 1)
    if target == "MainCol" then
        default = theme.BgBase
    elseif target == "AccentCol" then
        default = theme.Accent
    end
    self.Color = default
    self.H, self.S, self.V = default:ToHSV()
    self.Win.Buffers.Hex = (string.gsub(Util.toHex(default), "#", ""))
    self.Win.State["Target_" .. target] = default
end

function Picker.applyField(self: Self, field: string)
    local win = self.Win
    if field == "Hex" then
        local color = Util.fromHex(win.Buffers.Hex)
        if color then
            self.Color = color
            self.H, self.S, self.V = color:ToHSV()
            if self.Target then
                win.State[self.Target] = color
            end
        end
        return
    end
    local value = tonumber(win.Buffers[field])
    if not value then
        return
    end
    if field == "Alpha" then
        self.Alpha = math.clamp(value / 100, 0, 1)
    else
        local channel = math.clamp(value / 255, 0, 1)
        self:setChannel(string.sub(field, 1, 1), channel)
        return
    end
    self:write()
end

return Picker
end
modules["ui/regions"] = function(...)

local import: (string) -> any = ...
local Util: typeof(require("../core/util")) = import("core/util")

local Regions = {}

type Map = { [string]: any }

local function rememberClick(win: Map, position: Vector2, size: Vector2)
    win.State.LastClickedPos, win.State.LastClickedSize = position, size
end

local function sliderValue(el: Map, mouse: Vector2): number
    local fraction = math.clamp((mouse.X - el.FillBg.Position.X) / math.max(0.001, el.FillBg.Size.X), 0, 1)
    local value = el.Min + (el.Max - el.Min) * fraction
    if el.Step then
        return tonumber(string.format("%.3f", math.floor(value / el.Step + 0.5) * el.Step)) or value
    elseif el.IsFloat then
        return math.floor(value * 100) / 100
    end
    return math.floor(value)
end

local function queueSliderCallback(win: Map, el: Map, value: number)
    if not el.Callback then
        return
    end
    el.LastPendingVal = value
    if el.HasPendingCallback then
        return
    end
    el.HasPendingCallback = true
    table.insert(win.PendingActions, function()
        el.HasPendingCallback = false
        if el.LastPendingVal ~= nil then
            pcall(el.Callback, el.LastPendingVal)
        end
    end)
end

local function shouldCancel(win: Map, el: Map): boolean
    local state = win.State
    if el.Popup then
        return el.Popup ~= state.TargetPopup or el.Popup ~= state.ActivePopup
    end
    return state.PopAlpha > 0.005 or state.TargetPopup ~= "None"
end

local function openSetPopup(win: Map, el: Map)
    local state = win.State
    rememberClick(win, el.SetUnscaledPos, el.SetUnscaledSize)
    if el.SetPopup then
        state.PreviousPopup = if state.TargetPopup ~= "None" then state.TargetPopup else nil
        state.TargetPopup, state.PopAlpha = el.SetPopup, 0
    end
    if el.SetCallback then
        el.SetCallback()
    end
end

local function addSliderRegions(win: Map, view: Map, el: Map)
    win:region(el.ValBg.Position, el.ValBg.Size, { Click = function()
        rememberClick(win, el.UnscaledPos, el.UnscaledSize)
        win.Focus = el.InputKey
        win.Buffers[el.InputKey] = tostring(win.State[el.StateKey])
    end })
    local scale = view.GlobalScale
    local pad = Util.round(Vector2.new(10 * scale, 15 * scale))
    local grow = Util.round(Vector2.new(20 * scale, 30 * scale))
    win:region(Vector2.new(el.FillBg.Position.X - pad.X, el.FillBg.Position.Y - pad.Y), Vector2.new(el.FillBg.Size.X + grow.X, el.FillBg.Size.Y + grow.Y), {
        Drag = function(mouse: Vector2)
            if shouldCancel(win, el) then
                return false
            end
            queueSliderCallback(win, el, sliderValue(el, mouse))
            return true
        end,
    })
end

function Regions.add(win: Map, view: Map, el: Map)
    if not el.Bg or not el.Bg.Visible then
        return
    end
    if el.SetBtn and el.SetBtn.Visible then
        win:region(el.SetBtn.Position, el.SetBtn.Size, { Click = function()
            openSetPopup(win, el)
        end })
    end
    if el.Type == "Toggle" then
        win:region(el.Bg.Position, el.Bg.Size, { Click = function()
            rememberClick(win, el.UnscaledPos, el.UnscaledSize)
            el:Callback()
        end })
    elseif el.Type == "Slider" then
        addSliderRegions(win, view, el)
    elseif el.Type == "Button" then
        win:region(el.Bg.Position, el.Bg.Size, { Click = function()
            rememberClick(win, el.UnscaledPos, el.UnscaledSize)
            if el.IsInput then
                win.Focus = el.InputKey
                win.Buffers[el.InputKey] = ""
            end
            if el.Callback then
                el.Callback(el)
            end
        end })
    elseif el.Type == "Dropdown" then
        win:region(el.Bg.Position, el.Bg.Size, { Click = function()
            rememberClick(win, el.UnscaledPos, el.UnscaledSize)
            win.State.TargetDropdown = if win.State.TargetDropdown == el then nil else el
        end })
    end
end

return Regions
end
modules["ui/settings"] = function(...)

local import: (string) -> any = ...
local State: typeof(require("../state/state")) = import("state/state")

local Settings = {}

type Map = { [string]: any }

local COMPACT_WIDTH, COMPACT_HEIGHT = 400, 170

local RESET_KEYS = {
    "UITrans", "ButtonTrans", "Transparent", "LightMode", "UIScale", "DPIScale", "Snowfall", "SnowSize", "SnowSpeed",
    "SnowAmount", "SnowTrans", "UIFont", "BlockRobloxWindow",
}
local RESET_COLORS = { "AccentCol", "MainCol", "SnowCol" }

local function resetAppearance(win: Map)
    local defaults = State.create(win.Options, win.BaseWidth, win.BaseHeight)
    local state = win.State
    for _, key in RESET_KEYS do
        state[key] = defaults[key]
    end
    for _, key in RESET_COLORS do
        state["Target_" .. key] = defaults[key]
    end
    if not state.BlockRobloxWindow then
        win.Blocker.SetBlocked(false)
    end
    win:generateSnow()
end

local function openPopup(win: Map, name: string, previous: string?)
    local state = win.State
    if state.TargetPopup == name then
        state.TargetPopup = "None"
        return
    end
    state.PopAlpha, state.PreviousPopup, state.TargetPopup = 0, previous, name
    if name == "UIFont" then
        state.PopFontPage = 1
    end
end

local function keyRow(win: Map)
    win:createbutton("Settings", { Name = "Keybind: " .. win.State.Keybind, Col = 1, IsInput = true, InputKey = "Keybind", Half = "Left", SameRow = true, Height = 30, Callback = function()
        win.Focus = "Keybind"
    end })
    win:createtoggle("Settings", {
        Name = "RWB",
        StateKey = "BlockRobloxWindow",
        Col = 1,
        Half = "Right",
        Default = win.State.BlockRobloxWindow,
        Callback = function(enabled: boolean)
            win.State.BlockRobloxWindow = enabled
            if not enabled then
                win.Blocker.SetBlocked(false)
            end
        end,
    })
end

local function configControls(win: Map, column: number, popup: string?, compact: boolean)
    local state = win.State
    win:createbutton("Settings", { Name = "Config Name...", Col = column, Popup = popup, IsInput = true, InputKey = "ConfigName", Callback = function()
        win.Focus = "ConfigName"
        win.Buffers.ConfigName = ""
    end })
    win:createbutton("Settings", { Name = "Save Config", Col = column, Popup = popup, Callback = function()
        if win.Buffers.ConfigName ~= "" then
            win:saveConfig(win.Buffers.ConfigName)
        end
    end })
    win.ConfigDropdown = win:createdropdown("Settings", { Name = "Select Config", StateKey = "SelectedConfig", Col = column, Popup = popup, Options = win.Configs:list() })
    local load = { Name = "Load Config", Col = column, Popup = popup, Callback = function()
        if state.SelectedConfig ~= "None" then
            win:loadConfig(state.SelectedConfig, false)
        end
    end }
    local delete = { Name = "Delete Config", Col = column, Popup = popup, Callback = function()
        if state.SelectedConfig ~= "None" then
            openPopup(win, "DeleteConfirm", if compact then "Configs" else nil)
        end
    end }
    if compact then
        load.Half, load.SameRow = "Left", true
        delete.Half = "Right"
    end
    win:createbutton("Settings", load)
    win:createbutton("Settings", delete)
    win.DefaultConfigDropdown = win:createdropdown("Settings", { Name = "Default Config", StateKey = "DefaultConfigName", Col = column, Popup = popup, Options = win.Configs:listWithNone() })
end

local function customizeControls(win: Map, column: number, popup: string?, compact: boolean)
    local state = win.State
    local function pair(left: Map, right: Map)
        left.Half, left.SameRow = "Left", true
        right.Half = "Right"
        return left, right
    end
    local function common(options: Map): Map
        options.Col, options.Popup = column, popup
        return options
    end
    local previous = if compact then "Customize" else nil
    local uiTrans, buttonTrans = pair(common({ Name = "UI Transparency", StateKey = "UITrans", Min = 0, Max = 1, IsFloat = true }), common({ Name = "Btn Transparency", StateKey = "ButtonTrans", Min = 0, Max = 1, IsFloat = true }))
    win:createslider("Settings", uiTrans)
    win:createslider("Settings", buttonTrans)
    local light, transparent = pair(common({ Name = "Light Mode", StateKey = "LightMode", Callback = function()
        state.LightRippleOrigin, state.LightRippleAnim, state.LightRippleActive = nil, 0, true
    end }), common({ Name = "Transparent", StateKey = "Transparent" }))
    win:createtoggle("Settings", light)
    win:createtoggle("Settings", transparent)
    local snow, font = pair(common({ Name = "Snowfall Settings", Callback = function()
        openPopup(win, "Snowfall", previous)
    end }), common({ Name = "Change UI Font", Callback = function()
        openPopup(win, "UIFont", previous)
    end }))
    win:createbutton("Settings", snow)
    win:createbutton("Settings", font)
    local accent, main = common({ Name = "Accent Color", StateKey = "AccentCol", Default = state.AccentCol }), common({ Name = "Main Color", StateKey = "MainCol", Default = state.MainCol })
    if compact then
        accent, main = pair(accent, main)
    end
    win:createcolorpicker("Settings", accent)
    win:createcolorpicker("Settings", main)
    local reset = common({ Name = "Reset Settings", Callback = function()
        resetAppearance(win)
    end })
    local performance = common({ Name = "Performance UI", Callback = function()
        openPopup(win, "PerfUI", previous)
    end })
    if compact then
        reset, performance = pair(reset, performance)
    end
    win:createbutton("Settings", reset)
    win:createbutton("Settings", performance)
end

function Settings.build(win: Map)
    local options = win.Options
    local compact = options.CompactSettings
    if type(compact) ~= "boolean" then
        compact = win.BaseWidth <= COMPACT_WIDTH and win.BaseHeight <= COMPACT_HEIGHT
    end
    win:createtab("Settings")
    win:createlabel("Settings", "SETTINGS", 1)
    keyRow(win)
    if compact then
        win:createpopup("Configs", Vector2.new(280, 245))
        win:createpopup("Customize", Vector2.new(280, 265))
        win:createbutton("Settings", { Name = "Configs", Col = 2, Callback = function()
            win:openpopup("Configs")
        end })
        win:createbutton("Settings", { Name = "Customize", Col = 2, Callback = function()
            win:openpopup("Customize")
        end })
        configControls(win, 1, "Configs", true)
        customizeControls(win, 1, "Customize", true)
    else
        win:createlabel("Settings", "CONFIG", 1)
        configControls(win, 1, nil, false)
        win:createlabel("Settings", "UI CUSTOMIZATION", 2)
        customizeControls(win, 2, nil, false)
    end
end

return Settings
end
modules["ui/typing"] = function(...)

local Typing = {}

type Map = { [string]: any }

local FIRST_REPEAT = 0.4
local NEXT_REPEAT = 0.05
local DIGIT_FIELDS = { Red = true, Green = true, Blue = true, Alpha = true }
local NAMED = { Space = " ", Period = ".", KeypadDot = ".", NumberSign = "#" }

local function characterOf(key: string): string
    if #key == 1 then
        return key
    end
    local named = NAMED[key]
    if named then
        return named
    end
    local digit = string.match(key, "^Number(%d)$") or string.match(key, "^Keypad(%d)$")
    return digit or ""
end

function Typing.apply(win: Map)
    local focus: string? = win.Focus
    local state = win.State
    if focus == "Hex" or (focus and DIGIT_FIELDS[focus]) then
        win.Picker:applyField(focus)
    elseif focus and type(state[focus]) == "number" then
        local value = tonumber(win.Buffers[focus])
        if value then
            state[focus] = value
        end
    end
    win.Focus = nil
end

local function modifierIn(keys: { [string]: boolean? }): string?
    for name in keys do
        if string.match(name, "Shift") or string.match(name, "Control") or string.match(name, "Ctrl") or string.match(name, "Alt") then
            return name
        end
    end
    return nil
end

local function captureKey(win: Map, pressed: string)
    local key = pressed
    local modifier = modifierIn(win.Keys.GetPressed(false))
    if modifier then
        key = modifier
    end
    local lowered = string.lower(key)
    if string.match(lowered, "mouse") or string.match(lowered, "button") or key == "Unknown" then
        return
    end
    local focus: string = win.Focus
    if focus == "Keybind" then
        win.State.Keybind = key
    else
        win.State[focus] = if key == "Escape" or key == "Backspace" then "None" else key
    end
    win.Focus = nil
end

function Typing.step(win: Map, view: Map)
    local state = win.State
    if not state.Visible or not win.Focus then
        return
    end
    local ok, pressed = pcall(getpressedkey)
    if not ok or type(pressed) ~= "string" or pressed == "" or pressed == "None" then
        win.LastKey = ""
        return
    end
    local isNew = pressed ~= win.LastKey
    if isNew then
        win.LastKey, win.RepeatAt = pressed, view.Now + FIRST_REPEAT
    end
    if not isNew and view.Now <= win.RepeatAt then
        return
    end
    if not isNew then
        win.RepeatAt = view.Now + NEXT_REPEAT
    end
    local focus: string = win.Focus
    if pressed == "Enter" then
        if isNew then
            Typing.apply(win)
        end
    elseif focus == "Keybind" or string.match(focus, "_Key$") then
        if isNew then
            captureKey(win, pressed)
        end
    elseif pressed == "Backspace" then
        win.Buffers[focus] = string.sub(win.Buffers[focus] or "", 1, -2)
    else
        local character = characterOf(pressed)
        if character ~= "" and (not DIGIT_FIELDS[focus] or string.match(character, "%d")) then
            win.Buffers[focus] = (win.Buffers[focus] or "") .. character
        end
    end
end

return Typing
end
modules["ui/view"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local Palette: typeof(require("./palette")) = import("ui/palette")
local Util: typeof(require("../core/util")) = import("core/util")

local View = {}
View.__index = View

type Map = { [string]: any }

local OPEN_STIFFNESS, OPEN_DAMPING = 350, 24
local CLOSE_STIFFNESS, CLOSE_DAMPING = 500, 40
local CLOSED_SCALE = 0.4
local FOLLOW_SPEED = 28
local TAB_SPEED = 24
local POPUP_SPEED = 14
local DROPDOWN_SPEED = 18

function View.new(win: Map)
    return setmetatable({
        Win = win,
        Dt = 0.016,
        Now = 0,
        Mouse = Vector2.new(0, 0),
        LeftDown = false,
        Pal = nil :: any,
        GlobalScale = 1,
        Intro = 0,
        UITrans = 1,
        ButtonTrans = 1,
        TextAlpha = 1,
        Font = 5,
        TextScale = 1,
        Size = Vector2.new(0, 0),
        Origin = Vector2.new(0, 0),
        Corner = 4,
    }, View)
end

type Self = typeof(View.new({}))

function View.update(self: Self, now: number, dt: number, mouse: Vector2, leftDown: boolean)
    local win = self.Win
    local state = win.State
    self.Now, self.Dt, self.Mouse, self.LeftDown = now, dt, mouse, leftDown

    self.Pal = Palette.compute(state, dt)
    local globalScale = Util.finite(win.MenuSize.X / win.BaseWidth, 1)
    self.GlobalScale = globalScale

    state.IntroAlpha = Anim.ease(state, state.IntroAlpha or 0, if state.Visible then 1 else 0, dt, if state.Visible then 18 else 24)
    if not state.UIScaleAnim then
        state.UIScaleAnim, state.UIVelocity = 0.8, 0
    end
    if not state.UIYOffset then
        state.UIYOffset, state.UIYVelocity = 0, 0
    end
    local stiffness = if state.Visible then OPEN_STIFFNESS else CLOSE_STIFFNESS
    local damping = if state.Visible then OPEN_DAMPING else CLOSE_DAMPING
    state.UIScaleAnim, state.UIVelocity = Anim.spring(state, state.UIScaleAnim, if state.Visible then 1 else CLOSED_SCALE, state.UIVelocity, dt, stiffness, damping)
    state.UIYOffset, state.UIYVelocity = Anim.spring(state, state.UIYOffset, 0, state.UIYVelocity, dt, stiffness, damping)

    local follow = 1 - math.exp(-FOLLOW_SPEED * dt)
    win.MenuPos = Util.lerpVector(win.MenuPos, win.TargetMenuPos, follow)

    state.TabAlpha = Anim.ease(state, state.TabAlpha, if state.NextTab then 0 else 1, dt, TAB_SPEED)
    if state.NextTab and state.TabAlpha < 0.05 then
        state.CurrentTab, state.NextTab = state.NextTab, nil
    end
    state.PopAlpha = Anim.ease(state, state.PopAlpha or 0, if state.TargetPopup ~= "None" then 1 else 0, dt, POPUP_SPEED)
    state.DropAlpha = Anim.ease(state, state.DropAlpha or 0, if state.TargetDropdown then 1 else 0, dt, DROPDOWN_SPEED)
    if state.TargetPopup ~= "None" then
        state.ActivePopup = state.TargetPopup
    end
    if state.TargetDropdown then
        state.ActiveDropdown = state.TargetDropdown
    elseif (state.DropAlpha or 0) < 0.01 then
        state.ActiveDropdown = nil
    end

    local intro = state.IntroAlpha
    self.Intro = intro
    self.UITrans = math.clamp((if state.Transparent then state.UITrans else 1) * intro, 0, 1)
    self.ButtonTrans = math.clamp((if state.Transparent then state.ButtonTrans else 1) * intro, 0, 1)
    self.TextAlpha = math.clamp((intro - 0.15) * 1.176, 0, 1)

    local font = tonumber(state.UIFont) or 5
    self.Font = font
    self.TextScale = Util.finite(globalScale * intro * win.Pool:scaleOf(font), 1)
    self.Size = Vector2.new(win.MenuSize.X * state.UIScaleAnim, win.MenuSize.Y * state.UIScaleAnim)
    self.Origin = Vector2.new(
        win.MenuPos.X + win.MenuSize.X / 2 - self.Size.X / 2,
        win.MenuPos.Y + win.MenuSize.Y / 2 - self.Size.Y / 2 + state.UIYOffset
    )
    self.Corner = math.max(4, math.round(15 * globalScale))
end

function View.position(self: Self, point: Vector2): Vector2
    local scale = self.Win.State.UIScaleAnim * self.GlobalScale
    return Util.round(Vector2.new(self.Origin.X + (point.X - self.Win.MenuPos.X) * scale, self.Origin.Y + (point.Y - self.Win.MenuPos.Y) * scale))
end

function View.scale(self: Self, size: Vector2): Vector2
    local scale = self.Win.State.UIScaleAnim * self.GlobalScale
    return Util.round(Vector2.new(size.X * scale, size.Y * scale))
end

function View.press(self: Self, position: Vector2, size: Vector2, hit: boolean, animation: number?, shrink: number?): (Vector2, Vector2, number, number)
    local pressed = hit and self.LeftDown
    local nextAnimation = Util.finite(Anim.ease(self.Win.State, animation or 0, if pressed then 1 else 0, self.Dt, 28))
    local factor = Util.finite(1 - (shrink or 0.05) * nextAnimation, 1)
    local shrunk = Util.vector(size * factor, size)
    local moved = Util.vector(position + (size - shrunk) / 2, position)
    return moved, shrunk, nextAnimation, factor
end

function View.popup(self: Self, width: number, height: number): Map
    local win = self.Win
    local morph = win.State.PopAlpha
    local final = Vector2.new(win.MenuPos.X + win.BaseWidth / 2 - width / 2, win.MenuPos.Y + win.BaseHeight / 2 - height / 2)
    local position = self:position(Util.lerpVector(win.State.LastClickedPos, final, morph))
    local size = self:scale(Util.lerpVector(win.State.LastClickedSize, Vector2.new(width, height), morph))
    return { Width = width, Height = height, Morph = morph, Final = final, Position = position, Size = size }
end

function View.popupPosition(popup: Map, x: number, y: number): Vector2
    local px = if popup.Width > 0 then x / popup.Width else 0
    local py = if popup.Height > 0 then y / popup.Height else 0
    return Util.round(Vector2.new(popup.Position.X + px * popup.Size.X, popup.Position.Y + py * popup.Size.Y))
end

function View.popupSize(popup: Map, width: number, height: number): Vector2
    local pw = if popup.Width > 0 then width / popup.Width else 0
    local ph = if popup.Height > 0 then height / popup.Height else 0
    return Util.round(Vector2.new(pw * popup.Size.X, ph * popup.Size.Y))
end

return View
end
modules["ui/widgets"] = function(...)

local import: (string) -> any = ...
local Anim: typeof(require("../core/anim")) = import("core/anim")
local Elements: typeof(require("./elements")) = import("ui/elements")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local Util: typeof(require("../core/util")) = import("core/util")
local View: typeof(require("./view")) = import("ui/view")

local Widgets = {}

type Map = { [string]: any }

local DISABLED_COLOR = Color3.fromRGB(90, 90, 95)
local TEXT_BASELINE = 6.5
local TRANSPARENCY_KEYS = { UITrans = true, ButtonTrans = true }
local LOCKED_IN_PERFORMANCE_MODE = { Transparent = true, AnimationsEnabled = true }

local function z(env: Map, popup: number, page: number): number
    return if env.IsPopup then popup else page
end

local function isDisabled(state: Map, el: Map): boolean
    local transparency = TRANSPARENCY_KEYS[el.StateKey] == true
    if state.HighPerformanceMode and (el.BaseText == "Snowfall Settings" or transparency or LOCKED_IN_PERFORMANCE_MODE[el.StateKey]) then
        return true
    end
    return transparency and not state.Transparent
end

local function unscaledSize(el: Map, width: number): Vector2
    local sub = if el.SetBtn then 35 else 0
    local shrink = sub * (el.SubAnim or 0)
    if el.Type == "Toggle" then
        return Vector2.new(width - shrink, 30)
    elseif el.Type == "Button" or el.Type == "Dropdown" then
        return Vector2.new(width - shrink, el.Height or 25)
    elseif el.Type == "Slider" then
        return Vector2.new(width, 40)
    end
    return Vector2.new(width, Elements.height(el))
end

local function scaleOf(env: Map, vector: Vector2): Vector2
    if env.IsPopup then
        return View.popupSize(env.Popup, vector.X, vector.Y)
    end
    return env.View:scale(vector)
end

local function positionOf(env: Map, vector: Vector2): Vector2
    if env.IsPopup then
        return View.popupPosition(env.Popup, vector.X, vector.Y)
    end
    return env.View:position(vector)
end

local function baselineY(env: Map, box: Vector2, height: number): number
    return box.Y + height / 2 - TEXT_BASELINE * env.View.TextScale * env.Mult
end

local function fitText(text: any, maxWidth: number, baseSize: number)
    text.Size = baseSize
    pcall(function()
        local bounds = text.TextBounds
        if bounds and bounds.X > maxWidth and bounds.X > 0 then
            text.Size = math.ceil(math.max(8, baseSize * (maxWidth / bounds.X)))
        end
    end)
end

local function drawBackground(env: Map)
    local el, view, state = env.El, env.View, env.State
    local alpha = state.TabAlpha * view.ButtonTrans * env.Fade
    Pool.alpha(el.Bg, alpha)
    el.Bg.Visible = true
    el.Bg.Size, el.Bg.Position = env.Size, env.Pos
    el.Bg.ZIndex = z(env, 24, 5)
    local text = el.Txt
    text.Visible = true
    Pool.alpha(text, state.TabAlpha * view.TextAlpha * env.Fade)
    local maxWidth = env.Size.X - 15
    if el.Type == "Toggle" then
        maxWidth = env.Size.X - scaleOf(env, Vector2.new(64 * env.Press, 0)).X
    elseif el.Type == "Dropdown" then
        maxWidth = env.Size.X - scaleOf(env, Vector2.new(35 * env.Press, 0)).X
    end
    fitText(text, maxWidth, math.ceil(math.max(1, Util.finite(13 * view.TextScale * env.Press * env.Mult))))
    text.ZIndex = z(env, 25, 6)
end

local function drawToggle(env: Map)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    local dt = view.Dt
    local alpha = state.TabAlpha * view.ButtonTrans * env.Fade
    local textAlpha = state.TabAlpha * view.TextAlpha * env.Fade
    el.TogBg.Visible, el.TogKnob.Visible = true, true
    el.TogBg.ZIndex, el.TogKnob.ZIndex = z(env, 25, 6), z(env, 26, 7)
    el.Anim = Anim.ease(state, el.Anim, if state[el.StateKey] then 1 else 0, dt, 8)
    el.SubAnim = Anim.ease(state, el.SubAnim or 0, 1, dt, 16)

    el.Txt.Center = false
    el.Txt.Position = Vector2.new(env.Pos.X + scaleOf(env, Vector2.new(12 * env.Press, 0)).X, baselineY(env, env.Pos, env.Size.Y))
    el.HoverAnim = Anim.ease(state, el.HoverAnim, if env.Hovered then 1 else 0, dt, 16)
    el.Bg.Color = Util.lerpColor(Util.lerpColor(pal.Panel, state.AccentCol, 0.15 * el.HoverAnim), pal.Main, el.DisabledAnim)

    el.TogBg.Size = scaleOf(env, Vector2.new(36 * env.Press, 18 * env.Press))
    el.TogBg.Position = Vector2.new(env.Pos.X + env.Size.X - scaleOf(env, Vector2.new(44 * env.Press, 0)).X, env.Pos.Y + (env.Size.Y - el.TogBg.Size.Y) / 2)
    Pool.alpha(el.TogBg, alpha)
    el.TogBg.Color = Util.lerpColor(Util.lerpColor(pal.AccentOff, Util.lighten(state.AccentCol, 0.25 * el.HoverAnim), el.Anim), pal.Main, el.DisabledAnim)

    el.TogKnob.Size = scaleOf(env, Vector2.new(14 * env.Press, 14 * env.Press))
    Pool.alpha(el.TogKnob, textAlpha)
    local inset = scaleOf(env, Vector2.new(2 * env.Press, 0)).X
    local insetY = scaleOf(env, Vector2.new(0, 2 * env.Press)).Y
    local knobX = Util.lerp(el.TogBg.Position.X + inset, el.TogBg.Position.X + el.TogBg.Size.X - el.TogKnob.Size.X - inset, el.Anim)
    el.TogKnob.Position = Vector2.new(knobX, el.TogBg.Position.Y + insetY)
    el.TogKnob.Color = Util.lerpColor(Util.lerpColor(pal.TextSub, pal.Main, el.Anim), DISABLED_COLOR, el.DisabledAnim)
    el.Txt.Color = Util.lerpColor(pal.TextMain, DISABLED_COLOR, el.DisabledAnim)
end

local function drawSliderValue(env: Map): (Vector2, number)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    local width = env.Width
    local valuePosition = positionOf(env, Vector2.new(env.Origin.X + width - 45, env.Origin.Y + 17))
    local valueSize = scaleOf(env, Vector2.new(35, 18))
    local hovered = Util.contains(view.Mouse, valuePosition, valueSize) and (state.TargetPopup == "None" or state.TargetPopup == el.Popup)
        and not state.TargetDropdown and not env.Disabled
    local _, size, animation, factor = view:press(valuePosition, valueSize, hovered, el.ValPressAnim, 0.06)
    el.ValPressAnim = animation
    el.HoverAnim = Anim.ease(state, el.HoverAnim, if hovered then 1 else 0, view.Dt, 16)
    el.ValBg.Size = size
    local pad = scaleOf(env, Vector2.new(45 * env.Press, 0)).X
    local padY = scaleOf(env, Vector2.new(0, 17 * env.Press)).Y
    el.ValBg.Position = Vector2.new(env.Pos.X + env.Size.X - pad + (valueSize.X - size.X) / 2, env.Pos.Y + padY + (valueSize.Y - size.Y) / 2)
    Pool.alpha(el.ValBg, state.TabAlpha * view.ButtonTrans * env.Fade)
    el.ValBg.Color = Util.lerpColor(Util.lerpColor(pal.Main, state.AccentCol, 0.15 * el.HoverAnim), pal.Main, el.DisabledAnim)
    return size, factor
end

local function drawSlider(env: Map)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    local width = env.Width
    local textAlpha = state.TabAlpha * view.TextAlpha * env.Fade
    el.FillBg.Visible, el.Fill.Visible, el.ValBg.Visible, el.ValTxt.Visible = true, true, true, true
    el.FillBg.ZIndex, el.Fill.ZIndex = z(env, 25, 6), z(env, 26, 7)
    el.ValBg.ZIndex, el.ValTxt.ZIndex = z(env, 25, 6), z(env, 26, 7)
    local offset = scaleOf(env, Vector2.new(12 * env.Press, 5 * env.Press))
    el.Txt.Position = Vector2.new(env.Pos.X + offset.X, env.Pos.Y + offset.Y)
    el.FillBg.Size = scaleOf(env, Vector2.new(width - 65, 4) * env.Press)
    local track = scaleOf(env, Vector2.new(12 * env.Press, 28 * env.Press))
    el.FillBg.Position = Vector2.new(env.Pos.X + track.X, env.Pos.Y + track.Y)
    Pool.alpha(el.FillBg, textAlpha)
    el.Anim = Anim.ease(state, el.Anim, math.clamp((state[el.StateKey] - el.Min) / math.max(0.1, el.Max - el.Min), 0, 1), view.Dt, 18)
    el.Bg.Color = Util.lerpColor(pal.Panel, pal.Main, el.DisabledAnim)
    el.FillBg.Color = pal.Main

    local valueSize, valueFactor = drawSliderValue(env)
    el.Fill.Color = Util.lerpColor(Util.lighten(state.AccentCol, 0.25 * el.HoverAnim), DISABLED_COLOR, el.DisabledAnim)
    el.Fill.Size = Vector2.new(math.max(1, el.FillBg.Size.X * el.Anim), el.FillBg.Size.Y)
    el.Fill.Position = el.FillBg.Position
    Pool.alpha(el.Fill, textAlpha)

    local shown = if env.Win.Focus == el.InputKey then env.Win.Buffers[el.InputKey] .. "|" else tostring(state[el.StateKey])
    if not env.Win.Focus and el.IsFloat then
        shown = string.format("%.2f", state[el.StateKey])
    end
    el.Txt.Color = Util.lerpColor(pal.TextMain, DISABLED_COLOR, el.DisabledAnim)
    el.ValTxt.Color = el.Txt.Color
    el.ValTxt.Text = shown
    fitText(el.ValTxt, valueSize.X - 4, math.ceil(math.max(1, Util.finite(13 * view.TextScale * valueFactor * env.Mult))))
    el.ValTxt.Position = Vector2.new(el.ValBg.Position.X + valueSize.X / 2, el.ValBg.Position.Y + valueSize.Y / 2 - TEXT_BASELINE * view.TextScale * valueFactor * env.Mult)
    el.ValTxt.Center = true
    Pool.alpha(el.ValTxt, textAlpha)
end

local function inputLabel(env: Map): string
    local el, win = env.El, env.Win
    if el.InputKey == "Keybind" then
        return if win.Focus == "Keybind" then "Press Any..." else "Keybind: " .. tostring(env.State.Keybind)
    end
    if win.Focus == el.InputKey then
        return win.Buffers[el.InputKey] .. "|"
    end
    local typed = win.Buffers[el.InputKey]
    return if typed == "" or typed == nil then el.BaseText or "Type..." else typed
end

local function drawButton(env: Map)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    if el.Align == "Left" then
        el.Txt.Center = false
        el.Txt.Position = Vector2.new(env.Pos.X + scaleOf(env, Vector2.new(12 * env.Press, 0)).X, baselineY(env, env.Pos, env.Size.Y))
    else
        el.Txt.Center = true
        el.Txt.Position = Vector2.new(env.Pos.X + env.Size.X / 2, baselineY(env, env.Pos, env.Size.Y))
    end
    el.HoverAnim = Anim.ease(state, el.HoverAnim, if env.Hovered then 1 else 0, view.Dt, 16)
    local color = Util.lerpColor(pal.Panel, state.AccentCol, 0.25 * el.HoverAnim)
    if el.IsInput then
        el.Txt.Text = inputLabel(env)
        if env.Win.Focus == el.InputKey then
            color = pal.AccentOff
        end
    end
    el.Bg.Color = Util.lerpColor(color, pal.Main, el.DisabledAnim)
    el.Txt.Color = Util.lerpColor(pal.TextMain, DISABLED_COLOR, el.DisabledAnim)
end

local function drawDropdown(env: Map)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    Pool.alpha(el.Icon, state.TabAlpha * view.TextAlpha * env.Fade)
    el.Icon.Visible = true
    el.Icon.ZIndex = z(env, 25, 6)
    el.HoverAnim = Anim.ease(state, el.HoverAnim, if env.Hovered then 1 else 0, view.Dt, 16)
    el.Bg.Color = Util.lerpColor(pal.Panel, state.AccentCol, 0.15 * el.HoverAnim)
    el.Txt.Position = Vector2.new(env.Pos.X + scaleOf(env, Vector2.new(12 * env.Press, 0)).X, baselineY(env, env.Pos, env.Size.Y))
    el.Txt.Text = el.BaseText .. ": " .. tostring(state[el.StateKey])
    el.Txt.Color = Util.lerpColor(pal.TextMain, DISABLED_COLOR, el.DisabledAnim)
    el.Icon.Position = Vector2.new(env.Pos.X + env.Size.X - scaleOf(env, Vector2.new(15 * env.Press, 0)).X, baselineY(env, env.Pos, env.Size.Y))
    Pool.size(el.Icon, 13 * view.TextScale * env.Press * env.Mult)
    el.Icon.Color = Util.lerpColor(pal.TextSub, DISABLED_COLOR, el.DisabledAnim)
    el.DropAnim = Anim.ease(state, el.DropAnim or 0, if state.TargetDropdown == el then 1 else 0, view.Dt, if #el.Options < 4 then 14 else 18)
    if el.DropAnim > 0.005 then
        state.ActiveDropdown = el
    end
end

local function drawStatic(env: Map)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    if el.Type == "Separator" then
        el.Bg.Visible = true
        Pool.alpha(el.Bg, state.TabAlpha * view.TextAlpha * env.Fade)
        el.Bg.Size = scaleOf(env, Vector2.new(env.Width - 10, 1))
        el.Bg.Position = positionOf(env, Vector2.new(env.Origin.X + 5, env.Origin.Y + 4))
        el.Bg.Color = pal.Separator
        return
    end
    el.Bg.Visible = false
    el.Txt.Position = positionOf(env, Vector2.new(env.Origin.X + 5, env.Origin.Y + 1))
    el.Txt.Color = if el.Type == "Label" then state.AccentCol else pal.TextSub
end

local function drawSetButton(env: Map)
    local el, view, state, pal = env.El, env.View, env.State, env.Pal
    if not el.SetBtn or not el.SetTxt then
        return
    end
    if el.SubAnim <= 0.01 then
        el.SetBtn.Visible, el.SetTxt.Visible = false, false
        return
    end
    local position = positionOf(env, el.SetUnscaledPos)
    local size = scaleOf(env, el.SetUnscaledSize)
    local hovered = Util.contains(view.Mouse, position, size) and (state.TargetPopup == "None" or state.TargetPopup == el.Popup)
        and not state.TargetDropdown and not env.Disabled
    local pressedPosition, pressedSize, animation, factor = view:press(position, size, hovered, el.SetPressAnim, 0.05)
    el.SetPressAnim = animation
    el.BtnHoverAnim = Anim.ease(state, el.BtnHoverAnim or 0, if hovered then 1 else 0, view.Dt, 16)
    el.SetBtn.Visible, el.SetTxt.Visible = true, true
    el.SetBtn.ZIndex, el.SetTxt.ZIndex = z(env, 24, 5), z(env, 25, 6)
    el.SetBtn.Size, el.SetBtn.Position = pressedSize, pressedPosition
    el.SetBtn.Color = Util.lerpColor(pal.Panel, state.AccentCol, 0.15 * el.BtnHoverAnim)
    Pool.alpha(el.SetBtn, state.TabAlpha * view.ButtonTrans * el.SubAnim * env.Fade)
    el.SetTxt.Position = Vector2.new(pressedPosition.X + pressedSize.X / 2, baselineY(env, pressedPosition, pressedSize.Y))
    Pool.size(el.SetTxt, 14 * view.TextScale * factor * env.Mult)
    el.SetTxt.Center = true
    Pool.alpha(el.SetTxt, state.TabAlpha * view.TextAlpha * el.SubAnim * env.Fade)
    el.SetTxt.Color = Util.lerpColor(pal.TextMain, DISABLED_COLOR, el.DisabledAnim)
end

function Widgets.draw(win: Map, view: Map, el: Map, placement: Map, popup: Map)
    local state = win.State
    local isPopup = placement.Popup == true
    local env: Map = {
        Win = win, View = view, State = state, Pal = view.Pal, El = el, Popup = popup, IsPopup = isPopup,
        Origin = placement.Origin, Width = placement.Width, Fade = placement.Fade,
        Mult = if isPopup then popup.Morph else 1,
    }
    el.UnscaledSize = unscaledSize(el, placement.Width)
    local rawPosition = positionOf(env, placement.Origin)
    local rawSize = scaleOf(env, el.UnscaledSize)
    env.Disabled = isDisabled(state, el)
    el.DisabledAnim = Anim.ease(state, el.DisabledAnim or 0, if env.Disabled then 1 else 0, view.Dt, 12)
    local interactive = el.Type == "Toggle" or el.Type == "Slider" or el.Type == "Button" or el.Type == "Dropdown"
    env.Hovered = interactive and Util.contains(view.Mouse, rawPosition, rawSize) and (state.TargetPopup == "None" or state.TargetPopup == el.Popup)
        and not state.TargetDropdown and not env.Disabled
    local position, size, animation, factor = view:press(rawPosition, rawSize, env.Hovered, el.PressAnim, 0.04)
    el.PressAnim = animation
    env.Pos, env.Size, env.Press = position, size, factor

    if el.Type == "Label" or el.Type == "TextLabel" or el.Type == "Separator" then
        if el.Txt then
            el.Txt.Visible = true
            Pool.alpha(el.Txt, state.TabAlpha * view.TextAlpha * env.Fade)
            fitText(el.Txt, size.X - 15, math.ceil(math.max(1, Util.finite(13 * view.TextScale * factor * env.Mult))))
            el.Txt.ZIndex = z(env, 25, 6)
        end
        drawStatic(env)
        return
    end
    drawBackground(env)
    if el.Type == "Toggle" then
        drawToggle(env)
    elseif el.Type == "Slider" then
        drawSlider(env)
    elseif el.Type == "Button" then
        drawButton(env)
    elseif el.Type == "Dropdown" then
        drawDropdown(env)
    end
    drawSetButton(env)
end

return Widgets
end
modules["ui/window"] = function(...)

local import: (string) -> any = ...
local Canvas: typeof(require("../render/canvas")) = import("render/canvas")
local Chrome: typeof(require("./chrome")) = import("ui/chrome")
local Configs: typeof(require("../state/configs")) = import("state/configs")
local Dropdown: typeof(require("./dropdown")) = import("ui/dropdown")
local Elements: typeof(require("./elements")) = import("ui/elements")
local Host: typeof(require("../popups/host")) = import("popups/host")
local Interaction: typeof(require("./interaction")) = import("ui/interaction")
local Layout: typeof(require("./layout")) = import("ui/layout")
local Palette: typeof(require("./palette")) = import("ui/palette")
local Picker: typeof(require("./picker")) = import("ui/picker")
local Pool: typeof(require("../render/pool")) = import("render/pool")
local Regions: typeof(require("./regions")) = import("ui/regions")
local Settings: typeof(require("./settings")) = import("ui/settings")
local State: typeof(require("../state/state")) = import("state/state")
local Typing: typeof(require("./typing")) = import("ui/typing")
local Util: typeof(require("../core/util")) = import("core/util")
local View: typeof(require("./view")) = import("ui/view")
local Widgets: typeof(require("./widgets")) = import("ui/widgets")

local Window = {}
Window.__index = Window

type Map = { [string]: any }

local TOGGLE_COOLDOWN = 0.25
local PENDING_INTERVAL = 0.01
local MAX_FRAME = 0.05
local RESIZE_CORNER = 20
local TOPBAR_HEIGHT = 30
local SCROLL_TOP = 70

function Window.new(options: Map, modules: Map): Map
    local width = options.CustomResolution and options.CustomResolution.X or State.DEFAULT_WIDTH
    local height = options.CustomResolution and options.CustomResolution.Y or State.DEFAULT_HEIGHT
    local state = State.create(options, width, height)
    local self: Map = setmetatable({
        Options = options,
        State = state,
        BaseWidth = width,
        BaseHeight = height,
        MenuSize = Vector2.new(state.MenuSizeX, state.MenuSizeY),
        MenuPos = Vector2.new(0, 0),
        TargetMenuPos = Vector2.new(0, 0),
        DragOffset = Vector2.new(0, 0),
        Centered = false,
        Pool = Pool.new(),
        Configs = Configs.new(options.ConfigFolder or "severeui_configs"),
        ConfigKeys = table.clone(State.CONFIG_KEYS),
        ColorKeys = table.clone(State.COLOR_KEYS),
        Elements = {},
        Separators = {},
        TabDrawings = {},
        Tabs = {},
        Snowflakes = {},
        Buffers = { Hex = "", Keybind = "", ConfigName = "", DPIScale = "" },
        Focus = nil,
        LastKey = "",
        RepeatAt = 0,
        PopAnim = {},
        PendingActions = {},
        ToggleAt = 0,
        Heuristic = { Typing = false, Slash = false, Return = false, Escape = false },
        Keys = modules.Keys,
        Blocker = modules.Blocker,
        ChatCheck = nil :: any,
        Running = true,
    }, Window) :: any
    self.View = View.new(self)
    self.Chrome = Chrome.new(self)
    self.Host = Host.new(self)
    self.Dropdown = Dropdown.new(self)
    self.Interaction = Interaction.new(self)
    self.Picker = Picker.new(self)
    return self
end

type Self = Map

function Window.region(self: Self, position: Vector2, size: Vector2, spec: Map)
    self.Interaction:region(position, size, spec)
end

function Window.frontRegion(self: Self, position: Vector2, size: Vector2, spec: Map)
    spec.Position, spec.Size = position, size
    table.insert(self.Interaction.Layers.window, 1, spec)
end

function Window.generateSnow(self: Self)
    table.clear(self.Snowflakes)
    for _ = 1, self.State.SnowAmount do
        table.insert(self.Snowflakes, { X = math.random(0, 100), Y = math.random(0, 100), SpeedMult = 0.6 + math.random() * 1.5, Sine = math.random(0, 100) })
    end
end

function Window.getvalue(self: Self, name: string): any
    return self.State[name]
end

function Window.setvalue(self: Self, name: string, value: any)
    self.State[name] = value
    self.State["Target_" .. name] = value
end

function Window.switchTab(self: Self, name: string)
    local state = self.State
    if state.CurrentTab == name then
        return
    end
    state.NextTab, self.Focus, state.TargetDropdown = name, nil, nil
end

function Window.createtab(self: Self, name: string): string
    if table.find(self.Tabs, name) then
        return name
    end
    table.insert(self.Tabs, name)
    table.insert(self.TabDrawings, {
        Name = name,
        Box = self.Pool:square(true, State.THEME.PanelBg, 1, 3, 16),
        Txt = self.Pool:text(name, 13, true, State.THEME.TextSub, 4),
        Anim = 0,
    })
    local settingsIndex = table.find(self.Tabs, "Settings")
    if settingsIndex and settingsIndex < #self.Tabs then
        table.insert(self.Tabs, table.remove(self.Tabs, settingsIndex))
        table.insert(self.TabDrawings, table.remove(self.TabDrawings, settingsIndex))
    end
    if not self.State.CurrentTab then
        self.State.CurrentTab = name
    end
    return name
end

function Window.createpopup(self: Self, name: string, size: Vector2?, texts: { any }?)
    self.Host:define(name, size, texts)
end

function Window.openpopup(self: Self, name: string)
    self.State.PopAlpha, self.State.TargetPopup = 0, name
end

function Window.closepopup(self: Self)
    self.State.TargetPopup = "None"
end

function Window.createtoggle(self: Self, tabName: string, options: Map): Map
    return Elements.toggle(self, tabName, options)
end

function Window.createslider(self: Self, tabName: string, options: Map): Map
    return Elements.slider(self, tabName, options)
end

function Window.createbutton(self: Self, tabName: string, options: Map): Map
    return Elements.button(self, tabName, options)
end

function Window.createdropdown(self: Self, tabName: string, options: Map): Map
    return Elements.dropdown(self, tabName, options)
end

function Window.createcolorpicker(self: Self, tabName: string, options: Map): Map
    return Elements.color(self, tabName, options)
end

function Window.createlabel(self: Self, tabName: string, text: string, column: number?, popup: string?): Map
    return Elements.label(self, tabName, text, column, popup, "Label")
end

function Window.createtextlabel(self: Self, tabName: string, text: string, column: number?, popup: string?): Map
    return Elements.label(self, tabName, text, column, popup, "TextLabel")
end

function Window.createseparator(self: Self, tabName: string, column: number?, popup: string?): Map
    return Elements.separator(self, tabName, column, popup)
end

function Window.openColor(self: Self, key: string, button: Map?, popupName: string?)
    local state = self.State
    if button then
        state.LastClickedPos, state.LastClickedSize = button.UnscaledPos, button.UnscaledSize
    end
    state.PopAlpha, state.PreviousPopup, state.TargetPopup = 0, popupName or "None", "Color"
    self.Picker:open(key, state[key])
end

function Window.openColorPopup(self: Self, target: string, previous: string)
    local state = self.State
    state.PopAlpha, state.PreviousPopup, state.TargetPopup = 0, previous, "Color"
    self.Picker:open(target, state[target])
end

function Window.leavePopup(self: Self)
    local state = self.State
    local previous = state.PreviousPopup
    state.PreviousPopup = nil
    if previous and previous ~= "None" then
        state.PopAlpha, state.TargetPopup = 0, previous
    else
        state.TargetPopup = "None"
    end
end

function Window.closeColorPopup(self: Self)
    self:leavePopup()
end

function Window.applyInput(self: Self)
    Typing.apply(self)
end

function Window.saveConfig(self: Self, name: string)
    if self.Configs:save(name, self.State, self.ConfigKeys, self.MenuSize) then
        self.State.SelectedConfig = name
        self:refreshConfigLists()
    end
end

function Window.refreshConfigLists(self: Self)
    if self.ConfigDropdown then
        self.ConfigDropdown.Options = self.Configs:list()
    end
    if self.DefaultConfigDropdown then
        self.DefaultConfigDropdown.Options = self.Configs:listWithNone()
    end
end

function Window.loadConfig(self: Self, name: string, auto: boolean)
    local state = self.State
    if not self.Configs:load(name, state, self.ConfigKeys) then
        return
    end
    local scale = 1.0
    if state.MenuSizeX then
        local custom = self.Options.CustomResolution and self.BaseWidth ~= State.DEFAULT_WIDTH and state.MenuSizeX == State.DEFAULT_WIDTH
        scale = if custom then 1.0 else math.clamp(state.MenuSizeX / self.BaseWidth, 0.65, 2.5)
    end
    self.MenuSize = Vector2.new(self.BaseWidth * scale, self.BaseHeight * scale)
    if not auto then
        state.SelectedConfig = name
    end
    if not state.BlockRobloxWindow then
        self.Blocker.SetBlocked(false)
    end
    self:generateSnow()
end

function Window.deleteConfig(self: Self, name: string)
    local state = self.State
    if self.Configs:delete(name, state.DefaultConfigName) then
        state.DefaultConfigName = "None"
    end
    if self.ConfigDropdown then
        state.SelectedConfig = "None"
    end
    self:refreshConfigLists()
end

function Window.loadStartupConfig(self: Self)
    local name = self.Configs:startupName()
    if not name then
        return
    end
    local state = self.State
    if self.Configs:exists(name) then
        self:loadConfig(name, true)
        state.DefaultConfigName, state.SelectedConfig = name, "None"
    else
        self.Configs:clearDefaults()
        state.DefaultConfigName = "None"
    end
end

local function isMouseOverUI(self: Self, mouse: Vector2): boolean
    local state = self.State
    if not state.Visible or (state.IntroAlpha or 0) <= 0.05 then
        return false
    end
    local view = self.View
    if Util.contains(mouse, view.Origin, view.Size) or Util.contains(mouse, self.MenuPos, self.MenuSize) then
        return true
    end
    local host = self.Host
    if state.TargetPopup ~= "None" and host.Background.Visible and Util.contains(mouse, host.Background.Position, host.Background.Size) then
        return true
    end
    return self.Interaction.Active
end

local function isTyping(self: Self): boolean
    local keys = self.Keys.GetPressed(false)
    local heuristic = self.Heuristic
    local slash = keys.Slash == true or keys["/"] == true
    local enter = keys.Return == true or keys.Enter == true or keys.KeypadEnter == true
    local escape = keys.Escape == true
    if slash and not heuristic.Slash then
        heuristic.Typing = true
    end
    if (enter and not heuristic.Return) or (escape and not heuristic.Escape) then
        heuristic.Typing = false
    end
    heuristic.Slash, heuristic.Return, heuristic.Escape = slash, enter, escape
    if self.ChatCheck and self.ChatCheck.IsTyping() then
        heuristic.Typing = false
        return true
    end
    return heuristic.Typing
end

local function liveMouse(self: Self): Vector2
    local scale = self.State.DPIScale or 1
    local ok, position = pcall(getmouseposition)
    if ok and position then
        return position * scale
    end
    return Vector2.new(0, 0)
end

local function drawContent(self: Self, view: Map, popup: Map)
    local layout = Layout.new(self, popup.Width)
    local interaction = self.Interaction
    for _, element in self.Elements do
        local placement = Layout.place(layout, element, popup)
        if placement and not placement.Visible then
            Elements.hide(element)
        elseif placement then
            interaction.Layer = if placement.Popup then "popup" else "window"
            Widgets.draw(self, view, element, placement, popup)
            Regions.add(self, view, element)
        else
            Elements.hide(element)
        end
    end
    interaction.Layer = "window"
    Chrome.drawScrollbar(self, view, Layout.contentHeight(layout))
end

local function addWindowRegions(self: Self, view: Map)
    local state = self.State
    local parts = self.Chrome
    local drag = Interaction.windowDrag(self)
    self:frontRegion(self.MenuPos, Vector2.new(self.MenuSize.X, TOPBAR_HEIGHT * view.GlobalScale), drag)
    local corner = Util.round(Vector2.new(RESIZE_CORNER * view.GlobalScale, RESIZE_CORNER * view.GlobalScale))
    self:frontRegion(Vector2.new(self.MenuPos.X + self.MenuSize.X - corner.X, self.MenuPos.Y + self.MenuSize.Y - corner.Y), corner, {
        Drag = function(mouse: Vector2)
            Interaction.resize(self, mouse)
        end,
    })
    if parts.ScrollThumb.Visible then
        self:frontRegion(parts.ScrollThumb.Position, parts.ScrollThumb.Size, {
            Press = function(mouse: Vector2)
                self.ScrollGrab = Vector2.new(mouse.X - parts.ScrollThumb.Position.X, mouse.Y - parts.ScrollThumb.Position.Y)
            end,
            Drag = function(mouse: Vector2)
                local top, height = parts.ScrollTrack.Position.Y, parts.ScrollTrack.Size.Y
                local thumb = parts.ScrollThumb.Size.Y
                local target = math.clamp(mouse.Y - self.ScrollGrab.Y, top, top + height - thumb)
                local ratio = if height > thumb then (target - top) / (height - thumb) else 0
                local content = state.MaxScrollHeights[state.CurrentTab] or 0
                local viewport = self.MenuSize.Y / view.GlobalScale - SCROLL_TOP - 15
                state.ScrollOffsets[state.CurrentTab] = ratio * math.max(0, content - viewport)
            end,
        })
    end
end

local function drawWindow(self: Self, view: Map)
    local state = self.State
    local popupWidth, popupHeight = self.Host:size(state.ActivePopup)
    local popup = view:popup(popupWidth, popupHeight)
    local popupVisible = state.ActivePopup ~= "None" and (state.PopAlpha > 0.01 or state.TargetPopup ~= "None")
    Chrome.drawFrame(self, view)
    Chrome.drawSnow(self, view, if popupVisible then popup else nil)
    Chrome.drawTabs(self, view)
    drawContent(self, view, popup)
    addWindowRegions(self, view)

    self.Interaction.Layer = "dropdown"
    self.Dropdown:draw(self, view)
    self.Interaction.Layer = "popup"
    if popupVisible then
        self.Host:draw(self, view, popup)
    else
        state.ActivePopup = "None"
        self.Host:hideIdle()
    end
    self.Interaction.Layer = "window"
    return popup
end

local function hideWindow(self: Self)
    Chrome.hideAll(self)
    for _, element in self.Elements do
        Elements.hide(element)
    end
    self.Dropdown:hide()
    self.Host:hideAll()
end

local function handlePointer(self: Self, view: Map, popup: Map)
    local interaction = self.Interaction
    if view.LeftDown then
        if not interaction.Active then
            interaction:press(view, popup)
        else
            interaction:hold(view)
        end
    elseif interaction.Active then
        interaction:release(view)
    end
end

local function toggleMenu(self: Self, view: Map)
    local state = self.State
    local bind = state.Keybind
    if not bind or bind == "" or bind == "None" or not self.Keys.IsDown(bind) then
        return
    end
    if isTyping(self) or view.Now - self.ToggleAt < TOGGLE_COOLDOWN or self.Focus == "Keybind" or state.TargetPopup ~= "None" or state.TargetDropdown then
        return
    end
    self.ToggleAt = view.Now
    state.Visible = not state.Visible
    if not state.Visible then
        self.Blocker.SetBlocked(false)
    end
end

function Window.step(self: Self, now: number, dt: number)
    local camera = Util.read(workspace, "CurrentCamera")
    if not camera then
        return
    end
    local state = self.State
    local view = self.View
    local mouse = liveMouse(self)
    local okActive, active = pcall(isrbxactive)
    local leftDown = isleftpressed() == true and (not okActive or active == true)
    Palette.glide(state, self.ColorKeys, dt)
    view:update(now, dt, mouse, leftDown)
    self.Pool:rescale(view.TextScale, view.Font)
    local blocked = state.BlockRobloxWindow ~= false and state.Visible and view.Intro > 0.05 and isMouseOverUI(self, mouse)
    self.Blocker.SetBlocked(blocked)

    local viewport = Util.read(camera, "ViewportSize")
    if not self.Centered and viewport and viewport.X > 0 then
        self.MenuPos = Vector2.new(math.floor(viewport.X / 2 - self.MenuSize.X / 2), math.floor(viewport.Y / 2 - self.MenuSize.Y / 2))
        self.TargetMenuPos = self.MenuPos
        self.Centered = true
    end
    toggleMenu(self, view)
    Typing.step(self, view)

    Canvas.begin()
    self.Interaction:begin()
    if state.IntroAlpha > 0.001 then
        local popup = drawWindow(self, view)
        handlePointer(self, view, popup)
    else
        self.Blocker.SetBlocked(false)
        hideWindow(self)
    end
    Canvas.publish()
end

function Window.start(self: Self)
    self:generateSnow()
    Settings.build(self)
    local lastUpdate = os.clock()
    local connection: any = nil
    pcall(function()
        connection = game:GetService("RunService").Render:Connect(function()
            pcall(Canvas.flush)
        end)
    end)
    self.Connection = connection
    self.MainThread = task.spawn(function()
        while self.Running do
            local now = os.clock()
            local dt = math.min(now - lastUpdate, MAX_FRAME)
            lastUpdate = now
            local ok = pcall(self.step, self, now, dt)
            if not ok then
                Canvas.publish()
            end
            task.wait()
        end
    end)
    self.PendingThread = task.spawn(function()
        while self.Running do
            while #self.PendingActions > 0 do
                local action = table.remove(self.PendingActions, 1)
                if type(action) == "function" then
                    pcall(action)
                end
            end
            task.wait(PENDING_INTERVAL)
        end
    end)
    task.spawn(function()
        self:loadStartupConfig()
    end)
end

function Window.destroy(self: Self)
    if not self.Running then
        return
    end
    self.Running = false
    pcall(task.cancel, self.MainThread)
    pcall(task.cancel, self.PendingThread)
    if self.Connection then
        pcall(function()
            self.Connection:Disconnect()
        end)
    end
    self.Blocker.SetBlocked(false)
    Canvas.clear()
    self.Pool:destroy()
end

return Window
end
local Window = import("ui/window")
local Keys = import("modules/keys")
local Blocker = import("modules/blocker")

local severeui = {}

severeui.KeybindInput = Keys

local function loadChatCheck(window)
    task.spawn(function()
        local ok, module = pcall(function()
            return import("modules/chat")
        end)
        if ok and module then
            window.ChatCheck = module
            window.ChatCheckModule = module
            severeui.ChatCheck = module
        end
    end)
end

function severeui:createwindow(options)
    if _G.SevereCleanup then
        pcall(_G.SevereCleanup)
    end
    local window = Window.new(options or {}, { Keys = Keys, Blocker = Blocker })
    window.KeybindInput = Keys
    local function cleanup()
        window:destroy()
        if _G.SevereCleanup == cleanup then
            _G.SevereCleanup = nil
        end
    end
    _G.SevereCleanup = cleanup
    window:start()
    loadChatCheck(window)
    return window
end

return severeui
