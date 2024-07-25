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

    // Calculate the required increase in velocity to reach projected apoapsis
    local requiredVelocity is calculateOrbitalVelocity(ship:body, ship:orbit:semimajoraxis, transferOrbit:semimajoraxis).
    local deltaV is requiredVelocity - ship:velocity:orbit:mag.

    // Refine the node with hill cimbing to reach desired final altitude
    local initialNode is node(timeSpan(nodeEta), 0, 0, deltaV).
    local refinedNode is hillClimb(initialNode, orbitScoringFunction@, orbitVelocityLimitFunction@, 2).

    // Execute the transfer burn
    add refinedNode.
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

function orbitScoringFunction {
    parameter nodeToScore.

    add nodeToScore.

    // Ideally, the ship should have the periapsis of it's orbit with the target body at the target altitude
    // directly "behind" the body as it orbits (opposite it's velocity vector), to make the most advantage of a gravity assist
    // and result in an anti-clockwise orbit.

    // If the resulting orbit doesn't contain an encounter with the target body
    // then calculate the distance between the ship and the target point at the apoapsis
    local etaAtScoringPoint is 0.
    if not nodeToScore:orbit:hasNextPatch {
        set etaAtScoringPoint to nodeToScore:orbit:eta:apoapsis.
    } else {
        set etaAtScoringPoint to nodeToScore:orbit:nextPatch:eta:periapsis.
    }

    local bodyVelocity is velocityAt(target, time:seconds + etaAtScoringPoint):orbit.
    local bodyPosition is positionAt(target, time:seconds + etaAtScoringPoint).
    local targetPeriapsis is bodyVelocity:normalized * (targetAltitude + target:radius) * -1.
    local shipPosition is positionAt(ship, time:seconds + etaAtScoringPoint) - bodyPosition.
    local score is (targetPeriapsis - shipPosition):mag.

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