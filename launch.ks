
function main {
    doLaunch().
    circulariseOrbit().
    //matchTargetInclination().
    wait until false.
}

function doLaunch {
    // Initial setup
    rcs on.
    lock throttle to 1.
    lock steering to heading(90, 90).

    // Launch
    stage.

    // Setup launch staging trigger
    local stageMaxThrust is ship:maxThrustAt(0).
    when (ship:maxThrustAt(0) < stageMaxThrust) then {
        if stage:ready {
            stage.
        }
    }

    // Wait until start of gravity turn, and begin
    wait until alt:radar > 10000.
    lock steering to heading(90, calculateGravityTurn()).

    // Wait until apopasis gets to 100k and kill throttle
    wait until ship:apoapsis >= 100000.
    lock throttle to 0.

    // Wait until we get out of atmo before continuing
    wait until alt:radar > 70000.
}

function circulariseOrbit {
    // Lock the steering to prograde at apopasis
    local velocityAtApoapsis is velocityAt(ship, time:seconds + eta:apoapsis):orbit.
    lock steering to velocityAtApoapsis:normalized.

    // Calculate required orbit velocity
    local requiredVelocity is calculateOrbitVelocity(kerbin:radius + ship:apoapsis).
    local deltaV is requiredVelocity - velocityAtApoapsis:mag.

    // Add the burn to the flight plan (for visuals)
    local burnNode is node(timeSpan(eta:apoapsis), 0, 0, deltaV).
    add burnNode.

    // Wait until the burn should start
    local burnDuration is calculateManeuverBurnTime(burnNode).
    local waitTime is eta:apoapsis - (burnDuration / 2).
    wait waitTime.

    // Perform the burn, tailing down to 0 for an accurate burn
    lock throttle to max((requiredVelocity - ship:velocity:orbit:mag)/50, 0.05).
    wait until ship:velocity:orbit:mag >= requiredVelocity.
    lock throttle to 0.
}

function calculateGravityTurn {
    local altAboveTurnPoint is alt:radar - 10000.
    return (6.25e-9 * altAboveTurnPoint^2) - (0.0015 * altAboveTurnPoint) + 84.375.
}

function calculateOrbitVelocity {
    parameter orbitRadius. // From the centre of mass

    return sqrt(kerbin:mu / orbitRadius).
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

main().