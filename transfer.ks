function transferMain {
    matchTargetInclination().
    // performTransferBurn().
    // performRetroBurn().
}

// Assumes target is orbiting the same body as the ship
function matchTargetInclination {
    // Needed later to calculate when the target is going to cross the line of AN/DN nodes
    global inclinationBurnNodeVector is v(0, 0, 0).

    // Calculate the normal vectors of the two orbits
    local shipNormal is calculateShipOrbitNormal().
    local targetNormal is calculateTargetOrbitNormal(mun).

    // Calculate how long until we need to burn to match inclination
    local burnEta is calculateInclinationBurnEta(shipNormal, targetNormal).

    // Calculate the burn required to match the target inclination
    local burnNode is calculateInclinationBurn(burnEta, targetNormal).
    add burnNode.

    executeManeuver(burnNode).    
}

function calculateInclinationBurnEta {
    parameter shipNormal, targetNormal.

    // Calculate the vector of the ascending node - this is always shipNormal x targetNormal.
    // Descending node is targetNormal x shipNormal
    local nodeVector is vCrs(shipNormal, targetNormal).

    // Calculate the eta of the two nodes
    local ascendingNodeEta is calculateNodeEta(nodeVector, shipNormal, ship).
    local descendingNodeEta is calculateNodeEta(-nodeVector, shipNormal, ship).

    // Return whichever is soonest, and let the rest of the script which we've chosen
    if ascendingNodeEta < descendingNodeEta {
        set inclinationBurnNodeVector to nodeVector.
        return ascendingNodeEta.
    } else {
        set inclinationBurnNodeVector to -nodeVector.
        return descendingNodeEta.
    }
}

function calculateInclinationBurn {
    parameter burnEta, targetNormal.

    // Calculate the ship's current velocity at that time
    local shipStartingVelocity is velocityAt(ship, time:seconds + burnEta):orbit.

    // Calculate the final velocity at that time, after the burn
    // (the same direction as the target's velocity, with the ship's velocity's starting magnitude)
    local targetNodeEta is calculateNodeEta(inclinationBurnNodeVector, targetNormal, mun).
    local targetVelocity is velocityAt(mun, time:seconds + targetNodeEta):orbit.
    local shipFinalVelocity is targetVelocity.
    set shipFinalVelocity:mag to shipStartingVelocity:mag.

    // Get the burn deltaV by subtracting final from initial velocity
    local deltaV is shipFinalVelocity - shipStartingVelocity.

    return createNodeFromDeltaV(burnEta, deltaV).
}

function createNodeFromDeltaV {
    parameter nodeEta, deltaV.

    // Get the prograde, normal & radial vectors for the ship
    local progradeVector is velocityAt(ship, time:seconds + nodeEta):orbit:normalized.
    local normalVector is vCrs(ship:body:position, progradeVector):normalized.
    local radialVector is -ship:body:position:normalized.

    // Use dot products to project deltaV onto each node component
    local progradeDeltaV is vDot(deltaV, progradeVector).
    local normalDeltaV is vDot(deltaV, normalVector).
    local radialDeltaV is vDot(deltaV, radialVector).

    return node(timeSpan(nodeEta), radialDeltaV, normalDeltaV, progradeDeltaV).
}

function calculateShipOrbitNormal {
    local shipPosition is ship:body:position.
    local shipVelocity is ship:velocity:orbit.

    return vCrs(shipPosition, shipVelocity).
}

function calculateTargetOrbitNormal {
    parameter transferTarget.

    // Positions are relative to the ship, so the position of the target
    // needs to be subtracted from the position of the body the target orbits
    // to get the position vector from the target to the body
    local targetPosition is ship:body:position - transferTarget:position.
    local targetVelocity is transferTarget:velocity:orbit.

    return vCrs(targetPosition, targetVelocity).
}

function calculateNodeEta {
    parameter nodeVector, orbitNormal, orbitable.

    // Calculate the mean anomaly of the node on the current orbit
    local periapsisVector is calculatePeriapsisVector(orbitable).
    local nodeTrueAnomaly is calculateTrueAnomaly(nodeVector, periapsisVector, orbitNormal).
    local nodeMeanAnomaly is calculateMeanAnomalyFromTrueAnomaly(nodeTrueAnomaly).

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

    return arcTan((sqrt(1-e^2) * sin(f)) / (e + cos(f))).
}

// Calculates the mean anomaly from the true anomaly for the current orbit using Kepler's equation
function calculateMeanAnomalyFromEccentricAnomaly {
    parameter eccentricAnomaly.

    local e is ship:orbit:eccentricity.

    return eccentricAnomaly - (e * sin(eccentricAnomaly)).
}

runPath("0:/utility.ks").
transferMain().