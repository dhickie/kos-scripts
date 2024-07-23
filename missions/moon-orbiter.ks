wait until ship:unpacked.

// Setup staging trigger
when (stage:deltaV:current < 0.1) then {
    wait until stage:ready.
    stage.
    preserve.
}

if alt:radar > 70000 and ship:orbit:eccentricity < 1 {
    //runPath("0:/matchInclination.ks").
    set target to mun.
    runPath("0:/transfer.ks").
} else {
    runPath("0:/launch.ks").
    //runPath("0:/matchInclination.ks").
}