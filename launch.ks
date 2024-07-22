
function launchMain {
    doLaunch().
    circulariseOrbit().
}

function doLaunch {
    // Initial setup
    rcs on.
    lock throttle to 1.
    lock steering to heading(90, 90).

    print "Blast off!".

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
    print "Beginning gravity turn".
    lock steering to heading(90, calculateGravityTurn()).

    // Wait until apopasis gets to 100k and kill throttle
    wait until ship:apoapsis >= 100000.
    print "Target apoapsis reached, waiting to leave atmo".
    lock throttle to 0.

    // Wait until we get out of atmo before continuing
    wait until alt:radar > 70000.
}

function circulariseOrbit {
    // Lock the steering to prograde at apopasis
    print "Calculating circularisation burn".
    local velocityAtApoapsis is velocityAt(ship, time:seconds + eta:apoapsis):orbit.
    lock steering to velocityAtApoapsis:normalized.

    // Calculate required orbit velocity
    local requiredVelocity is calculateOrbitVelocity(kerbin:radius + ship:apoapsis).
    local deltaV is requiredVelocity - velocityAtApoapsis:mag.

    // Add the burn to the flight plan
    local burnNode is node(timeSpan(eta:apoapsis), 0, 0, deltaV).
    add burnNode.

    // Execute the burn
    print "Executing circularisation burn".
    executeManeuver(burnNode).
    remove burnNode.
}

function calculateGravityTurn {
    local altAboveTurnPoint is alt:radar - 10000.
    return (6.25e-9 * altAboveTurnPoint^2) - (0.0015 * altAboveTurnPoint) + 84.375.
}

function calculateOrbitVelocity {
    parameter orbitRadius. // From the centre of mass

    return sqrt(kerbin:mu / orbitRadius).
}

runOncePath("0:/utility.ks").
launchMain().