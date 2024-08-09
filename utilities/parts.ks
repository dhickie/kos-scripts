local shipParts is lexicon().
if exists("0:/logs/parts.txt") {
    deletePath("0:/logs/parts.txt").
}
local outputFile is create("0:/logs/parts.txt").

function write {
    parameter text.

    outputFile:writeLn(text).
}

function identifyShipParts {
    identifySolar().
    identifyComms().
    //identifyDrills().
    //identifyHeatSinks().
}

function identifySolar {
    identifyModules("launcher-solar", "ModuleDeployableSolarPanel", "launcher-solar").
    identifyModules("lander-solar", "ModuleDeployableSolarPanel", "lander-solar").
}

function identifyComms {
    identifyModules("launcher-comms", "ModuleDeployableAntenna", "launcher-comms").
    identifyModules("lander-comms", "ModuleDeployableAntenna", "lander-comms").
}

function identifyDrills {
    write("Drills:").
    local drillParts is ship:partsTagged("drill").
    printModuleDetails(drillParts).
}

function identifyHeatSinks {
    write("Heatsinks:").
    local heatsinkParts is ship:partsTagged("heatsink").
    printModuleDetails(heatsinkParts).
}

function extendLauncherSolar {
    doModuleEvent("launcher-solar", "extend solar panel").
}

function retractLauncherSolar {
    doModuleEvent("launcher-solar", "retract solar panel").
}

function extendLanderSolar {
    doModuleEvent("lander-solar", "extend solar panel").
}

function retractLanderSolar {
    doModuleEvent("lander-solar", "retract solar panel").
}

function extendLauncherComms {
    doModuleEvent("launcher-comms", "extend antenna").
}

function retractLauncherComms {
    doModuleEvent("launcher-comms", "retract antenna").
}

function extendLanderComms {
    doModuleEvent("lander-comms", "extend antenna").
}

function retractLanderComms {
    doModuleEvent("lander-comms", "retract antenna").
}

function extendDrills {

}

function startDrills {

}

function extendHeatsinks {

}

function identifyModules {
    parameter partsTag, moduleName, moduleKey.

    local taggedParts is ship:partsTagged(partsTag).
    set moduleList to list().
    for taggedPart in taggedParts {
        local targetModule is taggedPart:getModule(moduleName).
        moduleList:add(targetModule).
    }
    shipParts:add(moduleKey, moduleList).
}

function doModuleEvent {
    parameter moduleKey, eventName.

    local modules is shipParts[moduleKey].
    for module in modules {
        if module:hasEvent(eventName) {
            module:doEvent(eventName).
        }
    }
}

function printModuleDetails {
    parameter parts.

    for part in parts {
        write("Part: " + part:name).
        for moduleName in part:modules {
            local module is part:getModule(moduleName).
            write("Module: " + module:name).
            write("Fields: " + module:allFieldNames).
            write("Events: " + module:allEventNames).
            write("Actions: " + module:allActionNames).
            write("").
        }
        write("").
        write("").
    }
}