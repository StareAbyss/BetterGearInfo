from pathlib import Path
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / "BetterGearInfo.lua").read_text(encoding="utf-8-sig")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("assert(loadstring(...))", source)

# Execute the real counting and update functions against inventory snapshots.
start = source.index("local function GetGemMarkers(")
end = source.index("local function ShowMarker(", start)
update_start = source.index("local function UpdateList(")
update_end = source.index("local function QueueUpdate(", update_start)
constants = source[source.index("local slots ="):source.index("local eventFrame =")]
lua.execute("""
unpack = unpack
MUTED = { .48, .55, .58, 1 }
OUTER_BORDER_NEUTRAL = .24
OUTER_BORDER_CLASS_BLEND = .32
NAME_LEFT = 115
MARKER_STEP = 19
ENCHANT_SCROLL_ICON = 463531
CharacterFrame, InspectFrame = {}, {}
RAID_CLASS_COLORS = { MONK = { r = 0, g = 1, b = .6 } }
local function noop() end
local function ui()
    return setmetatable({ text = '', width = 338 }, { __index = function(_, key)
        if key == 'SetText' then return function(self, text) self.text = text end end
        if key == 'SetWidth' then return function(self, width) self.width = width end end
        if key == 'GetWidth' then return function(self) return self.width or 338 end end
        if key == 'GetStringWidth' then return function(self) return #self.text end end
        return noop
    end })
end
function newPanel(unit)
    local panel = { unit = unit, guid = 'guid', owner = unit == 'player' and CharacterFrame or InspectFrame,
        rows = {}, outerBorder = {}, headerDivider = ui(), headerStatus = ui() }
    for i = 1, 16 do
        panel.rows[i] = ui()
        panel.rows[i].name, panel.rows[i].level = ui(), ui()
        panel.rows[i].divider = ui()
        panel.rows[i].badges = { {}, {}, {}, {} }
        panel.rows[i].markers = { ui(), ui(), ui(), ui(), ui(), ui() }
    end
    return panel
end
inventory, data = {}, {}
function UnitExists() return true end
function UnitGUID() return 'guid' end
function UnitIsUnit(unit) return unit == 'player' end
function UnitClass() return 'monk', 'MONK' end
function GetInventoryItemLink(unit, slot) return (inventory[unit] or {})[slot] end
function GetInventoryItemTexture(unit, slot) return pendingSlot == slot and 123 or nil end
function GetAverageItemLevel() return 300, 300 end
C_PaperDollInfo = { GetInspectItemLevel = function() return 300 end }
C_Item = {
    GetItemInfo = function(link)
        local item = data[link]
        if not item or item.pending then return nil end
        return 'item', link, 4, 300, 0, '', '', 1, '', 123, 0, 4, 0, 0, 10, item.setID
    end,
    GetItemStats = function(link) return data[link].stats or {} end,
    GetItemNumSockets = function(link) return data[link].sockets or 0 end,
    GetItemGem = function(link, index)
        local gem = (data[link].gems or {})[index]
        if gem then return 'gem', gem end
    end,
    GetItemIconByID = function() return 123 end,
    GetItemQualityColor = function() return 1, 0, 1 end,
    GetDetailedItemLevelInfo = function() return 300 end,
    GetItemSetInfo = function(setID) return 'SET' .. setID end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local item = data[link]
    if item.tooltipPending then return nil end
    return { lines = { { leftText = 'SET' .. (item.setID or 0) .. ' (0/' .. (item.setSize or 5) .. ')' } } }
end }
function UpdateClassWatermark() end
function TintBorder() end
function UpdateBadge() end
function ShowMarker() end
function HideCraftingQualityIcon(link) return link end
function GetEquippedPvPItemLevel() end
function UpdateCharacterItemLevel() end
function equip(unit, slot, id, enchant, sockets, gem1, gem2, gem3, setID, setSize)
    local link = string.format('item:%d:%d:%d:%d:%d:0:0', id, enchant or 0, gem1 or 0, gem2 or 0, gem3 or 0)
    inventory[unit] = inventory[unit] or {}
    inventory[unit][slot] = link
    data[link] = { sockets = sockets or 0, setID = setID, setSize = setSize }
    return link
end
""" + constants + source[start:end] + source[update_start:update_end] + """
local player, inspect = newPanel('player'), newPanel('target')
-- A filled socket whose gem metadata is not cached, beside an empty added socket.
local ring = equip('player', 11, 101, 777, 2, 222)
local head = equip('player', 1, 102, 0, 0, nil, nil, nil, 100)
equip('player', 3, 103, 778, 0, nil, nil, nil, 100)
-- A two-piece crafted set must not count toward the four-piece target.
equip('player', 5, 104, 779, 0, nil, nil, nil, 200, 2)
equip('player', 7, 105, 780, 0, nil, nil, nil, 200, 2)
UpdateList(player)
assert(player.headerStatus.text == '|cffff5555附魔:4/5|r  |cffff5555宝石:1/2|r  |cffff5555套装:2/4|r', player.headerStatus.text)
local markers, filled, total = GetGemMarkers(ring, {})
assert(#markers == 2 and filled == 1 and total == 2)
assert(markers[1].itemLink == 'item:222' and markers[2].isEmptySocket)

-- Two different raid sets stay separate. Inspection doesn't read our inventory.
equip('target', 1, 201, 900, 0, nil, nil, nil, 300)
equip('target', 3, 202, 900, 0, nil, nil, nil, 300)
equip('target', 5, 203, 900, 0, nil, nil, nil, 400)
equip('target', 7, 204, 900, 0, nil, nil, nil, 400)
UpdateList(inspect)
assert(inspect.headerStatus.text == '|cffadb9bf附魔:4/4|r  |cffadb9bf宝石:0/0|r  |cffff5555套装:2/4|r', inspect.headerStatus.text)
assert(player.headerStatus.text:find('附魔:4/5', 1, true))

-- Five pieces in one set complete the four-piece target rather than show 5/4.
equip('target', 5, 205, 900, 0, nil, nil, nil, 300)
equip('target', 7, 206, 900, 0, nil, nil, nil, 300)
equip('target', 10, 207, 0, 0, nil, nil, nil, 300)
UpdateList(inspect)
assert(inspect.headerStatus.text:find('|cffadb9bf套装:4/4|r', 1, true))

-- Uncached item data or incomplete inspection must not report false failures.
data[head].pending = true
UpdateList(player)
assert(player.headerStatus.text:find('宝石:--/--', 1, true))
assert(player.headerStatus.text:find('套装:--/4', 1, true))
assert(player.headerStatus.text:find('附魔:4/5', 1, true))
data[head].pending = false
pendingSlot = 16
UpdateList(player)
assert(player.headerStatus.text:find('附魔:--/--', 1, true))
pendingSlot = nil
UpdateList(player)
assert(player.headerStatus.text:find('宝石:1/2', 1, true))

local empty = newPanel('empty')
UpdateList(empty)
assert(empty.headerStatus.text == '|cffadb9bf附魔:0/0|r  |cffadb9bf宝石:0/0|r  |cffff5555套装:0/4|r')
""")
print("PASS Lua 5.1 syntax and inventory scenarios: sockets, enchantments, separate sets, inspection, loading, empty equipment")
