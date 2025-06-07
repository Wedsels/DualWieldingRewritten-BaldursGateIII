--- @param _V _V
--- @param _F _F
return function( _V,  _F )
    Ext.Entity.OnDestroy(
        "SpellCastIsCasting",
        function( ent )
            local id = _F.UUID( ent )
            if not id then return end

            for uuid,_ in pairs( _V.Hips ) do
                local data = Ext.StaticData.Get( uuid, "EquipmentType" )
                data.WeaponType_OneHanded = "Small1H"
            end

            Osi.SetWeaponUnsheathed( id, 1, 1 )
            Osi.SetWeaponUnsheathed( id, 0, 1 )
        end
    )

    Ext.Entity.OnCreate(
        "SpellCastIsCasting",
        function()
            for uuid,type in pairs( _V.Hips ) do
                local data = Ext.StaticData.Get( uuid, "EquipmentType" )
                data.WeaponType_OneHanded = type
            end
        end
    )

    Ext.Entity.OnChange(
        "Unsheath",
        function( ent )
            if ent.Unsheath.State == "Sheathed" then
                for uuid,type in pairs( _V.Hips ) do
                    local data = Ext.StaticData.Get( uuid, "EquipmentType" )
                    data.WeaponType_OneHanded = type
                end
            end
        end
    )

    Ext.Osiris.RegisterListener(
        "CastedSpell",
        5,
        "after",
        function( caster, spell )
            local uuid = _F.UUID( caster )
            local dual = _V.Duals[ uuid ]

            if not dual or not dual.Melee and not dual.Ranged then
                return
            end

            local type = _V.Spells[ spell ]

            if _F.OffHandSpell( spell ) then
                _F.Boost( uuid, "Penalty" ).Apply()
                dual.Time = Ext.Utils.MonotonicTime()
                _F.ExchangeSpell( uuid, spell )
                return
            end

            if type == false and dual.Ranged or type == true and dual.Melee then
                _F.ExchangeSpell( uuid, spell )

                dual.Data[ spell .. _V.Off ].Time = 0
            end
        end
    )

    Ext.Osiris.RegisterListener( "TurnStarted", 1, "after", function( p ) _F.RemoveDualEffects( _F.UUID( p ) ) end )
    Ext.Osiris.RegisterListener( "EnteredCombat", 2, "after", function( p ) _F.RemoveDualEffects( _F.UUID( p ) ) end )
    Ext.Osiris.RegisterListener( "EnteredForceTurnBased", 1, "after", function( p ) _F.RemoveDualEffects( _F.UUID( p ) ) end )

    Ext.Osiris.RegisterListener(
        "LevelGameplayStarted",
        2,
        "after",
        function()
            for _,ent in pairs( Ext.Entity.GetAllEntities() ) do
                _F.CheckDualStatus( _F.UUID( ent ) )
            end

            Ext.Loca.UpdateTranslatedString(
                "h5153f9f3g7dcbg45d9gae1bgd19f398959a2",
                "Become more adept at twin weapons, no longer suffering a penalty of " .. _V.Penalty .. " <LSTag Tooltip=\"AttackRoll\">Accuracy</LSTag> while dual wielding.\n\n" ..
                "Improve stability and coordination, using the free <LSTag Tooltip=\"Action\">Action</LSTag> off hand attack no longer reduces <LSTag Tooltip=\"ArmourClass\">Armour Class</LSTag> by " .. _V.Penalty .. " for a turn."
            )

            Ext.Entity.OnChange( "DualWielding", function( e ) _F.CheckDualStatus( _F.UUID( e ) ) end )
        end
    )

    Ext.Events.Tick:Subscribe(
        function()
            for uuid,wield in pairs( _V.Duals ) do
                if not _F.InCombat( uuid ) then
                    if wield.Time > 0 and Ext.Utils.MonotonicTime() - wield.Time > 5000 then
                        _F.Boost( uuid, "Penalty" ).Remove()
                        wield.Time = -1
                    end

                    for spell,data in pairs( wield.Data ) do
                        if data.Time <= 0 then
                            data.Time = Ext.Utils.MonotonicTime()
                        end

                        if Ext.Utils.MonotonicTime() - data.Time > 5000 then
                            data.Time = 0
                            _F.ExchangeSpell( uuid, spell )
                        end
                    end
                end
            end
        end
    )
end