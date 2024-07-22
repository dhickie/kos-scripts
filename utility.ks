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

    if mnv:burnVector:mag >= 200 {
        // Begin the burn
        lock throttle to 1.

        // Wait until we get towards the end of the burn
        wait until mnv:burnVector:mag < 200.
    }

    // Set the throttle to ramp down as we approach target velocity
    lock throttle to max(mnv:burnVector:mag / rampDownPoint, 0.05).

    // Wait until the current burn vector has deviated by 30 degrees from the original
    // burn vector, then kill the throttle
    wait until vAng(originalBurnVector, mnv:burnVector) >= 30.
    lock throttle to 0.
    unlock steering.
    remove mnv.
}

function calculateManeuverBurnTime {
    parameter burnNode.

    list engines in en.
    // TODO figure out how to get thrust and isp of current stage
    local thrust is en[1]:availableThrust.
    local initialMass is ship:mass.
    local e is constant():e.
    local engineIsp is en[1]:ispAt(0).
    local g is 9.80665.
    local deltaV is burnNode:deltaV:mag.

    return g * initialMass * engineIsp * (1 - e^(-deltaV/(g * engineIsp))) / thrust.
}

// Performs a rotation of a vector clockwise about an axis by the specified number of degrees
// using the 3D vector rotation matrix
// https://en.wikipedia.org/wiki/Rotation_matrix
function rotateVectorAboutAxis {
    parameter vIn, // The vector to be rotated
        axis, // The axis about which to perform the rotation
        rotation. // The rotation, in degrees, to perform

    // Rotation is clockwise around the axis
    local xIn is vIn:x.
    local yIn is vIn:y.
    local zIn is vIn:z.
    local xA is axis:normalized:x.
    local yA is axis:normalized:y.
    local zA is axis:normalized:z.
    local rot is rotation.

    local xOut is ((cos(rot) + (xA^2 * (1 - cos(rot)))) * xIn) + (((xA * yA * (1 - cos(rot))) - (zA * sin(rot))) * yIn) + (((xA * zA * (1 - cos(rot))) + (yA * sin(rot))) * zIn).
    local yOut is (((yA * xA * (1 - cos(rot))) + (zA * sin(rot))) * xIn) + ((cos(rot) + (yA^2 * (1 - cos(rot)))) * yIn) + (((yA * zA * (1 - cos(rot))) - (xA * sin(rot))) * zIn).
    local zOut is (((zA * xA * (1 - cos(rot))) - (yA * sin(rot))) * xIn) + (((zA * yA * (1 - cos(rot))) + (xA * sin(rot))) * yIn) + ((cos(rot) + (zA^2 * (1 - cos(rot)))) * zIn).

    return v(xOut, yOut, zOut).
}

// Calculates the ETA until the provided orbitable arrives at the point along its orbit
// that is pointed to by nodeVector
function calculateEtaFromVector {
    parameter nodeVector, orbitNormal, orbitable.

    // Calculate the mean anomaly of the node on the current orbit
    local periapsisVector is calculatePeriapsisVector(orbitable).
    local nodeTrueAnomaly is calculateTrueAnomaly(nodeVector, periapsisVector, orbitNormal).

    return calculateEtaFromTrueAnomaly(nodeTrueAnomaly, orbitable).
}

// Calculates the ETA until the provided orbitable arrives at the point along its orbit
// defined by the provided true anomaly
function calculateEtaFromTrueAnomaly {
    parameter trueAnomaly, orbitable.

    // Calculate the mean anomaly of the node on the current orbit
    local nodeMeanAnomaly is calculateMeanAnomalyFromTrueAnomaly(trueAnomaly).

    // Calculate the difference between the orbitable's current mean anomaly and the node's mean anomaly
    local anomDiff is 0.
    local orbitableMeanAnomaly is calculateMeanAnomalyFromTrueAnomaly(orbitable:orbit:trueAnomaly).
    if nodeMeanAnomaly > orbitableMeanAnomaly {
        set anomDiff to nodeMeanAnomaly - orbitableMeanAnomaly.
    } else {
        set anomDiff to 360 - orbitableMeanAnomaly + nodeMeanAnomaly.
    }
    
    // Calculate how long it would take for the ship's mean anomaly to change by this amount
    // given the orbital period
    return (anomDiff / 360) * orbitable:orbit:period.
}

