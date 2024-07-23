
function launchMain {
    doLaunch().
    circulariseOrbit(eta:apoapsis).
    
    rcs off.
}

function doLaunch {
    // Initial setup
    rcs on.
    lock throttle to 1.
    lock steering to heading(90, 90).

    print "Blast off!".

    // Launch
    stage.

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

function calculateGravityTurn {
    local altAboveTurnPoint is alt:radar - 10000.
    return (6.25e-9 * altAboveTurnPoint^2) - (0.0015 * altAboveTurnPoint) + 84.375.
}

runOncePath("0:/utility.ks").
launchMain().