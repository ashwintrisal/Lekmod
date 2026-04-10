-- Lekmod: City-state tribute range hover display
-- When the mouse hovers over a city-state city tile, highlights all plots
-- within tribute range (5 tiles) using the same border style as the
-- bomber air-strike range preview.

local TRIBUTE_RANGE = 5;
local rangeColor    = Vector4(0.7, 0, 0, 1);   -- same red used by air-strike range
local rangeStyle    = "FireRangeBorder";

local g_lastCSPlayerID = -1;  -- track to avoid redrawing on same CS every frame

local function ClearTributeRange()
    if g_lastCSPlayerID ~= -1 then
        g_lastCSPlayerID = -1;
        Events.ClearHexHighlightStyle(rangeStyle);
    end
end

local function ShowTributeRange(cityX, cityY)
    Events.ClearHexHighlightStyle(rangeStyle);
    for iDX = -TRIBUTE_RANGE, TRIBUTE_RANGE do
        for iDY = -TRIBUTE_RANGE, TRIBUTE_RANGE do
            local pPlot = Map.GetPlotXY(cityX, cityY, iDX, iDY);
            if pPlot ~= nil then
                local pX = pPlot:GetX();
                local pY = pPlot:GetY();
                if Map.PlotDistance(cityX, cityY, pX, pY) <= TRIBUTE_RANGE then
                    local hexID = ToHexFromGrid(Vector2(pX, pY));
                    Events.SerialEventHexHighlight(hexID, true, rangeColor, rangeStyle);
                end
            end
        end
    end
end

function OnMouseMoveHex_TributeRange(hexX, hexY)
    -- Only show in normal selection mode
    local interfaceMode = UI.GetInterfaceMode();
    if interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_SELECTION then
        ClearTributeRange();
        return;
    end

    local gridX, gridY = ToGridFromHex(hexX, hexY);
    local pPlot = Map.GetPlot(gridX, gridY);
    if pPlot == nil then
        ClearTributeRange();
        return;
    end

    local pCity = pPlot:GetPlotCity();
    if pCity == nil then
        ClearTributeRange();
        return;
    end

    local iOwner = pCity:GetOwner();
    if iOwner < 0 or not Players[iOwner]:IsMinorCiv() then
        ClearTributeRange();
        return;
    end

    -- Hovering over a city-state city tile
    if g_lastCSPlayerID ~= iOwner then
        g_lastCSPlayerID = iOwner;
        ShowTributeRange(pCity:GetX(), pCity:GetY());
    end
end

Events.SerialEventMouseOverHex.Add(OnMouseMoveHex_TributeRange);
