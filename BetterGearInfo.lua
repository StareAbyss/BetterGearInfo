-- BetterGearInfo
-- 左侧角色界面风格参考 ElvUI；右侧装备详情栏灵感来源于 TinyInspect。
-- 在此基础上重新做了美化和修复。
local addonName = ...
local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(addonName, "Version") or "2.6.4"

local unpack = unpack
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local BORDER = { 0.10, 0.10, 0.10, 1 }
local PANEL = { 0.025, 0.025, 0.025, 0.96 }
local MUTED = { 0.48, 0.55, 0.58, 1 }
local OUTER_BORDER_NEUTRAL = 0.24
local OUTER_BORDER_CLASS_BLEND = 0.32
local ENCHANT_SCROLL_ICON = 463531
local NAME_LEFT = 115
local MARKER_STEP = 19

local slots = {
    { 1, INVTYPE_HEAD or "头部" },
    { 2, INVTYPE_NECK or "颈部" },
    { 3, INVTYPE_SHOULDER or "肩部" },
    { 5, INVTYPE_CHEST or "胸甲" },
    { 6, INVTYPE_WAIST or "腰带" },
    { 7, INVTYPE_LEGS or "腿部" },
    { 8, INVTYPE_FEET or "靴子" },
    { 9, INVTYPE_WRIST or "护腕" },
    { 10, INVTYPE_HAND or "手套" },
    { 11, INVTYPE_FINGER1 or "戒指 1" },
    { 12, INVTYPE_FINGER2 or "戒指 2" },
    { 13, INVTYPE_TRINKET1 or "饰品 1" },
    { 14, INVTYPE_TRINKET2 or "饰品 2" },
    { 15, INVTYPE_CLOAK or "披风" },
    { 16, INVTYPE_WEAPONMAINHAND or "主手" },
    { 17, INVTYPE_WEAPONOFFHAND or "副手" },
}
local slotButtons = {
    [1] = "CharacterHeadSlot", [2] = "CharacterNeckSlot",
    [3] = "CharacterShoulderSlot", [5] = "CharacterChestSlot",
    [6] = "CharacterWaistSlot", [7] = "CharacterLegsSlot",
    [8] = "CharacterFeetSlot", [9] = "CharacterWristSlot",
    [10] = "CharacterHandsSlot", [11] = "CharacterFinger0Slot",
    [12] = "CharacterFinger1Slot", [13] = "CharacterTrinket0Slot",
    [14] = "CharacterTrinket1Slot", [15] = "CharacterBackSlot",
    [16] = "CharacterMainHandSlot", [17] = "CharacterSecondaryHandSlot",
}
local statBadges = {
    { key = "ITEM_MOD_CRIT_RATING_SHORT", text = "暴", color = { 224 / 255, 28 / 255, 28 / 255 } },
    { key = "ITEM_MOD_HASTE_RATING_SHORT", text = "速", color = { 14 / 255, 213 / 255, 155 / 255 } },
    { key = "ITEM_MOD_MASTERY_RATING_SHORT", text = "精", color = { 146 / 255, 86 / 255, 255 / 255 } },
    { key = "ITEM_MOD_VERSATILITY", text = "全", color = { 191 / 255, 191 / 255, 191 / 255 } },
}
local enchantableSlots = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [11] = true, [12] = true, [16] = true }

local eventFrame = CreateFrame("Frame")
local listPanel
local inspectPanel
local initialized = false
local paperDollHooksInstalled = false
local itemLevelHooked = false
local inspectHooked = false
local skinAttempted = false
local initializationError
local closeButtonError

local function SuppressDuplicateGearList(panel)
    -- Hide another addon's overlapping gear list while leaving its other
    -- inspection and tooltip features available.
    if not panel or not panel:IsShown() then return end
    local source = panel.owner == InspectFrame and InspectFrame or PaperDollFrame
    local other = source and source.inspectFrame
    if not other then return end
    if not other.BetterGearInfoHooked then
        other.BetterGearInfoHooked = true
        other:HookScript("OnShow", function(self)
            if panel:IsShown() and panel.owner == source then self:Hide() end
        end)
    end
    if other:IsShown() then other:Hide() end
end

