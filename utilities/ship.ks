// Returns the maximum possible thrust of the ship's current stage
function shipPossibleThrust {
    local thrust is 0.

    for engine in ship:engines {
        if engine:stage = stage:number {
            set thrust to thrust + engine:possibleThrust.
        }
    }

    return thrust.
}