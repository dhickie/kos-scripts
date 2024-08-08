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