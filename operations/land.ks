// Dependencies
runOncePath("0:/operations/matchInclination.ks").
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/maneuver.ks").
runOncePath("0:/utilities/ship.ks").
runOncePath("0:/utilities/vector.ks").
runOncePath("0:/utilities/kos.ks").

function land {
    parameter lat, lng. // Position of the landing site 

    timer(1, printLatLng@).

    // Match the orbit inclination with the equator if it isn't already
    if ship:orbit:inclination > 0.1 {
        matchInclinationToEquator().
    }

    adjustInclinationForLanding(lat, lng).

    killLateralVelocityAboveLandingSite(lat, lng).

    // Lock the steering to surface retrograde but with roll locked
    local roll is ship:facing:roll.
    lock steering to r(srfRetrograde:pitch, srfRetrograde:yaw, roll).
    
    waitUntilSuicideBurn().
    
    legs on.
    lights on.

    performSuicideBurn().

    unlock steering.

    // Lower the ladder
    set ag3 to true.
}

function printLatLng {
    print "Latitude: " + ship:geoposition:lat + ", Longitude: " + ship:geoposition:lng.
}

function adjustInclinationForLanding {
    parameter lat, lng.

    // Calculate the location of the node we need to burn at to adjust the inclination just enough to reach
    // the landing site latitude
    local nodeLongitude is addToLongitude(lng, -90). 
    local nodeLocation is latLng(0, nodeLongitude).
    local nodeVector is nodeLocation:position - ship:body:position.

    // Calculate how long until we reach the node
    local orbitNormal is calculateOrbitNormal(ship).
    local nodeEta is calculateEtaAbovePoint(nodeVector, orbitNormal, ship).

    // Calculate the velocity needed at the node to have the desired inclination
    local rotationAxis is positionAt(ship, time:seconds + nodeEta) - ship:body:position.
    local velocityAtNode is velocityAt(ship, time:seconds + nodeEta):orbit.
    local rotation is -lat.
    local finalVelocity is rotateVectorAboutAxis(velocityAtNode, rotationAxis, rotation).

    // Calculate the burn required to reach the desired velocity
    local deltaV is finalVelocity - velocityAtNode.
    local burnNode is createManeuverFromDeltaV(nodeEta, deltaV).

    // Execute the burn
    executeManeuver(burnNode).
}

function addToLongitude {
    parameter lng, valueToAdd. // Can be negative

    local result is lng + valueToAdd.
    if valueToAdd < -180 {
        set result to result + 360.
    } else if valueToAdd > 180 {
        set result to result - 360.
    }

    return result.
}

function killLateralVelocityAboveLandingSite {
    parameter lat, lng. // Position of the landing site

    local landingSite is latLng(lat, lng).

    // Calculate when the ship will pass over the target landing site
    local landingSiteVector is landingSite:position - ship:body:position.
    local shipNormal is calculateOrbitNormal(ship).
    local flyoverEta is calculateEtaAbovePoint(landingSiteVector, shipNormal, ship).

    // Calculate how long it will take to kill the lateral velocity above the landing site
    local lateralVelocity is calculateLateralSurfaceVelocity(time:seconds + flyoverEta).
    //local burnTime is calculateManeuverBurnTime(lateralVelocity:mag).
    // executeManeuver will start half the burn time before the node, so adjust the burn eta so the burn
    // finishes as we reach the point we'd like to land at
    //local burnEta is flyoverEta - (burnTime * 0.5).

    // Create and execute a maneuver with the opposite deltaV
    local mnv is createManeuverFromDeltaV(flyoverEta, -lateralVelocity).
    executeManeuver(mnv).
}

function waitUntilSuicideBurn {
    // Lock a variable to show how far down the ship would travel if we applied
    // max thrust now
    lock maxDownwardDistance to calculateMaxDownwardTravel().

    // Wait until we hit the last point we can burn, with a buffer 
    // to accommodate the rate of physics ticks and increase in g as we approach
    wait until maxDownwardDistance >= (alt:radar - (ship:velocity:surface:mag * 1)).
}

function performSuicideBurn {
    local velocityRampDown is 20.
    lock throttle to max(abs(ship:verticalSpeed) / velocityRampDown, 0.1).

    local comHeight is 5.5.

    wait until alt:radar < comHeight or ship:verticalspeed >= -5.

    // If we're at the surface, kill the throttle
    // If we're not yet at the surface but velocity is low, then keep throttle
    // at a level that keeps velocity constant
    if (alt:radar < comHeight) {
        lock throttle to 0.
    } else {
        lock throttle to calculateHoverThrottle().
        wait until alt:radar < comHeight.
        lock throttle to 0.
    }
}

// Calculates how far below the ship's current point the ship would travel if
// it applied max thrust right now
function calculateMaxDownwardTravel {
    // How long would it take to cancel out our current velocity?
    local t is calculateManeuverBurnTime(ship:velocity:surface:mag).

    // How far would the ship travel in that time?
    local F is (shipPossibleThrust() * 1000) - calculateGravitationalForce().
    local a is F / (ship:mass * 1000).
    local u is ship:velocity:surface:mag.

    return (u * t) - ((a * t^2)/2).
}

// Calculates the throttle requires to keep the current downward velocity constant
function calculateHoverThrottle {
    local g is calculateGravitationalForce().
    local requiredForce is ship:mass * g.

    return requiredForce / shipPossibleThrust().
}