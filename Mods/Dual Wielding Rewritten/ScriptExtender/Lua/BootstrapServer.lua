local Common = require( "Common" )
Common.InitializeSpellLists()

Ext.Osiris.RegisterListener(
    "ObjectTimerFinished",
    2,
    "after",
    function( p, timer )
        if timer == Common.Key then
            Common.RefreshDualStatus( p )
        end
    end
)

Ext.Osiris.RegisterListener(
    "CastedSpell",
    5,
    "after",
    function( caster, spell, ... )
        Common.UnlearnOffHand( caster )
        Common.CheckDualStatus( caster )

        if not Common.Melee and not Common.Ranged then
            return
        end

        local type = Common.Spells[ spell ]

        if not type or Common.OffHandSpell( spell ) then
            if not Common.ActiveDebuff then
                Osi.AddPassive( caster, "Penalty_DualWielding" )
            end
            Common.ActiveDebuff = true
            Osi.ObjectTimerCancel( caster, Common.Key )
            Osi.ObjectTimerLaunch( caster, Common.Key, 5000, 1 )
            return
        end

        if type == 0 and Common.Ranged or type == 1 and Common.Melee then
            Common.ExchangeSpell( caster, spell )

            Osi.ObjectTimerCancel( caster, Common.Key )
            Osi.ObjectTimerLaunch( caster, Common.Key, 5000, 1 )
        end
    end
)

Ext.Osiris.RegisterListener( "TurnStarted", 1, "after", function( p ) Common.RefreshDualStatus( p ) end )
Ext.Osiris.RegisterListener( "EnteredCombat", 2, "after", function( p, ... ) Common.RefreshDualStatus( p ) end )
Ext.Osiris.RegisterListener( "EnteredForceTurnBased", 1, "after", function( p ) Common.RefreshDualStatus( p ) end )

Ext.Osiris.RegisterListener(
    "LevelGameplayStarted",
    2,
    "after",
    function( ... )
        for _,p in pairs( Osi.DB_Players:Get( nil ) ) do
            local char = p[ 1 ];

            Common.CheckDualStatus( char )
        end

        Ext.Loca.UpdateTranslatedString(
            "h5153f9f3g7dcbg45d9gae1bgd19f398959a2",
            "Become more adept at twin weapons, no longer suffering a penalty of " .. Common.Debt .. " <LSTag Tooltip=\"AttackRoll\">Accuracy</LSTag> while dual wielding.\n\n" ..
            "Improve stability and awareness, using the free <LSTag Tooltip=\"Action\">Action</LSTag> off hand attack no longer reduces <LSTag Tooltip=\"ArmourClass\">Armour Class</LSTag> by " .. Common.Debt .. " for a turn."
        )

        Ext.Entity.OnChange( "DualWielding", function( e ) Common.CheckDualStatus( e.Uuid.EntityUuid ) end )
    end
)