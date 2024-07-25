// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/maneuver.ks").
runOncePath("0:/utilities/ship.ks").

function land {
    killLateralVelocity().

    lock steering to retrograde.
    
    waitUntilSuicideBurn().
    
    // Extend legs

    performSuicideBurn().
}

function killLateralVelocity {
    // Calculate the orbit normal
    local orbitNormal is calculateOrbitNormal(ship).

    // Calculate the lateral vector in the direction of the ship's velocity
    local lateralVector is vCrs(orbitNormal, ship:body:position):normalized.

    // Calculate the amount of lateral velocity we're currently holding
    local lateralVelocity is vDot(ship:velocity:surface, lateralVector).

    // Create and execute a maneuver with the opposite deltaV
    local mnv is createManeuverFromDeltaV(5, -lateralVelocity).
    executeManeuver(mnv).
}

function waitUntilSuicideBurn {
    // Lock a variable to show how long it would currently take
    // to stop the ship
    lock timeToStop to (ship:velocity:surface:mag * shipPossibleThrust()) / ship:mass.

    // Lock a variable to show how long we have until we hit the surface
    lock timeToSurface to calculateTimeToSurface().

    // Wait until we hit the last point we can burn
    wait until timeToStop <= timeToSurface.
}

function performSuicideBurn {
    lock throttle to 1.

    wait until alt:radar < 0.5.

    lock throttle to 0.
}

// Calculates how long it would take to hit the ground below under
// the current acceleration from gravity, using the SUVAT equations
// and the quadratic equation
function calculateTimeToSurface {
    local g is ship:body:mu / ship:body:position:mag^2.
    local u is ship:velocity:surface.
    local s is alt:radar.

    local t1 is (-u + sqrt(u^2 - 2*g*s)) / g.
    local t2 is (-u - sqrt(u^2 - 2*g*s)) / g.

    if t1 > t2 {
        return t1.
    } else {
        return t2.
    }
}