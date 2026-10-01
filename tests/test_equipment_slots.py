from pathlib import Path
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / 'BetterGearInfo.lua').read_text(encoding='utf-8-sig')
fixture = r'''
local WHITE, BORDER = 'white', {0.1,0.1,0.1,1}
local methods = {}
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetTexCoord(...) self.coords = {...} end
function methods:SetVertexColor(...) self.color = {...} end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...) table.insert(self.points, {...}) end
function methods:SetAllPoints() end
function methods:Hide() self.shown = false end
function methods:Show()
    self.shown = true
    for _, hook in ipairs(self.hooks.OnShow or {}) do hook(self) end
end
function methods:HookScript(event, fn)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], fn)
end
function methods:GetName() return self.name end
function methods:GetID() return self.id or 3 end
function methods:GetNormalTexture() return self.normal end
function methods:GetPushedTexture() return self.pushed end
function methods:GetHighlightTexture() return self.highlight end
local function region()
    return setmetatable({alpha=1,shown=true,hooks={},points={}}, {__index=methods})
end
local function slot(name)
    local s = region()
    s.name, s.icon, s.IconBorder = name, region(), region()
    s.normal, s.pushed, s.highlight = region(), region(), region()
    return s
end
function StripTextures(s) s.IconBorder:SetTexture(nil) end
function MakeSolid() return region() end
function GetInventoryItemQuality(_, id) return id ~= 19 and 1 or nil end
C_Item = {GetItemQualityColor=function() return 1,1,1 end}
function TintBorder(edges, r, g, b)
    for _, edge in ipairs(edges) do edge:SetVertexColor(r, g, b, 1) end
end
local bordersCreated = 0
function AddBorder() bordersCreated = bordersCreated + 1; return {region()} end
local timers = {}
C_Timer = {After=function(_, fn) table.insert(timers, fn) end}
local function flush()
    local pending = timers; timers = {}
    for _, fn in ipairs(pending) do fn() end
end
function SetItemButtonQuality(s)
    s.IconBorder:SetTexture('native quality frame')
    s.IconBorder:Show()
end
function PaperDollItemSlotButton_Update(s)
    s.icon:SetTexCoord(0,1,0,1)
    SetItemButtonQuality(s)
end
function hooksecurefunc(name, callback)
    local original = _G[name]
    _G[name] = function(...)
        original(...)
        callback(...)
    end
end
'''
scenario = r'''
local s = slot('CharacterShoulderSlot')
SkinEquipmentSlot(s)
flush()
PaperDollItemSlotButton_Update(s)
assert(s.IconBorder.alpha == 0, 'native quality border reappeared after refresh')
-- Another update callback runs after our hook; deferred application wins.
s.icon:SetTexCoord(0,1,0,1)
flush()
local crop = (1 - .84 / 1.15) / 2
assert(math.abs(s.icon.coords[1] - crop) < 1e-12)
assert(math.abs(s.icon.coords[2] - (1-crop)) < 1e-12)
assert(#s.icon.points == 2 and s.icon.points[1][4] == 2 and s.icon.points[2][4] == -2)
-- The inspection addon creates its border later, outside the quality callback.
s.angularFrame = region()
for _, hook in ipairs(s.hooks.OnUpdate or {}) do hook(s, .21) end
assert(s.angularFrame.alpha == 0 and not s.angularFrame.shown)
s.angularFrame:Show()
assert(not s.angularFrame.shown, 'delayed inspection frame can reappear')
SkinEquipmentSlot(s)
assert(bordersCreated == 1, 'own quality border was duplicated')
local shirt = slot('CharacterShirtSlot'); shirt.id = 4
local tabard = slot('CharacterTabardSlot'); tabard.id = 19
SkinEquipmentSlot(shirt); SkinEquipmentSlot(tabard); flush()
assert(shirt.IconBorder.alpha == 0 and tabard.IconBorder.alpha == 0)
assert(shirt.BetterGearInfoBorder[1].color[1] == 1)
assert(tabard.BetterGearInfoBorder[1].color[1] == .16)
local bag = slot('BagItem')
SetItemButtonQuality(bag)
flush()
assert(bag.IconBorder.alpha == 1, 'an unrelated item button was altered')
'''

a = source.index('local equipmentVisualHooksInstalled =')
b = source.index('local function SkinStats()', a)
LuaRuntime().execute(fixture + source[a:b] + scenario)
a = source.index('local slots =')
b = source.index('local statBadges =', a)
slots, buttons = LuaRuntime(unpack_returned_tuples=True).execute(source[a:b] + '\nreturn slots, slotButtons')
assert len(slots) == 16 and len(list(buttons.items())) == 18
assert buttons[4] == 'CharacterShirtSlot' and buttons[19] == 'CharacterTabardSlot'
assert 'for _, buttonName in pairs(slotButtons) do' in source
print('PASS equipment refresh, delayed borders, crop restoration, shirt/tabard and unrelated buttons')