// Calculates the vector from the SOI body to the periapsis of an orbitable
function calculatePeriapsisVector {
    parameter orbitable.

    local periapsisEta is orbitable:orbit:eta:periapsis.

    local positionAtPeriapsisRelativeToShip is positionAt(orbitable, time:seconds + periapsisEta).
    return positionAtPeriapsisRelativeToShip - orbitable:body:position.
}

// Calculates the true anomaly of a position along an orbit, relative to the SOI body
function calculateTrueAnomaly {
    parameter nodeVector, periapsisVector, orbitNormal.

    local trueAnomaly is vAng(nodeVector, periapsisVector).

    // Calculate whether the node is currently on its way to the apopasis or the periapsis
    // If the former, then nodeVector x periapsisVector should point in the same direction as
    // the orbit normal
    if vCrs(nodeVector, periapsisVector):z > 0 and orbitNormal:z > 0 {
        return trueAnomaly.
    } else {
        return 360 - trueAnomaly.
    }
}

// Calculates the mean anomaly from the true anomaly for the current orbit
function calculateMeanAnomalyFromTrueAnomaly {
    parameter trueAnomaly.

    local eccentricAnomaly is calculateEccentricAnomalyFromTrueAnomaly(trueAnomaly).
    return calculateMeanAnomalyFromEccentricAnomaly(eccentricAnomaly).
}

// Calculates the eccentric anomaly from the true anomaly for the current orbit
function calculateEccentricAnomalyFromTrueAnomaly {
    parameter trueAnomaly.

    local e is ship:orbit:eccentricity.
    local f is trueAnomaly.
    return arcTan2(sqrt(1-e^2) * sin(f), e + cos(f)).
}

// Calculates the mean anomaly from the true anomaly for the current orbit using Kepler's equation
function calculateMeanAnomalyFromEccentricAnomaly {
    parameter eccentricAnomaly.

    local e is ship:orbit:eccentricity.

    return eccentricAnomaly - (e * sin(eccentricAnomaly)).
}

// Calculates the orbital velocity at any given point along an orbit
function calculateOrbitalVelocity {
    parameter orbitBody, // The body being orbited
        radius, // The radius of the body's position relative to the oribiting object
        semiMajorAxis. // The semi major axis of the orbit

    return sqrt(orbitBody:mu * ((2 / radius) - (1 / semiMajorAxis))).
}

// Circularises an orbit at the point the ship is at for the provided eta
function circulariseOrbit {
    parameter maneuverEta.

    // Calculate required velocity
    print "Calculating circularisation burn".
    local bodyAtEta is getBodyAtEta(ship:orbit, maneuverEta).
    local positionAtEta is positionAt(ship, time:seconds + maneuverEta).
    local velocityAtEta is velocityAt(ship, time:seconds + maneuverEta).
    local orbitalRadius is (positionAtEta - bodyAtEta:position):mag.
    local requiredVelocity is calculateOrbitalVelocity(bodyAtEta, orbitalRadius, orbitalRadius).
    local deltaV is requiredVelocity - velocityAtEta:orbit:mag.

    // Add the burn to the flight plan
    local burnNode is node(timeSpan(maneuverEta), 0, 0, deltaV).
    add burnNode.

    // Execute the burn
    print "Executing circularisation burn".
    executeManeuver(burnNode).
}

// Gets the body being orbited in the provided orbit at the provided eta
function getBodyAtEta {
    parameter calcOrbit, // The orbit to calculate the body for
        calcEta. // The ETA at which to calculate the body

    if calcOrbit:hasNextPatch and (calcOrbit:nextPatchEta < calcEta) {
        return getBodyAtEta(calcOrbit:nextPatch, calcEta).
    } else {
        return calcOrbit:body.
    }
}