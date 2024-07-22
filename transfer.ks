function transferMain {
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

    // Calculate the required increase in velocity to reach projected apopasis
    local requiredVelocity is calculateOrbitalVelocity(ship:body, ship:orbit:semimajoraxis, ship:orbit:semimajoraxis).
    local deltaV is requiredVelocity - ship:velocity:orbit:mag.

    // Refine the node with hill cimbing to reach desired final altitude
    local initialNode is node(nodeEta, 0, 0, deltaV).
    local refinedNode is hillClimb(initialNode, orbitScoringFunction@, 64).

    add refinedNode.
    executeManeuver(refinedNode).
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
        initialModFactor. // The initial amount we should modify node parameters by in candidates

    local nodeToBeat is initialNode.
    local scoreToBeat is scoringFunction(nodeToBeat).

    local modFactor is initialModFactor.
    until modFactor < 1 {
        local resultFound is false.
        until resultFound {
            local startingScore is scoreToBeat.
            local candidates is list(
                node(nodeToBeat:eta, 0, 0, nodeToBeat:prograde + modFactor),
                node(nodeToBeat:eta, 0, 0, nodeToBeat:prograde - 1),
                node(nodeToBeat:eta + modFactor, 0, 0, nodeToBeat:prograde),
                node(nodeToBeat:eta - modFactor, 0, 0, nodeToBeat:prograde),
                node(nodeToBeat:eta + modFactor, 0, 0, nodeToBeat:prograde + modFactor),
                node(nodeToBeat:eta - modFactor, 0, 0, nodeToBeat:prograde - modFactor)
            ).

            for candidate in candidates {
                local candidateScore is scoringFunction(candidate).
                if (candidateScore < scoreToBeat) {
                    set nodeToBeat to candidate.
                    set scoreToBeat to candidateScore.
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
    local score is 0.

    // If the resulting orbit doesn't contain an encounter with the target body
    // then calculate the distance between the ship and the target at the apoapsis
    if not nodeToScore:orbit:hasNextPatch {
        local timeToAp is ship:orbit:eta:apopasis.
        local shipPosAtAp is positionAt(ship, time:seconds + timeToAp).
        local targetPosAtAp is positionAt(target, time:seconds + timeToAp).

        set score to abs((shipPosAtAp - targetPosAtAp):mag - 100000).
    } else {
        set score to abs(nodeToScore:orbit:nextPatch:periapsis - 100000).
    }

    remove nodeToScore.
    return score.
}

runOncePath("0:/utility.ks").
transferMain().