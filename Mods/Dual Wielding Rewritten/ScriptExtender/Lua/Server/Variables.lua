--- @class _V
local _V = {}

_V.Debt = -3
_V.Key = "DualWieldingBalance"
_V.Off = "_DualOffHand"

--- @class Data
--- @field Charge number
--- @field Time number

--- @class Wield
--- @field Ranged boolean
--- @field Melee boolean
--- @field Time number
--- @field Boost table< string, string >
--- @field Data table< string, Data >

--- @type table< string, Wield >
_V.Duals = {}

_V.Boosts = function( uuid )
    local debt = Osi.HasPassive( uuid, "FightingStyle_TwoWeaponFighting" ) == 1 and 0 or _V.Debt

    return {
        Base = "TwoWeaponFighting()",
        Penalty = "AC( " .. debt .. " )",
        Ranged = "RollBonus( RangedWeaponAttack, " .. debt .. " );RollBonus( RangedOffHandWeaponAttack, " .. debt .. " )",
        Melee = "RollBonus( MeleeWeaponAttack, " .. debt .. " );RollBonus( MeleeOffHandWeaponAttack, " .. debt .. " )"
    }
end

--- @type table< string, boolean >
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