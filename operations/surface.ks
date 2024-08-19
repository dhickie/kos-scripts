// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/surface.ks").
runOncePath("0:/utilities/kos.ks").

function setAltitude {
    parameter targetAltitude.

    local delta is targetAltitude - ship:body:position:mag + ship:body:radius.

    if delta > 0 {
        ascendToAltitude(targetAltitude).
    } else {
        descendToAltitude(targetAltitude).
    }

    unlock steering.
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

// Travels to the provided latitude/longitude, maintaining the current altitude
function travelToPoint {
    parameter lat,lng.

    local destination is latLng(lat, lng).
    lock steering to heading(destination:heading, calculateMinPitch()).

    wait until destination:distance < 40000.
    lock steering to srfRetrograde.
    wait 0.5.
    lock throttle to ship:velocity:surface:mag / ((ship:availableThrust / ship:mass) / 2).
}

// Calculates the throttle required to hover at the current altitude
function calculateHoverThrottle {
    // Calculate the throttle that would maintain the current vertical velocity
    local gravityForce is max(calculateEffectiveGravity(), 0).
    local baselineThrottle is gravityForce / (ship:availableThrust * 1000).

    // Calculate the vertical throttle required to get to 0 vertical velocity
    local taperPoint is (ship:availableThrust / ship:mass) / 2.
    local verticalThrottle is baselineThrottle - (ship:verticalSpeed / taperPoint).
    local angleToHorizon is ship:facing:pitch.

    // Calculate the total throttle required such that the ship has sufficient 
    // vertical throttle
    if angleToHorizon <= 0 {
        return 1.
    } else {
        local perfectThrottle is verticalThrottle / sin(angleToHorizon).
        // Just cut the throttle if it gets tiny
        if perfectThrottle < 0.001 {
            set perfectThrottle to 0.
        }

        return perfectThrottle.
    }
}

// Calculates the minimum pitch the ship can orient at in order to maintain
// the vertical thrust required to maintain current altitude
function calculateMinPitch {
    local verticalThrust is calculateHoverThrottle().
    local currentMaxThrust is ship:availableThrust().

    // Allow a buffer for the ship over compensating with its steering
    return arcSin(verticalThrust / currentMaxThrust) + 5.
}