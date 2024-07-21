function executeManeuver {
    parameter mnv.

    // Point at the burn vector
    local originalBurnVector is mnv:burnVector.
    lock steering to mnv:burnVector.

    // Calculate when we need to start throttling down to avoid overshooting
    lock rampDownPoint to ship:availableThrust / ship:mass.

    // Wait until the burn should begin
    local burnDuration is calculateManeuverBurnTime(mnv).
    local waitTime is mnv:eta - (burnDuration / 2).
    wait waitTime.

    if mnv:burnVector:mag >= 200 {
        // Begin the burn
        lock throttle to 1.

        // Wait until we get towards the end of the burn
        wait until mnv:burnVector:mag < 200.
    }

    // Set the throttle to ramp down as we approach target velocity
    lock throttle to max(mnv:burnVector:mag / rampDownPoint, 0.05).

    // Wait until the current burn vector has deviated by 30 degrees from the original
    // burn vector, then kill the throttle
    wait until vAng(originalBurnVector, mnv:burnVector) >= 30.
    lock throttle to 0.
    unlock steering.
}

function calculateManeuverBurnTime {
    parameter burnNode.

    list engines in en.
    // TODO figure out how to get thrust and isp of current stage
    local thrust is en[1]:availableThrust.
    local initialMass is ship:mass.
    local e is constant():e.
    local engineIsp is en[1]:ispAt(0).
    local g is 9.80665.
    local deltaV is burnNode:deltaV:mag.

    return g * initialMass * engineIsp * (1 - e^(-deltaV/(g * engineIsp))) / thrust.
}

// Performs a rotation of a vector clockwise about an axis by the specified number of degrees
// using the 3D vector rotation matrix
// https://en.wikipedia.org/wiki/Rotation_matrix
function rotateVectorAboutAxis {
    parameter vIn, // The vector to be rotated
        axis, // The axis about which to perform the rotation
        rotation. // The rotation, in degrees, to perform

    // Rotation is clockwise around the axis
    local xIn is vIn:x.
    local yIn is vIn:y.
    local zIn is vIn:z.
    local xA is axis:normalized:x.
    local yA is axis:normalized:y.
    local zA is axis:normalized:z.
    local rot is rotation.

    local xOut is ((cos(rot) + (xA^2 * (1 - cos(rot)))) * xIn) + (((xA * yA * (1 - cos(rot))) - (zA * sin(rot))) * yIn) + (((xA * zA * (1 - cos(rot))) + (yA * sin(rot))) * zIn).
    local yOut is (((yA * xA * (1 - cos(rot))) + (zA * sin(rot))) * xIn) + ((cos(rot) + (yA^2 * (1 - cos(rot)))) * yIn) + (((yA * zA * (1 - cos(rot))) - (xA * sin(rot))) * zIn).
    local zOut is (((zA * xA * (1 - cos(rot))) - (yA * sin(rot))) * xIn) + (((zA * yA * (1 - cos(rot))) + (xA * sin(rot))) * yIn) + ((cos(rot) + (zA^2 * (1 - cos(rot)))) * zIn).

    return v(xOut, yOut, zOut).
}