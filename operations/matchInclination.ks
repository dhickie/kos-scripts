// Script variables
local inclinationBurnNodeType is "".

// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/vector.ks").
runOncePath("0:/utilities/maneuver.ks").

// Matches the inclination of the current target orbiting the same
// body as the ship
function matchInclinationToTarget {
    // Calculate the normal vectors of the two orbits
    local shipNormal is calculateOrbitNormal(ship).
    local targetNormal is calculateOrbitNormal(target).

    matchInclinationToNormal(shipNormal, targetNormal).
}

// Matches the inclination of the the equator of the current body
function matchInclinationToEquator {
    // Calculate the normal of the ship orbit, and use the angular momentum
    // vector of the body for the target normal
    local shipNormal is calculateOrbitNormal(ship).
    local northPole is latLng(90, 0).
    local targetNormal is northPole:position - ship:body:position.

    matchInclinationToNormal(shipNormal, targetNormal).
}

// Matches the inclination of the current orbit to a hypothetical orbit
// with the specified normal vector
function matchInclinationToNormal {
    parameter shipNormal, targetNormal.

    print "Calculating ascending/descending nodes".

    // Calculate how long until we need to burn to match inclination
    print "Determining closest node".
    local burnEta is calculateInclinationBurnEta(shipNormal, targetNormal).

    // Calculate the burn required to match the target inclination
    print "Calculating inclination burn".
    local burnNode is calculateInclinationBurn(burnEta, shipNormal, targetNormal).

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

    // Return whichever is soonest, and let the rest of the script know which we've chosen
    // If the node is under a minute away, choose the next one instead
    if ascendingNodeEta < descendingNodeEta and ascendingNodeEta > 60 {
        print "Burning at ascending node".
        set inclinationBurnNodeType to "ascending".
        return ascendingNodeEta.
    } else if ascendingNodeEta < descendingNodeEta and ascendingNodeEta < 60 {
        print "Burning at descending node".
        set inclinationBurnNodeType to "descending".
        return descendingNodeEta.
    } else if descendingNodeEta < ascendingNodeEta and descendingNodeEta > 60{
        print "Burning at descending node".
        set inclinationBurnNodeType to "descending".
        return descendingNodeEta.
    } else {
        print "Burning at ascending node".
        set inclinationBurnNodeType to "ascending".
        return ascendingNodeEta.
    }
}

function calculateInclinationBurn {
    parameter burnEta, shipNormal, targetNormal.

    // Calculate the ship's current velocity at that time
    local shipStartingVelocity is velocityAt(ship, time:seconds + burnEta):orbit.

    // Calculate the final velocity at that time, after the burn
    // Same magnitude as starting velocity, but rotated to have the same inclination as the target
    local inclinationChange is vAng(shipNormal, targetNormal).
    local radialVector is positionAt(ship, time:seconds + burnEta) - ship:body:position.
    local shipFinalVelocity is v(0,0,0).
    if (inclinationBurnNodeType = "ascending") {
        set shipFinalVelocity to rotateVectorAboutAxis(shipStartingVelocity, radialVector, inclinationChange).
    } else {
        set shipFinalVelocity to rotateVectorAboutAxis(shipStartingVelocity, radialVector, -inclinationChange).
    }

    // Get the burn deltaV by subtracting final from initial velocity
    local deltaV is shipFinalVelocity - shipStartingVelocity.

    return createManeuverFromDeltaV(burnEta, deltaV).
}