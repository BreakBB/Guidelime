local addonName, addon = ...
local L = addon.L

HBD = LibStub("HereBeDragons-2.0")
HBDPins = LibStub("HereBeDragons-Pins-2.0")

addon.MAX_MAP_INDEX = 59
addon.SPECIAL_MAP_INDEX = {monster = 60, item = 61, object = 62, npc = 63, LOC = 63}
addon.mapIcons = {}


local function createIconFrame(t, index)
    local f = CreateFrame("Button")
    f.texture = f:CreateTexture(nil, "TOOLTIP")
	addon.setMapIconTexture(f, t)
	if t ~= "GOTO" then
		index = addon.SPECIAL_MAP_INDEX[t]
	elseif index > addon.MAX_MAP_INDEX then
		index = addon.SPECIAL_MAP_INDEX.LOC
	end
	f.texture:SetTexCoord((index % 8) / 8, (index % 8 + 1) / 8, math.floor(index / 8) / 8, (math.floor(index / 8) + 1) / 8)
	-- dont mess with my icon
	f.texture.SetTexCoord = function() end
	f.texture.SetBackdrop = function() end
	f.texture.SetBackdropColor = function() end
	f.texture.SetBackdropBorderColor = function() end
	f.SetTexCoord = function() end
	f.SetBackdrop = function() end
	f.SetBackdropColor = function() end
	f.SetBackdropBorderColor = function() end
	f.isSkinned = true
	
    f.texture:SetAllPoints(f)
	local frameLevel, layer = 7 - index, "OVERLAY"
	if frameLevel < -8 then frameLevel = frameLevel + 16; layer = "ARTWORK" end
	if frameLevel < -8 then frameLevel = frameLevel + 16; layer = "BORDER" end
	if frameLevel < -8 then frameLevel = frameLevel + 16; layer = "BACKGROUND" end
	if frameLevel < -8 then frameLevel = -8 end
	f.texture:SetDrawLayer(layer, frameLevel)

    f:SetPoint("CENTER", 0, 0)
    f:EnableMouse(false)
	f:SetScript("OnEnter", function(self) 
		if self.tooltip ~= nil and self.tooltip ~= "" then 
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT",0,-32)
			GameTooltip:SetText(self.tooltip); GameTooltip:Show()
			addon.showingTooltip = true 
		end 
	end)
	f:SetScript("OnLeave", function(self) 
		if self.tooltip ~= nil and self.tooltip ~= "" and addon.showingTooltip then 
			GameTooltip:Hide()
			addon.showingTooltip = false 
		end 
	end)

    function f:Unload()
        HBDPins:RemoveMinimapIcon(addon, self);
        HBDPins:RemoveWorldMapIcon(addon, self);
        if(self.texture) then
            self.texture:SetVertexColor(1, 1, 1, 1);
        end
        self.miniMapIcon = nil;
		self:SetScript("OnUpdate", nil)
        self:Hide();
    end
    f:Hide()
    return f
end

function addon.setMapIconTexture(f, t)
	if t ~= "GOTO" then t = "LOC" end
    f.texture:SetTexture(addon.icons["MAP_MARKER_" .. GuidelimeData["mapMarkerStyle" .. t]])
	f.texture:SetAlpha(GuidelimeData["mapMarkerAlpha" .. t])
    f.texture:SetWidth(GuidelimeData["mapMarkerSize" .. t])
    f.texture:SetHeight(GuidelimeData["mapMarkerSize" .. t])
    f:SetWidth(GuidelimeData["mapMarkerSize" .. t])
    f:SetHeight(GuidelimeData["mapMarkerSize" .. t])
end

function addon.setMapIconTextures()
	for t, icons in pairs(addon.mapIcons) do
		for i = 0, #icons do
			if icons[i] ~= nil then
				addon.setMapIconTexture(icons[i].map, t)
				addon.setMapIconTexture(icons[i].minimap, t)
			end
		end
	end
end

local function createMapIcon(t, i)
	if i == nil then
		i = #addon.mapIcons[t] + 1
	end
	addon.mapIcons[t][i] = {}
	addon.mapIcons[t][i].map = createIconFrame(t, i)
	addon.mapIcons[t][i].minimap = createIconFrame(t, i)
	addon.mapIcons[t][i].index = i
	addon.mapIcons[t][i].inUse = false
	return addon.mapIcons[t][i]
end