local function MakeSolid(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function TryCircleMask(texture)
    local path = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"
    local parent = texture.GetParent and texture:GetParent()
    if texture.AddMaskTexture and parent and parent.CreateMaskTexture then
        local mask = parent:CreateMaskTexture()
        mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
        texture.BetterGearInfoMask = mask
    elseif texture.SetMask then
        pcall(texture.SetMask, texture, path)
    end
end

local function AddBorder(parent, color)
    local top = MakeSolid(parent, "OVERLAY", unpack(color))
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    local bottom = MakeSolid(parent, "OVERLAY", unpack(color))
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = MakeSolid(parent, "OVERLAY", unpack(color))
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    local right = MakeSolid(parent, "OVERLAY", unpack(color))
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    return { top, bottom, left, right }
end

local function TintBorder(edges, r, g, b)
    if not edges then return end
    for _, edge in ipairs(edges) do
        edge:SetColorTexture(r, g, b, 1)
    end
end

local artChildren = {
    "Inset", "inset", "InsetFrame", "LeftInset", "RightInset", "NineSlice",
    "BG", "Bg", "border", "Border", "Background", "BorderFrame",
    "bottomInset", "BottomInset", "bgLeft", "bgRight", "FilligreeOverlay",
    "PortraitOverlay", "ArtOverlayFrame", "Portrait", "portrait",
}

local function StripTextures(frame, keep, visited)
    if not frame or not frame.IsObjectType then return end
    visited = visited or {}
    if visited[frame] then return end
    visited[frame] = true
    if frame:IsObjectType("Texture") then
        if not keep or not keep[frame] then
            frame:SetTexture(nil)
            frame:SetAtlas("")
        end
        return
    end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("Texture") and (not keep or not keep[region]) then
                region:SetTexture(nil)
                region:SetAtlas("")
            end
        end
    end
    local name = frame.GetName and frame:GetName()
    for _, key in ipairs(artChildren) do
        local child = frame[key] or (name and _G[name .. key])
        if child and child ~= frame then StripTextures(child, keep, visited) end
    end
    if frame.NineSlice then frame.NineSlice:Hide() end
end

local function SkinHoverCloseButton(owner, button)
    if not button or button.BetterGearInfoHoverClose then return end
    StripTextures(button)
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    button:SetHighlightTexture("")
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -4, -4)
    button:SetSize(24, 24)
    button:SetFrameLevel(math.max(button:GetFrameLevel(), owner:GetFrameLevel() + 5))

    local strokes = {}
    for index = 1, 2 do
        local line = button:CreateLine(nil, "OVERLAY")
        line:SetColorTexture(0.70, 0.70, 0.70, 1)
        line:SetThickness(1.5)
        line:SetStartPoint("CENTER", button, -5, index == 1 and 5 or -5)
        line:SetEndPoint("CENTER", button, 5, index == 1 and -5 or 5)
        strokes[index] = line
    end
    local function PaintCross(hovered)
        local shade = hovered and 0.98 or 0.70
        for _, line in ipairs(strokes) do line:SetColorTexture(shade, shade, shade, 1) end
    end
    PaintCross(false)
    button:HookScript("OnEnter", function() PaintCross(true) end)
    button:HookScript("OnLeave", function() PaintCross(false) end)

    local wasVisible
    local function SetVisible(visible)
        if visible == wasVisible then return end
        wasVisible = visible
        button:SetAlpha(visible and 1 or 0)
        -- An invisible close control must not intercept the mouse.
        button:EnableMouse(visible)
        if not visible then
            PaintCross(false)
            if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
        end
    end
    local function UpdateVisibility()
        SetVisible(owner:IsShown() and owner:IsMouseOver())
    end
    owner:HookScript("OnUpdate", UpdateVisibility)
    owner:HookScript("OnShow", UpdateVisibility)
    owner:HookScript("OnHide", function() SetVisible(false) end)
    UpdateVisibility()
    button.BetterGearInfoHoverClose = true
end

local function TrySkinHoverCloseButton(owner, button)
    -- A decorative control must not abort equipment-list or character-skin setup.
    local ok, err = pcall(SkinHoverCloseButton, owner, button)
    if not ok then
        local message = tostring(err)
        if closeButtonError ~= message then
            closeButtonError = message
            print(addonName .. ": 关闭按钮初始化失败: " .. message)
        end
    end
    return ok
end

local function SkinPanel(frame, color, inset)
    if not frame then return end
    StripTextures(frame)
    local bg = MakeSolid(frame, "BACKGROUND", unpack(color or PANEL))
    if inset then
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    else
        bg:SetAllPoints()
    end
    AddBorder(frame, BORDER)
end

local function SkinEquipmentSlot(slot)
    if not slot or slot.BetterGearInfoSkinned then return end
    slot.BetterGearInfoSkinned = true
    local name = slot:GetName()
    local icon = slot.icon or slot.Icon or (name and _G[name .. "IconTexture"])
    local highlight = slot:GetHighlightTexture()
    local keep = {}
    if icon then keep[icon] = true end
    if highlight then keep[highlight] = true end
    if slot.ignoreTexture then keep[slot.ignoreTexture] = true end
    StripTextures(slot, keep)
    local backdrop = MakeSolid(slot, "BACKGROUND", 0.04, 0.04, 0.04, 0.94)
    backdrop:SetAllPoints()
    slot.BetterGearInfoBorder = AddBorder(slot, BORDER)

    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    end

    local normal = slot:GetNormalTexture()
    if normal then normal:SetTexture(nil) end
    local pushed = slot:GetPushedTexture()
    if pushed then pushed:SetTexture(nil) end
    if highlight then
        highlight:SetTexture(WHITE)
        highlight:SetVertexColor(1, 1, 1, 0.14)
        highlight:SetAllPoints()
    end
end

local function SkinStats()
    local pane = CharacterStatsPane
    if not pane then return end
    SkinPanel(pane, PANEL)
    for _, key in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
        local category = pane[key]
        if category then
            StripTextures(category)
            local bg = MakeSolid(category, "BACKGROUND", 0.075, 0.075, 0.075, 0.95)
            bg:SetPoint("CENTER", category, "CENTER")
            bg:SetSize(150, 18)
            AddBorder(category, BORDER)
        end
    end
    if pane.ItemLevelFrame then
        if pane.ItemLevelFrame.Background then pane.ItemLevelFrame.Background:SetAlpha(0) end
        if pane.ItemLevelFrame.Value then pane.ItemLevelFrame.Value:SetFont(FONT, 20, "OUTLINE") end
    end
end

local function UpdateStatRows()
    local pane = CharacterStatsPane
    if not pane or not pane.statsFramePool then return end
    for stat in pane.statsFramePool:EnumerateActive() do
        if stat.Label then
            if not stat.BetterGearInfoLabelHooked then
                local row = stat
                local ok = pcall(hooksecurefunc, stat.Label, "SetText", function(labelText)
                    if row.BetterGearInfoFormatting then return end
                    local current = labelText:GetText()
                    if type(current) ~= "string" then return end
                    local cleaned = current:gsub("：", ""):gsub(":", "")
                    if cleaned ~= current then
                        row.BetterGearInfoFormatting = true
                        labelText:SetText(cleaned)
                        row.BetterGearInfoFormatting = false
                    end
                end)
                stat.BetterGearInfoLabelHooked = ok
            end
            stat.Label:ClearAllPoints()
            stat.Label:SetPoint("LEFT", stat, "LEFT", 17, 0)
            local label = stat.Label:GetText()
            if type(label) == "string" then
                local cleaned = label:gsub("：", ""):gsub(":", "")
                if cleaned ~= label then stat.Label:SetText(cleaned) end
            end
        end
        if stat.Value then
            stat.Value:ClearAllPoints()
            stat.Value:SetPoint("RIGHT", stat, "RIGHT", -15, 0)
        end
        if stat.Background then
            local wasShown = stat.Background:IsShown()
            stat.Background:SetAlpha(0)
            if not stat.BetterGearInfoShade then
                stat.BetterGearInfoShade = MakeSolid(stat, "BACKGROUND", 0.10, 0.10, 0.10, 0.50)
                stat.BetterGearInfoShade:SetAllPoints()
            end
            stat.BetterGearInfoShade:SetShown(wasShown)
        end
    end
