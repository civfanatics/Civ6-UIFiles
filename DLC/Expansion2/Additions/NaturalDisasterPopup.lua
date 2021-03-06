-- Copyright 2018-2019, Firaxis Games
-- Popup for Natural Disasters (aka: Random events)

include("PopupManager");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID		:string = "NaturalDisasterPopup";
local NUCLEAR_OPERATOR_TYPE	:string = "NUCLEAR_ACCIDENT";


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kPopupMgr		:table	 = ExclusivePopupManager:new("NaturalDisasterPopup");
local m_kQueuedPopups	:table = {};
local m_kCurrentPopup	:table = nil;

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_AffectedPlots = nil;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--	Natural wonders can be multiple hexes, and require their own code to find all affected hexes
-- ===========================================================================
function GetAffectedPlots_NaturalWonder(plotx:number, ploty:number)
	local pPlot = Map.GetPlot(plotx, ploty);
	if (pPlot ~= nil and pPlot:IsNaturalWonder()) then
		local pFeature = pPlot:GetFeature();
		return pFeature:GetPlots();
	else
		UI.DataAssert("No plot("..tostring(plotx)..","..tostring(ploty)..") was affected by a natural wonder (disaster).");
		return nil;
	end
end

-- ===========================================================================
--	River floodplains can be multiple hexes, and require their own code to find all affected hexes
-- ===========================================================================
function GetAffectedPlots_Flood(plotx:number, ploty:number)
	local eRiver = RiverManager.GetRiverForFloodplain(plotx, ploty);
	if (eRiver >= 0) then
		return RiverManager.GetFloodplainPlots(eRiver);
	else
		UI.DataAssert("No plot("..tostring(plotx)..","..tostring(ploty)..") was affected by a flood.");
		return nil;
	end
end

-- ===========================================================================
--	Storms can be multiple hexes, and require their own code to find all affected hexes
-- ===========================================================================
function GetAffectedPlots_Storm(plotx:number, ploty:number)
	local iStormID = GameClimate.GetActiveStormIDAtPlot(plotx, ploty);
	return GameClimate.GetStormPlotsByID(iStormID)
end

-- ===========================================================================
--	Droughts can be multiple hexes, and require their own code to find all affected hexes
-- ===========================================================================
function GetAffectedPlots_Drought(plotx:number, ploty:number)
	local iDroughtID = GameClimate.GetActiveDroughtIDAtPlot(plotx, ploty);
	return GameClimate.GetDroughtPlotsByID(iDroughtID);
end

