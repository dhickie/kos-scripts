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

// Takes any vector and calculates the component of it that lies on a horizontal plane
function projectToHorizontalPlane {
    parameter vIn.

    local vInX is vDot(vIn, v(1,0,0)).
    local vInZ is vDot(vIn, v(0,0,1)).
    return v(vInX, 0, vInZ).
}

function drawVector {
    parameter vector, label, originOrbitable is ship.

    vecDraw(
        originOrbitable:position,
        vector,
        rgb(1,0,0),
        label,
        1.0,
        true,
        0.2,
        true,
        true
    ).
}