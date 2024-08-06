function timer {
    parameter period, action.

    local lastRun is time:second.
    when time:seconds > lastRun + period then {
        action().
        set lastRun to time:seconds.
        preserve.
    }
}