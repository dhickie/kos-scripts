// Dependencies
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/vector.ks").

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
    lock throttle to max(mnv:burnVector:mag / rampDownPoint, 0.01).

    // Wait until the current burn vector has deviated by 30 degrees from the original
    // burn vector, then kill the throttle
    wait until vAng(originalBurnVector, mnv:burnVector) >= 30 and mnv:burnVector:mag < 10.
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
    wait until kUniverse:timeWarp:isSettled.
}

function createManeuverFromDeltaV {
    parameter nodeEta, deltaV.

    // Get the prograde, normal & radial vectors for the ship
    local shipPosition is positionAt(ship, time:seconds + nodeEta).
    local bodyAtEta is getBodyAtEta(ship:orbit, nodeEta).

    local shipVelocityAtEta is velocityAt(ship, time:seconds + nodeEta).
    local velocityAtEta is 0.
    local bodyPosition is v(0,0,0).
    if bodyAtEta:name = ship:body:name {
        set velocityAtEta to shipVelocityAtEta:orbit.
        set bodyPosition to bodyAtEta:position - shipPosition.
    } else {
        local bodyVelocityAtEta is velocityAt(bodyAtEta, time:seconds + nodeEta).
        set velocityAtEta to shipVelocityAtEta:orbit - bodyVelocityAtEta:orbit.
        set bodyPosition to positionAt(bodyAtEta, time:seconds + nodeEta) - shipPosition.
    }

    local progradeVector is velocityAtEta:normalized.
    local normalVector is vCrs(bodyPosition, progradeVector):normalized.
    local radialVector is -bodyPosition:normalized.

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

// Calculates the stopping distance to come to a halt relative to another orbitable
// Assumes the other orbitable is orbiting the same SOI body
function calculateStoppingDistance {
    parameter orbitable.

    // How long would it take to cancel out our current velocity?
    local t is calculateManeuverBurnTime((ship:velocity:orbit - orbitable:velocity:orbit):mag).

    // How far would the ship travel in that time?
    local F is shipPossibleThrust().
    local a is F / ship:mass.
    local u is ship:velocity:surface:mag.

    local result is (u * t) - ((a * t^2)/2).
    return result.
}