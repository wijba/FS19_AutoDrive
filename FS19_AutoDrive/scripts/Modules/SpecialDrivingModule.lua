ADSpecialDrivingModule = {}

function ADSpecialDrivingModule:new(vehicle)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.vehicle = vehicle
    ADSpecialDrivingModule.reset(o)
    return o
end

function ADSpecialDrivingModule:reset()
    self.shouldStopOrHoldVehicle = false
end

function ADSpecialDrivingModule:stopVehicle(lx, lz)
    self.shouldStopOrHoldVehicle = true
    self.targetLX = lx
    self.targetLZ = lz
end

function ADSpecialDrivingModule:releaseVehicle()
    self.shouldStopOrHoldVehicle = false
    self.motorShouldBeStopped = false
end

function ADSpecialDrivingModule:update(dt)
    if self.shouldStopOrHoldVehicle then
        self:stopAndHoldVehicle(dt)
    end
end

function ADSpecialDrivingModule:isStoppingVehicle()
    return self.shouldStopOrHoldVehicle
end

function ADSpecialDrivingModule:stopAndHoldVehicle(dt)
    local finalSpeed = 0
    local acc = -0.6
    local allowedToDrive = false

    if math.abs(self.vehicle.lastSpeedReal) > 0.002 then
        finalSpeed = 0.01
        allowedToDrive = true
    end

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)

    local lx, lz = self.targetLX, self.targetLZ

    if lx == nil or lz == nil then
        --If no target was provided, aim in front of te vehicle to prevent steering maneuvers
        local rx, _, rz = localDirectionToWorld(self.vehicle.components[1].node, 0, 0, 1)
        x = x + rx
        z = z + rz

        lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, x, y, z)
    end

    AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, allowedToDrive, true, lx, lz, finalSpeed, 1)

    if self.vehicle.lastSpeedReal < 0.0013 then
        self.motorShouldBeStopped = true
        if self.vehicle.spec_motorized.isMotorStarted and (not g_currentMission.missionInfo.automaticMotorStartEnabled) then
            self.vehicle:stopMotor()
        end
    end
end

function ADSpecialDrivingModule:shouldStopMotor()
    return self.motorShouldBeStopped
end

function ADSpecialDrivingModule:driveForward(dt)
    local speed = 8
    local acc = 0.6

    local targetX, targetY, targetZ = localToWorld(self.vehicle.components[1].node, 0, 0, 20)
    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, targetX, targetY, targetZ)

    AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, true, true, lx, lz, speed, 1)
end

function ADSpecialDrivingModule:driveReverse(dt, maxSpeed, maxAcceleration)
    local speed = maxSpeed
    local acc = maxAcceleration

    local targetX, targetY, targetZ = localToWorld(self.vehicle.components[1].node, 0, 0, -20)
    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, targetX, targetY, targetZ)

    AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, true, false, -lx, -lz, speed, 1)
end

function ADSpecialDrivingModule:driveToPoint(dt, point, maxFollowSpeed, dynamicCollisionWindow, maxAcc, maxSpeed)
    local speed = math.min(ADDrivePathModule.SPEED_ON_FIELD, maxSpeed)
    local acc = math.min(0.75, maxAcc)

    local x, y, z = getWorldTranslation(self.vehicle.components[1].node)
    self.distanceToChasePos = MathUtil.vector2Length(x - point.x, z - point.z)

    if self.distanceToChasePos < 0.5 then
        speed = maxFollowSpeed * 0.95
    elseif self.distanceToChasePos < 7 then
        speed = maxFollowSpeed + self.distanceToChasePos*2
    elseif self.distanceToChasePos < 20 then
        speed = maxFollowSpeed + self.distanceToChasePos*2
    end

    --print("Targetspeed: " .. speed .. " distance: " .. self.distanceToChasePos .. " maxFollowSpeed: " .. maxFollowSpeed)

    local lx, lz = AIVehicleUtil.getDriveDirection(self.vehicle.components[1].node, point.x, point.y, point.z)

    self.vehicle.ad.sensors.frontSensor.dynamicCollisionWindow = dynamicCollisionWindow
    if self.vehicle.ad.collisionDetectionModule:hasDetectedObstable() or self.vehicle.ad.sensors.frontSensor:pollInfo() then
        self:stopVehicle(lx, lz)
        self:update(dt)
    else
        -- Allow active braking if vehicle is not 'following' targetSpeed precise enough
        if (self.vehicle.lastSpeedReal * 3600) > (speed + ADDrivePathModule.MAX_SPEED_DEVIATION) then
            self.acceleration = -0.6
        end
        --ADDrawingManager:addLineTask(x, y, z, point.x, point.y, point.z, 1, 0, 0)
        AIVehicleUtil.driveInDirection(self.vehicle, dt, 30, acc, 0.2, 20, true, true, lx, lz, speed, 1)
    end
end
