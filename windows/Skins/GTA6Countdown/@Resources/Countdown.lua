local RELEASE_MOMENT = os.time({ year = 2026, month = 11, day = 19, hour = 0, min = 0, sec = 0 })
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400
local DESIGN_SCREEN_HEIGHT = 1440
local WEEKDAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

local isLocked = true
local isShowingClock = false

local function screenVariable(name)
    return tonumber(SKIN:GetVariable(name))
end

local function scaledOutlineWidth(pixels)
    local scale = screenVariable("SCREENAREAHEIGHT") / DESIGN_SCREEN_HEIGHT
    return math.max(1, math.floor(pixels * scale + 0.5))
end

local function twoDigits(value)
    return string.format("%02d", value)
end

function Initialize()
    SKIN:Bang("!SetVariable", "DigitsOutlineWidth", scaledOutlineWidth(4))
    SKIN:Bang("!SetVariable", "CaptionOutlineWidth", scaledOutlineWidth(2))
    SKIN:Bang("!SetVariable", "DateOutlineWidth", scaledOutlineWidth(2))
end

function PlaceOnFirstRun()
    if SKIN:GetVariable("Positioned") == "1" then return end
    local horizontalPosition = tonumber(SKIN:GetVariable("HorizontalPosition"))
    local verticalPosition = tonumber(SKIN:GetVariable("VerticalPosition"))
    local x = screenVariable("SCREENAREAX") + screenVariable("SCREENAREAWIDTH") * horizontalPosition
    local y = screenVariable("SCREENAREAY") + screenVariable("SCREENAREAHEIGHT") * verticalPosition
    SKIN:Bang("!Move", math.floor(x), math.floor(y))
    SKIN:Bang("!WriteKeyValue", "Variables", "Positioned", "1")
end

function Lock()
    if isLocked then return end
    isLocked = true
    SKIN:Bang("!Draggable", "0")
    SKIN:Bang("!HideMeter", "MeterUnlockedFrame")
    SKIN:Bang("!Redraw")
end

function Unlock()
    isLocked = false
    SKIN:Bang("!Draggable", "1")
    SKIN:Bang("!ShowMeter", "MeterUnlockedFrame")
    SKIN:Bang("!Redraw")
end

function ToggleLock()
    if isLocked then Unlock() else Lock() end
end

local function showCountdown(remainingSeconds)
    SKIN:Bang("!SetVariable", "Days", twoDigits(math.floor(remainingSeconds / SECONDS_PER_DAY)))
    SKIN:Bang("!SetVariable", "Hours", twoDigits(math.floor((remainingSeconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)))
    SKIN:Bang("!SetVariable", "Minutes", twoDigits(math.floor((remainingSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)))
    SKIN:Bang("!SetVariable", "Seconds", twoDigits(remainingSeconds % SECONDS_PER_MINUTE))
end

local function switchToClock()
    SKIN:Bang("!HideMeterGroup", "Countdown")
    SKIN:Bang("!ShowMeterGroup", "Clock")
    isShowingClock = true
end

local function showClock()
    local now = os.date("*t")
    SKIN:Bang("!SetVariable", "ClockTime", os.date("%H:%M:%S"))
    SKIN:Bang("!SetVariable", "ClockDate", WEEKDAY_NAMES[now.wday] .. " " .. os.date("%d/%m/%Y"))
end

function Update()
    local remainingSeconds = math.floor(os.difftime(RELEASE_MOMENT, os.time()))
    if remainingSeconds > 0 then
        showCountdown(remainingSeconds)
        return ""
    end
    if not isShowingClock then switchToClock() end
    showClock()
    return ""
end
