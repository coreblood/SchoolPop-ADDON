------------------------------------------------------------------
-- SchoolPop — color-coded damage by spell school (WotLK 3.3.5a)
-- Floating text tinted by damage school, with an in-game options
-- panel (Esc > Interface > AddOns > SchoolPop, or /sp) for colors,
-- fonts, scroll direction, sizing and toggles.
------------------------------------------------------------------

local ADDON_NAME = "SchoolPop"

--========================== OPTIONS ==============================
-- Defaults. Everything here is editable in-game and saved per
-- character in SchoolPopDB. Edit this table to change defaults.
local DEFAULTS = {
    floating   = true,        -- show floating combat text
    includePet = true,        -- include pet/guardian damage
    healing    = true,        -- show healing you do
    critMarker = "!!!",       -- appended to critical hits
    shortNums  = true,        -- 1234 -> 1.2K, 1500000 -> 1.5M
    icons      = true,        -- show the spell's icon next to the number
    iconScale  = 1.1,         -- icon size relative to font size
    iconSide   = "LEFT",      -- "LEFT" or "RIGHT" of the number
    font       = "Fonts\\FRIZQT__.TTF",
    outline    = "OUTLINE",   -- "", "OUTLINE", "THICKOUTLINE"
    fontSize   = 22,
    critScale  = 1.45,        -- font multiplier for crits
    duration   = 1.6,         -- seconds each line floats
    distance   = 140,         -- pixels travelled over its lifetime
    spread     = 120,         -- random scatter of start points (0 = single column)
    mergeWindow = 0.3,        -- seconds; same-spell hits inside this are summed (0 = off)
    direction  = "ARC",       -- see DIRECTIONS below
    nameplates = true,        -- spawn text over the hit unit's nameplate when visible
    xOffset    = 0,           -- anchor offset from screen center
    yOffset    = 160,
    maxLines   = 20,
    logWindow  = false,       -- show the SchoolPop combat log window
    showItem   = false,       -- "ItemID": name the item a proc comes from in the log
    itemMap    = {},          -- manual proc spellId -> { id = itemId, name = itemName }
    logFilter  = "BOTH",      -- "DAMAGE", "HEALING" or "BOTH"
    logFontSize = 12,         -- font size inside the log window (8-24)
    logOpacity = 0.55,        -- background opacity of the log window (0-1)
    logLocked  = false,       -- lock the log window (no move/resize)
    logTimestamps = false,    -- show [HH:MM:SS] in the log window
    logMaxLines = 500,        -- lines kept in the log window
    logPos     = {},          -- saved position/size of the log window
    minimap    = true,        -- show minimap button
    minimapPos = 220,         -- angle (degrees) around the minimap
    colors     = {},          -- per-school overrides: [mask] = {r,g,b}
}

--===================== SCHOOL LOOKUP TABLE =======================
-- Correct 3.3.5a mask values (Holy is 0x02, not 0x04).
local SCHOOLS = {
    { mask = 0x01, name = "Physical", r = 1.00, g = 1.00, b = 0.00 },
    { mask = 0x02, name = "Holy",     r = 1.00, g = 0.90, b = 0.50 },
    { mask = 0x04, name = "Fire",     r = 1.00, g = 0.50, b = 0.00 },
    { mask = 0x08, name = "Nature",   r = 0.30, g = 1.00, b = 0.30 },
    { mask = 0x10, name = "Frost",    r = 0.50, g = 1.00, b = 1.00 },
    { mask = 0x20, name = "Shadow",   r = 0.50, g = 0.50, b = 1.00 },
    { mask = 0x40, name = "Arcane",   r = 1.00, g = 0.50, b = 1.00 },
}

-- Healing uses its own color (editable in the panel like the schools)
local HEAL = { mask = "heal", name = "Healing", r = 0.20, g = 1.00, b = 0.20 }

-- Fonts shipped with the 3.3.5a client. To use your own, drop a
-- .ttf into Interface\AddOns\SchoolPop\ and add a line like:
--   { key = "Interface\\AddOns\\SchoolPop\\MyFont.ttf", label = "My Font" },
local FONT_DIR = "Interface\\AddOns\\SchoolPop\\Fonts\\"
local FONTS = {
    -- Blizzard fonts shipped with the 3.3.5a client
    { key = "Fonts\\FRIZQT__.TTF",         label = "Friz Quadrata (WoW)" },
    { key = "Fonts\\ARIALN.TTF",           label = "Arial Narrow (WoW)" },
    { key = "Fonts\\MORPHEUS.TTF",         label = "Morpheus (WoW)" },
    { key = "Fonts\\skurri.ttf",           label = "Skurri (WoW)" },
    -- Open-licensed fonts bundled in SchoolPop\Fonts (see OFL.txt)
    { key = FONT_DIR .. "Bangers.ttf",          label = "Bangers (comic impact)" },
    { key = FONT_DIR .. "BlackOpsOne.ttf",      label = "Black Ops One (stencil)" },
    { key = FONT_DIR .. "RussoOne.ttf",         label = "Russo One (bold sans)" },
    { key = FONT_DIR .. "Anton.ttf",            label = "Anton (heavy condensed)" },
    { key = FONT_DIR .. "BebasNeue.ttf",        label = "Bebas Neue (tall caps)" },
    { key = FONT_DIR .. "AlfaSlabOne.ttf",      label = "Alfa Slab One (slab)" },
    { key = FONT_DIR .. "TitanOne.ttf",         label = "Titan One (rounded)" },
    { key = FONT_DIR .. "PathwayGothicOne.ttf", label = "Pathway Gothic (narrow)" },
}

local LOG_FILTERS = {
    { key = "BOTH",    label = "All" },
    { key = "DAMAGE",  label = "Damage" },
    { key = "HEALING", label = "Healing" },
}

local ICON_SIDES = {
    { key = "LEFT",  label = "Icon: Left" },
    { key = "RIGHT", label = "Icon: Right" },
}

local OUTLINES = {
    { key = "",             label = "None" },
    { key = "OUTLINE",      label = "Thin outline" },
    { key = "THICKOUTLINE", label = "Thick outline" },
}

-- x/y are direction multipliers applied to `distance`.
local DIRECTIONS = {
    { key = "UP",        label = "Up",             x =  0,    y =  1    },
    { key = "DOWN",      label = "Down",           x =  0,    y = -1    },
    { key = "LEFT",      label = "Left",           x = -1,    y =  0    },
    { key = "RIGHT",     label = "Right",          x =  1,    y =  0    },
    { key = "UPLEFT",    label = "Up-Left",        x = -0.7,  y =  0.7  },
    { key = "UPRIGHT",   label = "Up-Right",       x =  0.7,  y =  0.7  },
    { key = "DOWNLEFT",  label = "Down-Left",      x = -0.7,  y = -0.7  },
    { key = "DOWNRIGHT", label = "Down-Right",     x =  0.7,  y = -0.7  },
    { key = "STATIC",    label = "Static (fade)",  x =  0,    y =  0    },
    { key = "ARC",       label = "Arc (parabola)", x =  0,    y =  0, arc = true },
}


local function FindByKey(list, key)
    for _, item in ipairs(list) do
        if item.key == key then return item end
    end
    return list[1]
end

local db  -- SavedVariables, set on ADDON_LOADED

--===================== SCHOOL INFO RESOLUTION ====================
local function ToHex(r, g, b)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Returns the effective color for a pure school (user override or default)
local function GetSchoolColor(s)
    local c = db and db.colors[s.mask]
    if c then return c[1], c[2], c[3] end
    return s.r, s.g, s.b
end

-- Cache: mask -> { name, r, g, b, hex }. Rebuilt whenever a color
-- changes (RebuildSchoolInfo); combined masks are blended lazily.
local schoolInfo = {}

local function RebuildSchoolInfo()
    schoolInfo = {}
    for _, s in ipairs(SCHOOLS) do
        local r, g, b = GetSchoolColor(s)
        schoolInfo[s.mask] = { name = s.name, r = r, g = g, b = b, hex = ToHex(r, g, b) }
    end
end

local function GetHealInfo()
    local r, g, b = GetSchoolColor(HEAL)
    return { name = "Healing", r = r, g = g, b = b, hex = ToHex(r, g, b) }
end

