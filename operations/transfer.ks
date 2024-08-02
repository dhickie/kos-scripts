// Script variables
local targetAltitude is 0.

// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/vector.ks").
runOncePath("0:/utilities/maneuver.ks").
runOncePath("0:/operations/orbit.ks").

function transferToTarget {
    parameter tgtAlt.
    set targetAltitude to tgtAlt.

    print "Calculating initial node".
    // Calculate orbital period of transfer orbit
    local transferOrbit is calculateTransferOrbit().
    local transferDuration is transferOrbit:period  / 2.

    // Calculate how far target moves in this time
    local targetMovement is calculateTargetMovementDuringTransfer(transferDuration).

    // Calculate the vector that points at the point opposite the target offset
    // by the target's movement during the maneuver
    local opposite is ship:body:position - target:position.
    local orbitNormal is vCrs(ship:body:position, ship:velocity:orbit).
    local nodeVector is rotateVectorAboutAxis(opposite, orbitNormal, -targetMovement).

    // Calculate the ship's ETA at that point
    local nodeEta is calculateEtaFromVector(nodeVector, orbitNormal, ship).

    // If the node is too soon, do it on the next orbit
    if (nodeEta < 120) { 
        set nodeEta to nodeEta + ship:orbit:period.
    }

    // Calculate the required increase in velocity to reach projected apoapsis
    local requiredVelocity is calculateOrbitalVelocity(ship:body, ship:orbit:semimajoraxis, transferOrbit:semimajoraxis).
    local deltaV is requiredVelocity - ship:velocity:orbit:mag.

    // Refine the node with hill cimbing to reach desired final altitude
    local initialNode is node(timeSpan(nodeEta), 0, 0, deltaV).
    local refinedNode is refineTransferNode(initialNode).

    // Execute the transfer burn
    executeManeuver(refinedNode).

    // Circularise the orbit around the target
    local timeToPeriapsis is ship:orbit:nextPatch:eta:periapsis.
    circulariseOrbit(timeToPeriapsis).
}

function calculateTransferOrbit {
    local orbitPe is ship:orbit:semimajoraxis.
    local orbitAp is target:orbit:semimajoraxis.
    local e is (orbitAp - orbitPe) / (orbitAp + orbitPe).
    local inc is ship:orbit:inclination.
    local sma is (orbitAp + orbitPe) / 2.
    local lan is ship:orbit:lan.
    local argPe is ship:orbit:argumentofperiapsis.
    local mEp is ship:orbit:meananomalyatepoch.
    local t is ship:orbit:epoch.
    local orbitBody is ship:orbit:body.

    return createOrbit(inc, e, sma, lan, argPe, mEp, t, orbitBody).
}

function calculateTargetMovementDuringTransfer {
    parameter transferDuration.

    return (transferDuration / target:orbit:period) * 360.
}

// Refine the initial node with a combination of hill climbing and bidirectional searching
// to ensure the orbit is in the right direction
function refineTransferNode {
    parameter initialNode.

    local refinedNode is hillClimb(initialNode, orbitScoringFunction@, orbitVelocityLimitFunction@, 2).
    add refinedNode.
    local timeOfClosestApproach is time:seconds + refinedNode:orbit:nextPatch:eta:periapsis.
    if (isOrbitAntiClockwise(timeOfClosestApproach)) {
        remove refinedNode.
        return refinedNode.
    } else {
        remove refinedNode.
        set refinedNode to biDirectionalSearch(refinedNode, conditionCheckFunction@).
        return refineTransferNode(refinedNode).
    }
}