local function getMapIcon(t, element, highlight)
	if addon.mapIcons[t] == nil then addon.mapIcons[t] = {} end
	if highlight then 
		if addon.mapIcons[t][0] == nil then createMapIcon(t, 0) end
		return addon.mapIcons[t][0] 
	end
	if addon.mapIcons[t] ~= nil then
		for i, mapIcon in ipairs(addon.mapIcons[t]) do
			if mapIcon.inUse then 
				if mapIcon.mapID == element.mapID and mapIcon.x == element.x and mapIcon.y == element.y then
					return mapIcon
				end
			else
				return mapIcon
			end
		end
	end
	return createMapIcon(t)		
end

local function getTooltip(element)
	if not GuidelimeData.showTooltips then return end
	local tooltip
	if element and element.attached and element.attached.questId then 
		tooltip = addon.getQuestIcon(element.attached.questId, element.attached.t, element.attached.objective) .. 
			addon.getQuestText(element.attached.questId, element.attached.t, nil, element.step and element.step.active) 
		if element.attached.t ~= "ACCEPT" then
			local objectives
			if element.attached.t == "TURNIN" then
				objectives = true
			elseif element.attached.objective ~= nil then
				objectives = {element.attached.objective}
			elseif element.objectives ~= nil then
				objectives = element.objectives
			else
				objectives = true
			end
			local obj = addon.getQuestObjectiveText(element.attached.questId, objectives, "    ", element.npcId, element.objectId)
			if obj ~= "" then tooltip = tooltip .. "\n" .. obj end
		end
	end
	if tooltip == nil and element and element.step ~= nil then tooltip = addon.getStepText(element.step) end
	if element and element.estimate then if tooltip == nil then tooltip = L.ESTIMATE else tooltip = tooltip .. "\n" .. L.ESTIMATE end end
	return tooltip
end

function addon.addMapIcon(element, highlight, ignoreMaxNumOfMarkers)
	if element.x == nil or element.y == nil or element.mapID == nil then return end	
	local mapIcon = getMapIcon(element.markerTyp or element.t, element, highlight)
	if mapIcon == nil then return end
	if not ignoreMaxNumOfMarkers then
		if element.t == "GOTO" and mapIcon.index >= GuidelimeData.maxNumOfMarkersGOTO and GuidelimeData.maxNumOfMarkersGOTO > 0 then return end
		if not element.step.active and element.t ~= "GOTO" then return end
	end
	mapIcon.mapID = element.mapID
	mapIcon.x = element.x
	mapIcon.y = element.y
	local tooltip = getTooltip(element)
	if not mapIcon.inUse then
		mapIcon.map.tooltip = tooltip
		mapIcon.minimap.tooltip = tooltip
	elseif tooltip ~= nil then
		mapIcon.map.tooltip = (mapIcon.map.tooltip or "") .. "\n" .. tooltip
		mapIcon.minimap.tooltip = (mapIcon.minimap.tooltip or "") .. "\n" .. tooltip
	end
	mapIcon.inUse = true
	element.mapIndex = mapIcon.index
	--if addon.debugging then print("LIME : addMapIcon", element.mapID, element.x / 100, element.y / 100, highlight) end
end

function addon.removeMapIcons()
	HBDPins:RemoveAllWorldMapIcons(addon)
	HBDPins:RemoveAllMinimapIcons(addon)
	for _, icons in pairs(addon.mapIcons) do
		for i, mapIcon in pairs(icons) do
			mapIcon.inUse = false
		end
	end
	for i, step in ipairs(addon.currentGuide.steps) do
		for j, element in ipairs(step.elements) do
			element.mapIndex = nil
		end
	end
end

local function showMapIcon(mapIcon, t)
	if mapIcon ~= nil and mapIcon.inUse then
		if t ~= "GOTO" then t = "LOC" end
		if GuidelimeData["showMapMarkers" .. t] then HBDPins:AddWorldMapIconMap(addon, mapIcon.map, mapIcon.mapID, mapIcon.x / 100, mapIcon.y / 100, 3) end
		if GuidelimeData["showMinimapMarkers" .. t] then HBDPins:AddMinimapIconMap(addon, mapIcon.minimap, mapIcon.mapID, mapIcon.x / 100, mapIcon.y / 100, true, mapIcon.index == 0) end
	end
end

