-- Copyright 2018-2019, Firaxis Games.

include("DiplomacyRibbon_Expansion1.lua");
include("GameCapabilities");
include("CongressButton");


-- ===========================================================================
-- OVERRIDES
-- ===========================================================================
BASE_LateInitialize = LateInitialize;
BASE_UpdateLeaders = UpdateLeaders;
BASE_RealizeSize = RealizeSize;
BASE_FinishAddingLeader = FinishAddingLeader;
BASE_UpdateStatValues = UpdateStatValues;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kCongressButtonIM		:table = nil;
local m_uiCongressButtonInstance:table = nil;
local m_congressButtonWidth		:number = 0;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function UpdateLeaders()
	-- Create and add World Congress button if one was allocated (based on capabilities)
	if m_kCongressButtonIM then
		if Game.GetEras():GetCurrentEra() >= GlobalParameters.WORLD_CONGRESS_INITIAL_ERA then		
			m_kCongressButtonIM:ResetInstances();
			local congressProgButtonClass:table = {};
			kCongressButton, m_uiCongressButtonInstance = CongressButton:GetInstance( m_kCongressButtonIM );
			m_congressButtonWidth = m_uiCongressButtonInstance.Top:GetSizeX();
		end
	end

	BASE_UpdateLeaders();	
end


-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function RealizeSize( additionalElementsWidth:number )			
	BASE_RealizeSize( m_congressButtonWidth );
	--The Congress button takes up one leader slot, so the max num of leaders used to calculate scroll is reduced by one in XP2	
	g_maxNumLeaders = g_maxNumLeaders - 1;
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function FinishAddingLeader( playerID:number, uiLeader:table, kProps:table)	

	local isMasked:boolean = false;
	if kProps.isMasked then	isMasked = kProps.isMasked; end
	
	local isHideFavor	:boolean = isMasked or (not Game.IsVictoryEnabled("VICTORY_DIPLOMATIC"));		--TODO: Change to capability check when favor is added to capability system.
	uiLeader.Favor:SetHide( isHideFavor );

	BASE_FinishAddingLeader( playerID, uiLeader, kProps );
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function UpdateStatValues( playerID:number, uiLeader:table )	
	BASE_UpdateStatValues( playerID, uiLeader );
	local favor	:number = Round( Players[playerID]:GetFavor() );
	if uiLeader.Favor:IsVisible() then uiLeader.Favor:SetText( " [ICON_Favor] "..tostring(favor)); end
end

-- ===========================================================================
function OnLeaderClicked(playerID : number )
	-- Send an event to open the leader in the diplomacy view (only if they met)
	local pWorldCongress:table = Game.GetWorldCongress();
	local localPlayerID:number = Game.GetLocalPlayer();

	if localPlayerID == -1 or localPlayerID == 1000 then
		return;
	end

	if playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID) then
		if pWorldCongress:IsInSession() then
			LuaEvents.DiplomacyActionView_OpenLite(playerID);
		else
			LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView(playerID);
		end
	end
end

-- ===========================================================================
function LateInitialize()

	BASE_LateInitialize();

	if HasCapability("CAPABILITY_WORLD_CONGRESS") then
		m_kCongressButtonIM = InstanceManager:new("CongressButton", "Top", Controls.LeaderStack);
	end

	if not XP2_LateInitialize then	-- Only update leaders if this is the last in the call chain.
		UpdateLeaders();
	end
end