function hillClimb {
    parameter initialNode, // The node to start from 
        scoringFunction, // A function delegate that scores nodes to determine if they've improved
        velocityLimitFunction, // A function that limits the maximum velocity a node can reach
        initialModFactor. // The initial amount we should modify node parameters by in candidates

    local nodeToBeat is initialNode.
    local scoreToBeat is scoringFunction(nodeToBeat).

    local modFactor is initialModFactor.
    until modFactor < 0.25 {
        local resultFound is false.
        until resultFound {
            local startingScore is scoreToBeat.
            local candidates is list(
                node(timeSpan(nodeToBeat:eta), 0, 0, velocityLimitFunction(nodeToBeat:prograde + modFactor)),
                node(timeSpan(nodeToBeat:eta), 0, 0, nodeToBeat:prograde - modFactor),
                node(timeSpan(nodeToBeat:eta + modFactor), 0, 0, nodeToBeat:prograde),
                node(timeSpan(nodeToBeat:eta - modFactor), 0, 0, nodeToBeat:prograde),
                node(timeSpan(nodeToBeat:eta + modFactor), 0, 0, velocityLimitFunction(nodeToBeat:prograde + modFactor)),
                node(timeSpan(nodeToBeat:eta - modFactor), 0, 0, nodeToBeat:prograde - modFactor)
            ).

            for candidate in candidates {
                local candidateScore is scoringFunction(candidate).
                if (candidateScore < scoreToBeat) {
                    set nodeToBeat to candidate.
                    set scoreToBeat to candidateScore.
                    print "Score to beat: " + scoreToBeat.
                }
            }

            if scoreToBeat = startingScore {
                set resultFound to true.
            }
        }

        set modFactor to modFactor / 2.
    }

    return nodeToBeat.
}

// Moves the burn node in both directions in time until a condition is true
function biDirectionalSearch {
    parameter initialNode, conditionFunction.

    local conditionTrue is false.
    local result is initialNode.
    local modFactor is 1.
    until conditionTrue {
        local candidates is list(
                node(timeSpan(initialNode:eta - modFactor), initialNode:radialOut, initialNode:normal, initialNode:prograde),
                node(timeSpan(initialNode:eta + modFactor), initialNode:radialOut, initialNode:normal, initialNode:prograde)
        ).

        for candidate in candidates {
            if (conditionFunction(candidate)) {
                set result to candidate.
                set conditionTrue to true.
            } else {
                set modFactor to modFactor + 1.
            }
        }
    }

    return result.
}

function orbitScoringFunction {
    parameter nodeToScore.

    add nodeToScore.

    // If the resulting orbit doesn't contain an encounter with the target body
    // then calculate the distance between the ship and the target point at the apoapsis
    local scoringTimestamp is 0.
    if not nodeToScore:orbit:hasNextPatch {
        set scoringTimestamp to time:seconds + nodeToScore:orbit:eta:apoapsis.
    } else {
        set scoringTimestamp to time:seconds + nodeToScore:orbit:nextPatch:eta:periapsis.
    }

    local bodyPosition is positionAt(target, scoringTimestamp) - positionAt(ship, scoringTimestamp).

    // Calculate the altitude component of the score
    local score is abs(bodyPosition:mag - target:radius - targetAltitude).

    remove nodeToScore.
    return score.
}

function orbitVelocityLimitFunction {
    parameter vIn.

    // Don't let the velocity exceed the amount that would place the apopasis at targetAltitude
    // past the target's apoapsis
    local maxApoapsis is target:orbit:apoapsis + target:radius + targetAltitude.
    local maxSma is (ship:orbit:periapsis + maxApoapsis) / 2.
    local orbitVelocity is calculateOrbitalVelocity(ship:body, ship:orbit:semimajoraxis, maxSma).

    if vIn > orbitVelocity {
        return orbitVelocity.
    } else {
        return vIn.
    }
}

function conditionCheckFunction {
    parameter nodeToCheck.

    add nodeToCheck.
    local timeOfClosestApproach is time:seconds + nodeToCheck:orbit:nextPatch:eta:periapsis.
    local result is isOrbitAntiClockwise(timeOfClosestApproach).
    remove nodeToCheck.

    return result.
}

function isOrbitAntiClockwise {
    parameter timeToCheck.

    local bodyNormal is calculateOrbitNormal(target).
    local shipVelocity is velocityAt(ship, timeToCheck):orbit - velocityAt(target, timeToCheck):orbit.
    local bodyPosition is positionAt(target, timeToCheck) - positionAt(ship, timeToCheck).
    local shipNormal is vCrs(bodyPosition, shipVelocity).

    if (vAng(bodyNormal, shipNormal) > 90) {
        return true.
    } else {
        return false.
    }
}