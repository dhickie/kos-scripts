// Script variables
local manualStage is false.

function setupStagingTrigger {
    local maxAvailableThrust is ship:availableThrustAt(0).
    when (ship:availableThrustAt(0) < maxAvailableThrust) then {
        if not manualStage {
            wait until stage:ready.
            stage.
            wait 0.1.
        }

        set maxAvailableThrust to ship:availableThrustAt(0).
        set manualStage to false.
        
        preserve.
    }
}

// Jettisons the launch stage from the ship if it's still attached
function jettisonLaunchStage {
    local shipParts is ship:partsTagged("launch-stage").

    if shipParts:length > 0 {
        set manualStage to true.
        stage.
    }
}