end

local function SkinTabs()
    local index = 1
    local tab = _G["CharacterFrameTab" .. index]
    local previous
    while tab do
        local text = tab.Text or _G[tab:GetName() .. "Text"] or tab:GetFontString()
        local keep = {}
        if text then keep[text] = true end
        StripTextures(tab, keep)
        local bg = MakeSolid(tab, "BACKGROUND", 0.07, 0.07, 0.07, 1)
        bg:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -3)
        bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 3)
        if text then
            text:ClearAllPoints()
            text:SetPoint("CENTER", tab, "CENTER", 0, 0)
        end
        if previous then
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", -5, 0)
        end
        previous = tab
        index = index + 1
        tab = _G["CharacterFrameTab" .. index]
    end
end

local function SkinSidebarTabs()
    if not PaperDollFrame or not CharacterFrame or not CharacterFrameInsetRight then return end
    local tabs = PaperDollSidebarTabs
    if not tabs then return end
    if PaperDollFrame.BetterGearInfoSidebarHolder then
        return
    end
    for index = 1, 3 do
        if not _G["PaperDollSidebarTab" .. index] then return end
    end
    -- Blizzard's three 33-pixel tabs are centered inside this 168-pixel
    -- container. Center the container on the middle character information pane.
    tabs:ClearAllPoints()
    tabs:SetPoint("BOTTOM", CharacterFrameInsetRight, "TOP", 0, -1)
    tabs:SetFrameLevel(math.max(tabs:GetFrameLevel(), PaperDollFrame:GetFrameLevel()) + 5)
    PaperDollFrame.BetterGearInfoSidebarHolder = tabs

    local wasVisible
    local function UpdateSidebarVisibility()
        local visible = PaperDollFrame:IsShown() and CharacterFrame:IsMouseOver()
        if visible == wasVisible then return end
        wasVisible = visible
        tabs:SetAlpha(visible and 1 or 0)
        for index = 1, 3 do
            _G["PaperDollSidebarTab" .. index]:EnableMouse(visible)
        end
    end
    tabs:HookScript("OnShow", UpdateSidebarVisibility)
    CharacterFrame:HookScript("OnUpdate", function()
        UpdateSidebarVisibility()
    end)
    UpdateSidebarVisibility()
end

local sidebarSkinError
local function TrySkinSidebarTabs()
    if InCombatLockdown() then return end
    local ok, err = pcall(SkinSidebarTabs)
    if not ok then
        local message = tostring(err)
        if sidebarSkinError ~= message then
            sidebarSkinError = message
            print(addonName .. ": 切换按钮初始化失败: " .. message)
        end
    end
end

local function SkinCharacterFrame()
    local character = CharacterFrame
    if not character then return end

    -- Clear the decorative art before drawing the panel backgrounds.
    -- The model, stats, and equipment controls stay owned by Blizzard.
    StripTextures(character)
    StripTextures(CharacterModelScene)
    StripTextures(CharacterFrameInset)
    StripTextures(CharacterFrameInsetRight)
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if character.PortraitContainer then character.PortraitContainer:Hide() end
    local bg = MakeSolid(character, "BACKGROUND", unpack(PANEL))
    bg:SetAllPoints()
    local title = MakeSolid(character, "BORDER", 0.045, 0.045, 0.045, 1)
    title:SetPoint("TOPLEFT", character, "TOPLEFT", 3, -3)
    title:SetPoint("TOPRIGHT", character, "TOPRIGHT", -3, -3)
    title:SetHeight(28)
    character.BetterGearInfoOuterBorder = AddBorder(character, BORDER)

    local titleContainer = character.TitleContainer
    local titleText = titleContainer and titleContainer.TitleText
    if titleText then
        titleText:ClearAllPoints()
        titleText:SetPoint("TOPLEFT", character, "TOPLEFT", 36, -11)
        titleText:SetPoint("TOPRIGHT", character, "TOPRIGHT", -36, -11)
        titleText:SetFont(FONT, 17, "OUTLINE")
        titleText:SetJustifyH("CENTER")
    end
    if CharacterLevelText then
        CharacterLevelText:SetFont(FONT, 14, "OUTLINE")
    end

    SkinPanel(CharacterModelScene, { 0.025, 0.025, 0.025, 1 })
    if CharacterModelFrameBackgroundOverlay then
        CharacterModelFrameBackgroundOverlay:SetColorTexture(0, 0, 0, 1)
    end
    SkinStats()
    SkinTabs()

    local close = CharacterFrameCloseButton or character.CloseButton
    if close and close:IsObjectType("Button") then
        -- Keep Blizzard's original click handler and panel closing behavior.
        TrySkinHoverCloseButton(character, close)
    end

    for _, info in ipairs(slots) do
        SkinEquipmentSlot(_G[slotButtons[info[1]]])
    end
    if type(PaperDollFrame_UpdateStats) == "function" then
        hooksecurefunc("PaperDollFrame_UpdateStats", UpdateStatRows)
        UpdateStatRows()
    end
    CharacterStatsPane:HookScript("OnShow", function()
        C_Timer.After(0, UpdateStatRows)
    end)
end

