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
    local transferBurn is calculateTransferBurn().

    // Execute the transfer burn
    executeManeuver(transferBurn).

    // Do a correction burn when around 1/3 of the way to the periapsis
    local timeToPeriapsis is ship:orbit:nextPatch:eta:periapsis.
    local correctionBurn is calculateCorrectionBurn().

    // Execute the correction burn
    executeManeuver(correctionBurn).

    // Circularise the orbit around the target, minimising inclination
    local timeToPeriapsis is ship:orbit:nextPatch:eta:periapsis.
    circulariseOrbit(timeToPeriapsis, true).
}

function calculateTransferBurn {
    // Calculate orbital period of transfer orbit
    local transferOrbit is calculateInitialTransferOrbit().
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
    local radiusAtNode is (positionAt(ship, time:seconds + nodeEta) - ship:body:position):mag.
    local transferSma is (radiusAtNode + target:orbit:apoapsis) / 2.
    local requiredVelocity is calculateOrbitalVelocity(ship:body, radiusAtNode, transferSma).
    local deltaV is requiredVelocity - ship:velocity:orbit:mag.

    // Refine the node with hill cimbing to reach desired final altitude
    local initialNode is node(timeSpan(nodeEta), 0, 0, deltaV).
    return refineTransferNode(initialNode).
}

function calculateCorrectionBurn {
    local timeToPeriapsis is ship:orbit:nextPatch:eta:periapsis.
    local correctionEta is timeToPeriapsis / 3.
    local initialNode is node(timeSpan(correctionEta), 0, 0, 0).
    return refineCorrectionNode(initialNode).
}

function calculateInitialTransferOrbit {
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

    return refineNode(initialNode, false, transferOrbitScoringFunction@, list(true, false, false, true)).
}

// Refine the correction node with a combination of hill climbing and bidirectional searching
// to ensure the orbit is in the right direction
function refineCorrectionNode {
    parameter initialNode.

    return refineNode(initialNode, true, correctionOrbitScoringFunction@, list(false, true, true, true)).
}

function refineNode {
    parameter initialNode, searchForAntiClockwiseOrbit, orbitScoringFunction, hillClimbFactors.

    local refinedNode is hillClimb(initialNode, orbitScoringFunction, 8, hillClimbFactors).
    if (hasAntiClockwiseOrbit(refinedNode) or not searchForAntiClockwiseOrbit) {
        return refinedNode.
    } else {
        print "Searching for anticlockwise orbit".
        set refinedNode to biDirectionalSearch(refinedNode, hasAntiClockwiseOrbit@).
        return refineTransferNode(refinedNode).
    }
}

