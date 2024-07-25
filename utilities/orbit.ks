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

// Gets the normal vector for the orbit of any orbital
function calculateOrbitNormal {
    parameter orbitable.

    local pos is v(0,0,0).
    if orbitable:name = ship:name {
        set pos to ship:body:position.
    } else {
        // Positions are relative to the ship, so the position of the target
        // needs to be subtracted from the position of the body the target orbits
        // to get the position vector from the target to the body
        set pos to ship:body:position - orbitable:position.
    }

    local vel is orbitable:velocity:orbit.

    return vCrs(pos, vel).
}