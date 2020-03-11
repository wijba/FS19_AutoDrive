CatchCombinePipeTask = ADInheritsFrom(AbstractTask)

CatchCombinePipeTask.TARGET_DISTANCE = 15

CatchCombinePipeTask.STATE_PATHPLANNING = 1
CatchCombinePipeTask.STATE_DRIVING = 2

function CatchCombinePipeTask:new(vehicle, combine)
    local o = CatchCombinePipeTask:create()
    o.vehicle = vehicle
    o.combine = combine
    o.state = CatchCombinePipeTask.STATE_PATHPLANNING
    o.wayPoints = nil
    return o
end

function CatchCombinePipeTask:setUp()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:setUp()")
    self:startNewPathFinding()
end

function CatchCombinePipeTask:update(dt)
    if self.state == CatchCombinePipeTask.STATE_PATHPLANNING then
        if self.vehicle.ad.pathFinderModule:hasFinished() then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - STATE_PATHPLANNING finished")
            self.wayPoints = self.vehicle.ad.pathFinderModule:getPath()
            self.vehicle.ad.drivePathModule:setWayPoints(self.wayPoints)
            self.state = CatchCombinePipeTask.STATE_DRIVING
        else
            self.vehicle.ad.pathFinderModule:update()
            self.vehicle.ad.specialDrivingModule:stopVehicle()
            self.vehicle.ad.specialDrivingModule:update(dt)
        end
    elseif self.state == CatchCombinePipeTask.STATE_DRIVING then
        -- check if this is still a clever path to follow
        -- do this by distance of the combine to the last location pathfinder started at
        local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
        local combineTravelDistance = MathUtil.vector2Length(x - self.combinesStartLocation.x, z - self.combinesStartLocation.z)
        
        if combineTravelDistance > 40 then
            AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - combine travelled - recalculate path")
            self:startNewPathFinding()
            self.state = CatchCombinePipeTask.STATE_PATHPLANNING
        else
            if self.vehicle.ad.drivePathModule:isTargetReached() then
                -- check if we have atually reached the target or not
                -- accept current location if we are in a good position to start chasing: distance and angle are important here
                local angleToCombine = self.vehicle.ad.modes[AutoDrive.MODE_UNLOAD]:getAngleToCombineHeading()

                if angleToCombine < 20 and AutoDrive.getDistanceBetween (self.vehicle, self.combine) < 40 then
                    self:finished()
                else
                    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - angle or distance to combine too high - recalculate path now")
                    self:startNewPathFinding()
                    self.state = CatchCombinePipeTask.STATE_PATHPLANNING
                end
            else
                self.vehicle.ad.drivePathModule:update(dt)
            end
        end
    end
end

function CatchCombinePipeTask:abort()
end

function CatchCombinePipeTask:finished()
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_COMBINEINFO, "CatchCombinePipeTask:update - finished")
    self.vehicle.ad.taskModule:setCurrentTaskFinished()
end

function CatchCombinePipeTask:startNewPathFinding()
    self.vehicle.ad.pathFinderModule:startPathPlanningToPipe(self.combine, true)
    self.combinesStartLocation = {}
    self.combinesStartLocation.x, self.combinesStartLocation.y, self.combinesStartLocation.z = getWorldTranslation(self.combine.components[1].node)
end