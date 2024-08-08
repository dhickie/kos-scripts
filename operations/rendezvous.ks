// Dependencies
runOncePath("0:/utilities/maneuver.ks").

// Performs a rendezvous with the current target, ready for docking
// Assumes that we are already matched in inclination with the target
function rendezvousWithTarget {
    waitUntilRendezvousBurn().

    performRendezvousBurn(100).

    maintainRendezvousTrajectory().

    performFinalApproach(100).
}

function waitUntilRendezvousBurn {
    lock targetVector to target:position - ship:body:position.
    lock angle to vAng(targetVector, -ship:body:position).

    wait 0.1. // Wait a few ticks for any prior acceleration to stop 
    set kUniverse:timeWarp:rate to 5.
    wait until angle < 10.
    set kUniverse:timeWarp:rate to 0.
    wait until kUniverse:timeWarp:isSettled.
}

function performRendezvousBurn {
    parameter approachVelocity.

    local finalVelocity is target:position.
    set finalVelocity:mag to approachVelocity.
    set finalVelocity to finalVelocity + target:velocity:orbit.

    local deltaV is finalVelocity - ship:velocity:orbit.
    local burnNode is createManeuverFromDeltaV(5, deltaV).

    executeManeuver(burnNode).
}

function maintainRendezvousTrajectory {
    // Wait until our velocity vector and the direction to the target drifts
    // or we reach the target position
    until target:position:mag < 1000 {
        lock steering to prograde.
        wait until vAng(ship:velocity:orbit - target:velocity:orbit, target:position) > 5 or target:position:mag < 1000.

        if target:position:mag >= 1000 {
            performRendezvousBurn(100).
        }
    }
}

function performFinalApproach {
    parameter finalDistance.

    performRendezvousBurn(10).

    local targetRetrograde is target:velocity:orbit - ship:velocity:orbit.
    lock steering to lookDirUp(targetRetrograde, sun:position).
    lock stoppingDistance to calculateStoppingDistance(target).
    wait until stoppingDistance > target:position:mag - finalDistance.

    performRendezvousBurn(0).
}