local function PositionList(panel)
    local owner = panel and panel.owner
    if not owner then return end
    panel:ClearAllPoints()
    local ownerRight = owner:GetRight()
    local screenRight = UIParent:GetRight()
    if owner == InspectFrame and ownerRight and screenRight
        and ownerRight + panel:GetWidth() > screenRight - 4 then
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", 1, 0)
    else
        -- The list is above its owner by one frame level, so its left edge
        -- covers the owner's right edge and the seam stays one pixel wide.
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", -1, 0)
    end
    local height = math.max(owner:GetHeight(), 424)
    panel:SetHeight(height)
    local rowTop = 60
    -- One extra pixel per row uses 16 pixels of the previous bottom gap.
    local rowHeight = math.min((height - rowTop - 24) / #slots, 28) + 1
    for index, row in ipairs(panel.rows) do
        row:SetHeight(rowHeight)
        row.level:SetHeight(rowHeight - 1)
        row.name:SetHeight(rowHeight - 1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -rowTop - (index - 1) * rowHeight)
    end
end

local function MakeRow(parent, index, slotID, label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(338, 23)
    row:EnableMouse(true)
    row.slotID = slotID

    local bg = MakeSolid(row, "BACKGROUND", 0.035, 0.035, 0.035, index % 2 == 0 and 0.80 or 0.48)
    bg:SetAllPoints()
    if index < #slots then
        row.divider = MakeSolid(row, "BORDER", 0, 0, 0, 0)
        row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.divider:SetHeight(1)
    end
    row.badges = {}
    for badgeIndex, info in ipairs(statBadges) do
        local badge = CreateFrame("Frame", nil, row)
        badge:SetSize(17, 18)
        badge:SetPoint("LEFT", row, "LEFT", 1 + (badgeIndex - 1) * 20, 0)
        local badgeBg = MakeSolid(badge, "BACKGROUND", info.color[1] * 0.22, info.color[2] * 0.22, info.color[3] * 0.22, 0.80)
        badgeBg:SetAllPoints()
        badge.bg = badgeBg
        local glyph = badge:CreateFontString(nil, "OVERLAY")
        glyph:SetFont(FONT, 13, "OUTLINE")
        -- The rendered Chinese glyph ink sits slightly above and left of its font box.
        glyph:SetPoint("CENTER", badge, "CENTER", 1, -2)
        glyph:SetText(info.text)
        glyph:SetTextColor(unpack(info.color))
        glyph:Hide()
        badge.glyph = glyph
        badge.edges = AddBorder(badge, { info.color[1] * 0.28, info.color[2] * 0.28, info.color[3] * 0.28, 0.40 })
        row.badges[badgeIndex] = badge
    end

    row.level = row:CreateFontString(nil, "OVERLAY")
    row.level:SetFont(FONT, 15, "OUTLINE")
    row.level:SetSize(30, 22)
    row.level:SetJustifyH("RIGHT")
    row.level:SetPoint("LEFT", row, "LEFT", 80, 0)
    row.level:SetText("")

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(FONT, 15, "OUTLINE")
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", NAME_LEFT, 0)
    row.name:SetWidth(220)
    row.name:SetHeight(22)
    if row.name.SetMaxLines then row.name:SetMaxLines(1) end
    row.name:SetText("")

    row.markers = {}
    for markerIndex = 1, 6 do
        local marker = CreateFrame("Button", nil, row)
        marker:SetSize(16, 16)
        marker.bg = MakeSolid(marker, "BACKGROUND", 0.04, 0.04, 0.04, 0.9)
        marker.bg:SetAllPoints()
        marker.edges = AddBorder(marker, { 0.35, 0.35, 0.35, 0.8 })
        marker.icon = marker:CreateTexture(nil, "ARTWORK")
        marker.icon:SetSize(14, 14)
        marker.icon:SetPoint("CENTER")
        TryCircleMask(marker.icon)
        marker.text = marker:CreateFontString(nil, "OVERLAY")
        marker.text:SetFont(FONT, 14, "OUTLINE")
        marker.text:SetPoint("CENTER")
        marker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemLink then
                GameTooltip:SetHyperlink(self.itemLink)
            elseif self.spellID and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(self.spellID)
            else
                GameTooltip:SetText(self.title or "")
            end
            GameTooltip:Show()
        end)
        marker:SetScript("OnLeave", function() GameTooltip:Hide() end)
        marker:Hide()
        row.markers[markerIndex] = marker
    end

    row:SetScript("OnEnter", function(self)
        local unit = self:GetParent().unit
        if not unit or not GetInventoryItemLink(unit, self.slotID) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem(unit, self.slotID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function CreateList(owner, suffix)
    local panel = CreateFrame("Frame", addonName .. suffix, owner)
    panel:SetSize(354, 424)
    panel:SetFrameStrata(owner:GetFrameStrata())
    panel:SetFrameLevel(owner:GetFrameLevel() + 1)
    local bg = MakeSolid(panel, "BACKGROUND", 0.015, 0.015, 0.015, 0.97)
    bg:SetAllPoints()
    panel.outerBorder = AddBorder(panel, BORDER)

    panel.headerTitle = panel:CreateFontString(nil, "OVERLAY")
    panel.headerTitle:SetFont(FONT, 18, "OUTLINE")
    panel.headerTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -10)
    panel.headerTitle:SetText("装备详情")
    panel.headerTitle:SetTextColor(0.91, 0.93, 0.94)

    panel.headerStatus = panel:CreateFontString(nil, "OVERLAY")
    panel.headerStatus:SetFont(FONT, 12, "OUTLINE")
    panel.headerStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -36)
    panel.headerStatus:SetText("附魔:--/--  宝石:--/--  套装:--/4")
    panel.headerStatus:SetTextColor(0.68, 0.73, 0.75)

    panel.headerDivider = MakeSolid(panel, "BORDER", 0.4, 0.4, 0.4, 0.22)
    panel.headerDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -56)
    panel.headerDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -56)
    panel.headerDivider:SetHeight(1)

    -- Clip a larger emblem at the top/right corner. The child frame makes
    -- clipping apply to its texture without covering text or equipment rows.
    panel.watermarkClip = CreateFrame("Frame", nil, panel)
    panel.watermarkClip:SetSize(70, 54)
    panel.watermarkClip:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.watermarkClip:SetClipsChildren(true)
    local emblem = CreateFrame("Frame", nil, panel.watermarkClip)
    emblem:SetSize(76, 76)
    emblem:SetPoint("TOPRIGHT", panel.watermarkClip, "TOPRIGHT", 16, 14)
    panel.classWatermark = emblem:CreateTexture(nil, "ARTWORK")
    panel.classWatermark:SetPoint("CENTER", emblem, "CENTER")
    panel.classWatermark:SetAlpha(0.32)
    panel.classWatermark:Hide()

    panel.rows = {}
    for i, info in ipairs(slots) do
        panel.rows[i] = MakeRow(panel, i, info[1], info[2])
    end
    panel.closeButton = CreateFrame("Button", nil, panel)
    panel.closeButton:SetScript("OnClick", function() panel:Hide() end)
    panel.closeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("暂时收起装备栏")
        GameTooltip:Show()
    end)
    panel.closeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    TrySkinHoverCloseButton(panel, panel.closeButton)
    panel.owner = owner
    PositionList(panel)
    panel:Show()
    return panel
