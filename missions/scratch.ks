runOncePath("0:/utilities/parts.ks").

identifyShipParts().
extendLauncherSolar().
extendLauncherComms().
wait 10.
retractLauncherSolar().
retractLauncherComms().