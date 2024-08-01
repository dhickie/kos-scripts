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
    
    // Launch the ship
    launchFromKerbin().
    
    // Match inclination to the target if we're sufficiently off to warrant it
    if abs(target:orbit:inclination - ship:orbit:inclination) > 0.2 {
        matchInclinationToTarget().
    }
    
    // Transfer to the target
    transferToTarget(100000).

    // Set the inclination around the equator to 0
    matchInclinationToEquator().
}