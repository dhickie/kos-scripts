// Dependencies
runOncePath("0:/operations/launch.ks").
runOncePath("0:/operations/matchInclination.ks").
runOncePath("0:/operations/transfer.ks").
runOncePath("0:/operations/orbit.ks").

// Setup staging trigger
when (stage:deltaV:current < 0.1) then {
    wait until stage:ready.
    stage.
    preserve.
}

// Set target body
set target to mun.

launch().

if abs(target:orbit:inclination - ship:orbit:inclination) > 0.2 {
    matchInclination().
}

transferToTarget(100000).
circulariseOrbitAtAltitude(100000).