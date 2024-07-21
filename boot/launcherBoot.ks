CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

if alt:radar > 70000 and ship:orbit:eccentricity < 1 {
    runPath("0:/matchInclination.ks").
} else {
    runPath("0:/launch.ks").
    runPath("0:/matchInclination.ks").
}
