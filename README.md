# scs_pol_mdt — Police MDT + Dispatch
**Author:** FlipperZeus | **Version:** 1.1 | **Framework:** ESX · QBCore · Qbox

# For Support, Join Discord
SolidCoreStudios Discord: ['Discord'](https://discord.gg/frD69WsrrZ)

A full-featured Police Mobile Data Terminal for FiveM. Includes a login screen with job validation, live dashboard, citizen/vehicle/report/warrant/BOLO/evidence lookup, CCTV camera placement and live-feed viewing, bodycam streaming, a mugshot system, and a persistent mini-dispatch overlay — all in a single NUI resource.

---

## Dependencies

All of the following must be **started before** `scs_pol_mdt` in your `server.cfg`.

| Resource | Purpose |
|---|---|
| `es_extended` **or** `qb-core` **or** `qbx_core` | Framework (auto-detected) |
| [`ox_lib`](https://github.com/overextended/ox_lib) | Callbacks, notifications, context menus, keybind helpers |
| [`oxmysql`](https://github.com/overextended/oxmysql) | Database queries |
| [`ox_inventory`](https://github.com/overextended/ox_inventory) | Item checks and removal (MDT item, CCTV camera item, bodycam item) |
| [`ox_target`](https://github.com/overextended/ox_target) | Mugshot booking-desk sphere zone |
| [`screenshot-basic`](https://github.com/citizenfx/screenshot-basic) | Mugshot and officer portrait capture |

---

## Installation

1. Drop the `scs_pol_mdt` folder into your `resources` directory.
2. Add `ensure scs_pol_mdt` to your `server.cfg` **after** all dependencies.
3. Import the SQL tables — they are created automatically on first resource start (see the `CREATE TABLE IF NOT EXISTS` blocks in `server.lua`). No manual SQL import is required.
4. Add the three ox_inventory items below to your `ox_inventory/data/items.lua`.
5. Configure `config.lua` to match your server (department name, allowed jobs, webhooks, coords).
6. Restart the resource or reboot the server.

---

## ox_inventory Items

Add all three entries to `ox_inventory/data/items.lua`:

```lua
-- Police MDT tablet
['scs_police_mdt'] = {
    label  = 'Police MDT',
    weight = 500,
    stack  = false,
    close  = true,
    client = { event = 'scs_mdt:client:useMDTItem' },
},

-- CCTV placement camera
['cctvcamera'] = {
    label  = 'CCTV Camera',
    weight = 1500,
    stack  = false,
    close  = true,
    client = { event = 'scs_mdt:client:useCCTVCamera' },
},

-- Officer body camera
['bodycam'] = {
    label  = 'Body Camera',
    weight = 300,
    stack  = false,
    close  = true,
    client = { event = 'scs_mdt:client:useBodycam' },
},
```

> The item name for the MDT tablet must match `Config.MDTItem` in `config.lua` (default: `scs_police_mdt`).  
> The CCTV item name must match `Config.CCTV.item` (default: `cctvcamera`).  
> The bodycam item name must match `Config.Bodycam.item` (default: `bodycam`).

---

## Configuration (`config.lua`)

### Department Branding
```lua
Config.Department = {
    nameLine1       = 'ECLIPSE CITY',
    nameLine2       = 'POLICE DEPARTMENT',
    motto           = 'TO PROTECT AND TO SERVE',
    logoUrl         = 'assets/badge.png',   -- relative path inside html/assets/ OR a full https:// URL
    dispatchChannel = 'ECPD Dispatch',
}
```

### Job Access
```lua
Config.AllowedJobs = {
    'police',
    'sheriff',
    'detective',
}
```
Only players holding one of these jobs can log in to the MDT, use the mugshot zone, place CCTV cameras, or access bodycam feeds. Non-police players also receive no dispatch events server- or client-side.

### Framework
```lua
Config.Framework = 'auto'   -- 'auto' | 'esx' | 'qbcore'
```

### Keybind & Command
```lua
Config.OpenKey     = 'F9'             -- default key (player-rebindable in GTA V settings)
Config.OpenCommand = 'mdt'            -- also usable as a chat command: /mdt
Config.MDTItem     = 'scs_police_mdt' -- ox_inventory item required to open the MDT
```

### Tablet Prop & Animation
```lua
Config.Prop = {
    model     = 'prop_cs_tablet',
    boneIndex = 28422,
    offset    = { -0.05, 0.0, 0.0, 0.0, -90.0, 0.0 },
}
Config.Animation = {
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
    clip = 'idle_a',
}
```

### Dashboard Refresh
```lua
Config.RefreshInterval = 30000  -- ms between automatic dashboard data refreshes
```

### Webhooks
```lua
Config.MugshotWebhook  = 'https://discord.com/api/webhooks/...'  -- receives mugshot screenshots
Config.PortraitWebhook = 'https://discord.com/api/webhooks/...'  -- receives officer portrait screenshots
Config.EvidenceWebhook = 'https://discord.com/api/webhooks/...'  -- receives evidence locker save logs
```

### Mugshot System
```lua
Config.MugshotRange      = 10.0          -- GTA units radius to search for nearby players
Config.MugshotPoseDelay  = 400           -- ms subject holds pose before screenshot fires
Config.MugshotZoneCoords = vec3(-171.67, -914.05, 29.60)  -- world position of booking desk zone
Config.MugshotZoneRadius = 1.5
```

### CCTV / Surveillance
```lua
Config.CCTV = {
    item              = 'cctvcamera',
    prop              = 'prop_cctv_cam_01a',
    placeDistance     = 15.0,   -- max placement distance from player
    viewFov           = 40.0,   -- FOV when viewing a live feed
    rotateStep        = 5.0,    -- degrees per scroll tick during placement
    viewHeadingOffset = 180.0,  -- corrects for mesh lens direction (try 0 if backwards)
    panRange          = 60.0,   -- degrees left/right pan from mounted heading
    tiltRange         = 35.0,   -- degrees up/down tilt
    panSpeed          = 0.6,
    tiltSpeed         = 0.6,
}
```

### Bodycam
```lua
Config.Bodycam = {
    item = 'bodycam',
}
```

---

## Commands & Keybinds

### Player-Facing Commands

| Command | Default Key | Description |
|---|---|---|
| `/mdt` | `F9` | Open / close the Police MDT tablet. Requires the `scs_police_mdt` item. |

### Mini-Dispatch Overlay Controls

These are registered as FiveM key mappings — players can rebind them in **Settings → Key Bindings → FiveM**.

| Command | Default Key | Description |
|---|---|---|
| `scs_mdt_scrollLeft` | `←` (Left Arrow) | Scroll to the previous active dispatch call in the overlay |
| `scs_mdt_scrollRight` | `→` (Right Arrow) | Scroll to the next active dispatch call in the overlay |
| `scs_mdt_assignDispatch` | `G` | Assign yourself to / unassign yourself from the currently displayed call |

### Developer / Debug Commands

> ⚠️ **Comment out or remove `testdispatch` before deploying to a live server.**

```lua
-- In client.lua, comment out the entire block below before release:
--[[
RegisterCommand('testdispatch', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawnCoords = coords + (forward * 50.0)

    TriggerServerEvent('scs_mdt:server:createDispatchCall', {
        type = 'Test Call',
        priority = 'Code 3',
        description = 'Robbery in progress, suspects armed and fleeing on foot',
        x = spawnCoords.x, y = spawnCoords.y, z = spawnCoords.z
    })
end, false)
--]]
```

---

## Exports

### Client

```lua
-- Open the MDT programmatically from another resource
exports['scs_pol_mdt']:openMDT()

-- Create a dispatch call from another resource (e.g. a robbery script)
exports['scs_pol_mdt']:CreateDispatchCall({
    type        = 'Bank Robbery',           -- call type label
    coords      = GetEntityCoords(ped),     -- vector3 or table with x/y/z
    priority    = 'Code 3',                 -- 'Code 1' | 'Code 2' | 'Code 3'
    description = 'Robbery in progress at Pacific Standard Bank',  -- optional; falls back to coords
})

-- Begin CCTV camera placement mode (without opening the MDT first)
exports['scs_pol_mdt']:startCCTVPlacement()
```

---

## Database Tables

All tables are created automatically on resource start. No manual SQL is needed.

| Table | Description |
|---|---|
| `mdt_reports` | Incident reports |
| `mdt_warrants` | Arrest warrants |
| `mdt_bolos` | Be-On-the-Lookout alerts |
| `mdt_evidence` | Evidence locker records |
| `mdt_dispatch_calls` | Live and historical dispatch calls |
| `mdt_officer_assignments` | Per-officer patrol assignment (Patrol, Traffic, etc.) |
| `mdt_portraits` | Officer and citizen mugshot image URLs |
| `mdt_citizen_notes` | Officer-written notes attached to citizen profiles |
| `mdt_cameras` | Placed CCTV camera positions and headings |

### Auto-clear
Dispatch calls older than **5 minutes** are automatically set to `Cleared` and removed from all clients. This runs on a 60-second server tick.

---

## Features Overview

### Login Screen
- Job-gated: players without an allowed job see an error and cannot proceed.
- Session-persistent: once logged in, reopening the MDT skips the login screen until the resource restarts or the player drops their job.

### Dashboard
- Live counts: active warrants, active BOLOs, pending reports, active dispatch calls, unassigned calls, and officers on duty.
- Recent activity feed (last 10 warrant/BOLO/report actions).
- Quick-access buttons to Dispatch, Reports, and Warrants.
- Auto-refreshes every `Config.RefreshInterval` ms while the MDT is open.

### Citizens
- Search by name or identifier.
- Status flags: `CLEAR`, `WARRANT`, or `BOLO`.
- Full profile panel: portrait/mugshot, officer notes, registered vehicles, linked reports, and active warrants.

### Vehicles
- Search by plate or owner name.
- BOLO status flag per plate.

### Reports
- Create, search, and edit incident reports.
- Fields: title, type, subject, involved officers, involved citizens, charges, evidence attachments, status.

### Warrants
- Issue, search, and update warrants.
- Filter by status (Active/Served/Expired) and priority (Low/Medium/High/Critical).

### BOLOs
- Issue, search, and update BOLOs for persons, vehicles, or weapons.
- Filter by status and type.

### Evidence
- Link evidence locker records to a perpetrator and officer.
- Reads live item contents from the matching `ox_inventory` stash (`evidence-{number}`).
- Logs every save to the configured Discord webhook.

### Dispatch
- Card-based live call list with colour-coded priority borders (red = Code 3, orange = Code 2).
- RESPOND button assigns you to the call and sets a map blip + route.
- CLEAR button marks the call as cleared server-wide.
- Calls auto-clear after 5 minutes.

### Mini-Dispatch Overlay
- Always-visible HUD overlay outside the MDT tablet.
- Scrollable through active calls with arrow keys.
- Press `G` to assign/unassign yourself to the currently shown call.
- Position is drag-and-drop repositionable and saved to `localStorage`.
- Background opacity is adjustable in MDT Settings (10%–100%, default 50%), saved to `localStorage`.

### Surveillance (CCTV)
- Place `prop_cctv_cam_01a` cameras anywhere in the world using the `cctvcamera` item.
- Placement uses a ghost prop with scroll-wheel rotation and raycast positioning.
- Cameras persist across restarts (stored in `mdt_cameras` DB table).
- Live feed view from the Surveillance tab; pan/tilt controlled via NUI arrow keys.
- Delete cameras directly from the MDT.

### Bodycam
- Officers activate their bodycam via the `bodycam` item.
- Other officers can watch a live feed from the Bodycam tab in the MDT.
- Feed streams officer position/heading at ~10 fps via server relay.
- Automatically deactivates on job change or respawn.

### Mugshot System
- ox_target sphere zone at `Config.MugshotZoneCoords` (your booking desk).
- Officer selects a nearby player from a context menu and confirms.
- Screenshot is taken on the subject's client, uploaded to Discord, and saved to `mdt_portraits`.
- Officer receives a success/failure notification via ox_lib.

### Officer Portrait
- Officers can take their own portrait photo directly from the MDT sidebar.
- Uploaded to Discord and saved to `mdt_portraits` for display on the roster and profile pages.

### Settings (in-MDT)
- **UI Scale** — resize the entire MDT tablet (50%–150%, step 5%).
- **Dispatch Call Sound** — toggle the audio alert on new dispatch calls.
- **Mini Dispatch Position** — drag to reposition, reset to default.
- **Mini Dispatch Opacity** — adjust background transparency (10%–100%, step 10%).

---

## Integration — Firing Dispatch Calls from Other Scripts

Any resource on the server can create a dispatch call without depending on this resource directly:

**Via export (client-side, from the triggering player's client):**
```lua
exports['scs_pol_mdt']:CreateDispatchCall({
    type        = 'Store Robbery',
    coords      = vector3(25.74, -1347.09, 29.50),
    priority    = 'Code 3',
    description = 'Armed robbery in progress at Fleeca Bank',
})
```

**Via server event (server-side, from any script):**
```lua
TriggerEvent('scs_mdt:server:createDispatchCall', {
    type        = 'Store Robbery',
    priority    = 'Code 3',
    description = 'Armed robbery in progress at Fleeca Bank',
    x           = 25.74,
    y           = -1347.09,
    z           = 29.50,
})
```

The call is saved to the database, broadcast to all on-duty police clients, and appears instantly in both the mini-dispatch overlay and the Dispatch tab.

---

## fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'

shared_script '@ox_lib/init.lua'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*',
}

author      'FlipperZeus'
description 'Police MDT'
version     '1.1'
```

---

## File Structure

```
scs_pol_mdt/
├── config.lua          — all server-owner configuration
├── client.lua          — client-side logic (NUI, props, anims, CCTV, bodycam, dispatch)
├── server.lua          — server-side callbacks, DB queries, event handlers
├── fxmanifest.lua
└── html/
    ├── index.html      — NUI layout
    ├── style.css       — NUI styling
    ├── script.js       — NUI logic
    └── assets/
        └── badge.png   — default department logo (replace with your own)
```

---

*Resource developed by FlipperZeus for SolidCore Studios.*
