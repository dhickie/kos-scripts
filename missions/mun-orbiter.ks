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

if (ship:status = "prelaunch") {
    // Set target body
    set target to mun.
    
    launchFromKerbin().
    
    if abs(target:orbit:inclination - ship:orbit:inclination) > 0.2 {
        matchInclination().
    }
    
    transferToTarget(100000).
}