function addon.showMapIcons()
	for t, icons in pairs(addon.mapIcons) do
		for i = #icons, 0, -1 do
			showMapIcon(icons[i], t)
		end
	end
	if addon.updateFrame == nil then
		addon.updateFrame = CreateFrame("frame")
		addon.updateFrame:SetScript("OnUpdate", addon.updateArrow)
	end
	if addon.arrowFrame == nil then
		addon.arrowFrame = CreateFrame("FRAME", nil, UIParent)
		addon.arrowFrame:SetPoint(GuidelimeDataChar.arrowRelative, UIParent, GuidelimeDataChar.arrowRelative, GuidelimeDataChar.arrowX, GuidelimeDataChar.arrowY)
	    addon.arrowFrame.texture = addon.arrowFrame:CreateTexture(nil, "OVERLAY")
	    addon.setArrowTexture()
	    addon.arrowFrame.texture:SetAllPoints()
		addon.arrowFrame:SetAlpha(GuidelimeDataChar.arrowAlpha)
		addon.arrowFrame:SetWidth(GuidelimeDataChar.arrowSize)
		addon.arrowFrame:SetHeight(GuidelimeDataChar.arrowSize)
		addon.arrowFrame:SetMovable(true)
		addon.arrowFrame:EnableMouse(true)
		addon.arrowFrame:SetScript("OnMouseDown", function(this) 
			if not GuidelimeDataChar.arrowLocked then addon.arrowFrame:StartMoving() end
		end)
		addon.arrowFrame:SetScript("OnMouseUp", function(this) 
			addon.arrowFrame:StopMovingOrSizing() 
			local _
			_, _, GuidelimeDataChar.arrowRelative, GuidelimeDataChar.arrowX, GuidelimeDataChar.arrowY = addon.arrowFrame:GetPoint()
		end)
		addon.arrowFrame.text = addon.arrowFrame:CreateFontString(nil, addon.arrowFrame, "GameFontNormal")
		addon.arrowFrame.text:SetPoint("TOP", addon.arrowFrame, "BOTTOM", 0, 0)
		addon.arrowFrame:SetScript("OnEnter", function(self) 
			if addon.isAlive() then
				self.tooltip = getTooltip(self.element)
			else
				self.tooltip = L.ARROW_TOOLTIP_CORPSE
			end
			if self.tooltip ~= nil and self.tooltip ~= "" then 
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT",0,-32)
				GameTooltip:SetText(self.tooltip)
				GameTooltip:Show()
				addon.showingTooltip = true 
			end 
		end)
		addon.arrowFrame:SetScript("OnLeave", function(self) 
			if self.tooltip ~= nil and self.tooltip ~= "" and addon.showingTooltip then 
				GameTooltip:Hide()
				addon.showingTooltip = false 
			end 
		end)
	end
end

function addon.getMapMarkerText(element)
	local index = element.mapIndex
	if element.t ~= "GOTO" then
		index = addon.SPECIAL_MAP_INDEX[element.markerTyp or element.t]
	elseif index > addon.MAX_MAP_INDEX then
		index = addon.SPECIAL_MAP_INDEX.LOC
	end
	local t = element.t
	if t ~= "GOTO" then t = "LOC" end
	return "|T" .. addon.icons["MAP_MARKER_" .. GuidelimeData["mapMarkerStyle" .. t]] .. ":15:15:0:1:512:512:" .. 
		index % 8 * 64 .. ":" .. (index % 8 + 1) * 64 .. ":" .. 
		math.floor(index / 8) * 64 .. ":" .. (math.floor(index / 8) + 1) * 64 .. ":::|t"
end

function addon.setArrowTexture()
	if GuidelimeData.arrowStyle == 1 then
		addon.arrowFrame.texture:SetTexture(addon.icons.MAP_LIME_ARROW)
		addon.arrowFrame.texture:SetVertexColor(1,1,1)
	elseif GuidelimeData.arrowStyle == 2 then
		addon.arrowFrame.texture:SetTexture(addon.icons.MAP_ARROW)
		addon.arrowFrame.texture:SetVertexColor(0.5,1,0.2)
	end
	addon.arrowFrame:SetWidth(GuidelimeDataChar.arrowSize)
	addon.arrowFrame:SetHeight(GuidelimeDataChar.arrowSize)
end

function addon.getArrowIconText()
	local col, row = 0, 0
	if addon.arrowFrame ~= nil and addon.arrowFrame.col ~= nil then col = addon.arrowFrame.col end
	if addon.arrowFrame ~= nil and addon.arrowFrame.row ~= nil then row = addon.arrowFrame.row end
	if GuidelimeData.arrowStyle == 1 then
		return "|T" .. addon.icons.MAP_LIME_ARROW .. ":15:15:0:1:512:512:" .. 
			col * 64 .. ":" .. (col + 1) * 64 .. ":" .. 
			row * 64 .. ":" .. (row + 1) * 64 .. ":::|t"
	elseif GuidelimeData.arrowStyle == 2 then
		return "|T" .. addon.icons.MAP_ARROW .. ":15:15:0:1:512:512:" .. 
			col * 56 .. ":" .. (col + 1) * 56 .. ":" .. 
			row * 42 .. ":" .. (row + 1) * 42 .. ":127:255:51|t"
	end
