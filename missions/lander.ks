// Dependencies
runOncePath("0:/operations/land.ks").
runOncePath("0:/operations/launch.ks").

// Activate ag1 to lang, ag2 to take off again
wait until ag1.

land(-150, 0, 0).

wait until ag2.

launchFromVacuum(50000).