end

local function UpdateBadge(badge, info, active)
    badge.glyph:SetShown(active)
    badge.bg:SetColorTexture(info.color[1] * 0.22, info.color[2] * 0.22, info.color[3] * 0.22, 0.80)
    if active then
        for _, edge in ipairs(badge.edges) do
            edge:SetColorTexture(info.color[1], info.color[2], info.color[3], 0.55)
        end
    else
        for _, edge in ipairs(badge.edges) do
            edge:SetColorTexture(info.color[1] * 0.28, info.color[2] * 0.28, info.color[3] * 0.28, 0.40)
        end
    end
end

local function GetGemMarkers(link, stats)
    local gems = {}
    local socketCount = C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(link)
    local baseSockets = 0
    for key, amount in pairs(stats) do
        if type(key) == "string" and key:find("EMPTY_SOCKET_", 1, true) then
            baseSockets = baseSockets + (tonumber(amount) or 0)
        end
    end
    socketCount = socketCount or baseSockets
    local gemIDs = { link:match("item:%d+:[^:]*:([^:]*):([^:]*):([^:]*):([^:]*)") }
    local filled = 0
    for index = 1, 4 do
        local gemName, gemLink = C_Item.GetItemGem(link, index)
        local gemID = tonumber(gemIDs[index])
        -- The link records occupied sockets even while a gem's name is uncached.
        if not gemLink and gemID and gemID > 0 then gemLink = "item:" .. gemID end
        if gemLink then
            filled = filled + 1
            socketCount = math.max(socketCount, index)
            local _, _, quality, _, _, _, _, _, _, texture = C_Item.GetItemInfo(gemLink)
            texture = texture or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(gemLink))
            local r, g, b = C_Item.GetItemQualityColor(quality or 1)
            gems[index] = { title = gemName or "宝石", itemLink = gemLink, texture = texture, text = "宝", color = { r, g, b } }
        end
    end
    local ordered = {}
    for index = 1, math.min(socketCount, 4) do
        ordered[#ordered + 1] = gems[index] or {
            title = "空宝石插槽", texture = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
            isEmptySocket = true, color = { 0.65, 0.52, 0.16 },
        }
    end
    return ordered, filled, socketCount
end

local fourPieceSets = {}
local function IsFourPieceSet(setID, link)
    if fourPieceSets[setID] ~= nil then return fourPieceSets[setID] end
    local setName = C_Item.GetItemSetInfo and C_Item.GetItemSetInfo(setID)
    local tooltip = C_TooltipInfo and C_TooltipInfo.GetHyperlink(link, nil, nil, true)
    if not setName or setName == "" or not tooltip or not tooltip.lines then return end
    for _, line in ipairs(tooltip.lines) do
        local text = line.leftText
        if text and text:find(setName, 1, true) then
            local total = tonumber(text:match("%d+%s*/%s*(%d+)"))
            if total then
                fourPieceSets[setID] = total >= 4
                return fourPieceSets[setID]
            end
        end
    end
end

local function FormatProgress(label, filled, total, pending)
    if pending then return "|cffadb9bf" .. label .. ":--/" .. (label == "套装" and "4" or "--") .. "|r" end
    local color = filled < total and "|cffff5555" or "|cffadb9bf"
    return color .. label .. ":" .. filled .. "/" .. total .. "|r"
end

local function GetEnchantMarker(link, slotID)
    local enchantID = tonumber(link:match("item:%d+:(%d+)"))
    if not enchantID or enchantID == 0 then
        if enchantableSlots[slotID] then
            return { title = "缺少附魔", text = "!", textColor = { 1, 0.12, 0.10 }, color = { 0.72, 0.11, 0.10 }, missing = true }
        end
        return
    end
    local itemID, spellID
    if LibStub then
        local wind = LibStub:GetLibrary("LibItemEnchant-WT", true)
        if wind then
            itemID = wind:GetEnchantItemID(enchantID)
            spellID = wind:GetEnchantSpellID(enchantID)
        end
        if not itemID and not spellID then
            local tiny = LibStub:GetLibrary("LibItemEnchant.7000", true)
            if tiny then
                itemID = tiny:GetEnchantItemID(link)
                spellID = tiny:GetEnchantSpellID(link)
            end
        end
    end
    if itemID then
        local _, itemLink = C_Item.GetItemInfo(itemID)
        return { title = "附魔", itemLink = itemLink, texture = ENCHANT_SCROLL_ICON, color = { 1, 0.82, 0.05 } }
    end
    if spellID then
        return { title = "附魔", spellID = spellID, texture = ENCHANT_SCROLL_ICON, color = { 1, 0.82, 0.05 } }
    end
    return { title = "已附魔（ID " .. enchantID .. "）", texture = ENCHANT_SCROLL_ICON, color = { 1, 0.82, 0.05 } }
end

