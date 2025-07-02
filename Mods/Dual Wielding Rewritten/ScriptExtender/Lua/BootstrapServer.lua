local _V = require( "Server.Variables" )
local _F = require( "Server.Functions" )( _V )
local _H = require( "Server.Hooks" )( _V, _F )

_F.UpdateText()

if MCM then
    _V.Penalty = MCM.Get( "Penalty" )
    _V.TwoWeaponFighting = MCM.Get( "TwoWeaponFighting" )

    Ext.ModEvents.BG3MCM[ "MCM_Setting_Saved" ]:Subscribe(
        function( payload )
            if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
                return
            end

            _V[ payload.settingId ] = payload.value
            for uuid,wield in pairs( _V.Duals ) do
                for boost,_ in pairs( wield.Boost ) do
                    _F.Boost( uuid, boost ).Update()
                end
            end

            _F.UpdateText()
        end
    )
end