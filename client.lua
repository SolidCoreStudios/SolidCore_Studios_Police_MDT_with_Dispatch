-- POLICE MDT  |  client.lua
local mdtOpen          = false
local tabletPropHandle = nil
local currentOfficer   = nil   -- { name, id, job }
local hasLoggedIn      = false -- Tracks if the player has authenticated this session
local ActiveDispatchBlips = {} -- callId -> blip handle
local DispatchCallData = {}    -- callId -> { x, y, z, type, priority } (cached until someone assigns)

local function createDispatchBlip(callData)
    local blip = AddBlipForCoord(callData.x, callData.y, callData.z)
    SetBlipSprite(blip, 8) -- Police car sprite
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, callData.priority == 'Code 3' and 1 or 38) -- Red for Code 3, Blue for others
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(callData.type)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- CCTV / Surveillance state (declared up top so closeMDT can reference them)
local cctvPlacementActive = false
local cctvGhostProp       = nil
local cctvGhostHeading    = 0.0
local cctvViewing         = false
local cctvViewCam         = nil
local cctvCameraCache     = {} -- id -> { x, y, z, heading, name }
local cctvPlacedProps     = {} -- id -> entity handle (persisted world props)
local cctvNuiPan          = 0  -- pan input fed from NUI keydown events
local cctvNuiTilt         = 0  -- tilt input fed from NUI keydown events
local cctvBaseHeading     = 0.0
local cctvBaseCoords      = nil

-- BODYCAM state
local bodycamActive       = false  -- this officer's bodycam is on
local bodycamViewers      = {}     -- viewer server IDs we're streaming to (officer side)
local bodycamViewing      = false  -- this client is currently watching someone's feed
local bodycamViewCam      = nil    -- scripted cam on the viewer's side
local bodycamTargetSrc    = nil    -- server ID of the officer being watched
local cctvPanOffset       = 0.0
local cctvTiltOffset      = 0.0

-- INTERNAL: EQUIP TABLET (Plays anim & attaches prop)
local function equipTablet()
    local animDict = Config.Animation.dict
    local animClip = Config.Animation.clip
    lib.requestAnimDict(animDict)

    TaskPlayAnim(
        PlayerPedId(),
        animDict,
        animClip,
        3.0,
        -1.0,
        -1,
        49,
        0,
        false,
        false,
        false
    )

    local propModel = GetHashKey(Config.Prop.model)
    lib.requestModel(propModel)

    local ped  = PlayerPedId()
    local prop = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, false)
    local off  = Config.Prop.offset

    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, Config.Prop.boneIndex),
        off[1], off[2], off[3],
        off[4], off[5], off[6],
        true, true, false, true, 1, true
    )

    tabletPropHandle = prop
end

-- INTERNAL: OPEN MDT
local function openMDT()
    if mdtOpen then return end

    -- 1. ALWAYS verify job with server first
    lib.callback('police_mdt:checkJob', false, function(result)
        if not result.allowed then
            -- Job is no longer valid. Reset login state.
            hasLoggedIn = false
            currentOfficer = nil
        else
            -- Job is valid. Update cached officer info.
            currentOfficer = {
                name  = result.name,
                id    = result.id,
                job   = result.job,
                grade = result.grade,
            }
        end

        -- 2. Equip the tablet prop and play animation IMMEDIATELY (whether logging in or not)
        mdtOpen = true
        equipTablet()

        -- 3. ALWAYS enable NUI focus so the mouse works
        SetNuiFocus(true, true)

        -- 4. Decide what screen to show
        if result.allowed and hasLoggedIn then
            -- Authorized and already logged in this session: skip login, go straight to dashboard
            lib.callback('police_mdt:getDashboardData', false, function(dashboard)
                lib.callback('police_mdt:getRoster', false, function(roster)
                    SendNUIMessage({
                        action     = 'openMDT',
                        department = Config.Department,
                        dashboard  = dashboard,
                        roster     = roster,
                        officer    = currentOfficer,
                    })
                end)
                lib.callback('police_mdt:getDispatchCalls', false, function(calls)
                    SendNUIMessage({ action = 'initMiniDispatch', calls = calls or {}, myName = currentOfficer and currentOfficer.name or nil })
                end)
            end)
        else
            -- First time opening OR not authorized: show the login screen
            SendNUIMessage({
                action     = 'showLogin',
                department = Config.Department,
            })
        end
    end)
end

-- INTERNAL: CLOSE MDT
local function closeMDT()
    mdtOpen = false
    SetNuiFocus(false, false)

    if cctvViewing then
        cctvViewing = false
        cctvNuiPan  = 0
        cctvNuiTilt = 0
        RenderScriptCams(false, false, 0, true, true)
        if cctvViewCam and DoesCamExist(cctvViewCam) then DestroyCam(cctvViewCam, false) end
        cctvViewCam = nil
    end

    StopAnimTask(
        PlayerPedId(),
        Config.Animation.dict,
        Config.Animation.clip,
        3.0
    )

    if tabletPropHandle and DoesEntityExist(tabletPropHandle) then
        DeleteObject(tabletPropHandle)
        tabletPropHandle = nil
    end
end

local function takeMugshotCamera()
    local ped = PlayerPedId()
    local headBone = GetPedBoneIndex(ped, 31086) -- SKEL_Head
    local headCoords = GetPedBoneCoords(ped, headBone, 0.0, 0.0, 0.0)

    -- Position camera in front of the ped's face using entity-relative offset
    -- (y = forward distance from ped, in front of them)
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.6, 0.65)
    -- Note: negative Y = in front of the ped (forward), since ped's local +Y is forward
    -- 0.65 roughly approximates head height — adjust per your ped models

    local cam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        camCoords.x, camCoords.y, camCoords.z,
        0.0, 0.0, 0.0,
        50.0, -- FOV
        false, 0
    )

    PointCamAtEntity(cam, ped, 0.023, 0.0, 0.65, true) -- aim at head height, not pivot
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    return cam
end

