--- @param _V _V
--- @param _F _F
return function( _V,  _F )
    Ext.Osiris.RegisterListener( "TurnStarted", 1, "before", function( uuid ) _F.RemoveDualEffects( _F.UUID( uuid ) ) end )
    Ext.Osiris.RegisterListener( "LeftCombat", 2, "before", function( uuid ) _F.RemoveDualEffects( _F.UUID( uuid ) ) _F.Hip.Apply( uuid ) end )
    Ext.Entity.OnDestroy( "SpellCastIsCasting", function( ent, _, index ) _F.Hip.Apply( ent ) end )
    Ext.Entity.OnCreate( "SpellCastIsCasting", function( ent, _, index ) _F.Hip.Remove( ent ) end )
    Ext.Entity.OnChange(
        "Unsheath",
        function( ent, _, index )
            local sheath = ent.Unsheath
            if sheath.State == "Sheathed" then
                _F.Hip.Remove( ent )
            else
                local uuid = _F.UUID( ent )
                local entity = _V.Entities[ uuid ]
                if entity then
                    entity.Equip[ sheath.State ] = { sheath.MainHandWeapon, sheath.OffHandWeapon }
                    entity.Equip.Ranger = sheath.State == "Ranged"

                    entity.Update()
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
            local entity = _V.Entities[ uuid ]

            if not entity or not entity.Wield.Melee and not entity.Wield.Ranged then
                return
            end

            if _F.OffHandSpell( spell ) then
                _F.ExchangeSpell( uuid, spell )
                return
            end

            local type = _V.Spells[ spell ]

            if type == false and entity.Wield.Ranged or type == true and entity.Wield.Melee then
                if not entity.Wield.Generate then return end

                _F.ExchangeSpell( uuid, spell )

                entity.Wield.Data[ spell .. _V.Off ].Time = 300

                entity.Update()
            end
        end
    )

    Ext.Osiris.RegisterListener(
        "MissedBy",
        4,
        "after",
        function( defender, attackOwner, attacker, storyActionID )
            local uuid = _F.UUID( attacker )
            local entity = _V.Entities[ uuid ]

            if not _V.LostFooting
            or not entity
            or not entity.Wield.Melee and not entity.Wield.Ranged
            or not entity.Equip.Ranger and not entity.Wield.Melee
            or entity.Equip.Ranger and not entity.Wield.Ranged
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
                local entity = _V.Entities[ uuid ]

                if not entity or not status:find( _V.Status().Base .. "LostFooting" ) then
                    return
                end

                if not type then
                    _F.RemoveSpells( uuid )
                    entity.Wield.Time = 300
                end

                entity.Wield.Generate = type

                entity.Update()
            end

            return {
                Apply = function( uuid, status ) Change( uuid, status, false ) end,
                Remove = function( uuid, status ) Change( uuid, status, true ) end
            }
        end
    )()

    Ext.Osiris.RegisterListener( "StatusApplied", 4, "after", StatusChange.Apply )
    Ext.Osiris.RegisterListener( "StatusRemoved", 4, "after", StatusChange.Remove )

    Ext.Entity.OnChange( "DualWielding", function( ent, _, index ) _F.CheckDualStatus( ent ) end )

    Ext.Entity.OnCreateDeferred(
        "Active",
        function( ent, _, index )
            local uuid = _F.UUID( ent )
            if not uuid then return end

            local dual = ent.DualWielding
            if not dual or _V.Entities[ uuid ] then return end

            ent.Vars.DualWieldingCache = ent.Vars.DualWieldingCache or {
                Ranged = false,
                Melee = false,
                Time = -1,
                Status = {},
                Data = {},
                Generate = true
            }

            _V.Entities[ uuid ] = {
                Instance = ent,
                Wield = ent.Vars.DualWieldingCache,
                Equip = {
                    Ranger = false,
                    Melee = {},
                    MeleeMain = 0,
                    MeleeOffhand = 0,
                    Ranged = {},
                    RangedMain = 0,
                    RangedOffhand = 0,
                    Returns = {}
                },
                Update = function() ent.Vars.DualWieldingCache = ent.Vars.DualWieldingCache end
            }

            _F.CheckDualStatus( uuid )
        end
    )

    Ext.Entity.OnDestroyDeferred(
        "Active",
        function( ent, _, index )
            local uuid = _F.UUID( ent )
            if not uuid or not _V.Entities[ uuid ] then return end

            _V.Entities[ uuid ] = nil
        end
    )

    Ext.Events.Tick:Subscribe(
        function()
            for uuid,entity in pairs( _V.Entities ) do
                if not _F.InCombat( entity.Instance ) then
                    if entity.Wield.Time > 0 then
                        entity.Wield.Time = entity.Wield.Time - 1

                        if entity.Wield.Time == 0 then
                            _F.Status( uuid ).Penalty.Remove()
                            entity.Wield.Time = -1
                        end
                    end

                    for spell,data in pairs( entity.Wield.Data ) do
                        if data.Time > 0 then data.Time = data.Time - 1 end

                        if data.Time == 0 then
                            _F.ExchangeSpell( uuid, spell )
                        end
                    end

                    entity.Update()
                end
            end
        end
    )
end