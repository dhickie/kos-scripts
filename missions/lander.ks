// Dependencies
runOncePath("0:/operations/land.ks").
runOncePath("0:/operations/launch.ks").

// Activate ag1 to land, ag2 to take off again
until false {
    wait until ag1 or ag2.

    if ag1 {
        land(10, 0, 0).
        toggle ag1.
    } else if ag2 {
        launchFromVacuum(50000).
        toggle ag2.
    }
}

