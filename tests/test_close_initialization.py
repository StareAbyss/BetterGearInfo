from pathlib import Path
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / 'BetterGearInfo.lua').read_text(encoding='utf-8-sig')

fixture = r'''
local addonName, WHITE, FONT = 'test', 'white', 'font'
local BORDER = {.1,.1,.1,1}
local closeButtonError
local slots = {}
for i=1,16 do slots[i] = {i,'slot'} end
GameTooltip = {GetOwner=function() end, Hide=function() end,
    SetOwner=function() end, SetText=function() end, Show=function() end}
local function noop() end
local region = {}
for _, name in ipairs({'SetAllPoints','SetPoint','SetAlpha','SetColorTexture','SetTexture',
    'SetThickness','SetStartPoint','SetEndPoint','SetVertexColor','SetFont','SetTextColor',
    'SetText','SetSize','SetHeight','Hide','Show'}) do region[name] = noop end
local frame = {}
for _, name in ipairs({'SetSize','SetFrameStrata','SetFrameLevel','SetPoint','SetAlpha',
    'EnableMouse','ClearAllPoints','SetHeight','SetClipsChildren'}) do frame[name] = noop end
function frame:GetFrameLevel() return 2 end
function frame:GetFrameStrata() return 'MEDIUM' end
function frame:IsShown() return not self.hidden end
function frame:IsMouseOver() return self.inside or false end
function frame:CreateFontString() return setmetatable({}, {__index=region}) end
function frame:CreateTexture() return setmetatable({}, {__index=region}) end
function frame:CreateLine()
    if failLine then error('Injected line initialization failure') end
    return setmetatable({}, {__index=region})
end
function frame:SetScript(event, fn) self.scripts[event] = fn end
function frame:HookScript(event, fn) self.hooks[event] = fn end
function frame:Show() self.hidden=false; if self.hooks.OnShow then self.hooks.OnShow() end end
function frame:Hide() self.hidden=true; if self.hooks.OnHide then self.hooks.OnHide() end end
-- TextureAsset in Blizzard's button API is non-nil; unknown methods aren't fabricated.
for _, name in ipairs({'SetNormalTexture','SetPushedTexture','SetHighlightTexture','SetDisabledTexture'}) do
    frame[name] = function(self, asset) assert(type(asset)=='string', 'TextureAsset must be non-nil') end
end
function CreateFrame() return setmetatable({scripts={},hooks={}}, {__index=frame}) end
local function StripTextures() end
local function MakeSolid(parent) return parent:CreateTexture() end
local function AddBorder() return {} end
local function MakeRow() return {} end
local function PositionList() end
'''

def code(text):
    a = text.index('local function SkinHoverCloseButton(')
    b = text.index('local function SkinPanel(', a)
    c = text.index('local function CreateList(')
    d = text.index('local function UpdateBadge(', c)
    return fixture + text[a:b] + text[c:d] + '\nreturn CreateList'

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('assert(loadstring(...))', source)
create = lua.execute(code(source))
panel = create(lua.globals().CreateFrame(), 'GearList')
assert len(panel['rows']) == 16 and panel['owner'] is not None
lua.globals().failLine = True
panel = create(lua.globals().CreateFrame(), 'InspectGearList')
assert len(panel['rows']) == 16 and panel['owner'] is not None
print('PASS Lua 5.1 syntax, full list construction, injected close-control failure isolation')
