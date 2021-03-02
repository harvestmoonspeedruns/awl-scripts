-- This script records the locations of an actor
-- over time and logs them neatly in a text file.

------- Constants and helper functions ----------------------------------------

local MEM = {
    GAME_CLOCK = 0x8166C6C0,
    WAKE_TIME = 0x809E6F18,
    NAMI_NORTH = 0x80F1CA8C,
    NAMI_EAST = 0x80F1CA94,
    NAMI_ROOM = 0x8109E120
}

local TIME = {}
TIME.SECOND = 10
TIME.MINUTE = TIME.SECOND * 60
TIME.HOUR = TIME.MINUTE * 60
TIME.DAY = TIME.HOUR * 24
TIME.MONTH = TIME.DAY * 10
TIME.YEAR = TIME.MONTH * 4
TIME.MONTHS = {
    "Spring",
    "Summer",
    "Fall",
    "Winter"
}
TIME.daysSinceEpoch = function (time)
    return math.floor(time / TIME.DAY)
end
TIME.format = function (time, isLong)
    local year = math.floor(time / TIME.YEAR) + 1
    local month = TIME.MONTHS[math.floor(time % TIME.YEAR / TIME.MONTH) + 1]
    local dayAbsolute = math.floor(time / TIME.DAY) + 1
    local day = math.floor(time % TIME.MONTH / TIME.DAY) + 1
    local hour24 = math.floor(time % TIME.DAY / TIME.HOUR)
    local hour12 = (hour24 - 1) % 12 + 1
    local minute = math.floor(time % TIME.HOUR / TIME.MINUTE)
    local second = math.floor(time % TIME.MINUTE / TIME.SECOND)
    local ampm if hour24 < 12 then ampm = "am" else ampm = "pm" end

    if isLong then
        return string.format("%d\t%2d:%02d:%02d %s", dayAbsolute, hour12, minute, second, ampm)
    else
        return string.format("%d_%d,%02d", dayAbsolute, hour24, minute)
    end
end






ROOM = {
    "", -- Outside
    "?",
    "Home living room",
    "?",
    "?",
    "?",
    "Barn",
    "?",
    "?",
    "Player storeroom",
    "?",
    "Shed",
    "Takakura's house",
    "Pyro brothers' loft",
    "Cody's studio",
    "Laboratory",
    "Yurt",
    "Bar",
    "Bar bedroom",
    "Hotel lobby",
    "Hotel bedroom",
    "Hotel kitchen",
    "Nami's room",
    "Rock's room",
    "Hotel upstairs hallway",
    "?",
    "Villa Romana's bedroom",
    "Villa Sebastian's bedroom",
    "Villa kitchen",
    "Villa upstairs tea room",
    "Villa entryway",
    "Villa upstairs hallway",
    "West town house downstairs",
    "West town house upstairs",
    "?",
    "?",
    "East town house",
    "?",
    "Carter's tent",
    "Digsite",
    "Sprite tree interior",
    "Vesta's storeroom",
    "Vesta's downstairs",
    "Vesta's upstairs",
    "?",
    "?",
    "?",
    "?",
    "?",
    "?"
}


------- Callback behavior -----------------------------------------------------

local actors = {}
local startTime
local startFrame
local newWakeUpTime --= TIME.DAY + (21 * TIME.HOUR) + (2 * TIME.MINUTE)
local cancelTime --= newWakeUpTime
local cancelFrame

function onScriptStart()
    MsgBox("Script started")
    -- initialize local variables
    actors[1] = { size = 0, name = "Nami" }
end

function onScriptCancel()
    MsgBox("Script cancelled")
    local endTime = ReadValue32(MEM.GAME_CLOCK)
    local endFrame = GetFrameCount()
    -- Format the records and write them to files
    local actor = actors[1]
    local file = io.open(
        string.format(
            "%s %s_%d to %s_%d.txt",
            actor.name,
            TIME.format(startTime, false),
            startFrame,
            TIME.format(endTime, false),
            endFrame
        ),
        "w+"
    )
    -- all previous data is erased. Append mode is a+
    -- for each record
        -- format time
        -- format room
        -- write day header if it's a new day
        -- write time, north, east, room
    for i=1,actor.size do
        local record = actor[i]
        do
            -- Add a blank line before a new day
            local previousRecord = actor[i-1]
            if previousRecord ~= nil
                and TIME.daysSinceEpoch(previousRecord.time)
                    ~= TIME.daysSinceEpoch(record.time)
            then
                file:write("\n")
            end
        end
        file:write(string.format(
            "%s\t%6.2f\t%6.2f\t%s\n",
            TIME.format(record.time, true),
            record.north,
            record.east,
            ROOM[record.room]
        ))
    end
    file:close()
end

function onScriptUpdate()
    -- set initial conditions for file naming
    local currentTime = ReadValue32(MEM.GAME_CLOCK)
    local currentFrame = GetFrameCount()
    if newWakeUpTime ~= nil then
        WriteValue32(MEM.WAKE_TIME, newWakeUpTime)
    end

    if startTime == nil then startTime = currentTime end
    if startFrame == nil then startFrame = GetFrameCount() end

    local room = ReadValue32(MEM.NAMI_ROOM)
    local north = ReadValueFloat(MEM.NAMI_NORTH)
    local east = ReadValueFloat(MEM.NAMI_EAST)
    local actor = actors[1]
    if (actor.size == 0 -- has the location changed?
        or actor[actor.size].room ~= room
        or actor[actor.size].north ~= north
        or actor[actor.size].east ~= east
    ) then
        actor.size = actor.size + 1
        actor[actor.size] = {
            time = currentTime,
            north = north,
            east = east,
            room = room
        }
    end
    if 
        (cancelTime ~= nil and currentTime >= cancelTime)
        or (cancelFrame ~= nil and currentFrame >= cancelFrame)
    then
        CancelScript()
    end
end

function onStateLoaded()
end

function onStateSaved()
end

------- Testing structure -----------------------------------------------------

if arg ~= nil and arg[1] == "test" then
    print("Test started")

    local frame = 0
    local currentTime = 180000
    local wakeTime = 396000
    local nami = { north = 0.0, east = 0.0, room = 1 }
    local isSelfCancelled = false;

    -- Mockup Dolphin APIs
    function ReadValue32(address)
        local responses = {}
        responses[MEM.GAME_CLOCK] = currentTime
        responses[MEM.WAKE_TIME] = wakeTime
        responses[MEM.NAMI_ROOM] = nami.room
        return responses[address]
    end
    function ReadValueFloat(address)
        local responses = {}
        responses[MEM.NAMI_NORTH] = nami.north
        responses[MEM.NAMI_EAST] = nami.east
        return responses[address]
    end
    function WriteValue32(address, value)
        local responses = {}
        responses[MEM.WAKE_TIME] = function (v) wakeTime = v end
        return responses[address](value)
    end
    function LoadState()
        onStateLoaded()
    end
    function GetFrameCount()
        return frame
    end
    function MsgBox(message, delayMS)
        print(message)
    end
    function CancelScript()
        isSelfCancelled = true
        onScriptCancel()
        print("Test cancelled by script")
        os.exit()
    end

    onScriptStart()

    while not isSelfCancelled do
        onScriptUpdate()
        frame = frame + 1;
        if frame % 3 == 0 then
            currentTime = currentTime + 2400
        end
        if frame % 20 == 0 then
            nami.north = nami.north + 1.1
            nami.east = nami.east + 2.2
            nami.room = (nami.room + 1) % 44
        end
    end

    onScriptCancel()

    print("Test finished")
end