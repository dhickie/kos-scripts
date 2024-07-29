function executeManeuver {
    parameter mnv.

    add mnv.

    // Point at the burn vector
    local originalBurnVector is mnv:burnVector.
    lock steering to mnv:burnVector.

    // Calculate the duration of the burn
    local burnDuration is calculateManeuverBurnTime(mnv:deltaV:mag).
    print "Burn duration is " + burnDuration + " seconds".

    // Wait until the ship is pointing at the burn vector
    wait until vAng(ship:facing:foreVector, mnv:burnVector) < 1.

    // Warp to the maneuver, if required
    if (mnv:eta + (burnDuration/2) > 60) {
        print "Warping to maneuver".
        warpToManeuver(mnv, burnDuration).
    }

    // Wait until the burn should begin
    local waitTime is mnv:eta - (burnDuration / 2).
    wait waitTime.

    if mnv:burnVector:mag >= 200 {
        // Begin the burn
        lock throttle to 1.

        // Wait until we get towards the end of the burn
        wait until mnv:burnVector:mag < 200.
    }

    // Calculate when we need to start throttling down to avoid overshooting
    local rampDownPoint is ship:availableThrust / ship:mass.

    // Set the throttle to ramp down as we approach target velocity
    lock throttle to max(mnv:burnVector:mag / rampDownPoint, 0.05).

    // Wait until the current burn vector has deviated by 30 degrees from the original
    // burn vector, then kill the throttle
    wait until vAng(originalBurnVector, mnv:burnVector) >= 30.
    lock throttle to 0.
    unlock steering.
    remove mnv.
}

function warpToManeuver {
    parameter mnv, burnDuration.

    set warp to 1.
    wait 0.1.
    if (mnv:eta > 3600) {
        kUniverse:timeWarp:warpTo(time:seconds + mnv:eta - 3600).
        wait until mnv:eta < 3600.
        wait until kUniverse:timeWarp:isSettled.
    }

    kUniverse:timeWarp:warpTo(time:seconds + mnv:eta - burnDuration - 30).
}

function createManeuverFromDeltaV {
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

function calculateManeuverBurnTime {
    parameter mnvDeltaV, stageNumber is stage:number.

    local deltaV is mnvDeltaV.
    local stageDeltaV is ship:stageDeltaV(stageNumber):current.
    local burnTime is 0.
    if deltaV > stageDeltaV {
        // Take the current stage's deltaV off the total deltaV and calculate
        // the remaining burn time for the next stage
        set burnTime to burnTime + calculateManeuverBurnTime(deltaV - stageDeltaV, stage:number - 1).
        set deltaV to stageDeltaV.
    }

    // Get all the engines in the requested stage, and sum their thrust
    // TODO Cope with different engines in the same stage (weighted average of per engine isp)
    local thrust is 0.
    local engineIsp is 0.
    for engine in ship:engines {
        if engine:stage = stageNumber {
            set thrust to thrust + engine:possibleThrust.
            set engineIsp to engine:ispAt(0).
        }
    }

    local initialMass is shipMassAtStage(stageNumber).
    local e is constant():e.
    local g is 9.80665.

    return burnTime + (g * initialMass * engineIsp * (1 - e^(-deltaV/(g * engineIsp))) / thrust).
}

function shipMassAtStage {
    parameter stageNumber.

    local shipMass is ship:mass.
    for part in ship:parts {
        if part:decoupledIn >= stageNumber {
            set shipMass to shipMass - part:mass.
        }
    }

    return shipMass.
}