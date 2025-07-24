--- @param _V _V
--- @param _F _F
return function( _V,  _F )
    Ext.Osiris.RegisterListener( "TurnStarted", 1, "before", function( p ) _F.RemoveDualEffects( _F.UUID( p ) ) end )
    Ext.Osiris.RegisterListener( "LeftCombat", 2, "before", function( uuid ) _F.RemoveDualEffects( _F.UUID( uuid ) ) _F.Hip.Apply( uuid ) end )
    Ext.Entity.OnDestroy( "SpellCastIsCasting", function( ent ) _F.Hip.Apply( ent ) end )
    Ext.Entity.OnCreate( "SpellCastIsCasting", function( ent ) _F.Hip.Remove( ent ) end )
    Ext.Entity.OnChange(
        "Unsheath",
        function( ent )
            local sheath = ent.Unsheath
            if sheath.State == "Sheathed" then
                _F.Hip.Remove( ent )
            else
                local uuid = _F.UUID( ent )
                local equip = _V.Duals[ uuid ] and _V.Duals[ uuid ].Equip
                if equip then
                    equip[ sheath.State ] = { sheath.MainHandWeapon, sheath.OffHandWeapon }
                    equip.Ranger = sheath.State == "Ranged"
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
            local wield = _V.Duals[ uuid ]

            if not wield or not wield.Melee and not wield.Ranged then
                return
            end

            if _F.OffHandSpell( spell ) then
                _F.ExchangeSpell( uuid, spell )
                return
            end

            local type = _V.Spells[ spell ]

            if type == false and wield.Ranged or type == true and wield.Melee then
                if not wield.Generate then return end

                _F.ExchangeSpell( uuid, spell )

                wield.Data[ spell .. _V.Off ].Time = 0
            end
        end
    )

    Ext.Osiris.RegisterListener(
        "MissedBy",
        4,
        "after",
        function( defender, attackOwner, attacker, storyActionID )
            local uuid = _F.UUID( attacker )
            local wield = _V.Duals[ uuid ]

            if not _V.LostFooting
            or not wield
            or not wield.Melee and not wield.Ranged
            or not wield.Equip.Ranger and not wield.Melee
            or wield.Equip.Ranger and not wield.Ranged
            then
                return
            end

            _F.Status( uuid ).Penalty.Apply()
        end
    )

    local StatusChange = (
        function()
            local function Change( uuid, status, type )
                uuid = _F.UUID( uuid )
                local wield = _V.Duals[ uuid ]

                if not wield or not status:find( _V.Status().Base .. "LostFooting" ) then
                    return
                end

                if not type then
                    _F.RemoveSpells( uuid )
                    wield.Time = Ext.Utils.MonotonicTime()
                end

                wield.Generate = type
            end

            return {
                Apply = function( uuid, status ) Change( uuid, status, false ) end,
                Remove = function( uuid, status ) Change( uuid, status, true ) end
            }
        end
    )()

    Ext.Osiris.RegisterListener( "StatusApplied", 4, "after", StatusChange.Apply )
    Ext.Osiris.RegisterListener( "StatusRemoved", 4, "after", StatusChange.Remove )

    Ext.Osiris.RegisterListener( "Equipped", 2, "after", function( i, p ) _F.CheckDualStatus( _F.UUID( p ) ) end )

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
                        _F.Status( uuid ).Penalty.Remove()
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