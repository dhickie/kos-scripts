function executeManeuver {
    parameter mnv.

    // Point at the burn vector
    local originalBurnVector is mnv:burnVector.
    lock steering to mnv:burnVector.

    // Calculate when we need to start throttling down to avoid overshooting
    lock rampDownPoint to ship:availableThrust / ship:mass.

    // Wait until the burn should begin
    local burnDuration is calculateManeuverBurnTime(mnv).
    local waitTime is mnv:eta - (burnDuration / 2).
    wait waitTime.

    // Begin the burn
    lock throttle to 1.

    // Wait until we get towards the end of the burn
    wait until mnv:burnVector:mag < 200.

    // Set the throttle to ramp down as we approach target velocity
    lock throttle to max(mnv:burnVector:mag / rampDownPoint, 0.05).

    // Wait until the current burn vector has deviated by 30 degrees from the original
    // burn vector, then kill the throttle
    wait until vAng(originalBurnVector, mnv:burnVector) >= 30.
    lock throttle to 0.
    unlock steering.
}

function calculateManeuverBurnTime {
    parameter burnNode.

    list engines in en.
    // TODO figure out how to get thrust and isp of current stage
    local thrust is en[1]:availableThrust.
    local initialMass is ship:mass.
    local e is constant():e.
    local engineIsp is en[1]:isp.
    local g is 9.80665.
    local deltaV is burnNode:deltaV:mag.

    return g * initialMass * engineIsp * (1 - e^(-deltaV/(g * engineIsp))) / thrust.
}