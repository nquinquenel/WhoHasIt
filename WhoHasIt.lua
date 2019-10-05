-- Main Frame
local checkGear = CreateFrame("Frame")
checkGear.width = 200
checkGear.height = 300
checkGear:SetFrameStrata("FULLSCREEN_DIALOG")
checkGear:SetSize(checkGear.width, checkGear.height)
checkGear:SetPoint("CENTER",0,0)
checkGear:SetMovable(true)
checkGear:SetResizable(true)
checkGear:EnableMouse(true)
checkGear:EnableMouseWheel(true)
checkGear:RegisterForDrag("LeftButton")
checkGear:SetScript("OnDragStart", checkGear.StartMoving)
checkGear:SetScript("OnDragStop", checkGear.StopMovingOrSizing)
checkGear:SetMinResize(150,125)

checkGear:SetBackdrop({
	bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile     = true,
	tileSize = 32,
	edgeSize = 32,
	insets   = { left = 8, right = 8, top = 8, bottom = 8 }
})
checkGear:SetBackdropColor(0, 0, 0, 1)

local resizeButton = CreateFrame("Button", nil, checkGear)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT")
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeButton:SetScript("OnMouseDown", function(self, button)
    checkGear:StartSizing("BOTTOMRIGHT")
    checkGear:SetUserPlaced(true)
end)
 
resizeButton:SetScript("OnMouseUp", function(self, button)
    checkGear:StopMovingOrSizing()
end)

tinsert(UISpecialFrames, "AnimorHistoryFrame")

-- Stuff Frame
local messageFrame = CreateFrame("ScrollingMessageFrame", nil, checkGear)
messageFrame:SetPoint("LEFT", 20, 0)
messageFrame:SetSize(checkGear.width - 60, checkGear.height - 50)
messageFrame:SetFontObject(GameFontNormal)
messageFrame:SetTextColor(1, 1, 1, 1)
messageFrame:SetJustifyH("LEFT")
messageFrame:SetHyperlinksEnabled(true)
messageFrame:SetFading(false)
messageFrame:SetMaxLines(300)
checkGear.messageFrame = messageFrame

-- Scrollbar Frame
local scrollBar = CreateFrame("Slider", nil, checkGear, "UIPanelScrollBarTemplate")
scrollBar:SetPoint("RIGHT", checkGear, "RIGHT", -10, 10)
scrollBar:SetSize(30, checkGear.height - 90)
scrollBar:SetMinMaxValues(0, 9)
scrollBar:SetValueStep(1)
scrollBar.scrollStep = 1
checkGear.scrollBar = scrollBar

scrollBar:SetScript("OnValueChanged", function(self, value)
	messageFrame:SetScrollOffset(select(2, scrollBar:GetMinMaxValues()) - value)
end)

scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))

checkGear:SetScript("OnMouseWheel", function(self, delta)
	local cur_val = scrollBar:GetValue()
	local min_val, max_val = scrollBar:GetMinMaxValues()

	if delta < 0 and cur_val < max_val then
		cur_val = math.min(max_val, cur_val + 1)
		scrollBar:SetValue(cur_val)
	elseif delta > 0 and cur_val > min_val then
		cur_val = math.max(min_val, cur_val - 1)
		scrollBar:SetValue(cur_val)
	end
end)

checkGear:SetScript("OnSizeChanged", function(_, w, h) 
    messageFrame:SetSize(w - 60, h - 50)
    scrollBar:SetHeight(h - 90) 
end)

-- Exit Button
local b = CreateFrame("Button", "MyButton", checkGear, "UIPanelButtonTemplate")
b:SetSize(80 ,22)
b:SetText("Quitter")
b:SetPoint("BOTTOM")
b:SetScript("OnClick", function()
    checkGear:Hide()
end)

checkGear:Show()

checkGear:RegisterEvent("LOOT_OPENED");
checkGear:RegisterEvent("AUTOFOLLOW_BEGIN");
checkGear:RegisterEvent("GROUP_ROSTER_UPDATE")

checkGear.known = {}
local found = false

checkGear:SetScript("OnEvent", function(self, event, ...)
    if event=="INSPECT_READY" then
        checkGear:InspectReady()
    elseif event=="GROUP_ROSTER_UPDATE" then
        checkGear:InspectNextUnit()
    elseif event=="LOOT_OPENED" then
        partySize = GetNumGroupMembers();

        if partySize > 1 then
            for i = 1, GetNumLootItems() do
                if LootSlotHasItem(i) then
                    local itemName2, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                    itemEquipLoc, itemIcon, itemSellPrice, itemClassID = GetItemInfo(GetLootSlotLink(i));
                    if (itemRarity > 1) and (itemClassID == (2 or 4))  then
                        messageFrame:AddMessage("\n" .. itemName2)
                        for k, v in pairs(checkGear.known) do
                            for j = 1, 17 do
                                if v[j]==itemName2 then
                                    found = true
                                    break
                                end
                            end

                            if found then
                                messageFrame:AddMessage(k .. " : Yes")
                            else
                                messageFrame:AddMessage(k .. " : No")
                            end
                            found = false
                        end
                        checkGear:Show();
                    end
                end
            end
        end
    end
end)

local function dostuff(unit,name)
    for i=1, 17 do
       itemName = GetItemInfo(GetInventoryItemID(unit,i))
       checkGear.known[name][i] = itemName
    end
end

function checkGear:InspectNextUnit()
    if IsInGroup() then
        local inRaid = IsInRaid()
        local oor = false
        for i=1,GetNumGroupMembers() do
            local unit = inRaid and "raid"..i or i==1 and "player" or "party"..(i-1)
            local name = GetUnitName(unit,true)
            if ((checkGear.known[name] == nil) or (not checkGear.known[name])) then
                if CheckInteractDistance(unit,1) then
                    checkGear.unit = unit
                    checkGear.name = name
                    checkGear.known[name] = {}
                    NotifyInspect(unit)
                    checkGear:RegisterEvent("INSPECT_READY")
                    return
                else
                     oor = true
                end
            end
            
        end
        if oor then
            checkGear.timer = 3
            checkGear:SetScript("OnUpdate",checkGear.WaitForOOR)
            return
        end
    end
end

function checkGear:WaitForOOR(elapsed)
    self.timer = self.timer - elapsed
    if self.timer < 0 then
        self.timer = 0
        self:SetScript("OnUpdate",nil)
        self:InspectNextUnit()
    end
end

function checkGear:InspectReady()
    checkGear:UnregisterEvent("INSPECT_READY")
    checkGear:SetScript("OnUpdate",nil)
    local unit = checkGear.unit
    local missing
    for i=1,17 do   
        if GetInventoryItemID(unit,i) and not GetInventoryItemLink(unit,i) then
            missing = true
        end
    end

    if missing then
        checkGear:SetScript("OnUpdate",checkGear.InspectReady)
        return
    end

    -- Show scanned players
    messageFrame:AddMessage("\n" .. checkGear.name)
    dostuff(unit,checkGear.name)
    checkGear:InspectNextUnit()
end