CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set terminal:charHeight to 22.
wait until ship:unpacked.
runPath("0:/missions/moon-orbiter.ks", mun).