-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()

	UI.ClearTemporaryPlotVisibility("NaturalDisaster");
	
	UI.PlaySound("Stop_Disaster_Blizzard_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Flood_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Hurricane_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Sandstorm_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Tornado_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Volcano_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Drought_Movie_Loop");
	UI.PlaySound("Stop_Disaster_Meltdown_Movie_Loop");

	-- Stop the camera animation if it hasn't finished already
	if (m_kCurrentPopup ~= nil) then
		Events.StopAllCameraAnimations();
	end

	local isDone:boolean = true;

	-- Find first entry in table, display that, then remove it from the internal queue
	for i, entry in ipairs(m_kQueuedPopups) do
		ShowPopup(entry);
		table.remove(m_kQueuedPopups, i);
		isDone = false;
		break;
	end

	if isDone then
		m_kCurrentPopup = nil;
		LuaEvents.NaturalDisasterPopup_Closed();	-- Signal other systems (e.g., bulk show UI)
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);		
		UILens.RestoreActiveLens();
		m_kPopupMgr:Unlock();
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function ShowPopup( kData:table )
	
	-- Only call once to preserve whatever lens was on before showing scene
	if(UI.GetInterfaceMode() ~= InterfaceModeTypes.CINEMATIC) then
		UILens.SaveActiveLens();
		UILens.SetActive("DisasterCinematic");
		UI.SetInterfaceMode(InterfaceModeTypes.CINEMATIC);		
	end

	if (kData.Plots and #kData.Plots > 0) then
		-- Just in case the local player can't see all the plots, temporarily reveal them on the app side
		UI.AddTemporaryPlotVisibility("NaturalDisaster", kData.Plots, RevealedState.VISIBLE);
	end
	
	UI.LookAtPosition(kData.Center.x, kData.Center.y, true);
	if (kData.Animation ~= nil) then
		Events.PlayCameraAnimationAtPos(kData.Animation, kData.Center.x, kData.Center.y, 0.0, true);			
	end

	m_kCurrentPopup = kData;
	
	if(kData.QuoteAudio) then
		UI.PlaySound(kData.QuoteAudio);
	end
		
	if(kData.VisualEffect) then
		WorldView.PlayEffectAtXY(kData.VisualEffect, kData.PlotX, kData.PlotY);
	end

	if kData.EffectOperatorType == NUCLEAR_OPERATOR_TYPE then
		Controls.HeaderTitle:SetText(Locale.ToUpper("LOC_UI_FEATURE_NUCLEAR_DISASTER_DISCOVERY"));
	else
		Controls.HeaderTitle:SetText(Locale.ToUpper("LOC_UI_FEATURE_NATURAL_DISASTER_DISCOVERY"));
	end

	Controls.DisasterName:SetText( kData.Name );
	Controls.DisasterIcon:SetHide( kData.Icon == nil );
	Controls.DisasterDescriptionContainer:SetHide( kData.Description == nil );

	if kData.Icon then
		if kData.Icon == "ClimateEventStat_Flooding" and kData.IsMitigated then
			Controls.DisasterIcon:SetTexture( "ClimateEventStat_FloodMitigated" );
		else
			-- If Icon in sheet doesn't exist, try loose texture.
			if (Controls.DisasterIcon:TrySetIcon( kData.Icon, 64 )==false) then
				Controls.DisasterIcon:SetTexture( kData.Icon );
			end
		end	
	end

	if kData.Description then
		Controls.DisasterDescription:SetText( kData.Description );
	end

	if kData.FertilityAdded ~= nil and kData.FertilityAdded < 0 then
		Controls.PlotLostFertileLabel:SetText(math.abs(kData.FertilityAdded));
		Controls.PlotLostFertileContainer:SetHide(false);
	else
		Controls.PlotLostFertileContainer:SetHide(true);
	end

	if kData.FertilityAdded ~= nil and kData.FertilityAdded > 0 then
		Controls.PlotFertileLabel:SetText(kData.FertilityAdded);
		Controls.PlotFertileContainer:SetHide(false);
	else
		Controls.PlotFertileContainer:SetHide(true);
	end

	if kData.TilesDamaged ~= nil and kData.TilesDamaged > 0 then
		Controls.PlotDamagedLabel:SetText(kData.TilesDamaged);
		Controls.PlotDamagedContainer:SetHide(false);
	else
		Controls.PlotDamagedContainer:SetHide(true);
	end

	if kData.UnitsLost ~= nil and kData.UnitsLost > 0 then
		Controls.UnitsLostLabel:SetText(kData.UnitsLost);
		Controls.UnitsLostContainer:SetHide(false);
	else
		Controls.UnitsLostContainer:SetHide(true);
	end

	if kData.PopLost ~= nil and kData.PopLost > 0 then
		Controls.PopLostLabel:SetText(kData.PopLost);
		Controls.PopLostContainer:SetHide(false);
	else
		Controls.PopLostContainer:SetHide(true);
	end

	Controls.MitigatedLabel:SetHide(kData.IsMitigated ~= true);

	Controls.DisasterNameStack:CalculateSize();
	Controls.MainContainer:DoAutoSize();
end

-- ===========================================================================
--	Game EVENT
-- ===========================================================================
function OnRandomEventOccurred(type:number, severity:number, plotx:number, ploty:number, mitigationLevel:number)
	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer < 0) then
		return;	-- autoplay
	end

	local pPlayer :table = Players[localPlayer];
	if not pPlayer:IsHuman() then 
		return;
	end	

	-- Check if the event is visible to the local player
	-- TODO check all affected plots instead of just one plot
	local pPlayerVis:table = PlayersVisibility[localPlayer];
	if (pPlayerVis ~= nil) then
		if not pPlayerVis:IsRevealed(plotx, ploty) then
			return;
		end
	end
	
	-- Check if the event is within 6 hexes of the local player's cities
	-- TODO check all affected plots instead of just one plot
	local playerCities:table = pPlayer:GetCities();
	if not playerCities:IsCityWithinRange(plotx, ploty, 6) then
		return;
	end

	UILens.SetActive("Default");
	
	-- The plot is fully visible, enqueue a full reveal
	local info:table = GameInfo.RandomEvents[type];
	if info ~= nil then
		
		local description :string = nil;
		if info.Description ~= nil then
			description = Locale.Lookup(info.Description);
		end

		-- get the DB data
		local result : table = nil;
		result = GameInfo.RandomEvent_Presentation[info.RandomEventType];

		if (result == nil) then
			UI.DataError("No DB entry for random event: '"..tostring(info.RandomEventType).."'");
			return;
		end

		if (result.Animation == nil) then
			-- A handler exists, but the animation is nil, which means we should skip the popup
			return;
		end

		-- Use the callback to determine which plots were affected
		g_AffectedPlots = nil;
		if (result.Callback ~= nil) then
			-- return here must be to a global variable because loadstring runs the called function outside of any scope
			g_AffectedPlots = loadstring("return "..result.Callback.."(...)")(plotx, ploty);
		end

		-- Default to just a single hex
		if (g_AffectedPlots == nil or #g_AffectedPlots == 0) then
			g_AffectedPlots = { Map.GetPlotIndex(plotx, ploty) };
		end

		local fCenterX, fCenterY = UI.GetRegionCenter(g_AffectedPlots);
		
		local kData:table = { 			
			EventType			= type,
			Name				= Locale.ToUpper(Locale.Lookup(info.Name)),
			Description			= description,
			Animation			= result.Animation,
			Icon				= info.IconSmall,
			Center				= { x=fCenterX, y=fCenterY },
			Plots				= g_AffectedPlots,
            QuoteAudio			= result.Sound,
			VisualEffect		= result.VFX,
			PlotX				= plotx,
			PlotY				= ploty,
			IsMitigated			= mitigationLevel == 1 and true or false,
			EffectOperatorType	= info.EffectOperatorType
		};
		local kGameEvent :table = GameRandomEvents.GetCurrentTurnEvent();
		if kGameEvent ~= nil then
			kData.PopLost = kGameEvent.PopLost;
			kData.UnitsLost = kGameEvent.UnitsLost;
			kData.TilesDamaged = kGameEvent.TilesDamaged;
			kData.FertilityAdded = kGameEvent.FertilityAdded;
		end

		-- Add to queue if already showing a popup
		if not m_kPopupMgr:IsLocked() then								
			m_kPopupMgr:Lock( ContextPtr, PopupPriority.Medium );
			ShowPopup( kData );
			LuaEvents.NaturalDisasterPopup_Shown(); -- Signal other systems (e.g., bulk hide UI)
		else
			table.insert( m_kQueuedPopups, kData );
		end
	end
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if m_kPopupMgr:IsLocked() then
		m_kQueuedPopups = {};	-- Ensure queue is empty to close immediately.
		Close();
	end
end

-- ===========================================================================
function OnCameraAnimationStopped(name : string)
	if (m_kCurrentPopup ~= nil) then
		UI.LookAtPosition(m_kCurrentPopup.Center.x, m_kCurrentPopup.Center.y, true);
	end
end

-- ===========================================================================
function OnCameraAnimationNotFound()
	if (m_kCurrentPopup ~= nil) then
		-- this will play if the animation doesnt exist
		UI.LookAtPosition(m_kCurrentPopup.Center.x, m_kCurrentPopup.Center.y, true);
	end
end

-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kCurrentPopup", m_kCurrentPopup);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kPopupMgr", m_kPopupMgr.ToTable() );
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isHidden"] ~= nil and contextTable["isHidden"] == false then
			if contextTable["m_kCurrentPopup"] ~= nil then
				m_kCurrentPopup = contextTable["m_kCurrentPopup"];
				ShowPopup(m_kCurrentPopup);
			end
		end
		m_kPopupMgr.FromTable( contextTable["m_kPopupMgr"], ContextPtr );
	end
end

-- ===========================================================================
--	Native Input / ESC support
-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then
		Close();
		return true;
	end
	return false;
end
function OnInputHander( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end

-- ===========================================================================
--	Initialize the context
-- ===========================================================================
function Initialize()

	-- Because these popup movies lock the engine until complete; disable 
	-- them if playing in any type of multiplayer game.
	if GameConfiguration.IsAnyMultiplayer() or GameConfiguration.IsHotseat() then
		return;
	end
	
	ContextPtr:SetInputHandler( OnInputHander, true );	
	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.ScreenConsumer:RegisterCallback(Mouse.eRClick, OnClose);

	-- Hot-Reload Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
	
	Events.RandomEventOccurred.Add( OnRandomEventOccurred );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
	Events.CameraAnimationStopped.Add( OnCameraAnimationStopped );
	Events.CameraAnimationNotFound.Add( OnCameraAnimationNotFound );
end
Initialize();