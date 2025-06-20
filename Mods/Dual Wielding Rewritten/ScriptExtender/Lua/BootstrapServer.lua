local _V = require( "Server.Variables" )
local _F = require( "Server.Functions" )( _V )
local _H = require( "Server.Hooks" )( _V, _F )

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

            Ext.Loca.UpdateTranslatedString(
                "h5153f9f3g7dcbg45d9gae1bgd19f398959a2",
                "Become more adept at twin weapons, reducing the penalty of " .. _V.Penalty .. " <LSTag Tooltip=\"AttackRoll\">Accuracy</LSTag> by " .. _V.TwoWeaponFighting .. " while dual wielding.\n\n" ..
                "Improve stability and coordination, reducing the free <LSTag Tooltip=\"Action\">Action</LSTag> off hand attack <LSTag Tooltip=\"ArmourClass\">Armour Class</LSTag> penalty of " .. _V.Penalty .. " by " .. _V.TwoWeaponFighting .. "."
            )
        end
    )
end

local Sources = {
    slash = Ext.StaticData.Get( "f85002a2-8e0e-4a49-aa0f-f52e987d3a3a", "EquipmentType" ),
    pierce = Ext.StaticData.Get( "cb322434-365d-47bf-8357-e2f202dfb129", "EquipmentType" )
}

for _,uuid in ipairs( Ext.StaticData.GetAll( "EquipmentType" ) ) do
    local data = Ext.StaticData.Get( uuid, "EquipmentType" )

    local t = data.WeaponType_TwoHanded
    local change
    local source
    if t == "Polearm2H" or t == "Spear2H" or t == "Javelin1H" then
        change = "Javelin1H"
        source = Sources.pierce
    elseif t == "Sword2H" or t == "Piercing1H" then
        change = "Piercing1H"
        source = Sources.pierce
    elseif t == "Generic2H" or t == "Slashing1H" then
        change = "Slashing1H"
        source = Sources.slash
    elseif t == "Small1H" then
        change = "Small1H"
        source = Sources.slash
    end

    if source then
        data.BoneOffHandSheathed = source.BoneOffHandSheathed
        data.BoneVersatileSheathed = source.BoneVersatileSheathed

        data.BoneOffHandUnsheathed = source.BoneOffHandUnsheathed
        data.BoneVersatileUnsheathed = source.BoneVersatileUnsheathed
        data.SourceBoneVersatileSheathed = data.SourceBoneSheathed
        data.SourceBoneVersatileUnsheathed = source.SourceBoneVersatileUnsheathed
        data.WeaponType_OneHanded = change

        if t:find( "1H" ) then
            data.BoneMainSheathed = "Dummy_Sheath_Hip_L"
            data.BoneOffHandSheathed = "Dummy_Sheath_Hip_R"
            data.BoneVersatileSheathed = "Dummy_Sheath_Hip_L"

            _V.Hips[ uuid ] = data.WeaponType_OneHanded
        end
    end
end