function hillClimb {
    parameter initialNode, // The node to start from 
        scoringFunction, // A function delegate that scores nodes to determine if they've improved
        initialModFactor,   // The initial amount we should modify node parameters by in candidates
        modificationFactors. // Which factors of the node should be modified in this hill climb

    local nodeToBeat is initialNode.
    local scoreToBeat is scoringFunction(nodeToBeat).

    local modFactor is initialModFactor.
    until modFactor < 0.25 {
        local resultFound is false.
        until resultFound {
            local startingScore is scoreToBeat.
            local candidates is list().

            if modificationFactors[0] {
                candidates:add(node(timeSpan(nodeToBeat:eta + modFactor), nodeToBeat:radialOut, nodeToBeat:normal, nodeToBeat:prograde)).
                candidates:add(node(timeSpan(nodeToBeat:eta - modFactor), nodeToBeat:radialOut, nodeToBeat:normal, nodeToBeat:prograde)).
            }
            if modificationFactors[1] {
                candidates:add(node(timeSpan(nodeToBeat:eta), nodeToBeat:radialOut + modFactor, nodeToBeat:normal, nodeToBeat:prograde)).
                candidates:add(node(timeSpan(nodeToBeat:eta), nodeToBeat:radialOut - modFactor, nodeToBeat:normal, nodeToBeat:prograde)).
            }
            if modificationFactors[2] {
                candidates:add(node(timeSpan(nodeToBeat:eta), nodeToBeat:radialOut, nodeToBeat:normal + modFactor, nodeToBeat:prograde)).
                candidates:add(node(timeSpan(nodeToBeat:eta), nodeToBeat:radialOut, nodeToBeat:normal - modFactor, nodeToBeat:prograde)).
            }
            if modificationFactors[3] {
                candidates:add(node(timeSpan(nodeToBeat:eta), nodeToBeat:radialOut, nodeToBeat:normal, nodeToBeat:prograde + modFactor)).
                candidates:add(node(timeSpan(nodeToBeat:eta), nodeToBeat:radialOut, nodeToBeat:normal, nodeToBeat:prograde - modFactor)).
            }

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
    local modFactor is 0.
    until conditionTrue {
        set modFactor to modFactor + 1.
        local candidates is list().
        candidates:add(node(timeSpan(initialNode:eta), initialNode:radialOut - modFactor, initialNode:normal, initialNode:prograde)).
        candidates:add(node(timeSpan(initialNode:eta), initialNode:radialOut + modFactor, initialNode:normal, initialNode:prograde)).

        for candidate in candidates {
            if (conditionFunction(candidate)) {
                set result to candidate.
                set conditionTrue to true.
            }
        }
    }

    return result.
}

function transferOrbitScoringFunction {
    parameter nodeToScore.

    add nodeToScore.

    // If the resulting orbit doesn't contain an encounter with the target body
    // then calculate the distance between the ship and the target altitude at the apoapsis
    local scoringTimestamp is 0.
    if not nodeToScore:orbit:hasNextPatch { // Doesn't have an encounter
        set scoringTimestamp to time:seconds + nodeToScore:orbit:eta:apoapsis.
    } else if nodeToScore:orbit:hasNextPatch and nodeToScore:orbit:nextPatch:body:name <> target:name { // Has an encounter with a different body
        set scoringTimestamp to time:seconds + nodeToScore:orbit:nextPatchEta.
    } else { // Has an encounter with the target body
        set scoringTimestamp to time:seconds + nodeToScore:orbit:nextPatch:eta:periapsis.
    }

    local shipPositionRelativeToBody is positionAt(ship, scoringTimestamp) - positionAt(target, scoringTimestamp).
    local score is abs(shipPositionRelativeToBody:mag - target:radius - targetAltitude).

    remove nodeToScore.

    return score.
}

function correctionOrbitScoringFunction {
    parameter nodeToScore.

    add nodeToScore.

    // If the resulting orbit doesn't contain an encounter with the target body
    // then calculate the distance between the ship and the target point at the apoapsis
    local scoringTimestamp is 0.
    if not nodeToScore:orbit:hasNextPatch { // Doesn't have an encounter
        set scoringTimestamp to time:seconds + nodeToScore:orbit:eta:apoapsis.
    } else if nodeToScore:orbit:hasNextPatch and nodeToScore:orbit:nextPatch:body:name <> target:name { // Has an encounter with a different body
        set scoringTimestamp to time:seconds + nodeToScore:orbit:nextPatchEta.
    } else { // Has an encounter with the target body
        set scoringTimestamp to time:seconds + nodeToScore:orbit:nextPatch:eta:periapsis.
    }

    local shipPositionRelativeToBody is positionAt(ship, scoringTimestamp) - positionAt(target, scoringTimestamp).
    // Take the x-z component to get the vector pointing at the equator at the same longitude
    local equatorVector is projectToHorizontalPlane(shipPositionRelativeToBody).
    set equatorVector:mag to targetAltitude + target:radius.

    // Calculate how far the periapsis is off the equator at the target altitude
    local score is abs((shipPositionRelativeToBody - equatorVector):mag).

    remove nodeToScore.
    return score.
}

// Checks whether the orbit around the target that results from the provided node
// has an anti clockwise orbit around the target
function hasAntiClockwiseOrbit {
    parameter nodeToCheck.

    add nodeToCheck.
    local result is false.
    if nodeToCheck:orbit:hasNextPatch and nodeToCheck:orbit:nextPatch:body:name = target:name {
        local timeToCheck is time:seconds + nodeToCheck:orbit:nextPatch:eta:periapsis.

        local bodyNormal is calculateOrbitNormal(target).
        local shipVelocity is velocityAt(ship, timeToCheck):orbit - velocityAt(target, timeToCheck):orbit.
        local bodyPosition is positionAt(target, timeToCheck) - positionAt(ship, timeToCheck).
        local shipNormal is vCrs(bodyPosition, shipVelocity).

        if (vAng(bodyNormal, shipNormal) < 90) {
            set result to true.
        }
    }

    remove nodeToCheck.
    return result.
}