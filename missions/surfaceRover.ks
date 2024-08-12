// Dependencies
runOncePath("0:/operations/surface.ks").

until false {
    wait until ag1 or ag2.

    if ag1 {
        setAltitude(8000).
        toggle ag1.
    } else if ag2 {
        setAltitude(4000).
        toggle ag2.
    }
}