parameter targetBody.

// Dependencies
runOncePath("0:/operations/launch.ks").
runOncePath("0:/operations/matchInclination.ks").
runOncePath("0:/operations/transfer.ks").
runOncePath("0:/operations/orbit.ks").
runOncePath("0:/utilities/parts.ks").

identifyShipParts().

if (ship:status = "prelaunch") {
    // Set target body
    set target to targetBody.
    
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

    // Kill any rotation of the ship
    lock steering to "kill".
}