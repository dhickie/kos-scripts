function main {
    matchTargetInclination().
    // performTransferBurn().
    // performRetroBurn().
}

// Assumes target is orbiting the same body as the ship
function matchTargetInclination {
    // Calculate the orbit normals of two orbitables
    local shipNormal is calculateShipOrbitNormal().
    local targetNormal is calculateTargetOrbitNormal(mun).

    // Calculate the vector on which the ascending and descending nodes lie using a cross product
    local nodeVector is vCrs(shipNormal, targetNormal).

    // Calculate the eta of the two nodes
    local node1eta is calculateNodeEta(nodeVector).
    local node2eta is calculateNodeEta(-nodeVector).
}

function calculateShipOrbitNormal {
    local shipPosition is ship:body:position.
    local shipVelocity is ship:velocity:orbit.

    return vCrs(shipPosition, shipVelocity).
}

function calculateTargetOrbitNormal {
    parameter orbitable.

    // Positions are relative to the ship, so the position of the target
    // needs to be subtracted from the position of the body the target orbits
    // to get the position vector from the target to the body
    local targetPosition is orbitable:body:position - orbitable:position.
    local targetVelocity is orbitable:velocity:orbit.

    return vCrs(targetPosition, targetVelocity).
}

function calculateNodeEta {
    parameter nodeVector.

    local periapsisVector is calculatePeriapsisVector().
    local trueAnomaly is vAng(periapsisVector, nodeVector).
}

// Calculates the vector from the body to the periapsis of the ship's current orbit
function calculatePeriapsisVector {
    local positionAtPeriapsisRelativeToShip is positionAt(ship, timeSpan(time:seconds + eta:periapsis)).
    return positionAtPeriapsisRelativeToShip - ship:body:position.
}

main().