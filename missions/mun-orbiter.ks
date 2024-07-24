set terminal:charHeight to 22.
wait until ship:unpacked.

// Setup staging trigger
when (stage:deltaV:current < 0.1) then {
    wait until stage:ready.
    stage.
    preserve.
}

set target to mun.

runPath("0:/launch.ks").

if abs(target:orbit:inclination - ship:orbit:inclination) > 0.2 {
    runPath("0:/matchInclination.ks").
}

runPath("0:/transfer.ks", 100000).
runPath("0:/utility.ks").
//circulariseOrbitAtAltitude(300000).