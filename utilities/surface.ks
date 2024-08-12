// Dependencies
runOncePath("0:/utilities/orbit.ks").

// Calculates the throttle required to ensure we have 0 velocity when reaching
// the surface
function calculateDescentThrottleToSurface {
    local u is ship:velocity:surface:mag.
    local s is alt:radar - 10.
    local requiredAcceleration is (u^2) / (2*s).

    local netMaxThrust is ship:availableThrust * 1000 - calculateGravity().
    local maxAcceleration is netMaxThrust / (ship:mass * 1000).

    return requiredAcceleration / maxAcceleration.
}

// Calculates the throttle required to ensure we have 0 velocity when descending
// the specified altitude
function calculateDescentThrottleToAltitude {
    parameter targetAltitude.

    local u is ship:velocity:surface:mag.
    local s is ship:altitude - targetAltitude.
    local requiredAcceleration is (u^2) / (2*s).

    local netMaxThrust is ship:availableThrust * 1000 - calculateGravity().
    local maxAcceleration is netMaxThrust / (ship:mass * 1000).

    return requiredAcceleration / maxAcceleration.
}