local function stopMugshotCamera(cam)
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

local function takePortraitPose()
    local ped = PlayerPedId()
    if tabletPropHandle and DoesEntityExist(tabletPropHandle) then
        SetEntityVisible(tabletPropHandle, false, false)
    end
    StopAnimTask(ped, Config.Animation.dict, Config.Animation.clip, 0.0) -- instant stop, no blend
    ClearPedTasksImmediately(ped) -- harder reset than ClearPedTasks, snaps instantly
end

local function restorePortraitPose()
    local ped = PlayerPedId()

    -- Show the tablet prop again
    if tabletPropHandle and DoesEntityExist(tabletPropHandle) then
        SetEntityVisible(tabletPropHandle, true, false)
    end

    -- Resume the tablet idle anim
    local animDict = Config.Animation.dict
    local animClip = Config.Animation.clip
    lib.requestAnimDict(animDict)

    TaskPlayAnim(
        ped,
        animDict,
        animClip,
        3.0,
        -1.0,
        -1,
        49,
        0,
        false,
        false,
        false
    )
end

-- KEYBIND + COMMAND
RegisterKeyMapping(
    Config.OpenCommand,
    'Open / Close Police MDT',
    'keyboard',
    Config.OpenKey
)

RegisterCommand(Config.OpenCommand, function()
    -- If the MDT is already open, allow them to close it (even if they dropped the item)
    if mdtOpen then
        closeMDT()
        SendNUIMessage({ action = 'closeMDT' })
        return
    end

    -- Check if the player has the MDT item in their inventory
    local hasItem = exports.ox_inventory:Search('count', Config.MDTItem)
    if not hasItem or hasItem <= 0 then
        lib.notify({ title = 'MDT', description = 'You don\'t have a Police MDT.', type = 'error' })
        return
    end

    -- They have the item, open the MDT
    openMDT()
end, false)

RegisterNetEvent('scs_mdt:client:useMDTItem', function()
    if mdtOpen then
        closeMDT()
        SendNUIMessage({ action = 'closeMDT' })
    else
        openMDT()
    end
end)

-- NUI CALLBACKS
RegisterNUICallback('closeTablet', function(data, cb)
    closeMDT()
    cb({})
end)

RegisterNUICallback('closeLocked', function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)

-- LOGIN BUTTON CALLBACK
RegisterNUICallback('attemptLogin', function(data, cb)
    lib.callback('police_mdt:checkJob', false, function(result)
        if not result.allowed then
            -- Tell the NUI to show the error on the login screen
            SendNUIMessage({
                action = 'loginDenied',
                job    = result.job,
            })
            cb({ ok = false, job = result.job })
            return
        end

        -- Authorized — mark as logged in and fetch dashboard data
        hasLoggedIn = true
        
        lib.callback('police_mdt:getDashboardData', false, function(dashboard)
            lib.callback('police_mdt:getRoster', false, function(roster)
                SendNUIMessage({
                    action     = 'openMDT',
                    department = Config.Department,
                    dashboard  = dashboard,
                    roster     = roster,
                    officer    = currentOfficer,
                })
                cb({ ok = true })
            end)
            lib.callback('police_mdt:getDispatchCalls', false, function(calls)
                SendNUIMessage({ action = 'initMiniDispatch', calls = calls or {}, myName = currentOfficer and currentOfficer.name or nil })
            end)
        end)
    end)
end)

-- SEARCH CALLBACKS
RegisterNUICallback('searchCitizens', function(data, cb)
    lib.callback('police_mdt:lookupCitizen', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '')
end)

RegisterNUICallback('searchVehicles', function(data, cb)
    lib.callback('police_mdt:lookupVehicle', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '')
end)

RegisterNUICallback('searchReports', function(data, cb)
    lib.callback('police_mdt:lookupReports', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '')
end)

RegisterNUICallback('searchWarrants', function(data, cb)
    lib.callback('police_mdt:lookupWarrants', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '', data.status or '', data.priority or '')
end)

RegisterNUICallback('searchBOLOs', function(data, cb)
    lib.callback('police_mdt:lookupBOLOs', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '')
end)

-- REFRESH CALLBACKS
RegisterNUICallback('refreshDashboard', function(data, cb)
    lib.callback('police_mdt:getDashboardData', false, function(dashboard)
        lib.callback('police_mdt:getRoster', false, function(roster)
            cb({ dashboard = dashboard, roster = roster })
        end)
    end)
end)

RegisterNUICallback('refreshDispatch', function(data, cb)
    lib.callback('police_mdt:getDispatchCalls', false, function(calls)
        cb({ calls = calls or {} })
    end)
end)

