// Dependencies
runOncePath("0:/operations/matchInclination.ks").
runOncePath("0:/utilities/orbit.ks").
runOncePath("0:/utilities/maneuver.ks").
runOncePath("0:/utilities/vector.ks").
runOncePath("0:/utilities/kos.ks").
runOncePath("0:/utilities/geocoordinates.ks").
runOncePath("0:/utilities/parts.ks").

function land {
    parameter lat, lng. // Position of the landing site 

    timer(1, printLatLng@).

    // Extend required gear
    extendLanderSolar().
    extendLanderComms().

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
    lowerLadders().
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
    // Lock a variable to show the throttle required to stop the ship at the surface
    lock requiredThrottle to calculateRequiredThrottle().

    // Wait until the required throttle hits max throttle
    wait until requiredThrottle >= 1.
}

function performSuicideBurn {
    lock throttle to calculateRequiredThrottle().
    local comHeight is 10.

    wait until alt:radar < comHeight.
    lock throttle to 0.
}

// Calculates the throttle required to ensure we have the correct acceleration such
// that we reach 0 velocity as we reach the surface
function calculateRequiredThrottle {
    local u is ship:velocity:surface:mag.
    local s is alt:radar - 10.
    local requiredAcceleration is (u^2) / (2*s).

    local netMaxThrust is ship:availableThrust * 1000 - calculateGravity().
    local maxAcceleration is netMaxThrust / (ship:mass * 1000).

    return requiredAcceleration / maxAcceleration.
}