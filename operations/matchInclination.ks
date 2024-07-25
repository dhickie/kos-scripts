// Dependencies
runOncePath("0:/utilities/utility.ks").

function matchInclination {
    // Needed later to calculate which direction to burn in to match inclination
    print "Calculating ascending/descending nodes".
    global inclinationBurnNodeType is "".

    // Calculate the normal vectors of the two orbits
    local shipNormal is calculateShipOrbitNormal().
    local targetNormal is calculateTargetOrbitNormal().

    // Calculate how long until we need to burn to match inclination
    print "Determining closest node".
    local burnEta is calculateInclinationBurnEta(shipNormal, targetNormal).

    // Calculate the burn required to match the target inclination
    print "Calculating inclination burn".
    local burnNode is calculateInclinationBurn(burnEta).
    add burnNode.

    print "Executing inclination burn".
    executeManeuver(burnNode).  
}

function calculateInclinationBurnEta {
    parameter shipNormal, targetNormal.

    // Calculate the vector of the ascending node - this is always shipNormal x targetNormal.
    // Descending node is targetNormal x shipNormal
    local nodeVector is vCrs(shipNormal, targetNormal).

    // Calculate the eta of the two nodes
    local ascendingNodeEta is calculateEtaFromVector(nodeVector, shipNormal, ship).
    local descendingNodeEta is calculateEtaFromVector(-nodeVector, shipNormal, ship).

    // Return whichever is soonest, and let the rest of the script which we've chosen
    if ascendingNodeEta < descendingNodeEta {
        print "Burning at ascending node".
        set inclinationBurnNodeType to "ascending".
        return ascendingNodeEta.
    } else {
        print "Burning at descending node".
        set inclinationBurnNodeType to "descending".
        return descendingNodeEta.
    }
}

function calculateInclinationBurn {
    parameter burnEta.

    // Calculate the ship's current velocity at that time
    local shipStartingVelocity is velocityAt(ship, time:seconds + burnEta):orbit.

    // Calculate the final velocity at that time, after the burn
    // Same magnitude as starting velocity, but rotated to have the same inclination as the target
    local inclinationChange is abs(ship:orbit:inclination - target:orbit:inclination).
    local radialVector is -ship:body:position.
    local shipFinalVelocity is v(0,0,0).
    if (inclinationBurnNodeType = "ascending") {
        set shipFinalVelocity to rotateVectorAboutAxis(shipStartingVelocity, radialVector, inclinationChange).
    } else {
        set shipFinalVelocity to rotateVectorAboutAxis(shipStartingVelocity, radialVector, -inclinationChange).
    }

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
    // Positions are relative to the ship, so the position of the target
    // needs to be subtracted from the position of the body the target orbits
    // to get the position vector from the target to the body
    local targetPosition is ship:body:position - target:position.
    local targetVelocity is target:velocity:orbit.

    return vCrs(targetPosition, targetVelocity).
}