-- CREATE CALLBACKS (Warrant / BOLO / Report)
RegisterNUICallback('createWarrant', function(data, cb)
    lib.callback('police_mdt:createWarrant', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

RegisterNUICallback('createBOLO', function(data, cb)
    lib.callback('police_mdt:createBOLO', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

RegisterNUICallback('createReport', function(data, cb)
    lib.callback('police_mdt:createReport', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

RegisterNUICallback('getWarrant', function(data, cb)
    lib.callback('police_mdt:getWarrant', false, function(warrant)
        cb({ warrant = warrant })
    end, data.id)
end)

RegisterNUICallback('saveWarrant', function(data, cb)
    lib.callback('police_mdt:saveWarrant', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

RegisterNUICallback('getBOLO', function(data, cb)
    lib.callback('police_mdt:getBOLO', false, function(bolo)
        cb({ bolo = bolo })
    end, data.id)
end)

RegisterNUICallback('saveBOLO', function(data, cb)
    lib.callback('police_mdt:saveBOLO', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

-- Update searchBOLOs to pass filters
RegisterNUICallback('searchBOLOs', function(data, cb)
    lib.callback('police_mdt:lookupBOLOs', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '', data.status or '', data.type or '')
end)

-- EVIDENCE CALLBACKS
RegisterNUICallback('searchEvidence', function(data, cb)
    lib.callback('police_mdt:searchEvidence', false, function(rows)
        cb({ results = rows or {} })
    end, data.query or '')
end)

RegisterNUICallback('getEvidenceLocker', function(data, cb)
    lib.callback('police_mdt:getEvidenceLocker', false, function(evidence)
        cb({ evidence = evidence })
    end, data.lockerNumber)
end)

RegisterNUICallback('saveEvidence', function(data, cb)
    lib.callback('police_mdt:saveEvidence', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

-- GET RECENT ACTIVITY FOR DASHBOARD
RegisterNUICallback('getRecentActivity', function(data, cb)
    lib.callback('police_mdt:getRecentActivity', false, function(activities)
        cb({ activities = activities or {} })
    end)
end)

-- REPORT CALLBACKS
RegisterNUICallback('getReport', function(data, cb)
    lib.callback('police_mdt:getReport', false, function(report)
        cb({ report = report })
    end, data.id)
end)

RegisterNUICallback('saveReport', function(data, cb)
    lib.callback('police_mdt:saveReport', false, function(res)
        cb(res or { ok = false })
    end, data)
end)

RegisterNUICallback('searchNames', function(data, cb)
    lib.callback('police_mdt:searchNames', false, function(results)
        cb({ results = results or {} })
    end, data)
end)

-- CITIZEN PROFILE CALLBACKS
RegisterNUICallback('getCitizenProfile', function(data, cb)
    lib.callback('police_mdt:getCitizenProfile', false, function(profile)
        cb(profile or {})
    end, data.id, data.name)
end)

RegisterNUICallback('saveCitizenDescription', function(data, cb)
    lib.callback('police_mdt:saveCitizenDescription', false, function(res)
        cb(res or { ok = false })
    end, data.id, data.notes)
end)

-- TAKE PORTRAIT CALLBACK
RegisterNUICallback('takePortrait', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideForScreenshot' })

    takePortraitPose()
    local cam = takeMugshotCamera()
    Wait(300)

    exports['screenshot-basic']:requestScreenshotUpload(
        Config.PortraitWebhook,
        'files[]',
        { encoding = 'jpg', quality = 0.85 },
        function(data)
            stopMugshotCamera(cam)
            restorePortraitPose()
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'showAfterScreenshot' })

            local ok, resp = pcall(json.decode, data)

            if ok and resp and resp.attachments and resp.attachments[1] then
                local imageUrl = resp.attachments[1].url

                lib.callback('police_mdt:savePortrait', false, function(saved)
                    if saved then
                        cb({ ok = true, image = imageUrl })
                    else
                        cb({ ok = false })
                    end
                end, imageUrl)
            else
                cb({ ok = false })
            end
        end
    )
end)

-- GET PORTRAIT CALLBACK
RegisterNUICallback('getPortrait', function(data, cb)
    lib.callback('police_mdt:getPortrait', false, function(imageData)
        cb({ image = imageData })
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SURVEILLANCE / CCTV CAMERAS
-- ─────────────────────────────────────────────────────────────────────────────

-- Converts camera pitch/yaw rotation into a unit direction vector (standard FiveM raycast helper)
local function rotationToDirection(rotation)
    local rad = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z,
    }
    return vector3(
        -math.sin(rad.z) * math.abs(math.cos(rad.x)),
        math.cos(rad.z) * math.abs(math.cos(rad.x)),
        math.sin(rad.x)
    )
end

local function raycastFromGameplayCam(distance)
    local camCoord = GetGameplayCamCoord()
    local camRot   = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local destination = camCoord + (direction * distance)

    local rayHandle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    )
    local _, hit, endCoords = GetShapeTestResult(rayHandle)

    -- If the ray didn't hit anything (e.g. aiming through open air), fall back to the
    -- max-distance point along the ray instead of refusing placement entirely.
    if hit ~= 1 then
        endCoords = destination
    end

    return true, endCoords, destination
end

-- MINI DISPATCH CONTROLS
RegisterKeyMapping('scs_mdt_scrollLeft', 'Mini Dispatch: Scroll Left', 'keyboard', 'LEFT')
RegisterKeyMapping('scs_mdt_scrollRight', 'Mini Dispatch: Scroll Right', 'keyboard', 'RIGHT')
RegisterKeyMapping('scs_mdt_assignDispatch', 'Mini Dispatch: Assign Self', 'keyboard', 'G')

RegisterCommand('scs_mdt_scrollLeft', function()
    SendNUIMessage({ action = 'scrollMiniDispatch', dir = -1 })
end, false)

RegisterCommand('scs_mdt_scrollRight', function()
    SendNUIMessage({ action = 'scrollMiniDispatch', dir = 1 })
end, false)

RegisterCommand('scs_mdt_assignDispatch', function()
    SendNUIMessage({ action = 'toggleAssignDispatch' })
end, false)

RegisterNUICallback('assignSelfToDispatch', function(data, cb)
    if data.callId then
        TriggerServerEvent('scs_mdt:server:assignDispatchCall', data.callId)
    end
    cb({})
end)

RegisterNUICallback('unassignSelfFromDispatch', function(data, cb)
    if data.callId then
        TriggerServerEvent('scs_mdt:server:unassignDispatchCall', data.callId)
    end
    cb({})
end)

RegisterNUICallback('clearDispatchCallRequest', function(data, cb)
    if data.callId then
        TriggerServerEvent('scs_mdt:server:clearDispatchCall', data.callId)
    end
    cb({})
end)

-- Tracks the call (if any) the LOCAL player is currently routed to, so we can
-- automatically remove the blip/waypoint once they arrive.
local myAssignedCallId = nil

RegisterNetEvent('scs_mdt:client:updateDispatchCall', function(callId, unitName)
    SendNUIMessage({ action = 'updateDispatchCall', id = callId, unit = unitName })

    local isMine = currentOfficer and unitName == currentOfficer.name
    local blip = ActiveDispatchBlips[callId]

    if isMine then
        -- Create the blip now, only for the officer who actually assigned.
        if (not blip or not DoesBlipExist(blip)) and DispatchCallData[callId] then
            blip = createDispatchBlip(DispatchCallData[callId])
            ActiveDispatchBlips[callId] = blip
        end
        if blip and DoesBlipExist(blip) then
            SetBlipRoute(blip, true)
        end
        myAssignedCallId = callId
    else
        -- Not mine (unassigned, or claimed by someone else) — remove our blip entirely.
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        ActiveDispatchBlips[callId] = nil
        if myAssignedCallId == callId then
            myAssignedCallId = nil
        end
    end
end)

-- Auto-remove the blip/waypoint once the assigned officer reaches the scene.
-- SetBlipRoute never turns itself off on arrival, so we do it manually.
CreateThread(function()
    while true do
        Wait(1000)
        if myAssignedCallId then
            local blip = ActiveDispatchBlips[myAssignedCallId]
            if blip and DoesBlipExist(blip) then
                local bCoords = GetBlipCoords(blip)
                local pCoords = GetEntityCoords(PlayerPedId())
                if #(pCoords - bCoords) < 15.0 then
                    RemoveBlip(blip)
                    ActiveDispatchBlips[myAssignedCallId] = nil
                    myAssignedCallId = nil
                end
            else
                myAssignedCallId = nil
            end
        end
    end
end)

-- ENTRY POINT: called when the player uses the "CCTV Camera" item from their inventory.
-- Hooked up via an ox_inventory item with: client = { event = 'scs_mdt:client:useCCTVCamera' }
local function beginCameraPlacement()
    cctvPlacementActive = true
    cctvGhostHeading = GetEntityHeading(PlayerPedId())

    local propModel = GetHashKey(Config.CCTV.prop)
    lib.requestModel(propModel)
    cctvGhostProp = CreateObject(propModel, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(cctvGhostProp, 160, false)
    SetEntityCollision(cctvGhostProp, false, false)

    lib.showTextUI('[E] Place Camera   [Scroll] Rotate   [ESC] Cancel', { position = 'bottom-center' })

    CreateThread(function()
        while cctvPlacementActive do
            local hit, endCoords = raycastFromGameplayCam(Config.CCTV.placeDistance or 15.0)

            if hit and DoesEntityExist(cctvGhostProp) then
                SetEntityCoords(cctvGhostProp, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
                SetEntityRotation(cctvGhostProp, 0.0, 0.0, cctvGhostHeading, 2, true)
            end

            -- Scroll wheel rotates the ghost prop.
            -- Disabling 15/16 stops the weapon wheel from popping up and stealing the
            -- input; IsDisabledControlJustPressed still detects the press underneath.
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            if IsDisabledControlJustPressed(0, 15) then -- scroll up
                cctvGhostHeading = (cctvGhostHeading + (Config.CCTV.rotateStep or 5.0)) % 360.0
            elseif IsDisabledControlJustPressed(0, 16) then -- scroll down
                cctvGhostHeading = (cctvGhostHeading - (Config.CCTV.rotateStep or 5.0)) % 360.0
            end

            -- Confirm placement
            if hit and IsControlJustPressed(0, 38) then -- E
                local finalCoords = vector3(endCoords.x, endCoords.y, endCoords.z)
                local finalHeading = cctvGhostHeading
                cctvPlacementActive = false
                lib.hideTextUI()
                if cctvGhostProp and DoesEntityExist(cctvGhostProp) then DeleteEntity(cctvGhostProp) end
                cctvGhostProp = nil

                TriggerServerEvent('scs_mdt:server:placeCamera', { x = finalCoords.x, y = finalCoords.y, z = finalCoords.z }, finalHeading)
                break
            end

            -- Cancel — no server event fired, so the item is never removed
            if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then -- ESC / BACKSPACE
                cctvPlacementActive = false
                lib.hideTextUI()
                if cctvGhostProp and DoesEntityExist(cctvGhostProp) then DeleteEntity(cctvGhostProp) end
                cctvGhostProp = nil
                break
            end

            Wait(0)
        end
    end)
end

local function startCameraPlacement()
    if cctvPlacementActive then return end
    if mdtOpen then return end -- don't allow placement with the tablet open in your hands

    lib.callback('police_mdt:hasCCTVItem', false, function(hasItem)
        if not hasItem then
            lib.notify({ title = 'CCTV Camera', description = 'You don\'t have a CCTV camera.', type = 'error' })
            return
        end
        beginCameraPlacement()
    end)
end

RegisterNetEvent('scs_mdt:client:useCCTVCamera', function()
    startCameraPlacement()
end)

-- Triggered by the "+ PLACE CAMERA" button in the Surveillance tab.
-- Checks the item FIRST — only closes the tablet if the player actually has one.
RegisterNUICallback('requestPlaceCamera', function(data, cb)
    lib.callback('police_mdt:hasCCTVItem', false, function(hasItem)
        if not hasItem then
            cb({ ok = false, error = 'no_item' })
            return
        end
        closeMDT()
        SendNUIMessage({ action = 'closeMDT' })
        cb({ ok = true })
        Wait(50)
        beginCameraPlacement()
    end)
end)

exports('startCCTVPlacement', function()
    startCameraPlacement()
end)

RegisterNetEvent('scs_mdt:client:placementFailed', function(reason)
    lib.notify({ title = 'CCTV Camera', description = reason or 'Could not place camera.', type = 'error' })
end)

-- The server confirms the item was consumed and the camera saved — now prompt for a name.
-- Works even if the tablet isn't currently open.
RegisterNetEvent('scs_mdt:client:promptCameraName', function(cameraId)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'promptCameraName', cameraId = cameraId })
end)

RegisterNUICallback('saveCameraName', function(data, cb)
    TriggerServerEvent('scs_mdt:server:nameCamera', data.cameraId, data.name or '')
    if not mdtOpen then SetNuiFocus(false, false) end
    cb({ ok = true })
end)

RegisterNUICallback('skipCameraName', function(data, cb)
    TriggerServerEvent('scs_mdt:server:nameCamera', data.cameraId, '')
    if not mdtOpen then SetNuiFocus(false, false) end
    cb({ ok = true })
end)

-- Syncs live world props to match the DB camera list.
-- Deletes props for removed cameras; spawns props for new ones.
local function syncCCTVProps(rows)
    local propModel = GetHashKey(Config.CCTV.prop)
    lib.requestModel(propModel)

    -- Build a set of IDs still present in the list
    local activeIds = {}
    for _, r in ipairs(rows or {}) do
        activeIds[r.id] = true
    end

    -- Remove props for cameras that were deleted from the DB
    for id, handle in pairs(cctvPlacedProps) do
        if not activeIds[id] then
            if DoesEntityExist(handle) then DeleteEntity(handle) end
            cctvPlacedProps[id] = nil
        end
    end

    -- Spawn props for cameras that don't have a world entity yet
    for _, r in ipairs(rows or {}) do
        if not cctvPlacedProps[r.id] or not DoesEntityExist(cctvPlacedProps[r.id]) then
            local prop = CreateObject(propModel, r.pos_x, r.pos_y, r.pos_z, false, false, false)
            SetEntityRotation(prop, 0.0, 0.0, r.heading or 0.0, 2, true)
            FreezeEntityPosition(prop, true)
            SetEntityCollision(prop, true, true)
            cctvPlacedProps[r.id] = prop
        end
    end
end

-- Keep every client's cached camera list in sync so "View" works instantly from the MDT.
RegisterNetEvent('scs_mdt:client:cameraListUpdate', function(rows)
    cctvCameraCache = {}
    for _, r in ipairs(rows or {}) do
        cctvCameraCache[r.id] = { x = r.pos_x, y = r.pos_y, z = r.pos_z, heading = r.heading, name = r.name }
    end
    syncCCTVProps(rows)
    -- Always forward to NUI (cheap no-op if the page isn't visible) so the table is
    -- already fresh the next time the tablet or Surveillance tab is opened.
    SendNUIMessage({ action = 'cameraListUpdate', cameras = rows or {} })
end)

RegisterNUICallback('getCameras', function(data, cb)
    lib.callback('police_mdt:getCameras', false, function(rows)
        cctvCameraCache = {}
        for _, r in ipairs(rows or {}) do
            cctvCameraCache[r.id] = { x = r.pos_x, y = r.pos_y, z = r.pos_z, heading = r.heading, name = r.name }
        end
        syncCCTVProps(rows)
        cb({ results = rows or {} })
    end)
end)

RegisterNUICallback('deleteCamera', function(data, cb)
    lib.callback('police_mdt:deleteCamera', false, function(res)
        cb(res or { ok = false })
    end, data.id)
end)

-- VIEW LIVE FEED: render a scripted cam at the placed camera's position/heading
local function startCameraView(id)
    local cam = cctvCameraCache[id]
    if not cam then return end

    if cctvViewing then
        if cctvViewCam and DoesCamExist(cctvViewCam) then DestroyCam(cctvViewCam, false) end
        cctvViewCam = nil
    end

    cctvViewing = true
    cctvPanOffset  = 0.0
    cctvTiltOffset = 0.0
    cctvBaseHeading = (cam.heading or 0.0) + (Config.CCTV.viewHeadingOffset or 0.0)
    local headingRad = math.rad(cctvBaseHeading)
    local forwardOffset = 0.8  -- tweak this value
    cctvBaseCoords = vector3(
        cam.x + (-math.sin(headingRad) * forwardOffset),
        cam.y + ( math.cos(headingRad) * forwardOffset),
        cam.z + 0.4
    )

    cctvViewCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        cctvBaseCoords.x, cctvBaseCoords.y, cctvBaseCoords.z,
        0.0, 0.0, cctvBaseHeading,
        Config.CCTV.viewFov or 50.0,
        false, 0
    )
    SetCamActive(cctvViewCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Full NUI focus: owns all keyboard input so ESC can't reach the pause menu.
    -- Pan/tilt is handled via NUI keydown events fed back through cctvInput callback.
    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'cctvFeedActive', name = cam.name or 'Unnamed Camera' })

    CreateThread(function()
        while cctvViewing do
            -- Block combat inputs so the ped doesn't act while viewing
            DisableControlAction(0, 24, true)  -- Attack (left click)
            DisableControlAction(0, 25, true)  -- Aim (right click)
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 264, true) -- Melee Attack 2

            -- Pan/tilt is driven entirely by NUI keydown events via cctvInput callback
            -- (SetNuiFocus(true,true) owns the keyboard so game controls are unavailable)
            if cctvViewCam and DoesCamExist(cctvViewCam) then
                local panRange  = Config.CCTV.panRange  or 75.0
                local tiltRange = Config.CCTV.tiltRange or 35.0
                cctvPanOffset  = math.max(-panRange,  math.min(panRange,  cctvPanOffset  + cctvNuiPan  * (Config.CCTV.panSpeed  or 1.2)))
                cctvTiltOffset = math.max(-tiltRange, math.min(tiltRange, cctvTiltOffset + cctvNuiTilt * (Config.CCTV.tiltSpeed or 1.2)))
                SetCamRot(cctvViewCam, cctvTiltOffset, 0.0, cctvBaseHeading + cctvPanOffset, 2)
            end

            -- Force the game to stream in full-detail models/collision around the camera
            -- position, since the engine otherwise only streams high LOD around the ped.
            if cctvBaseCoords then
                SetFocusArea(cctvBaseCoords.x, cctvBaseCoords.y, cctvBaseCoords.z, 0.0, 0.0, 0.0)
                RequestCollisionAtCoord(cctvBaseCoords.x, cctvBaseCoords.y, cctvBaseCoords.z)
            end

            Wait(16)
        end
        ClearFocus()
    end)
end

local function stopCameraView()
    if not cctvViewing then return end
    cctvViewing = false
    cctvNuiPan  = 0
    cctvNuiTilt = 0
    RenderScriptCams(false, false, 0, true, true)
    if cctvViewCam and DoesCamExist(cctvViewCam) then DestroyCam(cctvViewCam, false) end
    cctvViewCam = nil
    ClearFocus()
    SendNUIMessage({ action = 'cctvFeedClosed' })
    -- Return focus to the tablet (it's still open) instead of dropping focus entirely
    SetNuiFocus(mdtOpen, mdtOpen)
end

RegisterNUICallback('viewCamera', function(data, cb)
    startCameraView(data.id)
    cb({ ok = true })
end)

RegisterNUICallback('exitCameraView', function(data, cb)
    stopCameraView()
    cb({ ok = true })
end)

RegisterNUICallback('cctvInput', function(data, cb)
    cctvNuiPan  = tonumber(data.pan)  or 0
    cctvNuiTilt = tonumber(data.tilt) or 0
    cb({})
end)

-- Safety net: if the tablet is closed while a feed is open (or the resource stops), tear the cam down.
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    stopCameraView()
    -- Clean up all placed CCTV world props
    for id, handle in pairs(cctvPlacedProps) do
        if DoesEntityExist(handle) then DeleteEntity(handle) end
    end
    cctvPlacedProps = {}
end)

-- PERIODIC DASHBOARD REFRESH
CreateThread(function()
    while true do
        Wait(Config.RefreshInterval)

        if mdtOpen then
            lib.callback('police_mdt:getDashboardData', false, function(dashboard)
                SendNUIMessage({
                    action    = 'dashboardUpdate',
                    dashboard = dashboard,
                })
            end)
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- MUGSHOT SYSTEM
-- ox_target on the officer's ped → nearby player menu → remote screenshot
-- ─────────────────────────────────────────────────────────────────────────────

-- SECTION 1: ox_target sphere zone at the configured world position
exports['ox_target']:addSphereZone({
    coords = Config.MugshotZoneCoords,
    radius = Config.MugshotZoneRadius,
    options = {
        {
            name  = 'scs_mdt_mugshot',
            icon  = 'fas fa-camera',
            label = 'Take Mugshot',
            canInteract = function()
                return true -- real gate is server-side job check
            end,
            onSelect = function()
                openMugshotMenu()
            end,
        }
    }
})

-- SECTION 2: Nearby player selection menu
function openMugshotMenu()
    lib.callback('police_mdt:getNearbyPlayers', false, function(result)
        if not result then
            lib.notify({ title = 'MDT', description = 'Unauthorised.', type = 'error' })
            return
        end
        if not result.allowed then
            lib.notify({ title = 'MDT', description = 'You are not authorised to take mugshots.', type = 'error' })
            return
        end

        local players = result.players or {}
        if #players == 0 then
            lib.notify({ title = 'MDT', description = 'No players nearby.', type = 'warning' })
            return
        end

        local options = {}
        for _, p in ipairs(players) do
            local captured = p -- closure capture
            options[#options + 1] = {
                title       = captured.name,
                description = 'Server ID: ' .. captured.serverId,
                icon        = 'fas fa-user',
                onSelect    = function()
                    confirmMugshot(captured)
                end,
            }
        end

        lib.registerContext({
            id      = 'mugshot_player_list',
            title   = 'Select Subject',
            options = options,
        })
        lib.showContext('mugshot_player_list')
    end)
end

-- SECTION 3: Confirm dialog then fire server event
function confirmMugshot(player)
    lib.registerContext({
        id      = 'mugshot_confirm',
        title   = 'Take Mugshot',
        options = {
            {
                title       = 'Confirm — ' .. player.name,
                description = 'This will capture a photo of the player.',
                icon        = 'fas fa-camera-retro',
                onSelect    = function()
                    TriggerServerEvent('scs_mdt:server:requestMugshot', player.serverId)
                end,
            },
            {
                title = 'Cancel',
                icon  = 'fas fa-times',
            },
        },
    })
    lib.showContext('mugshot_confirm')
end

-- SECTION 4: Runs on the SUBJECT's client — pose, snap, upload, report back
RegisterNetEvent('scs_mdt:client:takeMugshot', function(officerId)
    local ped = PlayerPedId()

    SendNUIMessage({ action = 'hideForScreenshot' })
    SetNuiFocus(false, false)

    if tabletPropHandle and DoesEntityExist(tabletPropHandle) then
        SetEntityVisible(tabletPropHandle, false, false)
    end
    ClearPedTasksImmediately(ped)

    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.6, 0.65)
    local cam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        camCoords.x, camCoords.y, camCoords.z,
        0.0, 0.0, 0.0,
        50.0, false, 0
    )
    PointCamAtEntity(cam, ped, 0.023, 0.0, 0.65, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    Wait(Config.MugshotPoseDelay or 400)

    exports['screenshot-basic']:requestScreenshotUpload(
        Config.MugshotWebhook,
        'files[]',
        { encoding = 'jpg', quality = 0.85 },
        function(rawData)
            RenderScriptCams(false, false, 0, true, true)
            if cam and DoesCamExist(cam) then DestroyCam(cam, false) end

            SendNUIMessage({ action = 'showAfterScreenshot' })
            if mdtOpen then SetNuiFocus(true, true) end

            if tabletPropHandle and DoesEntityExist(tabletPropHandle) then
                SetEntityVisible(tabletPropHandle, true, false)
            end

            local ok, resp = pcall(json.decode, rawData)
            local imageUrl = (ok and resp and resp.attachments and resp.attachments[1] and resp.attachments[1].url) or nil

            TriggerServerEvent('scs_mdt:server:mugshotResult', officerId, imageUrl)
        end
    )
end)

-- SECTION 5: Officer receives result notification
RegisterNetEvent('scs_mdt:client:mugshotDone', function(imageUrl, subjectName)
    if imageUrl then
        lib.notify({
            title       = 'Mugshot Captured',
            description = 'Mugshot for ' .. (subjectName or 'subject') .. ' saved to MDT.',
            type        = 'success',
            duration    = 6000,
        })
    else
        lib.notify({
            title       = 'Mugshot Failed',
            description = 'Screenshot upload failed. Try again.',
            type        = 'error',
            duration    = 5000,
        })
    end
end)

-- EXPORT
exports('openMDT', function()
    openMDT()
end)

-- ─ DISPATCH API EXPORTS (The "ps-dispatch" concept) ──
-- Other scripts can call this: exports['scs_pol_mdt']:CreateDispatchCall({
--     type = 'Bank Robbery',
--     coords = GetEntityCoords(PlayerPedId()),
--     priority = 'Code 3',
--     description = 'Robbery in progress at the Pacific Standard Bank' -- optional
-- })
-- If `description` is omitted, the call falls back to showing raw coordinates.
exports('CreateDispatchCall', function(data)
    if not data or not data.coords then return end
    TriggerServerEvent('scs_mdt:server:createDispatchCall', {
        type = data.type or 'Unknown',
        priority = data.priority or 'Code 2',
        description = data.description,
        x = data.coords.x,
        y = data.coords.y,
        z = data.coords.z
    })
end)

-- ─ DISPATCH VISUALS (Blips & Notifications) ──
-- (ActiveDispatchBlips / DispatchCallData / createDispatchBlip are declared
-- near the top of the file so the mini dispatch handlers above can use them.)

-- Listen for new calls
RegisterNetEvent('scs_mdt:client:newCall', function(callData)
    -- Hard gate: drop the event entirely if this player is not police.
    if not currentOfficer then return end

    -- Cache the data — NOT drawing a blip here. A blip/waypoint is only
    -- created once an officer actually assigns themselves to the call.
    DispatchCallData[callData.id] = {
        x = callData.x, y = callData.y, z = callData.z,
        type = callData.type, priority = callData.priority,
    }

    -- Update MDT UI instantly (works whether MDT is open or not)
    SendNUIMessage({
        action = 'newDispatchCall',
        call = callData
    })
end)

-- Sync mini dispatch on spawn so the overlay shows without opening the MDT
AddEventHandler('playerSpawned', function()
    -- Small delay to let the framework register the player's job
    Wait(3000)
    lib.callback('police_mdt:checkJob', false, function(result)
        -- Only proceed if this player is actually police
        if not (result and result.allowed) then return end

        currentOfficer = {
            name  = result.name,
            id    = result.id,
            job   = result.job,
            grade = result.grade,
        }

        lib.callback('police_mdt:getDispatchCalls', false, function(calls)
            if calls and #calls > 0 then
                SendNUIMessage({
                    action = 'initMiniDispatch',
                    calls  = calls,
                    myName = currentOfficer.name,
                })
            end
        end)
    end)
end)

-- Listen for cleared calls
RegisterNetEvent('scs_mdt:client:clearCall', function(callId)
    if ActiveDispatchBlips[callId] then
        RemoveBlip(ActiveDispatchBlips[callId])
        ActiveDispatchBlips[callId] = nil
    end
    DispatchCallData[callId] = nil
    if myAssignedCallId == callId then
        myAssignedCallId = nil
    end

    -- Update MDT UI
    SendNUIMessage({
        action = 'clearDispatchCall',
        id = callId
    })
end)

function isAllowedJob(job)
    for _, j in ipairs(Config.AllowedJobs) do
        if j == job then return true end
    end
    return false
end

RegisterNUICallback('saveAssignment', function(data, cb)
    lib.callback('police_mdt:saveAssignment', false, function(res)
        cb(res or { ok = false })
    end, data.assignment)
end)
-- ─────────────────────────────────────────────────────────────────────────────
-- BODYCAM SYSTEM
-- ─────────────────────────────────────────────────────────────────────────────

-- OFFICER SIDE: item event triggers bodycam toggle
RegisterNetEvent('scs_mdt:client:useBodycam', function()
    if not bodycamActive then
        bodycamActive = true
        bodycamViewers = {}
        TriggerServerEvent('scs_mdt:server:activateBodycam')
        lib.notify({ title = 'Bodycam', description = 'Body camera activated.', type = 'success', duration = 4000 })

        -- Stream position/heading to server ~10fps so viewers can follow
        CreateThread(function()
            while bodycamActive do
                if next(bodycamViewers) then
                    local ped = PlayerPedId()
                    local coords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped)
                    TriggerServerEvent('scs_mdt:server:bodycamFrame', {
                        x = coords.x, y = coords.y, z = coords.z, heading = heading
                    })
                end
                Wait(100)
            end
        end)
    else
        -- Already on — shouldn't happen via item (item deactivation is job-change/respawn)
        lib.notify({ title = 'Bodycam', description = 'Body camera is already active.', type = 'inform', duration = 3000 })
    end
end)

-- OFFICER SIDE: server tells us a viewer is watching
RegisterNetEvent('scs_mdt:client:bodycamAddViewer', function(viewerSrc)
    bodycamViewers[viewerSrc] = true
end)

-- OFFICER SIDE: server tells us a viewer stopped watching
RegisterNetEvent('scs_mdt:client:bodycamRemoveViewer', function(viewerSrc)
    bodycamViewers[viewerSrc] = nil
end)

-- OFFICER SIDE: deactivate bodycam (job change or respawn)
local function deactivateBodycam()
    if not bodycamActive then return end
    bodycamActive = false
    bodycamViewers = {}
    TriggerServerEvent('scs_mdt:server:deactivateBodycam')
end

-- Hook job change — ESX fires esx:setJob, QBCore fires QBCore:Client:OnJobUpdate
AddEventHandler('esx:setJob', function(job)
    if not isAllowedJob(job.name) then deactivateBodycam() end
end)
AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
    if not isAllowedJob(job.name) then deactivateBodycam() end
end)

-- Hook respawn (native FiveM baseevents)
AddEventHandler('baseevents:onPlayerSpawned', function()
    deactivateBodycam()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEWER SIDE
-- ─────────────────────────────────────────────────────────────────────────────

local bodycamLastFrame = nil  -- { x, y, z, heading }
local bodycamCamHeading = 0.0

local function stopBodycamView()
    if not bodycamViewing then return end
    bodycamViewing = false
    bodycamLastFrame = nil
    if bodycamTargetSrc then
        TriggerServerEvent('scs_mdt:server:stopWatchBodycam', bodycamTargetSrc)
        bodycamTargetSrc = nil
    end
    RenderScriptCams(false, false, 0, true, true)
    if bodycamViewCam and DoesCamExist(bodycamViewCam) then
        DestroyCam(bodycamViewCam, false)
    end
    bodycamViewCam = nil
    SendNUIMessage({ action = 'bodycamFeedClosed' })
    -- Return focus to the tablet (it's still open) instead of dropping focus entirely
    SetNuiFocus(mdtOpen, mdtOpen)
end

-- Server confirmed feed started — set up the scripted cam
RegisterNetEvent('scs_mdt:client:bodycamFeedStarted', function(officerName)
    bodycamViewing = true
    bodycamCamHeading = 0.0

    bodycamViewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(bodycamViewCam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'bodycamFeedActive', name = officerName, serverId = bodycamTargetSrc })

    -- Cam update thread — moves cam to match officer's last known position
    CreateThread(function()
        while bodycamViewing do
            if bodycamLastFrame and bodycamViewCam and DoesCamExist(bodycamViewCam) then
                local f = bodycamLastFrame
                -- Smoothly interpolate heading
                local targetH = f.heading
                local diff = ((targetH - bodycamCamHeading + 540) % 360) - 180
                bodycamCamHeading = bodycamCamHeading + diff * 0.15  -- smooth follow

                -- Chest-level offset
                local headingRad = math.rad(bodycamCamHeading)
                local fwdOffset = 0.35  -- push forward away from the body, tweak if needed
                SetCamCoord(bodycamViewCam,
                    f.x + (-math.sin(headingRad) * fwdOffset),
                    f.y + ( math.cos(headingRad) * fwdOffset),
                    f.z + 0.55
                )
                SetCamRot(bodycamViewCam, -5.0, 0.0, bodycamCamHeading, 2)
                SetFocusArea(f.x, f.y, f.z, 0.0, 0.0, 0.0)
            end

            -- Block combat while viewing
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)

            Wait(0)
        end
        ClearFocus()
    end)
end)

-- Receive streamed frame from officer (via server relay)
RegisterNetEvent('scs_mdt:client:bodycamFrame', function(data)
    bodycamLastFrame = data
end)

-- Server closed the feed (officer went off duty / disconnected)
RegisterNetEvent('scs_mdt:client:bodycamFeedClosed', function()
    stopBodycamView()
end)

-- NUI: viewer clicked Watch on an officer
RegisterNUICallback('watchBodycam', function(data, cb)
    if bodycamViewing then stopBodycamView() end
    bodycamTargetSrc = tonumber(data.serverId)
    TriggerServerEvent('scs_mdt:server:watchBodycam', bodycamTargetSrc)
    cb({ ok = true })
end)

-- NUI: viewer clicked Exit Feed
RegisterNUICallback('exitBodycamView', function(data, cb)
    stopBodycamView()
    cb({ ok = true })
end)

-- NUI: fetch active bodycam list for the tab
RegisterNUICallback('getBodycams', function(data, cb)
    lib.callback('police_mdt:getBodycams', false, function(list)
        cb({ results = list or {} })
    end)
end)

-- Keep bodycam list in sync via broadcast
RegisterNetEvent('scs_mdt:client:bodycamListUpdate', function(list)
    SendNUIMessage({ action = 'bodycamListUpdate', bodycams = list or {} })
    -- If the officer we're watching just dropped from the list, close the feed
    if bodycamViewing and bodycamTargetSrc then
        local stillActive = false
        for _, b in ipairs(list) do
            if b.serverId == bodycamTargetSrc then stillActive = true; break end
        end
        if not stillActive then stopBodycamView() end
    end
end)

RegisterCommand('testdispatch', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawnCoords = coords + (forward * 50.0) -- 50 units ahead so there's a real route to test

    TriggerServerEvent('scs_mdt:server:createDispatchCall', {
        type = 'Test Call',
        priority = 'Code 3',
        description = 'Robbery in progress, suspects armed and fleeing on foot',
        x = spawnCoords.x, y = spawnCoords.y, z = spawnCoords.z
    })
end, false)