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

        for _,name in pairs( Ext.Stats.GetStats( "Object" ) ) do
            if string.find( name, "Arrow" ) then
                Osi.TemplateAddTo( Ext.Stats.Get( name ).RootTemplate, Osi.GetHostCharacter(), 1 )
            end
        end
    end
)


	-- {
	-- 	"MainHandWeapon" : "Entity (0200000100000310)",
	-- 	"OffHandWeapon" : "Entity (0200000100000488)",
	-- 	"State" : "Melee",
	-- 	"field_10" : 4,
	-- 	"field_18" : 0,
	-- 	"field_19" : 1,
	-- 	"field_1A" : 0
	-- },


-- Ext.Loca.UpdateTranslatedString( off.DisplayName, Ext.Loca.GetTranslatedString( off.DisplayName ) .. " Off Hand" )
-- Ext.Loca.UpdateTranslatedString( off.Description, Ext.Loca.GetTranslatedString( off.Description ) .. "\n\nReduce your AC by ".. Debt .. " until your next turn" )

-- local bnp = create( "Base_Non_Player", "PassiveData" )
-- bnp.Boosts = "AC(14);Ability(Constitution,9)"
-- bnp:Sync()

-- Ext.Osiris.RegisterListener(
--     "Saw",
--     3,
--     "after",
--     function( c, t, ... )
--         if Osi.IsPlayer( t ) == 0 then
--             Osi.AddPassive( t, "Base_Non_Player" )
--         end
--     end
-- )

--_D(Ext.Stats.Get("Interrupt_AttackOfOpportunity"))

--_D(_C():GetComponent("Bound"))
--Ext.Entity.OnChange( "Transform", function( e ) end )
--_D(Ext.Entity.UuidToHandle(GetEquippedWeapon(GetHostCharacter())):GetComponent("Weapon"))

-- CHANGE THE MAIN ATTACK USED TO BE THE OFF HAND ATTACK
--[[

local hot = _C():GetComponent("HotbarContainer").Containers.DefaultBarContainer[ 5 ].Elements



[ 1 ].SpellId.OriginatorPrototype = "Target_Eyebite_Panicked"
_C():GetComponent("HotbarContainer").Containers.DefaultBarContainer[ 1 ].Elements[ 1 ].SpellId.Prototype = "Target_Eyebite_Panicked"

_C():Replicate("HotbarContainer")

]]--

--[[

local spell = "Target_Eyebite_Panicked"

Osi.AddSpell(GetHostCharacter(), spell)
Ext.Stats.Get(spell).UseCosts = ""
Ext.Stats.Get(spell).HitCosts = ""
Ext.Stats.Get(spell).RitualCosts = ""
Ext.Stats.Get(spell).TargetConditions = ""
Ext.Stats.Get(spell):Sync()

]]--