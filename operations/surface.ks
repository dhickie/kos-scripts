// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/surface.ks").

function setAltitude {
    parameter targetAltitude.

    local delta is targetAltitude - ship:body:position:mag + ship:body:radius.

    if delta > 0 {
        ascendToAltitude(targetAltitude).
    } else {
        descendToAltitude(targetAltitude).
    }
}

function ascendToAltitude {
    parameter targetAltitude.

    lock steering to up.
    lock throttle to 1.

    wait until ship:apoapsis >= targetAltitude.
    lock throttle to 0.

    wait until ship:altitude >= targetAltitude.
    lock throttle to calculateHoverThrottle().
}

function descendToAltitude {
    parameter targetAltitude.

    lock steering to up.
    lock throttle to 0.

    lock descentThrottle to calculateDescentThrottleToAltitude(targetAltitude).
    wait until descentThrottle >= 1.
    lock throttle to descentThrottle.
    wait until descentThrottle < 0.01.
    lock throttle to calculateHoverThrottle().
}

// Calculates the throttle required to hover at the current altitude
function calculateHoverThrottle {
    local gravityForce is calculateGravity().

    return gravityForce / (ship:availableThrust * 1000).
}