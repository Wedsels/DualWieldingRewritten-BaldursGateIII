--- @class _V
local _V = {}

_V.Off = "_DualOffHand"
_V.Key = "DualWieldingBalance"
_V.Die = { "d4", "d6", "d8", "d10", "d12" }
_V.Penalty = 1.0
_V.TwoWeaponFighting = 0.33

--- @class Data
--- @field Charge number
--- @field Time number

--- @class Equip
--- @field Ranger boolean
--- @field MeleeWeight number
--- @field RangedWeight number
--- @field Melee table< userdata, userdata >
--- @field Ranged table< userdata, userdata >
--- @field Returns table< userdata >

--- @class Wield
--- @field Ranged boolean
--- @field Melee boolean
--- @field Time number
--- @field Equip Equip
--- @field Boost table < string, string >
--- @field Data table < string, Data >

--- @type table< string, Wield >
_V.Duals = {}

_V.Boosts = function( uuid )
    local equip = _V.Duals[ uuid ] and _V.Duals[ uuid ].Equip
    if not equip then return end

    local proficiency = 1 + math.floor( Osi.GetLevel( uuid ) / 2.0 )

    local melee = 1 + proficiency + equip.MeleeWeight ^ 0.5 * 0.04
    local ranged = 1 + proficiency + equip.RangedWeight ^ 0.5 * 0.04

    if Osi.HasPassive( uuid, "FightingStyle_TwoWeaponFighting" ) == 1 then
        melee = melee * _V.TwoWeaponFighting
        ranged = ranged * _V.TwoWeaponFighting
    end

    melee = -math.ceil( melee * _V.Penalty )
    ranged = -math.ceil( ranged * _V.Penalty )

    return {
        Base = "TwoWeaponFighting()",
        Penalty = "AC( " .. ( equip.Ranger and ranged or melee ) .. " )",
        Melee = "RollBonus( MeleeWeaponAttack, " .. melee .. " );RollBonus( MeleeOffHandWeaponAttack, " .. melee .. " )",
        Ranged = "RollBonus( RangedWeaponAttack, " .. ranged .. " );RollBonus( RangedOffHandWeaponAttack, " .. ranged .. " )"
    }
end

--- @type table < string, boolean >
_V.Spells = {}
for _,name in pairs( Ext.Stats.GetStats( "SpellData" ) ) do
    local spell = Ext.Stats.Get( name )

    if not string.find( name, "AttackOfOpportunity" ) and not spell.InterruptPrototype or spell.InterruptPrototype == "" and string.sub( name, -#_V.Off ) ~= _V.Off and tostring( spell.CastTextEvent ) ~= "CastOffhand" then
        local type
        local val
        if spell.SpellType == "Projectile" then
            type = "Ammunition"
            val = false
        elseif spell.SpellType == "Target" then
            type = "Melee"
            val = true
        end

        if type then
            for _,weapon in ipairs( spell.WeaponTypes ) do
                if weapon == type then
                    _V.Spells[ name ] = val
                    break
                end
            end
        end
    end
end

return _V