local function ShowMarker(marker, data, x)
    marker:ClearAllPoints()
    marker:SetPoint("LEFT", marker:GetParent(), "LEFT", x, 0)
    marker.itemLink = data.itemLink
    marker.spellID = data.spellID
    marker.title = data.title
    marker.icon:SetTexture(data.texture)
    if data.isEmptySocket then
        marker.icon:SetTexCoord(0, 1, 0, 1)
    else
        marker.icon:SetTexCoord(0.18, 0.82, 0.18, 0.82)
    end
    marker.icon:SetShown(data.texture ~= nil)
    marker.text:SetText(data.text or "")
    marker.text:SetTextColor(unpack(data.textColor or { 1, 1, 1 }))
    marker.text:SetShown(data.texture == nil)
    if data.missing then
        marker.bg:SetColorTexture(0.13, 0.02, 0.02, 0.9)
    else
        marker.bg:SetColorTexture(0.04, 0.04, 0.04, 0.9)
    end
    for _, edge in ipairs(marker.edges) do
        edge:SetColorTexture(data.color[1], data.color[2], data.color[3], 0.7)
    end
    marker:Show()
end

local function HideCraftingQualityIcon(link)
    -- Crafted links can include a profession quality atlas inside the name.
    -- Keep the original link for item APIs and inventory tooltips.
    return link:gsub("%s*|A:Professions%-[^:|]*Quality%-Tier%d+:[^|]*|a", "")
end

