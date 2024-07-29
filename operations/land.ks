// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/maneuver.ks").
runOncePath("0:/utilities/ship.ks").

function land {
    killLateralVelocity().

    // Lock the steering to surface retrograde but with roll locked
    local roll is ship:facing:roll.
    lock steering to r(srfRetrograde:pitch, srfRetrograde:yaw, roll).
    
    waitUntilSuicideBurn().
    
    legs on.

    performSuicideBurn().
}

function killLateralVelocity {
    // Calculate the orbit normal
    local orbitNormal is calculateOrbitNormal(ship).

    // Calculate the lateral vector in the direction of the ship's velocity
    local lateralVector is vCrs(orbitNormal, ship:body:position):normalized.

    // Calculate the amount of lateral velocity we're currently holding
    local lateralVelocity is vDot(ship:velocity:surface, lateralVector) * lateralVector.

    // Create and execute a maneuver with the opposite deltaV
    local mnv is createManeuverFromDeltaV(5, -lateralVelocity).
    executeManeuver(mnv).
}

function waitUntilSuicideBurn {
    // Lock a variable to show how far down the ship would travel if we applied
    // max thrust now
    lock maxDownwardDistance to calculateMaxDownwardTravel().

    // Wait until we hit the last point we can burn, with a buffer 
    // to accommodate the rate of physics ticks
    wait until maxDownwardDistance >= (alt:radar - (ship:velocity:surface:mag * 0.88)).
}

function performSuicideBurn {
    lock throttle to 1.

    wait until alt:radar < 6 or ship:verticalspeed >= -3.

    // If we're at the surface, kill the throttle
    // If we're not yet at the surface but velocity is low, then keep throttle
    // at a level that keeps velocity constant
    if (alt:radar < 6) {
        lock throttle to 0.
    } else {
        lock throttle to calculateHoverThrottle().
        wait until alt:radar < 6.
        lock throttle to 0.
    }
}

// Calculates how far below the ship's current point the ship would travel if
// it applied max thrust right now
function calculateMaxDownwardTravel {
    // How long would it take to cancel out our current velocity?
    local t is calculateManeuverBurnTime(ship:velocity:surface:mag).

    // How far would the ship travel in that time?
    local F is (shipPossibleThrust() * 1000) - calculateGravitationalForce().
    local a is F / (ship:mass * 1000).
    local u is ship:velocity:surface:mag.

    return (u * t) - ((a * t^2)/2).
}

// Calculates the throttle requires to keep the current downward velocity constant
function calculateHoverThrottle {
    local g is calculateGravitationalForce().
    local requiredForce is ship:mass * g.

    return requiredForce / shipPossibleThrust().
}