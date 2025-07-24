local _V = require( "Server.Variables" )
local _F = require( "Server.Functions" )( _V )
local _H = require( "Server.Hooks" )( _V, _F )

if MCM then
    _V.Penalty = MCM.Get( "Penalty" )
    _V.TwoWeaponFighting = MCM.Get( "TwoWeaponFighting" )
    _V.LostFooting = MCM.Get( "LostFooting" )

    Ext.ModEvents.BG3MCM[ "MCM_Setting_Saved" ]:Subscribe(
        function( payload )
            if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
                return
            end

            _V[ payload.settingId ] = payload.value

            _F.CreateStatuses()

            for uuid,wield in pairs( _V.Duals ) do
                for _,boost in pairs( _F.Status( uuid ) ) do
                    boost.Update()
                end
            end

            _F.UpdateText()
        end
    )
end

_F.UpdateText()