--- @param _V _V
--- @param _F _F
return function( _V,  _F )
    Ext.Osiris.RegisterListener( "LeftCombat", 2, "before", function( uuid ) _F.Hip.Apply( uuid ) end )
    Ext.Entity.OnDestroy( "SpellCastIsCasting", function( ent ) _F.Hip.Apply( ent ) end )
    Ext.Entity.OnCreate( "SpellCastIsCasting", _F.Hip.Remove )
    Ext.Entity.OnChange( "Unsheath", function( ent ) if ent.Unsheath.State == "Sheathed" then _F.Hip.Remove() end end )

    Ext.Osiris.RegisterListener(
        "MissedBy",
        4,
        "after",
        function( defender, attackOwner, attacker, storyActionID )
            local uuid = _F.UUID( attacker )
            local dual = _V.Duals[ uuid ]

            if not dual
            or not dual.Melee and not dual.Ranged
            or not dual.Equip.Ranger and not dual.Melee
            or dual.Equip.Ranger and not dual.Ranged
            then
                return
            end

            _F.Boost( uuid, "Penalty" ).Apply()
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

    Ext.Osiris.RegisterListener( "Equipped", 2, "after", function( i, p ) _F.CheckDualStatus( _F.UUID( p ) ) end )
    Ext.Entity.OnChange(
        "WeaponSet",
        function( e )
            local uuid = _F.UUID( e )
            if not uuid then return end
            local equip = _V.Duals[ uuid ] and _V.Duals[ uuid ].Equip
            if not equip then return end

            equip.Ranger = not equip.Ranger
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