local function GetSchoolInfo(mask)
    if not mask or mask == 0 then return schoolInfo[0x01] end
    local info = schoolInfo[mask]
    if info then return info end

    local names, r, g, b, n = {}, 0, 0, 0, 0
    for _, s in ipairs(SCHOOLS) do
        if bit.band(mask, s.mask) ~= 0 then
            local sr, sg, sb = GetSchoolColor(s)
            names[#names + 1] = s.name
            r, g, b, n = r + sr, g + sg, b + sb, n + 1
        end
    end
    if n == 0 then return schoolInfo[0x01] end
    r, g, b = r / n, g / n, b / n
    info = { name = table.concat(names, "+"), r = r, g = g, b = b, hex = ToHex(r, g, b) }
    schoolInfo[mask] = info
    return info
end

--================= NUMBER FORMAT & ICON LOOKUP ===================
-- Abbreviate at each 1000x threshold: K, M, B, T, Qa, Qi, S.
local NUM_SUFFIX = {
    { 1e21, "S" }, { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" },
}
local function FormatNumber(n)
    if not db.shortNums or n < 1000 then return tostring(n) end
    for _, s in ipairs(NUM_SUFFIX) do
        if n >= s[1] then
            local out = string.format("%.1f%s", n / s[1], s[2])
            return (string.gsub(out, "%.0" .. s[2], s[2]))  -- 2.0B -> 2B
        end
    end
    if n >= 10000 then
        return string.format("%dK", math.floor(n / 1000 + 0.5))
    end
    local out = string.format("%.1fK", n / 1000)
    return (string.gsub(out, "%.0K", "K"))
end

local MELEE_ICON   = "Interface\\Icons\\Ability_MeleeDamage"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local iconCache = {}

local function GetSpellIcon(spellId)
    if not spellId then return MELEE_ICON end
    local icon = iconCache[spellId]
    if icon then return icon end
    local _, _, tex = GetSpellInfo(spellId)  -- 3.3.5a: name, rank, icon, ...
    icon = tex or UNKNOWN_ICON
    iconCache[spellId] = icon
    return icon
end

local anchor = CreateFrame("Frame", "SchoolPopAnchor", UIParent)
anchor:SetWidth(1)
anchor:SetHeight(1)

--===================== NAMEPLATE TRACKING ========================
-- 3.3.5a gives addons no way to read a unit's screen position, but
-- nameplates are ordinary frames under WorldFrame that the engine
-- keeps positioned over each unit. We find the plate whose name
-- matches the hit unit and spawn the text at its location. Requires
-- nameplates to be shown (V key); otherwise falls back to the
-- screen anchor.
local NAMEPLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"
local plates, lastChildCount = {}, 0

local function IsNamePlate(f)
    if f:GetName() then return false end
    local _, border = f:GetRegions()
    return border and border:GetObjectType() == "Texture"
        and border:GetTexture() == NAMEPLATE_BORDER
end

local function FindNameRegion(f)
    local name = select(7, f:GetRegions())   -- 3.3.5a layout
    if name and name:GetObjectType() == "FontString" then return name end
    for i = 1, select("#", f:GetRegions()) do
        local r = select(i, f:GetRegions())
        if r:GetObjectType() == "FontString" then return r end
    end
end

local function ScanPlates()
    local n = WorldFrame:GetNumChildren()
    if n == lastChildCount then return end
    lastChildCount = n
    local children = { WorldFrame:GetChildren() }
    for _, f in ipairs(children) do
        if plates[f] == nil then
            plates[f] = IsNamePlate(f) and (FindNameRegion(f) or false) or false
        end
    end
end

-- Returns the visible nameplate frame belonging to `unitName`, or nil.
local function FindPlate(unitName)
    if not unitName then return end
    ScanPlates()
    local best, bestAlpha = nil, -1
    for f, nameFS in pairs(plates) do
        if nameFS and f:IsShown() and nameFS:GetText() == unitName then
            local a = f:GetAlpha()          -- current target's plate is alpha 1
            if a > bestAlpha then best, bestAlpha = f, a end
        end
    end
    return best
end

-- Nameplates are recycled by the engine: a plate that was "Sethekk
-- Guard" can become a different unit's plate a second later. A line
-- only follows its plate while the plate is shown AND still carries
-- the same name; otherwise the unit is off-screen and the line hides.
local function PlateIsValid(plate, unitName)
    local nameFS = plates[plate]
    return plate:IsShown() and nameFS and nameFS:GetText() == unitName
end

-- Current x, y of the plate's top-centre, relative to our anchor.
local function PlateOffset(plate)
    local px, py = plate:GetCenter()
    if not px then return end
    local scale = plate:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local ax, ay = anchor:GetCenter()
    return px * scale - ax, py * scale + plate:GetHeight() * scale * 0.5 - ay
end

--==================== FLOATING TEXT ENGINE =======================
-- Pooled FontStrings animated in OnUpdate. Touches no Blizzard
-- combat-text code, so no taint for CombatText, Recount or Skada.

local pool, active = {}, {}
local Notify  -- forward declaration; defined with the log window below

local function ApplyAnchor()
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", db.xOffset, db.yOffset)
end

local function AcquireLine()
    local fs = table.remove(pool)
    if not fs then
        fs = anchor:CreateFontString(nil, "OVERLAY")
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.8)
        -- icon rides along with the text: anchored to the string's left edge
        local icon = anchor:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("RIGHT", fs, "LEFT", -4, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim the default border
        fs.icon = icon
    end
    return fs
end

local function ReleaseLine(line)
    line.fs:Hide()
    line.fs.icon:Hide()
    table.insert(pool, line.fs)
end

-- True if a box of (w x h) centred on x,y would overlap any live line.
local function Collides(x, y, w, h)
    for _, l in ipairs(active) do
        if math.abs(l.x - x) < (l.w + w) * 0.5 and math.abs(l.y - y) < (l.h + h) * 0.5 then
            return true
        end
    end
    return false
end

local SLOT_ORDER = { 0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6 }
local arcSide = 1

local function SpawnText(text, r, g, b, isCrit, iconPath, unitName)
    if #active >= db.maxLines then
        ReleaseLine(table.remove(active, 1))
    end
    local fs = AcquireLine()
    local size = db.fontSize * (isCrit and db.critScale or 1)
    if not fs:SetFont(db.font, size, db.outline) then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, db.outline)
    end
    fs:SetText(text)
    fs:SetTextColor(r, g, b)
    fs:SetAlpha(1)
    local w = fs:GetStringWidth() + 8
    if db.icons and iconPath then
        local isz = size * db.iconScale
        fs.icon:SetWidth(isz)
        fs.icon:SetHeight(isz)
        fs.icon:ClearAllPoints()
        if db.iconSide == "RIGHT" then
            fs.icon:SetPoint("LEFT", fs, "RIGHT", 4, 0)
        else
            fs.icon:SetPoint("RIGHT", fs, "LEFT", -4, 0)
        end
        fs.icon:SetTexture(iconPath)
        fs.icon:SetAlpha(1)
        fs.icon:Show()
        w = w + isz + 4
        fs.hasIcon = true
    else
        fs.icon:Hide()
        fs.hasIcon = false
    end
    local h = size * 1.15

    local dir = FindByKey(DIRECTIONS, db.direction)

    -- base position: over the unit's nameplate if we can find it.
    -- The plate is remembered so the line follows it every frame.
    local bx, by, plate = 0, 0, nil
    if db.nameplates then
        plate = FindPlate(unitName)
        if plate then
            local ox, oy = PlateOffset(plate)
            if ox then bx, by = ox, oy else plate = nil end
        end
    end

    -- scatter
    local sx, sy = 0, 0
    if dir.arc then
        arcSide = -arcSide
        local s = math.floor(db.spread / 3)
        if s > 0 then sx = math.random(-s, s) end
    elseif db.spread > 0 then
        local s = math.floor(db.spread)
        sx = math.random(-s, s)
        sy = math.random(-math.floor(s / 2), math.floor(s / 2))
    end
    local x, y = bx + sx, by + sy

    -- Collision avoidance: if the start box overlaps a live line, step
    -- up/down one line-height at a time until a free slot is found.
    -- Lines that spawn together follow the same path, so they stay apart.
    for _, k in ipairs(SLOT_ORDER) do
        if not Collides(x, y + k * h, w, h) then
            y = y + k * h
            break
        end
    end

    -- ox/oy are relative to the base (plate or anchor); x/y are absolute
    local line = { fs = fs, elapsed = 0, ox = x - bx, oy = y - by, x = x, y = y,
                   w = w, h = h, dx = dir.x, dy = dir.y, arc = dir.arc, side = arcSide,
                   plate = plate, plateName = unitName, hidden = false }
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", anchor, "CENTER", x, y)
    fs:Show()
    table.insert(active, line)
end

--------------------------- MERGING -------------------------------
-- Hits of the same spell that land within `mergeWindow` seconds
-- (multi-target Consecration ticks, Divine Storm, etc.) are summed
-- into one line "18.7M!!! x5" instead of five overlapping lines.
local pending, pendingCount = {}, 0

local function FlushPending(p)
    local text = (p.isHeal and "+" or "") .. FormatNumber(p.amount)
    if p.crit then text = text .. db.critMarker end
    if p.count > 1 then text = text .. " x" .. p.count end
    if p.isPet then text = text .. " (pet)" end
    SpawnText(text, p.r, p.g, p.b, p.crit, p.icon, p.unit)
end

local function QueueText(key, amount, isCrit, info, icon, unitName, isHeal, isPet)
    if (db.mergeWindow or 0) <= 0 then
        FlushPending({ amount = amount, count = 1, crit = isCrit, r = info.r, g = info.g,
            b = info.b, icon = icon, unit = unitName, isHeal = isHeal, isPet = isPet })
        return
    end
    local p = pending[key]
    if p then
        p.amount = p.amount + amount
        p.count = p.count + 1
        p.crit = p.crit or isCrit
        p.unit = unitName
    else
        pending[key] = { t = GetTime(), amount = amount, count = 1, crit = isCrit,
            r = info.r, g = info.g, b = info.b, icon = icon, unit = unitName,
            isHeal = isHeal, isPet = isPet }
        pendingCount = pendingCount + 1
    end
end

dmgPump = CreateFrame("Frame")
dmgPump:Hide()
dmgPump:SetScript("OnUpdate", function(self, dt)
    dmgTick = dmgTick + dt
    if dmgTick < 0.5 then return end
    dmgTick = 0
    local any = false
    for sid in pairs(dmgWanted) do
        if spellDmg[sid] then dmgWanted[sid] = nil
        else any = true
            SendAddonMessage("REAGENTBANK", "USPELLDMG:" .. sid, "WHISPER", UnitName("player"))
        end
    end
    dmgTries = dmgTries + 1
    if not any or dmgTries > 20 then self:Hide(); dmgTries = 0 end
end)

anchor:SetScript("OnUpdate", function(self, dt)
    if pendingCount > 0 then
        local now = GetTime()
        for key, p in pairs(pending) do
            if now - p.t >= db.mergeWindow then
                pending[key] = nil
                pendingCount = pendingCount - 1
                FlushPending(p)
            end
        end
    end
    if #active == 0 then return end
    local i = 1
    while i <= #active do
        local line = active[i]
        line.elapsed = line.elapsed + dt
        local p = line.elapsed / db.duration
        if p >= 1 then
            ReleaseLine(line)
            table.remove(active, i)
        else
            -- base position: follow the plate if we have one
            local bx, by, visible = 0, 0, true
            if line.plate then
                if PlateIsValid(line.plate, line.plateName) then
                    bx, by = PlateOffset(line.plate)
                    if not bx then visible = false end
                else
                    visible = false   -- unit scrolled off-screen / plate recycled
                end
            end

            if visible then
                local x, y
                if line.arc then
                    -- parabola: rises to a peak around 40% then falls away
                    x = bx + line.ox + line.side * p * db.distance * 0.8
                    y = by + line.oy + db.distance * (1.6 * p - 2 * p * p)
                else
                    x = bx + line.ox + line.dx * p * db.distance
                    y = by + line.oy + line.dy * p * db.distance
                end
                line.x, line.y = x, y
                line.fs:ClearAllPoints()
                line.fs:SetPoint("CENTER", self, "CENTER", x, y)
                local a = (p > 0.65) and (1 - (p - 0.65) / 0.35) or 1
                line.fs:SetAlpha(a)
                line.fs.icon:SetAlpha(a)
                if line.hidden then
                    line.hidden = false
                    line.fs:Show()
                    if line.fs.hasIcon then line.fs.icon:Show() end
                end
            elseif not line.hidden then
                line.hidden = true
                line.fs:Hide()
                line.fs.icon:Hide()
                line.x, line.y = -99999, -99999  -- never collides while hidden
            end
            i = i + 1
        end
    end
end)

-- sample spell IDs per school (any valid ID works; only the icon is used)
local TEST_SPELLS = { [0x01] = 6603, [0x02] = 585, [0x04] = 133, [0x08] = 5176,
                      [0x10] = 116, [0x20] = 8092, [0x40] = 30451 }

local function RunTest()
    -- All normal hits; the last line is the only crit (bigger, with marker).
    -- In nameplate mode the text appears over your current target.
    local tgt = UnitExists("target") and UnitName("target") or nil
    local amounts = { 843, 1250, 25400, 56000, 127000, 556000, 1200000 }
    for i, s in ipairs(SCHOOLS) do
        local info = GetSchoolInfo(s.mask)
        QueueText("test" .. i, amounts[i], false, info, GetSpellIcon(TEST_SPELLS[s.mask]), tgt, false)
    end
    QueueText("testheal", 18500, false, GetHealInfo(), GetSpellIcon(2061), tgt, true)
    local ff = GetSchoolInfo(0x14) -- Fire+Frost blend, shown as a crit
    QueueText("testcrit", 1500000, true, ff, GetSpellIcon(44614), tgt, false)
    -- three hits of the same "spell" -> one merged line "x3"
    for _ = 1, 3 do
        QueueText("testmerge", 6200000, true, GetSchoolInfo(0x02), GetSpellIcon(20271), tgt, false)
    end
    Notify("SchoolPop test: 8 normal hits, 1 crit, and 3 same-spell "
        .. "crits merged into one 'x3' line.")
end

--==================== PROC -> ITEM RESOLUTION ====================
-- 3.3.5a has no API that links a proc spell to the item that owns
-- it, so this is done in three layers:
--   1. db.itemMap  - assignments you make with /sp item <spellId> [item]
--   2. auto-match  - an equipped item whose name, or whose GetItemSpell()
--                    name, equals the proc's spell name
--   3. detection   - any damage/heal spell that is NOT in your
--                    spellbook is flagged as a proc; the log shows its
--                    spell ID so you can assign it with /sp item.
local knownSpells = {}      -- spell name -> true (your spellbook + pet book)
local equippedBySpell = {}  -- spell name -> { id, name } (auto-match)

local function ScanSpellbook()
    knownSpells = {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, num = GetSpellTabInfo(tab)
        for i = offset + 1, offset + num do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if name then knownSpells[name] = true end
        end
    end
    if HasPetSpells and HasPetSpells() then
        local numPet = HasPetSpells()
        for i = 1, numPet do
            local name = GetSpellName(i, BOOKTYPE_PET)
            if name then knownSpells[name] = true end
        end
    end
    knownSpells["Melee"] = true
end

-- hidden tooltip used to read equipped items' text
local scanTip = CreateFrame("GameTooltip", "SchoolPopScanTip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local equippedNames = {}   -- lower(item name) -> item name
local equippedSets  = {}   -- lower(set name)  -> set name
local equippedText  = {}   -- item name -> lowercased tooltip text
--------------- Uncapped "soulbound proc" wire listener -----------------
-- On this server the Uncapped addon receives every imprinted (soulbound)
-- proc from the server over CHAT_MSG_ADDON, prefix "UNC", as:
--   ICITEM:E:<slot>  /  ICITEM:B:<bag>:<slot>   (start of one item)
--   ICIPROC:<spellId>:<trigger>:<chance>:<mag>  (a proc on that item)
--   ICINVEND                                     (end of inventory)
-- Uncapped asks for it on login and on every gear change; we just listen
-- to the same stream, so we know the EXACT spell ID on each item.
local UNC_PREFIX = "UNC"
local UNC_TRIGGER = { [0] = "On Use", [1] = "Passive", [2] = "On Hit", [3] = "On Cast" }
local boundStaging, boundCur = {}, nil
local boundBySpell = {}    -- spellId -> { {key=, item=, trigger=}, ... }
local boundByKey   = {}    -- "E:<slot>" / "B:<bag>:<slot>" -> { proc tables }
local boundProcInfo = {}   -- spellId -> proc table (mag, bases, spPct, apPct, ...)
local SchoolPop_RefreshInvID  -- defined with the InvID window below
local boundReceived = false

local function BoundItemName(key)
    local slot = string.match(key, "^E:(%d+)$")
    if slot then
        local link = GetInventoryItemLink("player", tonumber(slot))
        return link and GetItemInfo(link) or ("equipped slot " .. slot), true
    end
    local bag, bslot = string.match(key, "^B:(%d+):(%d+)$")
    if bag then
        local link = GetContainerItemLink(tonumber(bag), tonumber(bslot))
        return (link and GetItemInfo(link) or "?") .. " (bag " .. bag .. ")", false
    end
    return key, false
end

local function OnUncappedLine(body)
    local cmd, rest = string.match(body, "^(%u+):?(.*)$")
    if not cmd then return end
    if cmd == "ICITEM" then
        boundCur = rest
        boundStaging[rest] = boundStaging[rest] or {}
    elseif cmd == "ICIPROC" then
        local sid, tr, ch, mg = string.match(rest, "^(%d+):(%d+):(%d+):(%d+)")
        if sid and boundCur then
            table.insert(boundStaging[boundCur], { spellId = tonumber(sid),
                trigger = tonumber(tr), chance = tonumber(ch), mag = tonumber(mg) or 100,
                bases = {} })
        end
    elseif cmd == "ICIPROCBP" then
        local cur = boundCur and boundStaging[boundCur]
        local last = cur and cur[#cur]
        if last then
            local v = {}
            for n in string.gmatch(rest, "(%d+)") do v[#v + 1] = tonumber(n) end
            last.bases = v
        end
    elseif cmd == "ICIPROCFACT" then
        local sc, rs, sp, ap = string.match(rest, "^(%d+):(%d+):(%d+):(%d+)$")
        local cur = boundCur and boundStaging[boundCur]
        local last = cur and cur[#cur]
        if last and sc then
            last.stackCap = tonumber(sc) or 0
            last.rankScales = (tonumber(rs) or 0) == 1
            last.spPct = tonumber(sp) or 0
            last.apPct = tonumber(ap) or 0
        end
    elseif cmd == "ICINVEND" then
        boundBySpell = {}
        for key, procs in pairs(boundStaging) do
            local name, equipped = BoundItemName(key)
            for _, p in ipairs(procs) do
                boundBySpell[p.spellId] = boundBySpell[p.spellId] or {}
                table.insert(boundBySpell[p.spellId],
                    { key = key, item = name, equipped = equipped, trigger = p.trigger })
                boundProcInfo[p.spellId] = p   -- facts for the hover tooltip
            end
        end
        boundByKey = boundStaging
        boundStaging, boundCur = {}, nil
        boundReceived = true
        if SchoolPop_RefreshInvID then SchoolPop_RefreshInvID() end
    end
end

-- Equipped items carrying this exact spell ID, as "on A, B" (or nil)
local function BoundCarriers(spellId, includeBags)
    local list = spellId and boundBySpell[spellId]
    if not list then return nil end
    local names = {}
    for _, c in ipairs(list) do
        if c.equipped or includeBags then names[#names + 1] = c.item end
    end
    if #names == 0 then return nil end
    return table.concat(names, ", ")
end

local function ScanEquipment()
    equippedBySpell, equippedNames, equippedSets, equippedText = {}, {}, {}, {}
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local itemId = tonumber(string.match(link, "item:(%d+)"))
            local name = GetItemInfo(link)
            if name and itemId then
                local entry = { id = itemId, name = name }
                equippedBySpell[name] = entry
                equippedNames[string.lower(name)] = name
                local spellName = GetItemSpell(link)
                if spellName then equippedBySpell[spellName] = entry end
                -- tooltip text: set membership lines and proc descriptions
                scanTip:ClearLines()
                scanTip:SetInventoryItem("player", slot)
                local lines = {}
                for i = 1, scanTip:NumLines() do
                    local fs = _G["SchoolPopScanTipTextLeft" .. i]
                    local t = fs and fs:GetText()
                    if t then
                        lines[#lines + 1] = string.lower(t)
                        local setName = string.match(t, "^(.-) %(%d+/%d+%)$")
                        if setName then equippedSets[string.lower(setName)] = setName end
                    end
                end
                equippedText[name] = table.concat(lines, "\n")
            end
        end
    end
end

-- Picks the best entry from a ProcDB value (string or list), preferring
-- an item you are wearing or a set you have pieces of.
local function PickSource(value)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return nil end
    for _, v in ipairs(value) do
        local lv = string.lower(v)
        if equippedNames[lv] then return v end
        local setName = string.match(lv, "^(.-) %(set bonus%)$")
        if setName and equippedSets[setName] then return v end
    end
    if #value == 1 then return value[1] end
    local shown = {}
    for i = 1, math.min(3, #value) do shown[i] = value[i] end
    local s = table.concat(shown, " / ")
    if #value > 3 then s = s .. " / ..." end
    return s
end

-- Resolves the source of a spell. Order:
--   1. your own /sp item assignments
--   2. SchoolPop_ProcDB_Manual (hand-maintained overrides)
--   3. spellbook (an ability you know is not a proc)
--   4. SchoolPop_AbilityDB  (damage/heals triggered by your abilities)
--   5. SchoolPop_ProcDB     (items / set bonuses, Vanilla-WotLK)
--   6. equipped item whose tooltip mentions the spell name
-- Returns a source string or nil.
local function ResolveSource(spellId, spellName)
    if not spellId then return nil end
    local manual = db.itemMap[spellId]
    if manual then return manual.name end
    if SchoolPop_ProcDB_Manual and SchoolPop_ProcDB_Manual[spellId] then
        return PickSource(SchoolPop_ProcDB_Manual[spellId])
    end
    if spellName and knownSpells[spellName] then return nil end
    if SchoolPop_AbilityDB and SchoolPop_AbilityDB[spellId] then
        return "via " .. SchoolPop_AbilityDB[spellId]
    end
    if SchoolPop_ProcDB and SchoolPop_ProcDB[spellId] then
        return PickSource(SchoolPop_ProcDB[spellId])
    end
    if spellName and equippedBySpell[spellName] then
        return equippedBySpell[spellName].name
    end
    if spellName then
        local needle = string.lower(spellName)
        for itemName, text in pairs(equippedText) do
            if string.find(text, needle, 1, true) then return itemName end
        end
    end
    return nil
end

-- Builds the " (Source)" suffix for log lines.
local function ItemSuffix(spellId, spellName)
    if not db.showItem then return "" end
    local source = ResolveSource(spellId, spellName)
    local carriers = BoundCarriers(spellId, false)
    if carriers then
        local on = "on " .. carriers
        source = source and (source .. "; " .. on) or on
    end
    -- item/source names and the proc ID are shown in white inside the coloured line
    if source then return string.format(" |cffffffff(%s) (%d)|r", source, spellId) end
    return ""
end

--======================== LOG WINDOW =============================
-- A movable, resizable window with its own ScrollingMessageFrame.
-- Independent of Blizzard's chat system entirely: nothing here is
-- filtered, tabbed or hidden by chat settings.
local logFrame = CreateFrame("Frame", "SchoolPopLogFrame", UIParent)
logFrame:SetWidth(420)
logFrame:SetHeight(160)
logFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
logFrame:SetMovable(true)
logFrame:SetResizable(true)
logFrame:SetMinResize(345, 150)  -- title bar + 3 arrows + meter line + grip
logFrame:SetMaxResize(1000, 700)
do local w, h = UIParent:GetWidth(), UIParent:GetHeight()
   if w and h then logFrame:SetMaxResize(math.min(1000, w - 20), math.min(700, h - 20)) end end
logFrame:SetClampedToScreen(true)
logFrame:SetFrameStrata("LOW")
logFrame:EnableMouse(true)
logFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
logFrame:SetBackdropColor(0, 0, 0, 0.55)
logFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
logFrame:Hide()

local function SaveLogPos()
    local point, _, relPoint, x, y = logFrame:GetPoint()
    db.logPos = { point = point, relPoint = relPoint, x = x, y = y,
                  w = logFrame:GetWidth(), h = logFrame:GetHeight() }
end

local function ApplyLogPos()
    local p = db.logPos
    if p and p.point then
        logFrame:ClearAllPoints()
        logFrame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
        logFrame:SetWidth(p.w)
        logFrame:SetHeight(p.h)
    end
end

-- title bar: drag to move
-- Drag anywhere on the window background (title strip or the log area
-- itself) to move it; buttons and the dropdown still work normally.
logFrame:RegisterForDrag("LeftButton")
logFrame:SetScript("OnDragStart", function(self)
    if not db.logLocked then self:StartMoving() end
end)
logFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveLogPos()
end)

local logIdFilter = nil  -- spell ID currently filtered on ("?" box), or nil
local logTextFilter = nil  -- lowercased name substring, or nil
local logMessages = CreateFrame("ScrollingMessageFrame", nil, logFrame)
logMessages:SetPoint("TOPLEFT", 8, -26)
logMessages:SetPoint("BOTTOMRIGHT", -26, 24)

--------------------------- DPS / HPS METER ------------------------
-- One line under the log: your damage and healing per second for the
-- current fight (from the first hit until you leave combat). The last
-- fight's numbers stay on screen until the next one starts.
local meterText = logFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
meterText:SetPoint("BOTTOMLEFT", 10, 7)
meterText:SetPoint("RIGHT", -70, 0)
meterText:SetJustifyH("LEFT")
meterText:SetText("DPS: 0   HPS: 0")

local meter = { dmg = 0, heal = 0, start = nil, last = nil, active = false }
local meterTimer = 0
local breakdown = { dmg = {}, heal = {} }

local function MeterFormat(n)
    if n >= 1e18 then return string.format("%.2fQi", n / 1e18)
    elseif n >= 1e15 then return string.format("%.2fQa", n / 1e15)
    elseif n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9  then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.1fK", n / 1e3)
    else return string.format("%d", n) end
end

local function MeterRefresh()
    local dur = 0
    if meter.start then
        dur = (meter.active and GetTime() or meter.last or meter.start) - meter.start
    end
    if dur < 1 then dur = 1 end
    local hint = ""
    if logIdFilter then
        hint = hint .. string.format("   |cffff4040[filter: %d]|r", logIdFilter)
    elseif logTextFilter then
        hint = hint .. "   |cffff4040[filter: name]|r"
    end
    if not logMessages:AtBottom() then
        hint = hint .. "   |cffff8000[scrolled up - click the bottom arrow]|r"
    end
    meterText:SetText(string.format("|cffffd100DPS:|r %s   |cff33ff33HPS:|r %s   |cff888888(%ds)|r%s",
        MeterFormat(meter.dmg / dur), MeterFormat(meter.heal / dur), math.floor(dur), hint))
end

-- called by the handlers for every damage/heal you (or your pet) do
local function MeterAdd(amount, isHeal, name, r, g, b, spellId)
    if not amount then return end
    -- Cumulative until reset: start the clock on the first action after a reset,
    -- then keep accumulating across fights (no auto-reset on a new fight).
    if not meter.start then
        meter.start = GetTime()
        meter.active = true
    end
    meter.last = GetTime()
    if isHeal then meter.heal = meter.heal + amount else meter.dmg = meter.dmg + amount end
    local tbl = isHeal and breakdown.heal or breakdown.dmg
    -- key by spell ID so same-named procs stay separate; melee has no id
    local key = spellId or "melee"
    local e = tbl[key]
    if not e then
        e = { name = name or "Unknown", total = 0, hits = 0, r = r, g = g, b = b, id = spellId }
        tbl[key] = e
    end
    e.total = e.total + amount
    e.hits = e.hits + 1
end

local function MeterCombatEnded()
    -- cumulative meter keeps running; just refresh the display
    MeterRefresh()
end

-- Clear button at the bottom-right: clears the log AND resets the DPS/HPS meter
local meterReset = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
meterReset:SetPoint("BOTTOMRIGHT", -20, 4)
meterReset:SetWidth(44)
meterReset:SetHeight(15)
meterReset:SetText("Clear")
meterReset:SetScript("OnClick", function()
    meter.dmg, meter.heal, meter.active = 0, 0, false
    meter.start, meter.last = nil, nil
    breakdown.dmg, breakdown.heal = {}, {}
    MeterRefresh()
    if SchoolPop_RefreshBreakdown then SchoolPop_RefreshBreakdown() end
    if SchoolPop_ClearLog then SchoolPop_ClearLog() end
end)
meterReset:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Clear log and reset DPS / HPS")
    GameTooltip:Show()
end)
meterReset:SetScript("OnLeave", function() GameTooltip:Hide() end)

logFrame:SetScript("OnUpdate", function(self, dt)
    meterTimer = meterTimer + dt
    if meterTimer >= 0.5 then
        meterTimer = 0
        MeterRefresh()
    end
end)
logMessages:SetJustifyH("LEFT")
logMessages:SetFading(false)
logMessages:SetInsertMode("BOTTOM")
logMessages:EnableMouseWheel(true)
logMessages:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)

local logClose = CreateFrame("Button", nil, logFrame, "UIPanelCloseButton")
logClose:SetPoint("TOPRIGHT", 3, 3)
logClose:SetHitRectInsets(0, 0, 0, 0)
logClose:SetWidth(24)
logClose:SetHeight(24)

-- plain-text copy of every line (for export); capped like the window
local logBuffer = {}   -- plain-text lines (timestamped) for Export
local logEntries = {}  -- { text=, r=, g=, b=, spellId=, stamp= } for re-rendering
local RenderLog          -- forward declaration (defined next to LogLine)

function SchoolPop_ClearLog()
    logMessages:Clear()
    logMessages:ScrollToBottom()
    logBuffer = {}
    logEntries = {}
end

-- scroll buttons (up / down / jump to bottom) down the right edge
local function LogScrollButton(tex, anchorTo, y, onClick)
    local b = CreateFrame("Button", nil, logFrame)
    b:SetWidth(20)
    b:SetHeight(20)
    if anchorTo then
        b:SetPoint("TOP", anchorTo, "BOTTOM", 0, y)
    else
        b:SetPoint("TOPRIGHT", logFrame, "TOPRIGHT", -2, y)
    end
    b:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-" .. tex .. "-Up")
    b:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-" .. tex .. "-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", onClick)
    return b
end
local logUp     = LogScrollButton("ScrollUp",   nil,     -26, function() logMessages:ScrollUp() end)
local logDown   = LogScrollButton("ScrollDown", logUp,   0,   function() logMessages:ScrollDown() end)
local logBottom = LogScrollButton("ScrollEnd",  logDown, 0,   function() logMessages:ScrollToBottom() end)

--------------------------- EXPORT --------------------------------
-- WoW addons cannot write arbitrary files; the only disk output the
-- client allows is SavedVariables, written on logout or /reload.
-- So "Export" does two things: opens a window with the log as plain
-- text pre-selected (Ctrl+C, then paste into Word/Notepad), AND
-- stores the same text in the SchoolPopExport saved variable, which
-- the client writes to
--   WTF\Account\<ACCOUNT>\SavedVariables\SchoolPopExport.lua
-- the next time you log out or reload.
local exportFrame = CreateFrame("Frame", "SchoolPopExportFrame", UIParent)
exportFrame:SetWidth(540)
exportFrame:SetHeight(380)
exportFrame:SetPoint("CENTER")
exportFrame:SetFrameStrata("DIALOG")
exportFrame:SetMovable(true)
exportFrame:EnableMouse(true)
exportFrame:SetClampedToScreen(true)
exportFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
exportFrame:Hide()

local exportTitle = CreateFrame("Frame", nil, exportFrame)
exportTitle:SetPoint("TOPLEFT", 12, -12)
exportTitle:SetPoint("TOPRIGHT", -12, -12)
exportTitle:SetHeight(20)
exportTitle:EnableMouse(true)
exportTitle:RegisterForDrag("LeftButton")
exportTitle:SetScript("OnDragStart", function() exportFrame:StartMoving() end)
exportTitle:SetScript("OnDragStop", function() exportFrame:StopMovingOrSizing() end)
local exportTitleText = exportTitle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
exportTitleText:SetPoint("CENTER")
exportTitleText:SetText("SchoolPop Log Export")

local exportHint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportHint:SetPoint("BOTTOM", 0, 20)
exportHint:SetText("Text is selected: press Ctrl+C, then paste into Word or Notepad. "
    .. "Also saved to WTF\\...\\SavedVariables\\SchoolPopExport.lua on logout/reload.")

local exportScroll = CreateFrame("ScrollFrame", "SchoolPopExportScroll", exportFrame,
    "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", 16, -36)
exportScroll:SetPoint("BOTTOMRIGHT", -36, 40)

local exportEdit = CreateFrame("EditBox", nil, exportScroll)
exportEdit:SetMultiLine(true)
exportEdit:SetAutoFocus(false)
exportEdit:SetMaxLetters(0)
exportEdit:SetFontObject(ChatFontNormal)
exportEdit:SetWidth(480)
exportEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
exportScroll:SetScrollChild(exportEdit)

local exportClose = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
exportClose:SetPoint("TOPRIGHT", -6, -6)
exportClose:SetHitRectInsets(0, 0, 0, 0)

local function ExportText(title, text, lines)
    exportTitleText:SetText(title)
    if text == "" then text = "(nothing to export)" end
    exportEdit:SetText(text)
    exportFrame:Show()
    exportEdit:SetFocus()
    exportEdit:HighlightText()
    SchoolPopExport = SchoolPopExport or {}
    SchoolPopExport.exportedAt = date("%Y-%m-%d %H:%M:%S")
    SchoolPopExport.title = title
    SchoolPopExport.lines = lines
end

local function ExportLog()
    ExportText("SchoolPop Log Export", table.concat(logBuffer, "\n"), { unpack(logBuffer) })
end

--=================== SERVER SPELL DAMAGE =========================
-- The server computes each proc's real hit "with your stats" and the
-- Uncapped UI shows it via USPELLDMG -> USPELLDMGR. We ask the same
-- question and display the same figure, so it always matches the
-- Extraction window. Cache is cleared when gear changes.
local spellDmg = {}       -- spellId -> { min, max }
local dmgWanted = {}
local dmgTick, dmgTries = 0, 0
local dmgPump
local function RequestSpellDamage(spellId)
    -- InvID is disabled in this build; no USPELLDMG traffic. (kept for structure)
end

-- Ask the server for every imprinted proc at once (called when the window
-- opens / data arrives), so the figure is already cached before you hover.
function SchoolPop_PrefetchDamage()
    for _, list in pairs(boundBySpell) do
        for _, c in ipairs(list) do
            if c.equipped then RequestSpellDamage(c.spellId) end
        end
    end
end

-- Same abbreviation the Uncapped tooltip uses, so our number reads identically.
local function AbbrevNum(n)
    n = tonumber(n) or 0
    local scale, suffix
    if     n >= 1e18 then scale, suffix = 1e18, "Qi"
    elseif n >= 1e15 then scale, suffix = 1e15, "Qa"
    elseif n >= 1e12 then scale, suffix = 1e12, "T"
    elseif n >= 1e9  then scale, suffix = 1e9,  "B"
    elseif n >= 1e6  then scale, suffix = 1e6,  "M"
    elseif n >= 1e3  then scale, suffix = 1e3,  "K"
    else return string.format("%d", math.floor(n)) end
    local whole = math.floor(n / scale)
    local frac  = math.floor(n / (scale / 100)) % 100
    if frac > 0 then return string.format("%d.%02d%s", whole, frac, suffix) end
    return string.format("%d%s", whole, suffix)
end

--=================== PROC POTENCY TOOLTIP ========================
-- Hidden tooltip to scrape the spell's own description (no
-- GetSpellDescription on 3.3.5a; spell hyperlinks work).

function ShowProcTooltip(anchor, spellId)
    local pname = GetSpellInfo(spellId) or "Proc"
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:AddLine(pname, 1, 0.82, 0)
    local p = boundProcInfo[spellId]
    -- Server-computed "with your stats" figure (identical to the Extraction window)
    local dmg = spellDmg[spellId]
    if dmg then
        if dmg[2] and dmg[2] > dmg[1] then
            GameTooltip:AddLine("Approx. " .. AbbrevNum(dmg[1]) .. " - " .. AbbrevNum(dmg[2])
                .. " with your stats", 1, 0.82, 0)
        else
            GameTooltip:AddLine("Approx. " .. AbbrevNum(dmg[1]) .. " with your stats", 1, 0.82, 0)
        end
    else
        RequestSpellDamage(spellId)   -- reply arrives async; next hover shows it
        GameTooltip:AddLine("Calculating with your stats...", 0.6, 0.6, 0.6)
    end
    if p then
        if p.chance and p.chance > 0 then
            GameTooltip:AddLine(string.format("Proc chance: %d%%", p.chance), 0.7, 0.7, 0.7)
        end
        if p.stackCap and p.stackCap > 1 then
            GameTooltip:AddLine("Stacks up to " .. p.stackCap, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:Show()
end

--======================= INVID WINDOW ============================
-- Lists every equipped item with its imprinted procs:
--   Item name - Proc name - Proc ID - Item of origin
local invFrame = CreateFrame("Frame", "SchoolPopInvIDFrame", UIParent)
invFrame:SetWidth(560)
invFrame:SetHeight(300)
invFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
invFrame:SetMovable(true)
invFrame:SetResizable(true)
invFrame:SetMinResize(360, 140)
invFrame:SetMaxResize(1000, 700)
do local w, h = UIParent:GetWidth(), UIParent:GetHeight()
   if w and h then invFrame:SetMaxResize(math.min(1000, w - 20), math.min(700, h - 20)) end end
invFrame:SetClampedToScreen(true)
invFrame:SetFrameStrata("MEDIUM")
invFrame:EnableMouse(true)
invFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
invFrame:SetBackdropColor(0, 0, 0, 0.8)
invFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
invFrame:RegisterForDrag("LeftButton")
invFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
invFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
invFrame:Hide()
tinsert(UISpecialFrames, "SchoolPopInvIDFrame")  -- Esc closes it

local invTitle = invFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
invTitle:SetPoint("TOPLEFT", 10, -6)
invTitle:SetText("InvID - imprinted procs on equipped items")

-- Real columns: a header row plus pooled row-frames inside a scroll frame.
-- Column widths are fractions of the window width, so they follow resizing.
local INV_COLS = {
    { title = "Item",           w = 0.26 },
    { title = "Imprinted proc", w = 0.20 },
    { title = "Proc ID",        w = 0.09 },
    { title = "Item of origin", w = 0.25 },
    { title = "Dropped by",     w = 0.20 },
}

local function DropText(spellId)
    local d = SchoolPop_DropDB and SchoolPop_DropDB[spellId]
    if not d then return "-" end
    return table.concat(d, ", ")
end
local INV_FONT = "Fonts\\ARIALN.TTF"
local INV_FONT_SIZE = 13
local INV_ROW_H = 17

local invScroll = CreateFrame("ScrollFrame", "SchoolPopInvScroll", invFrame,
    "UIPanelScrollFrameTemplate")
invScroll:SetPoint("TOPLEFT", 8, -44)
invScroll:SetPoint("BOTTOMRIGHT", -30, 40)

local invContent = CreateFrame("Frame", nil, invScroll)
invContent:SetWidth(1)
invContent:SetHeight(1)
invScroll:SetScrollChild(invContent)

-- header cells sit on the main frame, above the scroll area
local invHeader = {}
for c = 1, #INV_COLS do
    local fs = invFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetHeight(14)
    fs:SetText(INV_COLS[c].title)
    invHeader[c] = fs
end
local invHeaderLine = invFrame:CreateTexture(nil, "ARTWORK")
invHeaderLine:SetTexture(1, 0.82, 0)
invHeaderLine:SetHeight(1)
invHeaderLine:SetAlpha(0.5)

-- pooled data rows: one frame with four cell FontStrings each
local invRowPool = {}
local function InvAcquireRow(index)
    local row = invRowPool[index]
    if not row then
        row = CreateFrame("Frame", nil, invContent)
        row:SetHeight(INV_ROW_H)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if not self.spellId then return end
            ShowProcTooltip(self, self.spellId)
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.cells = {}
        for c = 1, #INV_COLS do
            local fs = row:CreateFontString(nil, "OVERLAY")
            fs:SetFont(INV_FONT, INV_FONT_SIZE, "")
            fs:SetJustifyH("LEFT")
            fs:SetHeight(INV_ROW_H)
            row.cells[c] = fs
        end
        invRowPool[index] = row
    end
    return row
end

local invUsedRows = 0

-- warning label under the scroll area (reserved strip at the bottom)
local invWarning = invFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
invWarning:SetPoint("BOTTOMLEFT", 10, 6)
invWarning:SetPoint("BOTTOMRIGHT", -10, 6)
invWarning:SetJustifyH("LEFT")
invWarning:SetTextColor(1, 0.3, 0.3)
invWarning:Hide()

-- position headers and size every cell from the current window width
local function InvLayout()
    local width = invScroll:GetWidth()
    if not width or width < 50 then return end
    invContent:SetWidth(width)
    local x = 0
    for c, col in ipairs(INV_COLS) do
        local w = math.floor(width * col.w) - 6
        invHeader[c]:ClearAllPoints()
        invHeader[c]:SetPoint("TOPLEFT", invFrame, "TOPLEFT", 8 + x, -28)
        invHeader[c]:SetWidth(w)
        for i = 1, invUsedRows do
            local cellFS = invRowPool[i].cells[c]
            cellFS:ClearAllPoints()
            cellFS:SetPoint("LEFT", invRowPool[i], "LEFT", x, 0)
            cellFS:SetWidth(w)
        end
        x = x + math.floor(width * col.w)
    end
    invHeaderLine:ClearAllPoints()
    invHeaderLine:SetPoint("TOPLEFT", 8, -42)
    invHeaderLine:SetPoint("TOPRIGHT", -30, -42)
end
invFrame:SetScript("OnSizeChanged", function() InvLayout() end)

local invClose = CreateFrame("Button", nil, invFrame, "UIPanelCloseButton")
invClose:SetPoint("TOPRIGHT", 3, 3)
invClose:SetWidth(24)
invClose:SetHeight(24)

local invGrip = CreateFrame("Button", nil, invFrame)
invGrip:SetWidth(16)
invGrip:SetHeight(16)
invGrip:SetPoint("BOTTOMRIGHT", -2, 2)
invGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
invGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
invGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
invGrip:SetScript("OnMouseDown", function() invFrame:StartSizing("BOTTOMRIGHT") end)
invGrip:SetScript("OnMouseUp", function() invFrame:StopMovingOrSizing() end)

local invRows = {}   -- plain-text rows for Print

-- Origin of a proc from the databases only (no "on ..." carrier part)
local function OriginOf(spellId, spellName)
    local manual = db.itemMap[spellId]
    if manual then return manual.name end
    if SchoolPop_ProcDB_Manual and SchoolPop_ProcDB_Manual[spellId] then
        return PickSource(SchoolPop_ProcDB_Manual[spellId])
    end
    if SchoolPop_AbilityDB and SchoolPop_AbilityDB[spellId] then
        return SchoolPop_AbilityDB[spellId] .. " (ability)"
    end
    if SchoolPop_ProcDB and SchoolPop_ProcDB[spellId] then
        return PickSource(SchoolPop_ProcDB[spellId])
    end
    return "-"
end


-- On 3.3.5a GetItemInfo returns nil until the item is cached; prime the cache
-- for every equipped item and re-render as names resolve, so the list fills in
-- quickly on the first open instead of showing "slot N".
local SchoolPop_itemPrimer = CreateFrame("Frame")
SchoolPop_itemPrimer:Hide()
local primerElapsed = 0
SchoolPop_itemPrimer:SetScript("OnUpdate", function(self, dt)
    primerElapsed = primerElapsed + dt
    local allKnown = true
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and not GetItemInfo(link) then allKnown = false end
    end
    if allKnown or primerElapsed > 3 then
        self:Hide(); primerElapsed = 0
        SchoolPop_RefreshInvID()   -- final re-render with everything cached
    elseif math.floor(primerElapsed * 5) % 2 == 0 then
        SchoolPop_RefreshInvID()   -- periodic re-render as items trickle in
    end
end)

SchoolPop_RefreshInvID = function()
    if not invFrame:IsShown() then return end
    SchoolPop_PrefetchDamage()
    invRows = {}
    local n = 0
    local function AddRow(cols, r, g, b, idR, idG, idB)
        n = n + 1
        local row = InvAcquireRow(n)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", invContent, "TOPLEFT", 0, -(n - 1) * INV_ROW_H)
        row:SetPoint("RIGHT", invContent, "RIGHT", 0, 0)
        for c = 1, #INV_COLS do
            row.cells[c]:SetText(cols[c] or "")
            if c == 3 and idR then
                row.cells[c]:SetTextColor(idR, idG, idB)
            else
                row.cells[c]:SetTextColor(r, g, b)
            end
        end
        row.spellId = cols.spellId   -- for the hover tooltip
        row:Show()
        invRows[#invRows + 1] = table.concat({ cols[1] or "", cols[2] or "",
            cols[3] or "", cols[4] or "", cols[5] or "" }, "  -  ")
    end

    if not boundReceived then
        AddRow({ "No imprint data received from the server yet (is Uncapped loaded?)" },
            1, 0.5, 0.5)
    else
        -- count how many equipped items carry each proc ID
        local count = {}
        for slot = 1, 19 do
            for _, p in ipairs(boundByKey["E:" .. slot] or {}) do
                count[p.spellId] = (count[p.spellId] or 0) + 1
            end
        end
        local duplicates = false
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link then
                local name = GetItemInfo(link) or ("slot " .. slot)
                local procs = boundByKey["E:" .. slot]
                if procs and #procs > 0 then
                    for _, p in ipairs(procs) do
                        local pname = GetSpellInfo(p.spellId) or "?"
                        local dup = (count[p.spellId] or 0) > 1
                        if dup then duplicates = true end
                        local cols = { name, pname, tostring(p.spellId),
                            OriginOf(p.spellId, pname), DropText(p.spellId), spellId = p.spellId }
                        if dup then
                            AddRow(cols, 1, 0.25, 0.25, 1, 0.25, 0.25)
                        else
                            AddRow(cols, 0.75, 0.55, 1, 1, 1, 1)
                        end
                    end
                else
                    AddRow({ name, "-", "-", "-", "-" }, 0.6, 0.6, 0.6)
                end
            end
        end
        if duplicates then
            invWarning:SetText("Two or more items (in red) carry the same proc. Procs won't "
                .. "proc more than once no matter how many times you imprint them on an item.")
            invWarning:Show()
        else
            invWarning:Hide()
        end
    end

    for i = n + 1, invUsedRows do invRowPool[i]:Hide() end
    invUsedRows = n
    invContent:SetHeight(math.max(1, n * INV_ROW_H))
    InvLayout()
end

local invPrint = CreateFrame("Button", nil, invFrame, "UIPanelButtonTemplate")
invPrint:SetPoint("RIGHT", invClose, "LEFT", 2, 0)
invPrint:SetWidth(50)
invPrint:SetHeight(16)
invPrint:SetText("Print")
invPrint:SetScript("OnClick", function()
    local out = { "Item  -  Imprinted proc  -  Proc ID  -  Item of origin" }
    for _, r in ipairs(invRows) do out[#out + 1] = r end
    if invWarning:IsShown() then
        out[#out + 1] = ""
        out[#out + 1] = invWarning:GetText()
    end
    ExportText("SchoolPop InvID Export", table.concat(out, "\n"), out)
end)

local invRefresh = CreateFrame("Button", nil, invFrame, "UIPanelButtonTemplate")
invRefresh:SetPoint("RIGHT", invPrint, "LEFT", -2, 0)
invRefresh:SetWidth(56)
invRefresh:SetHeight(16)
invRefresh:SetText("Refresh")
invRefresh:SetScript("OnClick", function() SchoolPop_RefreshInvID() end)

local invReset = CreateFrame("Button", nil, invFrame, "UIPanelButtonTemplate")
invReset:SetPoint("RIGHT", invRefresh, "LEFT", -2, 0)
invReset:SetWidth(50)
invReset:SetHeight(16)
invReset:SetText("Reset")
invReset:SetScript("OnClick", function()
    invFrame:ClearAllPoints()
    invFrame:SetWidth(560)
    invFrame:SetHeight(300)
    invFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    InvLayout()
end)

-- Ask the server for a fresh soulbound-inventory stream immediately.
local function RequestImprints()
    SendAddonMessage("REAGENTBANK", "ICINV", "WHISPER", UnitName("player"))
end

function SchoolPop_ToggleInvID()
    if invFrame:IsShown() then
        invFrame:Hide()
    else
        invFrame:Show()
        SchoolPop_RefreshInvID()
        SchoolPop_itemPrimer:Show()
        RequestImprints()
    end
end

-- filter dropdown in the log window's own title bar
local logFilterDD = CreateFrame("Frame", "SchoolPopLogFilterDD", logFrame, "UIDropDownMenuTemplate")
logFilterDD:SetPoint("TOPLEFT", logFrame, "TOPLEFT", -12, -1)
UIDropDownMenu_SetWidth(logFilterDD, 70)
local function LogFilterLabel()
    for _, f in ipairs(LOG_FILTERS) do
        if f.key == db.logFilter then return f.label end
    end
    return LOG_FILTERS[1].label
end
-- NOTE: in 3.3.5a UIDropDownMenu_Initialize runs the init function
-- immediately, so it must not be called at file load (db is nil then).
-- It is called from SchoolPop_UpdateLogWindow after ADDON_LOADED.
local logFilterInitialized = false
local function LogFilterInit()
    for _, f in ipairs(LOG_FILTERS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = f.label
        info.value = f.key
        info.checked = (db and db.logFilter == f.key)
        info.func = function()
            db.logFilter = f.key
            UIDropDownMenu_SetSelectedValue(logFilterDD, f.key)
            UIDropDownMenu_SetText(logFilterDD, f.label)
        end
        UIDropDownMenu_AddButton(info)
    end
end

-- small settings flyout (font size, opacity) toggled from the title bar
local logOpts = CreateFrame("Frame", "SchoolPopLogOptions", logFrame)
logOpts:SetWidth(190)
logOpts:SetHeight(132)
logOpts:SetPoint("TOPRIGHT", logFrame, "TOPRIGHT", 0, 0)
logOpts:SetFrameLevel(logFrame:GetFrameLevel() + 5)
logOpts:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
logOpts:SetBackdropColor(0, 0, 0, 0.9)
logOpts:EnableMouse(true)
logOpts:Hide()
local logOptsClose = CreateFrame("Button", nil, logOpts, "UIPanelCloseButton")
logOptsClose:SetPoint("TOPRIGHT", 2, 2)
logOptsClose:SetHitRectInsets(0, 0, 0, 0)
logOptsClose:SetWidth(24)
logOptsClose:SetHeight(24)
logOptsClose:SetScript("OnClick", function() logOpts:Hide() end)

local function LogOptSlider(name, label, key, minV, maxV, step, y, fmt)
    local s = CreateFrame("Slider", "SchoolPopLogOpt" .. name, logOpts, "OptionsSliderTemplate")
    s:SetPoint("TOP", logOpts, "TOP", 0, y)
    s:SetWidth(140)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    _G[s:GetName() .. "Low"]:SetText(minV)
    _G[s:GetName() .. "High"]:SetText(maxV)
    local text = _G[s:GetName() .. "Text"]
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        db[key] = value
        text:SetText(label .. ": " .. string.format(fmt, value))
        SchoolPop_UpdateLogWindow()
    end)
    s.Refresh = function() s:SetValue(db[key]) end
    return s
end
local logOptFont = LogOptSlider("Font", "Font size", "logFontSize", 8, 24, 1, -30, "%d")
local logOptAlpha = LogOptSlider("Alpha", "Opacity", "logOpacity", 0, 1, 0.05, -74, "%.2f")
local logOptStamp = CreateFrame("CheckButton", "SchoolPopLogOptStamp", logOpts, "OptionsCheckButtonTemplate")
logOptStamp:SetPoint("TOPLEFT", 12, -100)
_G["SchoolPopLogOptStampText"]:SetText("Timestamps")
logOptStamp:SetScript("OnClick", function(self)
    db.logTimestamps = self:GetChecked() and true or false
    RenderLog()
end)

local logOptButton = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
logOptButton:SetPoint("RIGHT", logClose, "LEFT", 2, 0)
logOptButton:SetWidth(32)
logOptButton:SetHeight(16)
logOptButton:SetText("Opt")
logOptButton:SetScript("OnClick", function()
    if logOpts:IsShown() then
        logOpts:Hide()
    else
        logOptFont.Refresh()
        logOptAlpha.Refresh()
        logOptStamp:SetChecked(db.logTimestamps)
        logOpts:Show()
    end
end)

-- "?" button: Filter by ID
local idFilterFrame = CreateFrame("Frame", "SchoolPopIdFilterFrame", UIParent)
idFilterFrame:SetWidth(220)
idFilterFrame:SetHeight(92)
idFilterFrame:SetFrameStrata("DIALOG")
idFilterFrame:SetMovable(true)
idFilterFrame:EnableMouse(true)
idFilterFrame:SetClampedToScreen(true)
idFilterFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
idFilterFrame:SetBackdropColor(0, 0, 0, 0.9)
idFilterFrame:RegisterForDrag("LeftButton")
idFilterFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
idFilterFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
idFilterFrame:Hide()
tinsert(UISpecialFrames, "SchoolPopIdFilterFrame")

local idFilterTitle = idFilterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
idFilterTitle:SetPoint("TOPLEFT", 12, -10)
idFilterTitle:SetText("Filter by ID or name")

local idFilterClose = CreateFrame("Button", nil, idFilterFrame, "UIPanelCloseButton")
idFilterClose:SetPoint("TOPRIGHT", 3, 3)
idFilterClose:SetHitRectInsets(0, 0, 0, 0)
idFilterClose:SetWidth(24)
idFilterClose:SetHeight(24)

local idFilterBox = CreateFrame("EditBox", "SchoolPopIdFilterBox", idFilterFrame, "InputBoxTemplate")
idFilterBox:SetPoint("TOPLEFT", 18, -32)
idFilterBox:SetWidth(120)
idFilterBox:SetHeight(20)
idFilterBox:SetAutoFocus(false)
idFilterBox:SetMaxLetters(40)  -- accepts a spell ID or a name to search

local idFilterStatus = idFilterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
idFilterStatus:SetPoint("TOPLEFT", 14, -60)
idFilterStatus:SetPoint("RIGHT", -10, 0)
idFilterStatus:SetJustifyH("LEFT")

-- Empty or invalid -> no filter (everything shown again). Valid -> only that
-- ID, for both the existing log and every new line while it stays set.
local function ApplyIdFilter()
    local text = idFilterBox:GetText()
    local n = tonumber(text)
    if n and n > 0 then
        logIdFilter, logTextFilter = n, nil
        local shown = 0
        for _, e in ipairs(logEntries) do if e.spellId == n then shown = shown + 1 end end
        local name = GetSpellInfo(n)
        idFilterStatus:SetText(string.format("Showing only %s (%d): %d line%s",
            name or "unknown spell", n, shown, shown == 1 and "" or "s"))
    elseif text and text ~= "" then
        logIdFilter, logTextFilter = nil, string.lower(text)
        local shown = 0
        for _, e in ipairs(logEntries) do
            if string.find(string.lower(e.text or ""), logTextFilter, 1, true) then shown = shown + 1 end
        end
        idFilterStatus:SetText(string.format("Name contains \"%s\": %d line%s",
            text, shown, shown == 1 and "" or "s"))
    else
        logIdFilter, logTextFilter = nil, nil
        idFilterStatus:SetText("Showing all. Type a proc ID or a name to filter.")
    end
    RenderLog()
end
idFilterBox:SetScript("OnTextChanged", ApplyIdFilter)
idFilterBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
idFilterBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
idFilterClose:SetScript("OnClick", function() idFilterFrame:Hide() end)
-- Whatever hides the window (X, Escape, the ? button) clears the filter, so
-- the log can never stay silently filtered with the box out of sight.
idFilterFrame:SetScript("OnHide", function()
    idFilterBox:SetText("")
    logIdFilter, logTextFilter = nil, nil
    RenderLog()
end)

local logHelp = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
logHelp:SetPoint("RIGHT", logOptButton, "LEFT", -2, 0)
logHelp:SetWidth(20)
logHelp:SetHeight(16)
logHelp:SetText("?")
logHelp:SetScript("OnClick", function()
    if idFilterFrame:IsShown() then
        idFilterFrame:Hide()
    else
        idFilterFrame:ClearAllPoints()
        idFilterFrame:SetPoint("BOTTOMLEFT", logFrame, "TOPLEFT", 0, 4)
        idFilterFrame:Show()
        ApplyIdFilter()
        idFilterBox:SetFocus()
    end
end)

local logExport = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
logExport:SetPoint("RIGHT", logHelp, "LEFT", -2, 0)
logExport:SetWidth(46)
logExport:SetHeight(16)
logExport:SetText("Export")
logExport:SetScript("OnClick", ExportLog)

-- open the Breakdown window from the log window
local logBreakdown = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
logBreakdown:SetPoint("RIGHT", logExport, "LEFT", -2, 0)
logBreakdown:SetWidth(70)
logBreakdown:SetHeight(16)
logBreakdown:SetText("Breakdown")
logBreakdown:SetScript("OnClick", function()
    if SchoolPop_ToggleBreakdown then SchoolPop_ToggleBreakdown() end
end)

-- resize grip
local logGrip = CreateFrame("Button", "SchoolPopLogGrip", logFrame)
logGrip:SetWidth(16)
logGrip:SetHeight(16)
logGrip:SetPoint("BOTTOMRIGHT", -2, 2)
logGrip:SetFrameLevel(logFrame:GetFrameLevel() + 3)  -- always on top of the arrows
logGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
logGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
logGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
logGrip:SetScript("OnMouseDown", function() if not db.logLocked then logFrame:StartSizing("BOTTOMRIGHT") end end)
logGrip:SetScript("OnMouseUp", function() logFrame:StopMovingOrSizing(); SaveLogPos() end)

function SchoolPop_UpdateLogWindow()
    logMessages:SetFont("Fonts\\ARIALN.TTF", db.logFontSize, "")
    logMessages:SetMaxLines(db.logMaxLines)
    logFrame:SetBackdropColor(0, 0, 0, db.logOpacity)
    logFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, math.max(0.15, db.logOpacity))
    if not logFilterInitialized then
        logFilterInitialized = true
        UIDropDownMenu_Initialize(logFilterDD, LogFilterInit)
    end
    UIDropDownMenu_SetSelectedValue(logFilterDD, db.logFilter)
    UIDropDownMenu_SetText(logFilterDD, LogFilterLabel())
    if db.logWindow then
        ApplyLogPos()
        logFrame:Show()
    else
        if SchoolPopLogOptions then SchoolPopLogOptions:Hide() end
        logFrame:Hide()
    end
end

logClose:SetScript("OnClick", function()
    db.logWindow = false
    SchoolPop_UpdateLogWindow()
end)

local function Commas(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Does this entry pass the "Filter by ID" window? (nil filter = everything)
local function PassesIdFilter(e)
    if logIdFilter then return e.spellId == logIdFilter end
    if logTextFilter then
        return string.find(string.lower(e.text or ""), logTextFilter, 1, true) ~= nil
    end
    return true
end

-- Redraw the window from the buffer, applying the ID filter
RenderLog = function()
    logMessages:Clear()
    for _, e in ipairs(logEntries) do
        if PassesIdFilter(e) then
            logMessages:AddMessage((db.logTimestamps and e.stamp or "") .. e.text, e.r, e.g, e.b)
        end
    end
    logMessages:ScrollToBottom()
end

local function LogLine(kind, text, r, g, b, spellId)
    if not db.logWindow then return end
    if kind ~= "INFO" and db.logFilter ~= "BOTH" and db.logFilter ~= kind then return end
    local stamp = date("[%H:%M:%S] ")
    local e = { text = text, r = r, g = g, b = b, spellId = spellId, stamp = stamp }
    logEntries[#logEntries + 1] = e
    logBuffer[#logBuffer + 1] = stamp .. text
    if #logBuffer > db.logMaxLines then
        table.remove(logBuffer, 1)
        table.remove(logEntries, 1)
    end
    if PassesIdFilter(e) then
        logMessages:AddMessage((db.logTimestamps and stamp or "") .. text, r, g, b)
    end
end

-- All addon messages go to the log window, never to Blizzard chat.
Notify = function(text)
    LogLine("INFO", text, 0.6, 0.85, 1)
end


do  -- scope the breakdown window's locals (Lua 5.1: 200-local chunk limit)
--===================== BREAKDOWN WINDOW ==========================
-- Per-source DPS / HPS for the current fight, in two tabs. Reads the
-- `breakdown` tables the meter fills. Movable/resizable/closable.
local bdFrame = CreateFrame("Frame", "SchoolPopBreakdownFrame", UIParent)
bdFrame:SetWidth(500)
bdFrame:SetHeight(320)
bdFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
bdFrame:SetMovable(true)
bdFrame:SetResizable(true)
bdFrame:SetMinResize(440, 160)
do local w, h = UIParent:GetWidth(), UIParent:GetHeight()
   if w and h then bdFrame:SetMaxResize(math.min(1000, w - 20), math.min(700, h - 20)) end end
bdFrame:SetClampedToScreen(true)
bdFrame:SetFrameStrata("MEDIUM")
bdFrame:EnableMouse(true)
bdFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
bdFrame:SetBackdropColor(0, 0, 0, 0.85)
bdFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
bdFrame:RegisterForDrag("LeftButton")
bdFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
bdFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
bdFrame:Hide()

local bdTitle = bdFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bdTitle:SetPoint("TOPLEFT", 10, -8)
bdTitle:SetText("SchoolPop Breakdown")

local bdClose = CreateFrame("Button", nil, bdFrame, "UIPanelCloseButton")
bdClose:SetPoint("TOPRIGHT", 3, 3)
bdClose:SetHitRectInsets(0, 0, 0, 0)

-- two tabs: Damage / Healing
local bdTab = "dmg"
local function MakeTab(label, key, x)
    local b = CreateFrame("Button", nil, bdFrame, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, -30)
    b:SetWidth(70)
    b:SetHeight(18)
    b:SetText(label)
    b:SetScript("OnClick", function()
        bdTab = key
        if SchoolPop_RefreshBreakdown then SchoolPop_RefreshBreakdown() end
    end)
    return b
end
local bdTabDmg  = MakeTab("DPS", "dmg", 10)
local bdTabHeal = MakeTab("HPS", "heal", 84)

-- open the Log window from the breakdown window
local bdLogBtn = CreateFrame("Button", nil, bdFrame, "UIPanelButtonTemplate")
bdLogBtn:SetPoint("TOPRIGHT", bdClose, "TOPLEFT", -2, -4)
bdLogBtn:SetWidth(46)
bdLogBtn:SetHeight(18)
bdLogBtn:SetText("Log")
bdLogBtn:SetScript("OnClick", function()
    if db then db.logWindow = true end
    if SchoolPop_UpdateLogWindow then SchoolPop_UpdateLogWindow() end
    if widgets and widgets.logWindow then widgets.logWindow:SetChecked(true) end
end)

-- reset the current fight (clears breakdown, meter and log)
local bdReset = CreateFrame("Button", nil, bdFrame, "UIPanelButtonTemplate")
bdReset:SetPoint("RIGHT", bdLogBtn, "LEFT", -2, 0)
bdReset:SetWidth(56)
bdReset:SetHeight(18)
bdReset:SetText("Reset")
bdReset:SetScript("OnClick", function()
    meter.dmg, meter.heal, meter.active = 0, 0, false
    meter.start, meter.last = nil, nil
    breakdown.dmg, breakdown.heal = {}, {}
    if MeterRefresh then MeterRefresh() end
    SchoolPop_RefreshBreakdown()
    if SchoolPop_ClearLog then SchoolPop_ClearLog() end
end)

-- header row
-- Fixed-position columns so values line up regardless of font width.
-- Ability is left-aligned from the left edge; the four numeric columns are
-- right-aligned at fixed x offsets (measured from the left edge).
local BD_FONT = "Fonts\\ARIALN.TTF"
local BD_FONT_SIZE = 13
local BD_ROW_H = 16
-- Name is left-aligned; the four numeric columns are right-aligned at fixed
-- offsets from the row's RIGHT edge, so they fit at any window width.
local BD_COL = { name = 4 }
-- offset of each numeric column's right edge from the row's right edge;
-- nameGap reserves room for the Total values left of the name column's end
local BD_R = { total = 204, pct = 162, hits = 114, ps = 42, nameGap = 62 }

-- Header cells anchor to the scroll area (same left origin as rows), and each
-- numeric header's RIGHT edge sits at its column's right-edge x, so headers line
-- up with the data and stay inside the window at any width. (8 = scroll left inset)
local BD_LEFT = 8
local bdHeaderCells = {}
local function BDHeaderL(text, x, w)
    local fs = bdFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", BD_LEFT + x, -60)
    fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetText(text)
    return fs
end
local function BDHeaderR(text, rOff)
    local fs = bdFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- 30 = scroll area's right inset; rOff = column offset from the content's right edge
    fs:SetPoint("RIGHT", bdFrame, "RIGHT", -(30 + rOff), 0)
    fs:SetPoint("TOP", bdFrame, "TOP", 0, -60)
    fs:SetJustifyH("RIGHT"); fs:SetText(text)
    return fs
end
BDHeaderL("Ability", BD_COL.name, 170)
BDHeaderR("Total",   BD_R.total)
BDHeaderR("%",       BD_R.pct)
BDHeaderR("Hits",    BD_R.hits)
BDHeaderR("DPS/HPS", BD_R.ps)

local bdHeaderLine = bdFrame:CreateTexture(nil, "ARTWORK")
bdHeaderLine:SetTexture(1, 0.82, 0)
bdHeaderLine:SetHeight(1)
bdHeaderLine:SetAlpha(0.5)
bdHeaderLine:SetPoint("TOPLEFT", 8, -76)
bdHeaderLine:SetPoint("TOPRIGHT", -26, -76)

-- scroll area holds pooled row frames
local bdScroll = CreateFrame("ScrollFrame", "SchoolPopBDScroll", bdFrame, "UIPanelScrollFrameTemplate")
bdScroll:SetPoint("TOPLEFT", 8, -80)
bdScroll:SetPoint("BOTTOMRIGHT", -30, 30)
local bdContent = CreateFrame("Frame", nil, bdScroll)
bdContent:SetWidth(1); bdContent:SetHeight(1)
bdScroll:SetScrollChild(bdContent)

local bdRowPool, bdUsedRows = {}, 0
local function BDAcquireRow(i)
    local row = bdRowPool[i]
    if not row then
        row = CreateFrame("Frame", nil, bdContent)
        row:SetHeight(BD_ROW_H)
        row.name  = row:CreateFontString(nil, "OVERLAY"); row.name:SetFont(BD_FONT, BD_FONT_SIZE, "")
        row.total = row:CreateFontString(nil, "OVERLAY"); row.total:SetFont(BD_FONT, BD_FONT_SIZE, "")
        row.pct   = row:CreateFontString(nil, "OVERLAY"); row.pct:SetFont(BD_FONT, BD_FONT_SIZE, "")
        row.hits  = row:CreateFontString(nil, "OVERLAY"); row.hits:SetFont(BD_FONT, BD_FONT_SIZE, "")
        row.ps    = row:CreateFontString(nil, "OVERLAY"); row.ps:SetFont(BD_FONT, BD_FONT_SIZE, "")
        row.name:SetPoint("LEFT", row, "LEFT", BD_COL.name, 0)
        -- single line: fixed height truncates with "..." instead of wrapping
        -- onto the next row; right edge stops short of the Total column
        row.name:SetHeight(BD_ROW_H)
        row.name:SetPoint("RIGHT", row, "RIGHT", -(BD_R.total + BD_R.nameGap), 0)
        row.name:SetJustifyH("LEFT")
        row.total:SetPoint("RIGHT", row, "RIGHT", -BD_R.total, 0); row.total:SetJustifyH("RIGHT")
        row.pct:SetPoint("RIGHT", row, "RIGHT", -BD_R.pct, 0);     row.pct:SetJustifyH("RIGHT")
        row.hits:SetPoint("RIGHT", row, "RIGHT", -BD_R.hits, 0);   row.hits:SetJustifyH("RIGHT")
        row.ps:SetPoint("RIGHT", row, "RIGHT", -BD_R.ps, 0);       row.ps:SetJustifyH("RIGHT")
        bdRowPool[i] = row
    end
    return row
end

local bdFooter = bdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bdFooter:SetPoint("BOTTOMLEFT", 12, 8)

local bdGrip = CreateFrame("Button", nil, bdFrame)
bdGrip:SetWidth(16)
bdGrip:SetHeight(16)
bdGrip:SetPoint("BOTTOMRIGHT", -2, 2)
bdGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
bdGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
bdGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
bdGrip:SetScript("OnMouseDown", function() bdFrame:StartSizing("BOTTOMRIGHT") end)
bdGrip:SetScript("OnMouseUp", function() bdFrame:StopMovingOrSizing() end)

local function PadRight(s, n)
    s = tostring(s)
    if #s >= n then return string.sub(s, 1, n) end
    return s .. string.rep(" ", n - #s)
end
local function PadLeft(s, n)
    s = tostring(s)
    if #s >= n then return s end
    return string.rep(" ", n - #s) .. s
end

local bdEmpty = bdContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
bdEmpty:SetPoint("TOPLEFT", 4, -4)
bdEmpty:Hide()

function SchoolPop_RefreshBreakdown()
    if not bdFrame:IsShown() then return end
    bdTabDmg:SetAlpha(bdTab == "dmg" and 1 or 0.5)
    bdTabHeal:SetAlpha(bdTab == "heal" and 1 or 0.5)
    bdTitle:SetText(bdTab == "dmg" and "SchoolPop Breakdown - Damage"
        or "SchoolPop Breakdown - Healing")

    local tbl = breakdown[bdTab]
    local grand = (bdTab == "dmg") and meter.dmg or meter.heal
    local dur = 0
    if meter.start then
        dur = (meter.active and GetTime() or meter.last or meter.start) - meter.start
    end
    if dur < 1 then dur = 1 end

    local rows = {}
    for _, e in pairs(tbl) do
        -- always show the ID in parentheses (melee has none)
        local label = e.id and (e.name .. " (" .. e.id .. ")") or e.name
        rows[#rows + 1] = { name = label, e = e }
    end
    table.sort(rows, function(a, b) return a.e.total > b.e.total end)

    bdContent:SetWidth(bdScroll:GetWidth())
    local n = 0
    for _, r in ipairs(rows) do
        n = n + 1
        local e = r.e
        local pct = grand > 0 and (e.total / grand * 100) or 0
        local row = BDAcquireRow(n)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", bdContent, "TOPLEFT", 0, -(n - 1) * BD_ROW_H)
        row:SetPoint("RIGHT", bdContent, "RIGHT", 0, 0)
        row.name:SetText(r.name)
        row.total:SetText(MeterFormat(e.total))
        row.pct:SetText(string.format("%.0f%%", pct))
        row.hits:SetText(tostring(e.hits))
        row.ps:SetText(MeterFormat(e.total / dur))
        local cr, cg, cb = e.r or 1, e.g or 1, e.b or 1
        row.name:SetTextColor(cr, cg, cb)
        row.total:SetTextColor(cr, cg, cb)
        row.pct:SetTextColor(cr, cg, cb)
        row.hits:SetTextColor(cr, cg, cb)
        row.ps:SetTextColor(cr, cg, cb)
        row:Show()
    end
    for i = n + 1, bdUsedRows do bdRowPool[i]:Hide() end
    bdUsedRows = n
    bdContent:SetHeight(math.max(1, n * BD_ROW_H))

    if n == 0 then
        bdEmpty:SetText("No " .. (bdTab == "dmg" and "damage" or "healing")
            .. " recorded this fight.")
        bdEmpty:Show()
    else
        bdEmpty:Hide()
    end

    bdFooter:SetText(string.format("Total: |cffffd100%s|r over |cffffd100%ds|r  =  %s/sec",
        MeterFormat(grand), math.floor(dur), MeterFormat(grand / dur)))
end

function SchoolPop_ToggleBreakdown()
    if bdFrame:IsShown() then
        bdFrame:Hide()
    else
        bdFrame:Show()
        SchoolPop_RefreshBreakdown()
    end
end

-- keep it live while shown
bdFrame:SetScript("OnUpdate", function(self, dt)
    self._t = (self._t or 0) + dt
    if self._t >= 0.5 then self._t = 0; SchoolPop_RefreshBreakdown() end
end)


end  -- breakdown window scope

-- Runs the floating-text path protected: a Lua error there is
-- reported once instead of silently killing the whole handler.
local reportedError
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reportedError then
        reportedError = true
        Notify("|cffff3333SchoolPop error:|r " .. tostring(err))
    end
end

--====================== COMBAT LOG HANDLER =======================
local TRACKED = {
    SWING_DAMAGE = true, RANGE_DAMAGE = true,
    SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true,
}
local HEAL_EVENTS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local playerGUID
local debugMode = false
local traceSpell = nil  -- spellId to trace verbosely (/sp trackheal <id>)

-- Classifies a combat-log source. Returns:
--   "player"  - you
--   "pet"     - a real pet (hunter/warlock/DK pet), labelled "(pet)"
--   "own"     - anything else you own: guardians, totems, item-proc
--               summons, dynamic objects (Consecration on some cores).
--               Shown as your own damage with no label.
--   nil       - not yours
local function ClassifySource(srcGUID, flags)
    if srcGUID == playerGUID then return "player" end
    if not flags or bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) == 0 then
        return nil
    end
    if bit.band(flags, COMBATLOG_OBJECT_TYPE_PET) ~= 0 then
        return db.includePet and "pet" or nil
    end
    return "own"
end

local function HandleDamage(eventType, isPet, isMine, srcName, dstName, ...)
    local spellId, spellName, school, amount, critical
    if eventType == "SWING_DAMAGE" then
        local a, _, s, _, _, _, c = ...
        spellName, amount, school, critical = "Melee", a, s, c
    else
        local id, name, spellSchool, a, _, _, _, _, _, c = ...
        spellId, spellName, amount, school, critical = id, name, a, spellSchool, c
    end
    if not amount then return end

    local info = GetSchoolInfo(school)
    if isMine then
        MeterAdd(amount, false, spellName or "Melee", info.r, info.g, info.b, spellId)
    end

    LogLine("DAMAGE", string.format("%s hits %s with %s%s for %s%s",
        srcName or "?", dstName or "?", spellName or "?", ItemSuffix(spellId, spellName),
        Commas(amount), critical and db.critMarker or ""), info.r, info.g, info.b, spellId)

    if db.floating then
        local key = (isPet and "pet:" or "") .. (spellId or "melee")
        SafeCall(QueueText, key, amount, critical and true or false, info,
            GetSpellIcon(spellId), dstName, false, isPet)
    end
end

local function HandleHeal(isPet, isMine, srcName, dstGUID, dstName, ...)
    -- 3.3.5a payload: spellId, spellName, spellSchool, amount,
    -- overhealing, critical  (some builds insert an absorbed arg
    -- before critical, so we accept either position)
    local spellId, spellName, _, amount, overheal, a6, a7 = ...
    if not amount then return end
    local critical = (a6 == true or a6 == 1) or (a7 == true or a7 == 1)
    local info = GetHealInfo()
    if isMine then
        MeterAdd(amount, true, spellName or "Heal", info.r, info.g, info.b, spellId)
    end

    local critText = critical and db.critMarker or ""
    if type(overheal) == "number" and overheal > 0 then
        critText = critText .. " (" .. Commas(overheal) .. " overheal)"
    end
    if dstGUID == playerGUID and not isPet then
        LogLine("HEALING", string.format("%s is healed by %s%s for %s%s",
            srcName or "?", spellName or "?", ItemSuffix(spellId, spellName),
            Commas(amount), critText), info.r, info.g, info.b, spellId)
    else
        LogLine("HEALING", string.format("%s heals %s with %s%s for %s%s",
            srcName or "?", dstName or "?", spellName or "?", ItemSuffix(spellId, spellName),
            Commas(amount), critText), info.r, info.g, info.b, spellId)
    end

    if db.floating then
        local key = "heal:" .. (isPet and "pet:" or "") .. (spellId or "?")
        SafeCall(QueueText, key, amount, critical and true or false, info,
            GetSpellIcon(spellId), dstName, true, isPet)
    end
end

--======================= OPTIONS PANEL ===========================
local panel = CreateFrame("Frame", "SchoolPopOptionsPanel", UIParent)
panel.name = "SchoolPop"
local widgets = {}

local function MakeCheck(name, label, key, x, y)
    local cb = CreateFrame("CheckButton", "SchoolPop" .. name, panel, "OptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self) db[key] = self:GetChecked() and true or false end)
    widgets[key] = cb
    return cb
end

local function MakeSlider(name, label, key, minV, maxV, step, x, y, onChange)
    local s = CreateFrame("Slider", "SchoolPop" .. name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(110)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    _G[s:GetName() .. "Low"]:SetText(minV)
    _G[s:GetName() .. "High"]:SetText(maxV)
    s.label = _G[s:GetName() .. "Text"]
    s.labelText = label
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        db[key] = value
        local shown = (step < 1) and string.format("%.1f", value) or tostring(value)
        self.label:SetText(label .. ": " .. shown)
        if onChange then onChange() end
    end)
    widgets[key] = s
    return s
end

local function MakeDropdown(name, label, key, list, x, y, width, onChange)
    local dd = CreateFrame("Frame", "SchoolPop" .. name, panel, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x, y)
    if label and label ~= "" then
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        title:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 3)
        title:SetText(label)
    end
    UIDropDownMenu_SetWidth(dd, width or 120)
    UIDropDownMenu_Initialize(dd, function()
        for _, item in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.label
            info.value = item.key
            info.checked = (db[key] == item.key)
            info.func = function()
                db[key] = item.key
                UIDropDownMenu_SetSelectedValue(dd, item.key)
                UIDropDownMenu_SetText(dd, item.label)
                if onChange then onChange() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    dd.list = list
    widgets[key] = dd
    return dd
end

local function MakeButton(label, x, y, width, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- Color swatch: click to open the standard color picker
local swatches = {}
local function MakeSwatch(school, x, y)
    local b = CreateFrame("Button", nil, panel)
    b:SetPoint("TOPLEFT", x, y)
    b:SetWidth(18)
    b:SetHeight(18)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture(1, 1, 1)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tex = tex
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", b, "RIGHT", 6, 0)
    label:SetText(school.name)
    b.label = label

    local function Apply(r, g, b_)
        db.colors[school.mask] = { r, g, b_ }
        tex:SetTexture(r, g, b_)
        label:SetTextColor(r, g, b_)
        RebuildSchoolInfo()
    end
    b.Refresh = function()
        local r, g, b_ = GetSchoolColor(school)
        tex:SetTexture(r, g, b_)
        label:SetTextColor(r, g, b_)
    end
    b:SetScript("OnClick", function()
        local r, g, b_ = GetSchoolColor(school)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b_ }
        ColorPickerFrame.func = function()
            Apply(ColorPickerFrame:GetColorRGB())
        end
        ColorPickerFrame.cancelFunc = function(prev)
            Apply(prev[1], prev[2], prev[3])
        end
        ColorPickerFrame:SetColorRGB(r, g, b_)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)
    swatches[#swatches + 1] = b
    return b
end

local function BuildPanel()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("SchoolPop")
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetText("Floating damage and healing text, color-coded by school.")

    -- Toggles: three columns, three rows
    MakeCheck("Float",   "Floating text",   "floating",   8,   -44)
    MakeCheck("Pet",     "Pet damage",      "includePet", 135, -44)
    MakeCheck("Heal",    "Show healing",    "healing",    262, -44)
    MakeCheck("Short",   "Short numbers",   "shortNums",  8,   -66)
    MakeCheck("Icons",   "Spell icons",     "icons",      135, -66)
    MakeCheck("Plates",  "Over nameplates", "nameplates", 262, -66)
    local mmCheck = MakeCheck("Minimap", "Minimap button", "minimap", 8, -88)
    mmCheck:SetScript("OnClick", function(self)
        db.minimap = self:GetChecked() and true or false
        SchoolPop_UpdateMinimapButton()
    end)
    MakeCheck("ItemID", "ItemID", "showItem", 262, -88)
    local logCheck = MakeCheck("Log", "Log window", "logWindow", 135, -88)
    logCheck:SetScript("OnClick", function(self)
        db.logWindow = self:GetChecked() and true or false
        SchoolPop_UpdateLogWindow()
    end)

    -- Dropdowns: one row
    MakeDropdown("Font",      "Font",      "font",      FONTS,      -8,  -130, 110)
    MakeDropdown("Outline",   "Outline",   "outline",   OUTLINES,   135, -130, 75)
    MakeDropdown("Direction", "Direction", "direction", DIRECTIONS, 250, -130, 90)

    -- Sliders: three columns
    MakeSlider("Size",     "Font size",     "fontSize",    10,  48,  1,   16,  -176)
    MakeSlider("Duration", "Duration (s)",  "duration",    0.5, 4,   0.1, 146, -176)
    MakeSlider("Distance", "Distance",      "distance",    0,   400, 10,  276, -176)
    MakeSlider("XOff",     "Horizontal",    "xOffset",    -600, 600, 10,  16,  -218, ApplyAnchor)
    MakeSlider("YOff",     "Vertical",      "yOffset",    -400, 400, 10,  146, -218, ApplyAnchor)
    MakeSlider("Spread",   "Spread",        "spread",      0,   400, 10,  276, -218)
    MakeSlider("Merge",    "Merge (s)",     "mergeWindow", 0,   1,   0.1, 16,  -260)
    MakeSlider("IconSize", "Icon size",     "iconScale",   0.5, 2,   0.1, 146, -260)
    MakeDropdown("IconSide", "", "iconSide", ICON_SIDES, 252, -250, 80)

    -- Color swatches: four columns, two rows
    local ch = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ch:SetPoint("TOPLEFT", 16, -296)
    ch:SetText("Colors (click a swatch to change)")
    local swatchList = {}
    for i, s in ipairs(SCHOOLS) do swatchList[i] = s end
    swatchList[#swatchList + 1] = HEAL
    for i, s in ipairs(swatchList) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        MakeSwatch(s, 16 + col * 95, -316 - row * 24)
    end

    -- Bottom action buttons, centered. Row 1: Reset colors / Test / Reset all.
    MakeButton("Reset colors", 61,  -366, 100, function()
        db.colors = {}
        RebuildSchoolInfo()
        for _, sw in ipairs(swatches) do sw.Refresh() end
    end)
    MakeButton("Test", 169, -366, 60, RunTest)
    MakeButton("Reset all", 237, -366, 90, function()
        for k, v in pairs(DEFAULTS) do
            db[k] = (type(v) == "table") and {} or v
        end
        RebuildSchoolInfo()
        ApplyAnchor()
        SchoolPop_UpdateMinimapButton()
        SchoolPop_UpdateLogWindow()
        panel.refresh()
    end)
    -- Row 2 (beneath), centered: Open log / Breakdown.
    MakeButton("Open log", 113, -392, 70, function()
        db.logWindow = true
        SchoolPop_UpdateLogWindow()
        widgets.logWindow:SetChecked(true)
    end)
    MakeButton("Breakdown", 191, -392, 84, SchoolPop_ToggleBreakdown)
end

-- Push db values into the widgets (called when the panel is shown)
panel.refresh = function()
    for key, w in pairs(widgets) do
        local t = w:GetObjectType()
        if t == "CheckButton" then
            w:SetChecked(db[key])
        elseif t == "Slider" then
            w:SetValue(db[key])
        elseif t == "Frame" then -- dropdown
            local item = FindByKey(w.list, db[key])
            UIDropDownMenu_SetSelectedValue(w, item.key)
            UIDropDownMenu_SetText(w, item.label)
        end
    end
    for _, sw in ipairs(swatches) do sw.Refresh() end
end
panel.okay    = function() end          -- settings are applied live
panel.cancel  = function() end
panel.default = function() end


--======================= MINIMAP BUTTON ==========================
local mm = CreateFrame("Button", "SchoolPopMinimapButton", Minimap)
mm:SetWidth(32)
mm:SetHeight(32)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")

local mmOverlay = mm:CreateTexture(nil, "OVERLAY")
mmOverlay:SetWidth(53)
mmOverlay:SetHeight(53)
mmOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmOverlay:SetPoint("TOPLEFT")

local mmIcon = mm:CreateTexture(nil, "BACKGROUND")
mmIcon:SetWidth(20)
mmIcon:SetHeight(20)
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Variety_02") -- change icon here
mmIcon:SetPoint("TOPLEFT", 7, -5)

local function MinimapSetPosition()
    local angle = math.rad(db.minimapPos or 220)
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

function SchoolPop_UpdateMinimapButton()
    if db.minimap then
        MinimapSetPosition()
        mm:Show()
    else
        mm:Hide()
    end
end

mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        db.minimapPos = math.deg(math.atan2(py - my, px - mx))
        MinimapSetPosition()
    end)
end)
mm:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)
mm:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if SchoolPop_ToggleBreakdown then SchoolPop_ToggleBreakdown() end
    else
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end)
mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("SchoolPop")
    GameTooltip:AddLine("Left-click: open options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: open breakdown", 1, 1, 1)
    GameTooltip:AddLine("Drag: move button", 1, 1, 1)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

--========================= EVENT FRAME ===========================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- 3.3.5a: timestamp, subEvent, srcGUID, srcName, srcFlags,
        --         dstGUID, dstName, dstFlags, payload...
        local _, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName = ...
        if traceSpell then
            local sid = select(9, ...)
            if sid == traceSpell then
                local parts = {}
                for i = 9, select("#", ...) do parts[#parts+1] = tostring((select(i, ...))) end
                local mine = srcFlags and bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cffff88ffSP trace|r %s src=%s guid=%s mine=%s | %s",
                    tostring(eventType), tostring(srcName), tostring(srcGUID),
                    tostring(mine), table.concat(parts, ", ")))
            end
        end
        if debugMode and (TRACKED[eventType] or HEAL_EVENTS[eventType])
           and srcFlags and bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
            local parts = {}
            for i = 9, select("#", ...) do
                parts[#parts + 1] = tostring((select(i, ...)))
            end
            Notify(string.format(
                "|cffaaaaaaSchoolPop %s from %s [flags 0x%X, %s]: %s|r",
                eventType, tostring(srcName), srcFlags,
                srcGUID == playerGUID and "player" or "owned unit",
                table.concat(parts, ", ")))
        end
        if TRACKED[eventType] then
            local src = ClassifySource(srcGUID, srcFlags)
            if src then
                HandleDamage(eventType, src == "pet",
                    (src == "player" or src == "pet"), srcName, dstName, select(9, ...))
            end
        elseif db.healing and HEAL_EVENTS[eventType] then
            local src = ClassifySource(srcGUID, srcFlags)
            if src then
                HandleHeal(src == "pet",
                    (src == "player" or src == "pet"), srcName, dstGUID, dstName, select(9, ...))
            end
        end

    elseif event == "ADDON_LOADED" and ... == ADDON_NAME then
        SchoolPopDB = SchoolPopDB or {}
        db = SchoolPopDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then
                db[k] = (type(v) == "table") and {} or v
            end
        end
        db.chat, db.chatTarget, db.chatMode, db.anchorMode = nil, nil, nil, nil
        RebuildSchoolInfo()
        ApplyAnchor()
        BuildPanel()
        InterfaceOptions_AddCategory(panel)
        SchoolPop_UpdateMinimapButton()
        SchoolPop_UpdateLogWindow()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_REGEN_ENABLED" then
        MeterCombatEnded()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, body = ...
        if prefix == UNC_PREFIX and body then
            if string.sub(body, 1, 2) == "IC" then
                OnUncappedLine(body)
            else
                local sid, mn, mx = string.match(body, "^USPELLDMGR:(%d+):(%d+):(%d+)$")
                if sid then
                    sid = tonumber(sid)
                    spellDmg[sid] = { tonumber(mn), tonumber(mx) }
                    -- if the tooltip is open on this proc, redraw it now
                    if GameTooltip:IsShown() and GameTooltip:GetOwner()
                       and GameTooltip:GetOwner().spellId == sid then
                        ShowProcTooltip(GameTooltip:GetOwner(), sid)
                    end
                end
            end
        end

    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        if playerGUID then ScanSpellbook() end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if ... == "player" then
            ScanEquipment()
            spellDmg = {}; dmgWanted = {}   -- stats changed; re-ask
        end

    elseif event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        ScanSpellbook()
        ScanEquipment()
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end)

--======================== KEY BINDINGS ===========================
-- Names shown in Escape > Key Bindings; the binding itself is in Bindings.xml
BINDING_HEADER_SCHOOLPOP = "SchoolPop"
BINDING_NAME_SCHOOLPOP_TOGGLE_LOG = "Toggle log window"
function SchoolPop_ToggleLog()
    if not db then return end
    db.logWindow = not db.logWindow
    SchoolPop_UpdateLogWindow()
end

--======================= SLASH COMMANDS ==========================
SLASH_SCHOOLPOP1 = "/schoolpop"
SLASH_SCHOOLPOP2 = "/sp"

local function OnOff(v) return v and "|cff33ff33ON|r" or "|cffff3333OFF|r" end

SlashCmdList["SCHOOLPOP"] = function(msg)
    msg = string.gsub(msg or "", "^%s+", "")
    if not string.match(string.lower(msg), "^item%s") then
        msg = string.lower(msg)
    end
    if msg == "float" then
        db.floating = not db.floating
        Notify("SchoolPop floating text: " .. OnOff(db.floating))
    elseif msg == "pet" then
        db.includePet = not db.includePet
        Notify("SchoolPop pet damage: " .. OnOff(db.includePet))
    elseif msg == "heal" then
        db.healing = not db.healing
        Notify("SchoolPop healing text: " .. OnOff(db.healing))
    elseif msg == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = (type(v) == "table") and {} or v end
        RebuildSchoolInfo(); ApplyAnchor(); SchoolPop_UpdateMinimapButton()
        Notify("SchoolPop settings reset.")
    elseif string.match(msg, "^track%s+%d+") or string.match(msg, "^trackheal%s+%d+") then
        traceSpell = tonumber(string.match(msg, "(%d+)"))
        DEFAULT_CHAT_FRAME:AddMessage("SchoolPop: tracing spell " .. traceSpell
            .. " to chat. Trigger it, then paste me the lines. /sp track off to stop.")
    elseif msg == "track off" or msg == "trackheal off" then
        traceSpell = nil
        DEFAULT_CHAT_FRAME:AddMessage("SchoolPop: spell trace off.")
    elseif msg == "debug" then
        debugMode = not debugMode
        Notify("SchoolPop raw event dump: " .. OnOff(debugMode))
    elseif string.match(msg, "^item%s") then
        -- /sp item <spellId> [itemlink]   or   /sp item <spellId> <itemId>
        -- or /sp item <spellId> clear
        local spellId, rest = string.match(msg, "^item%s+(%d+)%s*(.*)$")
        spellId = tonumber(spellId)
        if not spellId then
            Notify("Usage: /sp item <spellId> [shift-click item]  |  /sp item <spellId> clear")
        elseif rest == "clear" then
            db.itemMap[spellId] = nil
            Notify("SchoolPop: cleared item for spell " .. spellId)
        else
            local itemId = tonumber(string.match(rest, "item:(%d+)")) or tonumber(string.match(rest, "^(%d+)"))
            local name = itemId and GetItemInfo(itemId)
            if not itemId then
                Notify("SchoolPop: no item found in '" .. rest .. "'. Shift-click an item into the command.")
            else
                db.itemMap[spellId] = { id = itemId, name = name or ("item " .. itemId) }
                Notify(string.format("SchoolPop: spell %d -> %s (%d)",
                    spellId, db.itemMap[spellId].name, itemId))
            end
        end
    elseif string.match(msg, "^find%s+%S") then
        -- /sp find <spellId or name>: every equipped/bag item carrying it
        local q = string.match(msg, "^find%s+(.+)$")
        local ids = {}
        if tonumber(q) then
            ids[1] = tonumber(q)
        else
            local needle = string.lower(q)
            for sid in pairs(boundBySpell) do
                local n = GetSpellInfo(sid)
                if n and string.lower(n) == needle then ids[#ids + 1] = sid end
            end
        end
        if not boundReceived then
            Notify("SchoolPop: no imprint data received from the server yet (is Uncapped loaded?)")
        elseif #ids == 0 then
            Notify("SchoolPop find '" .. q .. "': no imprinted proc with that name")
        else
            for _, sid in ipairs(ids) do
                local name = GetSpellInfo(sid) or "?"
                local source = ResolveSource(sid, name)
                Notify(string.format("SchoolPop find %s (%d)%s:", name, sid,
                    source and (" [" .. source .. "]") or ""))
                for _, c in ipairs(boundBySpell[sid] or {}) do
                    Notify(string.format("  %s  -  %s%s", c.item,
                        UNC_TRIGGER[c.trigger] or "?", c.equipped and " (equipped)" or ""))
                end
            end
        end
    elseif msg == "link" or msg == "links" then
        -- Diagnostic: dump raw item links and tooltip lines (with colours) of
        -- every equipped item into the log, so imprint storage can be analysed.
        Notify("SchoolPop item dump (Export to copy):")
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link then
                local raw = string.gsub(link, "|", "||")
                Notify(string.format("slot %d: %s", slot, raw))
                scanTip:ClearLines()
                scanTip:SetInventoryItem("player", slot)
                for i = 1, scanTip:NumLines() do
                    local l = _G["SchoolPopScanTipTextLeft" .. i]
                    local r = _G["SchoolPopScanTipTextRight" .. i]
                    local t = l and l:GetText()
                    if t and t ~= "" then
                        local cr, cg, cb = l:GetTextColor()
                        local rt = r and r:GetText()
                        Notify(string.format("   %02d [%02x%02x%02x] %s%s", i,
                            cr * 255, cg * 255, cb * 255, t,
                            (rt and rt ~= "") and ("  |  " .. rt) or ""))
                    end
                end
            end
        end
    elseif msg == "items" then
        Notify("|cff80ffffSchoolPop|r proc -> item assignments:")
        local n = 0
        for id, item in pairs(db.itemMap) do
            n = n + 1
            local sname = GetSpellInfo(id)
            Notify(string.format("  %d %s -> %s (%d)",
                id, tostring(sname), item.name, item.id))
        end
        if n == 0 then Notify("  (none yet)") end
    elseif msg == "breakdown" or msg == "dps" or msg == "hps" then
        SchoolPop_ToggleBreakdown()
    elseif msg == "log" then
        db.logWindow = not db.logWindow
        SchoolPop_UpdateLogWindow()
        Notify("SchoolPop log window: " .. OnOff(db.logWindow))
    elseif string.match(msg, "^logfont%s+%d+") then
        db.logFontSize = tonumber(string.match(msg, "%d+"))
        SchoolPop_UpdateLogWindow()
        Notify("SchoolPop log font size: " .. db.logFontSize)
    elseif msg == "test" then
        local me = UnitName("player")
        LogLine("DAMAGE", me .. " hits Training Dummy with Crusader Strike for 1,234,567"
            .. db.critMarker, 1, 1, 0)
        LogLine("HEALING", me .. " is healed by Judgement of Light for 87,500", 0.2, 1, 0.2)
        RunTest()
    elseif msg == "help" then
        Notify("|cff80ffffSchoolPop|r: /sp (options), /sp float, /sp pet, /sp heal, /sp log, /sp logfont <size>, /sp invid, /sp find <spellId or name>, /sp item <spellId> [item], /sp items, /sp test, /sp reset")
    else
        -- Called twice: a 3.3.5a quirk where the first call sometimes
        -- only expands the AddOns list without selecting the panel.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
