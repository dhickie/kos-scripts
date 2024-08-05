// Dependencies
runOncePath("0:/operations/land.ks").
runOncePath("0:/operations/launch.ks").
runOncePath("0:/operations/matchInclination.ks").
runOncePath("0:/operations/rendezvous.ks").

// Activate ag1 to land, ag2 to take off again
until false {
    wait until ag1 or ag2.

    if ag1 {
        land(142, 0, 0).
        toggle ag1.
    } else if ag2 {
        set target to "Speedy Cheetah 2".
        launchFromVacuum(target:periapsis - 10000).
        matchInclinationToTarget().
        rendezvousWithTarget().
        toggle ag2.
    }
}