end

function addon.updateArrow()
	addon.x, addon.y, addon.instance = HBD:GetPlayerWorldPosition()
	addon.face = GetPlayerFacing()
	if addon.x == nil or addon.y == nil or addon.face == nil then return end
	
	if addon.arrowFrame == nil or addon.x == nil or addon.y == nil then return end
	
	addon.arrowX, addon.arrowY = nil, nil
	if GuidelimeDataChar.showArrow then
		if not addon.isAlive() then
			local corpse = HBD:GetPlayerZone() and C_DeathInfo.GetCorpseMapPosition(HBD:GetPlayerZone())
			if corpse ~= nil then
				addon.arrowX, addon.arrowY = HBD:GetWorldCoordinatesFromZone(corpse.x, corpse.y, HBD:GetPlayerZone())
			end
		elseif addon.arrowFrame.element ~= nil and addon.arrowFrame.element.wx ~= nil and addon.arrowFrame.element.wy ~= nil and addon.arrowFrame.element.instance == addon.instance then
			addon.arrowX, addon.arrowY = addon.arrowFrame.element.wx, addon.arrowFrame.element.wy
		end
	end
	
	if addon.arrowX == nil or addon.arrowY == nil then 
		if addon.arrowFrame:IsShown() then addon.arrowFrame:Hide() end
		return 
	end
	local angle = addon.face - math.atan2(addon.arrowX - addon.x, addon.arrowY - addon.y)
	if GuidelimeData.arrowStyle == 1 then
		local index = angle * 32 / math.pi
		if index >= 64 then index = index - 64 elseif index < 0 then index = index + 64 end
		addon.arrowFrame.col = math.floor(index % 8)
		addon.arrowFrame.row = math.floor(index / 8)
		addon.arrowFrame.texture:SetTexCoord(addon.arrowFrame.col / 8, (addon.arrowFrame.col + 1) / 8, addon.arrowFrame.row / 8, (addon.arrowFrame.row + 1) / 8)
	elseif GuidelimeData.arrowStyle == 2 then
		local index = -angle * 54 / math.pi
		if index < 0 then index = index + 108 end
		if index < 0 then index = index + 108 end
		addon.arrowFrame.col = math.floor(index % 9)
		addon.arrowFrame.row = math.floor(index / 9)
		addon.arrowFrame.texture:SetTexCoord(addon.arrowFrame.col * 56 / 512, (addon.arrowFrame.col + 1) * 56 / 512, addon.arrowFrame.row * 42 / 512, (addon.arrowFrame.row + 1) * 42 / 512)
	end
	local dist2 = (addon.x - addon.arrowX) * (addon.x - addon.arrowX) + (addon.y - addon.arrowY) * (addon.y - addon.arrowY)
	if addon.arrowFrame.element and addon.arrowFrame.element.radius and addon.lastDistance2 then
		local radius2 = addon.arrowFrame.element.radius * addon.arrowFrame.element.radius
		if (dist2 < radius2 and addon.lastDistance2 >= radius2) or (dist2 >= radius2 * addon.GOTO_HYSTERESIS_FACTOR and addon.lastDistance2 <= radius2 * addon.GOTO_HYSTERESIS_FACTOR) then
			if addon.debugging then print("LIME: position reached/left") end
			addon.updateSteps()
		end
	end
	addon.lastDistance2 = dist2
	if GuidelimeData.arrowDistance then
	 	local dist = math.floor(math.sqrt(dist2))
		addon.arrowFrame.text:SetText(dist .. " " .. L.YARDS)
		addon.arrowFrame.text:Show()
	else
		addon.arrowFrame.text:Hide()
	end
	if addon.arrowFrame.element and addon.arrowFrame.element.step then 
		addon.updateStepText(addon.arrowFrame.element.step.index) 
	end
	if not addon.arrowFrame:IsShown() then addon.arrowFrame:Show() end
end

function addon.showArrow(element)
	if addon.arrowFrame ~= nil then
		addon.arrowFrame.element = element 
	end
end

function addon.hideArrow()
	if addon.arrowFrame ~= nil then 
		addon.arrowFrame.element = nil
	end
end
