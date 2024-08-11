// Dependencies
runOncePath("0:/operations/orbit.ks").
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/geocoordinates.ks").
runOncePath("0:/utilities/parts.ks").

function launchFromKerbin {
    rcs on.

    doKerbinLaunch().
    circulariseOrbit(eta:apoapsis).
    
    rcs off.
}

function launchFromVacuum {
    parameter targetAltitude.

    raiseLadders().
    doVacuumLaunch(targetAltitude).
    circulariseOrbit(eta:apoapsis).
}

function doKerbinLaunch {
    // Initial setup
    lock throttle to 1.
    local compassHeading is calculateCompassHeading().
    lock steering to heading(compassHeading, 90).

    print "Blast off!".

    // Launch
    stage.

    // Setup staging trigger
    local maxAvailableThrust is ship:availableThrustAt(0).
    when (ship:availableThrustAt(0) < maxAvailableThrust) then {
        wait until stage:ready.
        stage.
        wait 0.1.
        set maxAvailableThrust to ship:availableThrustAt(0).
        preserve.
    }

    // Wait until start of gravity turn, and begin
    wait until alt:radar > 10000.
    print "Beginning gravity turn".
    lock steering to heading(compassHeading, calculateGravityTurn()).

    // Wait until apopasis gets to 100k and kill throttle
    wait until ship:apoapsis >= 100000.
    print "Target apoapsis reached, waiting to leave atmo".
    lock throttle to 0.
    lock steering to heading(compassHeading, 0).

    // Wait until we get out of atmo before continuing
    wait until alt:radar > 70000.
    extendLauncherSolar().
    extendLauncherComms().
}

function doVacuumLaunch {
    parameter targetAltitude.

    lock throttle to 1.
    wait 0.5.
    local compassHeading is calculateCompassHeading().
    lock steering to heading(compassHeading, 45).
    legs off.
    lights off.

    wait until ship:apoapsis >= targetAltitude.

    lock throttle to 0.
}

// Calculates the compass direction the ship should point in to
// result in as low an inclination orbit as possible
function calculateCompassHeading {
    local equatorCrossingPoint is latLng(0, addToLongitude(ship:geoposition:lng, 90)).
    return equatorCrossingPoint:heading.
}

function calculateGravityTurn {
    local altAboveTurnPoint is alt:radar - 10000.
    return (6.25e-9 * altAboveTurnPoint^2) - (0.0015 * altAboveTurnPoint) + 84.375.
}