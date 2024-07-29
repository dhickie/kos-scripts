// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/maneuver.ks").

// Circularises an orbit at the point the ship is at for the provided eta
function circulariseOrbit {
    parameter maneuverEta.

    // Calculate required velocity
    print "Calculating circularisation burn".
    local bodyAtEta is getBodyAtEta(ship:orbit, maneuverEta).
    local positionAtEta is positionAt(ship, time:seconds + maneuverEta).
    local bodyPositionAtEta is positionAt(bodyAtEta, time:seconds + maneuverEta).

    local shipVelocityAtEta is velocityAt(ship, time:seconds + maneuverEta).
    local velocityAtEta is 0.
    local orbitalRadius is 0.
    if bodyAtEta:name = ship:body:name {
        set velocityAtEta to shipVelocityAtEta:orbit.
        set orbitalRadius to (positionAtEta - ship:body:position):mag.
    } else {
        local bodyVelocityAtEta is velocityAt(bodyAtEta, time:seconds + maneuverEta).
        set velocityAtEta to bodyVelocityAtEta:orbit - shipVelocityAtEta:orbit.
        set orbitalRadius to (positionAtEta - bodyPositionAtEta):mag.
    }

    print positionAtEta:mag.
    print bodyPositionAtEta:mag.
    print orbitalRadius.
    local requiredVelocity is calculateOrbitalVelocity(bodyAtEta, orbitalRadius, orbitalRadius).
    local deltaV is requiredVelocity - velocityAtEta:mag.

    // Add the burn to the flight plan
    local burnNode is node(timeSpan(maneuverEta), 0, 0, deltaV).

    // Execute the burn
    print "Executing circularisation burn".
    executeManeuver(burnNode).
}

// Circularises the current stable orbit at the requested altitude
function circulariseOrbitAtAltitude {
    parameter targetAltitude.

    // Get one side to the target altitude
    performApsisBurn(targetAltitude).
    // Get the other side to the target altitude
    performApsisBurn(targetAltitude).
}

// Performs a burn at the apoapsis or periapsis (whichever is sooner), to raise or
// lower the opposing side of the orbit to the requested altitude
function performApsisBurn {
    parameter targetAltitude.

    // Calculate when the burn will be
    local burnEta is 0.
    if (eta:apoapsis < eta:periapsis) {
        set burnEta to eta:apoapsis.
    } else {
        set burnEta to eta:periapsis.
    }

    // Calculate what the velocity at this point should be, for the orbit on the other side
    // to reach the target altitude
    local altAtBurn is (positionAt(ship, time:seconds + burnEta) - ship:body:position):mag.
    local sma is (altAtBurn + targetAltitude + ship:body:radius) / 2.
    local requiredVelocity is calculateOrbitalVelocity(ship:body, altAtBurn, sma).
    local deltaV is requiredVelocity - velocityAt(ship, time:seconds + burnEta):orbit:mag.
    local burnNode is node(timeSpan(burnEta), 0, 0, deltaV).
    executeManeuver(burnNode).
}