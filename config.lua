----------------------------------------------------
-- POLICE MDT  |  config.lua
----------------------------------------------------

Config = {}

----------------------------------------------------
-- DEPARTMENT BRANDING
-- These values are injected into the NUI on open.
-- Change them here — no HTML edits needed.
----------------------------------------------------

Config.Department = {
    nameLine1 = 'LOS SANTOS',           -- Top line in the header
    nameLine2 = 'POLICE DEPARTMENT',    -- Second line in the header
    motto     = 'TO PROTECT AND TO SERVE',
    -- Logo: relative path inside html/assets/ OR a full https:// URL.
    -- Leave empty string '' to show the default shield SVG fallback.
    logoUrl   = 'assets/badge.png',
    -- Dispatch channel name shown on the dashboard
    dispatchChannel = 'LSPD Dispatch',
}

----------------------------------------------------
-- JOB ACCESS
-- Players must hold one of these jobs to open the MDT.
-- Add multiple jobs if detectives, sheriff, etc. also
-- need access.  Job names are case-sensitive and must
-- match exactly what your framework stores.
----------------------------------------------------

Config.AllowedJobs = {
    'police',
    'sheriff',
    'detective',
}

----------------------------------------------------
-- FRAMEWORK
-- 'auto'    — detect ESX / QBCore / Qbox automatically (recommended)
-- 'esx'     — force ESX
-- 'qbcore'  — force QBCore / Qbox
----------------------------------------------------

Config.Framework = 'auto'

----------------------------------------------------
-- KEYBIND
-- Default key to open/close the MDT.
-- Uses FiveM's RegisterKeyMapping — players can
-- rebind this in their GTA V key settings.
----------------------------------------------------

Config.OpenKey     = 'F9'          -- Default keybind
Config.OpenCommand = 'mdt'         -- Also registered as a chat command
Config.MDTItem     = 'scs_police_mdt'  -- ox_inventory item name to open the MDT

----------------------------------------------------
-- TABLET PROP & ANIMATION
----------------------------------------------------

Config.Prop = {
    model     = 'prop_cs_tablet',
    boneIndex = 28422,             -- Left hand bone
    -- Attachment offsets (x, y, z, rx, ry, rz)
    offset    = { -0.05, 0.0, 0.0, 0.0, -90.0, 0.0 },
}

Config.Animation = {
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
    clip = 'idle_a',
}

----------------------------------------------------
-- DASHBOARD LIVE DATA
-- Intervals (ms) at which the server refreshes
-- the counts sent back to the MDT dashboard.
----------------------------------------------------

Config.RefreshInterval = 30000     -- 30 seconds

----------------------------------------------------
-- MUGSHOT SYSTEM
----------------------------------------------------

-- Discord webhook that receives mugshot screenshots (same format as PortraitWebhook).
Config.MugshotWebhook = 'https://discord.com/api/webhooks/...'

-- Radius in GTA units to search for nearby players when taking a mugshot.
Config.MugshotRange = 10.0

-- Milliseconds the subject holds their pose before the screenshot fires.
Config.MugshotPoseDelay = 400

-- World position of the "Take Mugshot" ox_target zone (e.g. your booking desk).
-- Replace with your actual coordinates.
Config.MugshotZoneCoords = vec3(0,0,0)

-- Radius of the ox_target sphere at that position.
Config.MugshotZoneRadius = 1.5

-- Discord webhook for officer portrait screenshots (the "Update Portrait" button in the MDT).
Config.PortraitWebhook = 'https://discord.com/api/webhooks/...'

-- Discord webhook that receives a log entry every time an evidence locker is saved
-- (locker number, officer, perpetrator, date/time, and the items currently in the locker).
Config.EvidenceWebhook = 'https://discord.com/api/webhooks/...'

----------------------------------------------------
-- SURVEILLANCE / CCTV CAMERAS
----------------------------------------------------

Config.CCTV = {
    -- ox_inventory item name that triggers camera placement when used.
    -- Add this item to your ox_inventory/data/items.lua, e.g.:
    --   ['cctvcamera'] = {
    --       label = 'CCTV Camera',
    --       weight = 1500,
    --       stack = false,
    --       close = true,
    --       client = { event = 'scs_mdt:client:useCCTVCamera' }
    --   }
    item = 'cctvcamera',

    -- Prop used for both the placement ghost and the placed camera.
    prop = 'prop_cctv_cam_01a',

    -- Maximum distance (GTA units) the player can place a camera from themselves.
    placeDistance = 15.0,

    -- Field of view used while viewing a live feed from a placed camera.
    viewFov = 40.0,

    -- Degrees rotated per scroll-wheel tick while aiming the ghost prop.
    rotateStep = 5.0,

    -- The prop_cctv_cam_01a mesh's lens faces the opposite way from the heading you
    -- set on it, so the live feed otherwise looks exactly backwards from the ghost
    -- preview. This rotates the VIEW cam only (not the placed prop itself) to correct
    -- for that. If your camera still looks backwards, try 0; if it looks 90° off, try
    -- 90 or -90.
    viewHeadingOffset = 180.0,

    -- Live feed pan/tilt limits while viewing a camera (WASD / Arrow keys).
    panRange  = 60.0,  -- degrees left/right from the camera's mounted heading (150° total swing)
    tiltRange = 35.0,  -- degrees up/down from level
    panSpeed  = 0.6,   -- degrees per tick at full input
    tiltSpeed = 0.6,
}

----------------------------------------------------
-- BODYCAM
----------------------------------------------------

Config.Bodycam = {
    -- ox_inventory item name that activates the bodycam when used.
    -- Add to your ox_inventory/data/items.lua:
    --   ['bodycam'] = {
    --       label = 'Body Camera',
    --       weight = 300,
    --       stack = false,
    --       close = true,
    --       client = { event = 'scs_mdt:client:useBodycam' }
    --   }
    item = 'bodycam',
}