local function GetEquippedPvPItemLevel(unit, equippedLevel)
    local tooltipFormat = _G.PVP_ITEM_LEVEL_TOOLTIP
    if not equippedLevel or equippedLevel <= 0 or type(tooltipFormat) ~= "string"
        or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return end
    local placeholder = tooltipFormat:find("%d", 1, true)
    if not placeholder then return end
    local prefix = tooltipFormat:sub(1, placeholder - 1)
    local suffix = tooltipFormat:sub(placeholder + 2)
    if prefix == "" then return end
    local baseSum, uplift = 0, 0
    local pvpLevels = {}
    local offhandEquipped = GetInventoryItemLink(unit, 17) ~= nil

    for _, slot in ipairs(slots) do
        local slotID = slot[1]
        local link = GetInventoryItemLink(unit, slotID)
        if link then
            local baseLevel = C_Item.GetDetailedItemLevelInfo(link)
            if not baseLevel then return end
            local weight = 1
            if slotID == 16 and not offhandEquipped then
                local equipLocation = select(4, C_Item.GetItemInfoInstant(link))
                if equipLocation == "INVTYPE_2HWEAPON" or equipLocation == "INVTYPE_RANGED"
                    or equipLocation == "INVTYPE_RANGEDRIGHT" then
                    weight = 2
                end
            end
            baseSum = baseSum + baseLevel * weight

            local tooltip = C_TooltipInfo.GetHyperlink(link, nil, nil, true)
            if not tooltip or not tooltip.lines then return end
            for _, line in ipairs(tooltip.lines) do
                local text = line.leftText
                local prefixStart = text and text:find(prefix, 1, true)
                if prefixStart then
                    local valueStart = prefixStart + #prefix
                    local number = text:sub(valueStart):match("^(%d+)")
                    if number and (suffix == "" or text:sub(valueStart + #number, valueStart + #number + #suffix - 1) == suffix) then
                        local pvpLevel = tonumber(number)
                        if pvpLevel then pvpLevels[slotID] = pvpLevel end
                        if pvpLevel and pvpLevel > baseLevel then
                            uplift = uplift + (pvpLevel - baseLevel) * weight
                        end
                        break
                    end
                end
            end
        end
    end

    if uplift <= 0 then return nil, pvpLevels end
    local denominator = math.floor(baseSum / equippedLevel + 0.5)
    if denominator < 15 or denominator > 17 then return nil, pvpLevels end
    return equippedLevel + uplift / denominator, pvpLevels
end

local function UpdateCharacterItemLevel(equipped, equippedPvP, alreadyCalculated)
    local statFrame = CharacterStatsPane and CharacterStatsPane.ItemLevelFrame
    if not statFrame or not statFrame.Value then return end
    if type(equipped) ~= "number" then
        equipped = select(2, GetAverageItemLevel())
    end
    if not equipped or equipped <= 0 then return end
    if not alreadyCalculated then
        equippedPvP = GetEquippedPvPItemLevel("player", equipped)
    end
    local pveText = tostring(math.floor(equipped))
    if equippedPvP and equippedPvP > equipped + 0.05 then
        statFrame.Value:SetText(pveText .. "|cff999999 | |r|cff75bfff" .. math.floor(equippedPvP) .. "|r")
    else
        statFrame.Value:SetText(pveText)
    end
end

local function UpdateClassWatermark(panel, class, color)
    local texture = panel.classWatermark
    if not class or not C_Texture or not C_Texture.GetAtlasInfo then
        texture:Hide()
        return
    end
    if panel.watermarkClass ~= class then
        local suffix = class == "DEATHKNIGHT" and "DeathKnight"
            or class == "DEMONHUNTER" and "DemonHunter"
            or (class:sub(1, 1) .. class:sub(2):lower())
        local found
        for _, atlas in ipairs({ "GarrMission_ClassIcon-" .. suffix, "classicon-" .. class:lower() }) do
            local info = C_Texture.GetAtlasInfo(atlas)
            if info and info.width and info.height and info.height > 0 then
                texture:SetAtlas(atlas)
                texture:SetSize(76 * info.width / info.height, 76)
                texture:SetDesaturated(true)
                panel.watermarkClass = class
                found = true
                break
            end
        end
        if not found then
            texture:Hide()
            return
        end
    end
    if color then
        texture:SetVertexColor(0.85 + color.r * 0.15, 0.85 + color.g * 0.15, 0.85 + color.b * 0.15)
    else
        texture:SetVertexColor(1, 1, 1)
    end
    texture:Show()
end

local function UpdateList(panel)
    if not panel then return end
    local unit = panel.unit
    if not unit or not UnitExists(unit)
        or (panel.owner == InspectFrame and UnitGUID(unit) ~= panel.guid) then
        return
    end
    local isPlayer = UnitIsUnit(unit, "player")
    local _, class = UnitClass(unit)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    UpdateClassWatermark(panel, class, classColor)
    if classColor then
        local neutral = OUTER_BORDER_NEUTRAL * (1 - OUTER_BORDER_CLASS_BLEND)
        local borderR = neutral + classColor.r * OUTER_BORDER_CLASS_BLEND
        local borderG = neutral + classColor.g * OUTER_BORDER_CLASS_BLEND
        local borderB = neutral + classColor.b * OUTER_BORDER_CLASS_BLEND
        if isPlayer then
            TintBorder(CharacterFrame and CharacterFrame.BetterGearInfoOuterBorder, borderR, borderG, borderB)
        end
        TintBorder(panel.outerBorder, borderR, borderG, borderB)
        panel.headerDivider:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.22)
        for _, row in ipairs(panel.rows) do
            if row.divider then
                row.divider:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.08)
            end
        end
    end
    local equipped
    if isPlayer then
        equipped = select(2, GetAverageItemLevel())
    else
        equipped = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
            and C_PaperDollInfo.GetInspectItemLevel(unit)
    end
    local pvpLevels
    if equipped and equipped > 0 then
        local equippedPvP
        equippedPvP, pvpLevels = GetEquippedPvPItemLevel(unit, equipped)
        if isPlayer then
            UpdateCharacterItemLevel(equipped, equippedPvP, true)
        end
    end

    local enchanted, enchantTotal, gemmed, socketTotal = 0, 0, 0, 0
    local setCounts = {}
    local gemsPending, setsPending, inventoryPending = false, false, false
    for index, info in ipairs(slots) do
        local row = panel.rows[index]
        local link = GetInventoryItemLink(unit, info[1])
        if link then
            local itemInfo = { C_Item.GetItemInfo(link) }
            local quality, setID = itemInfo[3], itemInfo[16]
            if not itemInfo[1] then
                gemsPending, setsPending = true, true
            end
            if enchantableSlots[info[1]] then
                enchantTotal = enchantTotal + 1
                if (tonumber(link:match("item:%d+:(%d+)")) or 0) > 0 then
                    enchanted = enchanted + 1
                end
            end
            if setID and setID > 0 then
                local eligible = IsFourPieceSet(setID, link)
                if eligible then
                    setCounts[setID] = (setCounts[setID] or 0) + 1
                elseif eligible == nil then
                    setsPending = true
                end
            end
            local r, g, b = C_Item.GetItemQualityColor(quality or 1)
            local characterSlot = isPlayer and _G[slotButtons[info[1]]]
            if characterSlot and characterSlot.BetterGearInfoBorder then
                for _, edge in ipairs(characterSlot.BetterGearInfoBorder) do
                    edge:SetColorTexture(r, g, b, 1)
                end
            end
            row.name:SetText(HideCraftingQualityIcon(link))
            row.name:SetTextColor(1, 1, 1)
            local level = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
            local pvpLevel = pvpLevels and pvpLevels[info[1]]
            local shownLevel = pvpLevel or level
            row.level:SetText(shownLevel and tostring(shownLevel) or "")
            if pvpLevel then
                row.level:SetTextColor(0.73, 0.85, 1.00, 0.90)
            else
                row.level:SetTextColor(1, 1, 1, 1)
            end
            local stats = C_Item.GetItemStats(link) or {}
            for badgeIndex, badgeInfo in ipairs(statBadges) do
                UpdateBadge(row.badges[badgeIndex], badgeInfo, stats[badgeInfo.key] ~= nil)
            end
            local markers, filled, total = GetGemMarkers(link, stats)
            gemmed, socketTotal = gemmed + filled, socketTotal + total
            local enchant = GetEnchantMarker(link, info[1])
            if enchant then markers[#markers + 1] = enchant end
            local count = math.min(#markers, #row.markers)
            row.name:SetWidth(0)
            local nameWidth = math.min(row.name:GetStringWidth(), 208)
            local availableWidth = row:GetWidth() - NAME_LEFT - (count > 0 and (count * MARKER_STEP + 5) or 4)
            row.name:SetWidth(math.max(60, math.min(nameWidth, availableWidth)))
            local markerX = NAME_LEFT + row.name:GetWidth() + 5
            for markerIndex, marker in ipairs(row.markers) do
                if markerIndex <= count and markers[markerIndex] then
                    ShowMarker(marker, markers[markerIndex], markerX + (markerIndex - 1) * MARKER_STEP)
                else
                    marker:Hide()
                end
            end
        else
            if GetInventoryItemTexture(unit, info[1]) then inventoryPending = true end
            local characterSlot = isPlayer and _G[slotButtons[info[1]]]
            if characterSlot and characterSlot.BetterGearInfoBorder then
                for _, edge in ipairs(characterSlot.BetterGearInfoBorder) do
                    edge:SetColorTexture(0.16, 0.16, 0.16, 1)
                end
            end
            row.name:SetText(info[2])
            row.name:SetTextColor(unpack(MUTED))
            row.level:SetText("")
            for _, marker in ipairs(row.markers) do marker:Hide() end
            for badgeIndex, badgeInfo in ipairs(statBadges) do
                UpdateBadge(row.badges[badgeIndex], badgeInfo, false)
            end
        end
    end
    local setPieces = 0
    for _, count in pairs(setCounts) do setPieces = math.max(setPieces, count) end
    panel.headerStatus:SetText(
        FormatProgress("附魔", enchanted, enchantTotal, inventoryPending)
        .. "  " .. FormatProgress("宝石", gemmed, socketTotal, gemsPending or inventoryPending)
        .. "  " .. FormatProgress("套装", math.min(setPieces, 4), 4, setsPending or inventoryPending)
    )
end

local function QueueUpdate(panel)
    if not panel or panel.updateQueued or not panel.owner:IsShown() then return end
    panel.updateQueued = true
    C_Timer.After(0.05, function()
        panel.updateQueued = false
        if not panel.owner:IsShown() or not panel:IsShown() then return end
        SuppressDuplicateGearList(panel)
        UpdateList(panel)
    end)
end

local function ShowListFor(panel, unit)
    if not panel or not unit then return false end
    if panel.owner == CharacterFrame and (not PaperDollFrame or not PaperDollFrame:IsShown()) then
        panel:Hide()
        return false
    end
    local guid = UnitGUID(unit)
    if panel.unit ~= unit or panel.guid ~= guid then
        panel.classWatermark:Hide()
        panel.headerStatus:SetText("附魔:--/--  宝石:--/--  套装:--/4")
        for index, row in ipairs(panel.rows) do
            row.name:SetText(slots[index][2])
            row.name:SetTextColor(unpack(MUTED))
            row.level:SetText("")
            for _, marker in ipairs(row.markers) do marker:Hide() end
            for badgeIndex, badgeInfo in ipairs(statBadges) do
                UpdateBadge(row.badges[badgeIndex], badgeInfo, false)
            end
        end
    end
    panel.unit = unit
    panel.guid = guid
    panel:SetFrameStrata(panel.owner:GetFrameStrata())
    panel:SetFrameLevel(panel.owner:GetFrameLevel() + 1)
    PositionList(panel)
    panel:Show()
    QueueUpdate(panel)
    return true
end

local function HookInspectFrame()
    if inspectHooked or not InspectFrame or not listPanel then return end
    if not inspectPanel then
        local ok, result = pcall(CreateList, InspectFrame, "InspectGearList")
        if not ok then
            initializationError = "创建观察清单失败: " .. tostring(result)
            print(addonName .. ": " .. initializationError)
            return
        end
        inspectPanel = result
    end
    inspectHooked = true
    InspectFrame:HookScript("OnShow", function(self)
        ShowListFor(inspectPanel, self.unit or INSPECTED_UNIT)
        C_Timer.After(0, function() SuppressDuplicateGearList(inspectPanel) end)
    end)
    InspectFrame:HookScript("OnHide", function()
        inspectPanel:Hide()
    end)
    InspectFrame:HookScript("OnSizeChanged", function()
        PositionList(inspectPanel)
    end)
    if InspectFrame:IsShown() then ShowListFor(inspectPanel, InspectFrame.unit or INSPECTED_UNIT) end
end

local function Initialize()
    if not CharacterFrame then return end
    if InCombatLockdown() then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not listPanel then
        local ok, result = pcall(CreateList, CharacterFrame, "GearList")
        if not ok then
            initializationError = "创建装备清单失败: " .. tostring(result)
            print(addonName .. ": " .. initializationError)
            return
        end
        listPanel = result
    end
    if not initialized then
        initialized = true
        CharacterFrame:HookScript("OnShow", function()
            ShowListFor(listPanel, "player")
            C_Timer.After(0, function() SuppressDuplicateGearList(listPanel) end)
            C_Timer.After(0, UpdateStatRows)
            C_Timer.After(0, TrySkinSidebarTabs)
        end)
        CharacterFrame:HookScript("OnSizeChanged", function()
            PositionList(listPanel)
        end)
    end
    if PaperDollFrame and not paperDollHooksInstalled then
        paperDollHooksInstalled = true
        PaperDollFrame:HookScript("OnShow", function()
            if CharacterFrame:IsShown() then ShowListFor(listPanel, "player") end
        end)
        PaperDollFrame:HookScript("OnHide", function()
            if listPanel then listPanel:Hide() end
        end)
    end
    HookInspectFrame()
    if not skinAttempted and PaperDollFrame and PaperDollItemsFrame and CharacterModelScene and CharacterStatsPane then
        skinAttempted = true
        local ok, err = pcall(SkinCharacterFrame)
        if not ok then
            initializationError = "角色栏皮肤失败: " .. tostring(err)
            print(addonName .. ": " .. initializationError)
        end
    end
    if not itemLevelHooked and type(PaperDollFrame_UpdateStats) == "function" then
        hooksecurefunc("PaperDollFrame_UpdateStats", function()
            UpdateCharacterItemLevel()
        end)
        itemLevelHooked = true
        UpdateCharacterItemLevel()
    end
    TrySkinSidebarTabs()
    ShowListFor(listPanel, "player")
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        Initialize()
    elseif event == "INSPECT_READY" then
        C_Timer.After(0, function()
            local unit = InspectFrame and (InspectFrame.unit or INSPECTED_UNIT)
            if InspectFrame and InspectFrame:IsShown() and unit
                and UnitGUID(unit) == arg1 then
                Initialize()
                if inspectPanel then
                    if not inspectPanel.unit or inspectPanel.guid ~= UnitGUID(unit) then
                        ShowListFor(inspectPanel, unit)
                    elseif inspectPanel:IsShown() then
                        QueueUpdate(inspectPanel)
                    end
                end
            end
        end)
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_MODEL_CHANGED" then
        if arg1 == "player" then QueueUpdate(listPanel) end
        if inspectPanel and arg1 == inspectPanel.unit then QueueUpdate(inspectPanel) end
    else
        QueueUpdate(listPanel)
        QueueUpdate(inspectPanel)
    end
end)

SLASH_BETTERGEARINFO1 = "/bgi"
SLASH_BETTERGEARINFO2 = "/bettergearinfo"
SlashCmdList.BETTERGEARINFO = function(message)
    Initialize()
    if message == "status" then
        local ready = PaperDollFrame and PaperDollFrame.BetterGearInfoSidebarHolder ~= nil
        print(addonName .. " " .. addonVersion .. ": 原生切换按钮=" .. (ready and "已调整" or "未就绪")
            .. "，角色栏皮肤=" .. (initializationError or "正常")
            .. "，切换按钮错误=" .. (sidebarSkinError or "无")
            .. "，关闭按钮错误=" .. (closeButtonError or "无"))
        return
    end
    local shown = false
    if listPanel and CharacterFrame:IsShown() and ShowListFor(listPanel, "player") then
        UpdateList(listPanel)
        shown = true
    end
    if inspectPanel and InspectFrame:IsShown() then
        local unit = InspectFrame.unit or INSPECTED_UNIT
        if ShowListFor(inspectPanel, unit) then
            UpdateList(inspectPanel)
            shown = true
        end
    end
    print(addonName .. ": " .. (shown and "装备清单已显示。"
        or initializationError or "请先打开角色栏或观察窗口。"))
end
