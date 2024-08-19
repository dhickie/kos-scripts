// Dependencies
runOncePath("0:/operations/surface.ks").

until false {
    wait until ag1 or ag2.

    if ag1 {
        setAltitude(7000).
        travelToPoint(0, -65).
        toggle ag1.
    } else if ag2 {
        setAltitude(1000).
        toggle ag2.
    }
}