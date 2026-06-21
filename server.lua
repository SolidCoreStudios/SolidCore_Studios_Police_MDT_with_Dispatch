-- POLICE MDT  |  server.lua (FIXED & CLEANED)
-- FRAMEWORK AUTO-DETECTION
local Framework     = nil
local FrameworkName = nil

CreateThread(function()
    for attempt = 1, 10 do
        if GetResourceState('es_extended') == 'started' then
            local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
            if ok and obj then
                Framework = obj; FrameworkName = 'esx'
                print('^2[POLICE MDT] Framework detected: ESX^7')
                return
            end
        end
        if GetResourceState('qb-core') == 'started' then
            local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok and obj then
                Framework = obj; FrameworkName = 'qbcore'
                print('^2[POLICE MDT] Framework detected: QBCore^7')
                return
            end
        end
        if GetResourceState('qbx_core') == 'started' then
            local ok, obj = pcall(function() return exports['qbx_core']:GetCoreObject() end)
            if ok and obj then
                Framework = obj; FrameworkName = 'qbcore'
                print('^2[POLICE MDT] Framework detected: Qbox^7')
                return
            end
        end
        Wait(1000)
    end
    print('^1[POLICE MDT] WARNING: No supported framework detected.^7')
end)

-- CREATE MDT TABLES
CreateThread(function()
    Wait(2000)
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_reports` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `title` VARCHAR(150) NOT NULL DEFAULT 'Untitled Report',
            `report_type` VARCHAR(60) NOT NULL DEFAULT 'Incident Report',
            `officer` VARCHAR(100) NOT NULL,
            `subject` VARCHAR(100) NOT NULL DEFAULT 'N/A',
            `details` TEXT NOT NULL DEFAULT '',
            `involved_officers` TEXT NOT NULL DEFAULT '[]',
            `involved_citizens` TEXT NOT NULL DEFAULT '[]',
            `charges` TEXT NOT NULL DEFAULT '',
            `evidence` TEXT NOT NULL DEFAULT '[]',
            `status` VARCHAR(20) NOT NULL DEFAULT 'OPEN',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_bolos` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `bolo_type` VARCHAR(20) NOT NULL DEFAULT 'person',
            `subject_name` VARCHAR(100) NOT NULL DEFAULT '',
            `description` TEXT NOT NULL,
            `last_seen` VARCHAR(200) NOT NULL DEFAULT '',
            `plate` VARCHAR(20) NOT NULL DEFAULT '',
            `image_url` VARCHAR(255) NOT NULL DEFAULT '',
            `priority` VARCHAR(20) NOT NULL DEFAULT 'Medium',
            `issued_by` VARCHAR(100) NOT NULL,
            `status` VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_warrants` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `subject_id` VARCHAR(60) NOT NULL,
            `subject_name` VARCHAR(100) NOT NULL,
            `charge` TEXT NOT NULL,
            `description` TEXT NOT NULL DEFAULT '',
            `priority` VARCHAR(20) NOT NULL DEFAULT 'Medium',
            `issued_by` VARCHAR(100) NOT NULL,
            `status` VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_evidence` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `locker_number` INT NOT NULL,
            `perpetrator` VARCHAR(100) NOT NULL,
            `officer` VARCHAR(100) NOT NULL,
            `notes` TEXT NOT NULL DEFAULT '',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `locker_number` (`locker_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_dispatch_calls` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `call_type` VARCHAR(50) NOT NULL,
            `location` VARCHAR(100) NOT NULL,
            `location_x` FLOAT NOT NULL DEFAULT 0,
            `location_y` FLOAT NOT NULL DEFAULT 0,
            `location_z` FLOAT NOT NULL DEFAULT 0,
            `priority` VARCHAR(20) NOT NULL DEFAULT 'Code 2',
            `status` VARCHAR(20) NOT NULL DEFAULT 'Pending',
            `assigned_unit` VARCHAR(100) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_officer_assignments` (
            `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
            `assignment` VARCHAR(50) NOT NULL DEFAULT 'Unassigned'
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_portraits` (
            `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
            `portrait_data` LONGTEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_citizen_notes` (
            `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
            `notes` TEXT NOT NULL DEFAULT '',
            `updated_by` VARCHAR(100) NOT NULL DEFAULT '',
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mdt_cameras` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(60) NOT NULL DEFAULT 'Unnamed Camera',
            `pos_x` FLOAT NOT NULL,
            `pos_y` FLOAT NOT NULL,
            `pos_z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `placed_by` VARCHAR(100) NOT NULL DEFAULT 'Unknown',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
        
    print('^2[POLICE MDT] MDT tables ready.^7')
end)

-- HELPERS
local function getPlayerJob(src)
    if not Framework then return nil end
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(src)
        return xPlayer and xPlayer.job.name
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(src)
        return Player and Player.PlayerData.job.name
    end
    return nil
end

local function getPlayerIdentifier(src)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(src)
        return Player and Player.PlayerData.citizenid
    end
    return nil
end

local function getPlayerCharName(src)
    if not Framework then return GetPlayerName(src) end
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(src)
        if not xPlayer then return GetPlayerName(src) end
        if xPlayer.getName then return xPlayer.getName() end
        if xPlayer.get then
            local first = xPlayer.get('firstname') or ''
            local last = xPlayer.get('lastname') or ''
            if first ~= '' then return (first .. ' ' .. last):gsub('%s+$','') end
        end
        return GetPlayerName(src)
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(src)
        if not Player then return GetPlayerName(src) end
        local pd = Player.PlayerData
        return (pd.charinfo and (pd.charinfo.firstname .. ' ' .. pd.charinfo.lastname)) or GetPlayerName(src)
    end
    return GetPlayerName(src)
end

local function getPlayerGradeLabel(src)
    if not Framework then return 'Unknown' end
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(src)
        if xPlayer and xPlayer.job then
            -- ESX uses grade_label for the human-readable name (e.g., "Sergeant")
            return xPlayer.job.grade_label or xPlayer.job.grade_name or 'Unknown'
        end
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.grade then
            -- QBCore uses grade.name for the human-readable name
            return Player.PlayerData.job.grade.name or 'Unknown'
        end
    end
    return 'Unknown'
end

local function isAllowedJob(job)
    if not job then return false end
    for _, allowed in ipairs(Config.AllowedJobs) do
        if job == allowed then return true end
    end
    return false
end

-- CALLBACKS
lib.callback.register('police_mdt:checkJob', function(source)
    local job = getPlayerJob(source)
    local name = getPlayerCharName(source)
    local grade = getPlayerGradeLabel(source)
    return { allowed = isAllowedJob(job), job = job or 'unknown', grade = grade or 'Unknown', name = name or GetPlayerName(source), id = source }
end)

lib.callback.register('police_mdt:getDashboardData', function(source)
    -- Count on-duty officers
    local onDuty = 0
    for _, playerId in ipairs(GetPlayers()) do
        local job = getPlayerJob(tonumber(playerId))
        if isAllowedJob(job) then
            onDuty = onDuty + 1
        end
    end

    -- Live counts from DB
    local warrantCount  = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_warrants` WHERE `status` = ?', { 'ACTIVE' }) or 0
    local boloCount     = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `status` = ?', { 'ACTIVE' }) or 0
    local pendingCount  = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_reports` WHERE `status` = ?', { 'PENDING' }) or 0
    
    -- FIX: Fetch actual dispatch counts
    local activeCallsCount = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_dispatch_calls` WHERE `status` != "Cleared"') or 0
    local unassignedCallsCount = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_dispatch_calls` WHERE `status` = "Pending"') or 0

    return {
        activeWarrants  = warrantCount,
        activeBOLOs     = boloCount,
        unitsOnDuty     = onDuty,
        pendingReports  = pendingCount,
        activeCalls     = activeCallsCount,      -- Updated
        unassignedCalls = unassignedCallsCount,  -- Updated
        dispatchChannel = Config.Department.dispatchChannel,
    }
end)

lib.callback.register('police_mdt:lookupCitizen', function(source, query)
    if not query or query == '' then return {} end
    local like = '%' .. query .. '%'
    
    if FrameworkName == 'esx' then
        local columns = MySQL.query.await('DESCRIBE `users`', {}) or {}
        local hasFirst = false
        for _, col in ipairs(columns) do if col.Field == 'firstname' then hasFirst = true end end
        local nameExpr = hasFirst and "CONCAT(firstname, ' ', lastname)" or 'name'

        local rows = MySQL.query.await(string.format([[
            SELECT identifier, %s AS charname, COALESCE(dateofbirth, '') AS dob, COALESCE(job, '') AS job
            FROM `users` WHERE %s LIKE ? LIMIT 30
        ]], nameExpr, nameExpr), { like })

        local out = {}
        for _, r in ipairs(rows or {}) do
            local hasWarrant = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_warrants` WHERE `subject_id` = ? AND `status` = ?', { r.identifier, 'ACTIVE' }) or 0
            local hasBolo = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `description` LIKE ? AND `status` = ?', { '%' .. (r.charname or '') .. '%', 'ACTIVE' }) or 0
            table.insert(out, { id = r.identifier, name = r.charname or '', dob = r.dob, job = r.job, status = hasWarrant > 0 and 'WARRANT' or (hasBolo > 0 and 'BOLO' or 'CLEAR') })
        end
        return out

    elseif FrameworkName == 'qbcore' then
        local rows = MySQL.query.await([[
            SELECT citizenid, charinfo, job FROM `players`
            WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
               OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
               OR citizenid LIKE ? LIMIT 30
        ]], { like, like, like, like })

        local out = {}
        for _, r in ipairs(rows or {}) do
            local ok, ci = pcall(json.decode, r.charinfo or '{}')
            if not ok then ci = {} end
            local fullName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$','')
            local dob = ci.birthdate or ''
            local ok2, jobInfo = pcall(json.decode, r.job or '{}')
            local jobName = (ok2 and jobInfo and jobInfo.name) or ''

            local hasWarrant = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_warrants` WHERE `subject_id` = ? AND `status` = ?', { r.citizenid, 'ACTIVE' }) or 0
            local hasBolo = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `description` LIKE ? AND `status` = ?', { '%' .. fullName .. '%', 'ACTIVE' }) or 0
            table.insert(out, { id = r.citizenid, name = fullName, dob = dob, job = jobName, status = hasWarrant > 0 and 'WARRANT' or (hasBolo > 0 and 'BOLO' or 'CLEAR') })
        end
        return out
    end
    return {}
end)

lib.callback.register('police_mdt:lookupVehicle', function(source, query)
    if not query or query == '' then return {} end
    local like = '%' .. query .. '%'
    
    if FrameworkName == 'esx' then
        local columns = MySQL.query.await('DESCRIBE `users`', {}) or {}
        local hasFirst = false
        for _, col in ipairs(columns) do if col.Field == 'firstname' then hasFirst = true end end
        local nameExpr = hasFirst and "CONCAT(u.firstname, ' ', u.lastname)" or 'u.name'

        local vehTable = 'owned_vehicles'
        local tbls = MySQL.query.await("SHOW TABLES LIKE 'owned_vehicles'", {}) or {}
        if #tbls == 0 then vehTable = 'player_vehicles' end

        local rows = MySQL.query.await(string.format([[
            SELECT ov.plate, ov.owner, ov.vehicle, %s AS owner_name
            FROM `%s` ov LEFT JOIN `users` u ON u.identifier = ov.owner
            WHERE ov.plate LIKE ? OR %s LIKE ? LIMIT 30
        ]], nameExpr, vehTable, nameExpr), { like, like }) 

        local out = {}
        for _, r in ipairs(rows or {}) do
            local model = r.vehicle or 'Unknown'
            if model:sub(1,1) == '{' then
                local ok, veh = pcall(json.decode, model)
                if ok and veh then model = tostring(veh.model or veh.name or 'Unknown') end
            end
            local hasBolo = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `plate` = ? AND `status` = ?', { r.plate, 'ACTIVE' }) or 0
            table.insert(out, { plate = r.plate, model = model, color = 'N/A', owner = r.owner_name or r.owner, status = hasBolo > 0 and 'BOLO' or 'CLEAR' })
        end
        return out

    elseif FrameworkName == 'qbcore' then
        local rows = MySQL.query.await([[
            SELECT pv.plate, pv.citizenid, pv.vehicle, pv.garage, p.charinfo
            FROM `player_vehicles` pv LEFT JOIN `players` p ON p.citizenid = pv.citizenid
            WHERE pv.plate LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE ? LIMIT 30
        ]], { like, like, like })

        local out = {}
        for _, r in ipairs(rows or {}) do
            local ok, veh = pcall(json.decode, r.vehicle or '{}')
            local ok2, ci = pcall(json.decode, r.charinfo or '{}')
            if not ok then veh = {} end
            if not ok2 then ci = {} end
            local model = tostring(veh.model or 'Unknown')
            local ownerName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+',''):gsub('%s+$','')
            local colour = 'N/A'
            if veh.mods and veh.mods.color1 then colour = tostring(veh.mods.color1) end
            
            local hasBolo = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `plate` = ? AND `status` = ?', { r.plate, 'ACTIVE' }) or 0
            table.insert(out, { plate = r.plate, model = model, color = colour, owner = ownerName ~= '' and ownerName or r.citizenid, status = hasBolo > 0 and 'BOLO' or 'CLEAR' })
        end
        return out
    end
    return {}
end)

lib.callback.register('police_mdt:lookupReports', function(source, query)
    local rows
    if query and query ~= '' then
        local like = '%' .. query .. '%'
        rows = MySQL.query.await([[
            SELECT id, title, report_type, officer, subject, status, DATE_FORMAT(created_at, '%Y-%m-%d') AS date 
            FROM `mdt_reports` 
            WHERE CAST(id AS CHAR) LIKE ? OR `title` LIKE ? OR `officer` LIKE ? OR `subject` LIKE ? OR `report_type` LIKE ? 
            ORDER BY created_at DESC LIMIT 50
        ]], { like, like, like, like, like })
    else
        rows = MySQL.query.await([[
            SELECT id, title, report_type, officer, subject, status, DATE_FORMAT(created_at, '%Y-%m-%d') AS date 
            FROM `mdt_reports` ORDER BY created_at DESC LIMIT 50
        ]], {})
    end
    return rows or {}
end)

lib.callback.register('police_mdt:getReport', function(source, reportId)
    local report = MySQL.query.await('SELECT * FROM `mdt_reports` WHERE `id` = ?', { reportId })
    if report and #report > 0 then
        return report[1]
    end
    return nil
end)

lib.callback.register('police_mdt:saveReport', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then
        return { ok = false, error = 'Not authorised' }
    end
    
    local officerName = getPlayerCharName(source)
    local reportTitle = data.title and data.title ~= '' and data.title or 'Untitled Report'
    
    if data.id and data.id > 0 then
        MySQL.update.await('UPDATE `mdt_reports` SET title = ?, report_type = ?, subject = ?, details = ?, involved_officers = ?, involved_citizens = ?, charges = ?, evidence = ?, status = ? WHERE id = ?', {
            reportTitle,
            data.reportType or 'Incident Report',
            data.subject or 'N/A',
            data.details or '',
            json.encode(data.involvedOfficers or {}),
            json.encode(data.involvedCitizens or {}),
            data.charges or '',
            json.encode(data.evidence or {}),
            data.status or 'OPEN',
            data.id
        })
        return { ok = true, id = data.id }
    else
        local id = MySQL.insert.await('INSERT INTO `mdt_reports` (title, report_type, officer, subject, details, involved_officers, involved_citizens, charges, evidence, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            reportTitle,
            data.reportType or 'Incident Report',
            officerName,
            data.subject or 'N/A',
            data.details or '',
            json.encode(data.involvedOfficers or {}),
            json.encode(data.involvedCitizens or {}),
            data.charges or '',
            json.encode(data.evidence or {}),
            data.status or 'OPEN'
        })
        return { ok = true, id = id }
    end
end)

-- WARRANTS LOOKUP CALLBACK (with filters)
lib.callback.register('police_mdt:lookupWarrants', function(source, query, statusFilter, priorityFilter)
    local conditions = {}
    local params = {}
    
    -- Text search condition
    if query and query ~= '' then
        local like = '%' .. query .. '%'
        -- Added CAST(id AS CHAR) LIKE ? to allow searching by Warrant Number
        table.insert(conditions, '(CAST(`id` AS CHAR) LIKE ? OR `subject_name` LIKE ? OR `charge` LIKE ? OR `subject_id` LIKE ?)')
        table.insert(params, like)
        table.insert(params, like)
        table.insert(params, like)
        table.insert(params, like)
    end
    
    -- Status filter
    if statusFilter and statusFilter ~= '' then
        table.insert(conditions, '`status` = ?')
        table.insert(params, statusFilter)
    end
    
    -- Priority filter
    if priorityFilter and priorityFilter ~= '' then
        table.insert(conditions, '`priority` = ?')
        table.insert(params, priorityFilter)
    end
    
    -- Build the WHERE clause
    local whereClause = ''
    if #conditions > 0 then
        whereClause = 'WHERE ' .. table.concat(conditions, ' AND ')
    end
    
    local rows = MySQL.query.await(string.format(
        'SELECT id, subject_id, subject_name, charge, issued_by, status, priority, DATE_FORMAT(created_at, \'%%Y-%%m-%%d\') AS date FROM `mdt_warrants` %s ORDER BY created_at DESC LIMIT 100',
        whereClause
    ), params)
    
    return rows or {}
end)

lib.callback.register('police_mdt:lookupBOLOs', function(source, query)
    local rows
    if query and query ~= '' then
        local like = '%' .. query .. '%'
        rows = MySQL.query.await([[
            SELECT id, bolo_type, subject_name, description, last_seen, plate, issued_by, status,
                   DATE_FORMAT(created_at, '%Y-%m-%d') AS date
            FROM `mdt_bolos`
            WHERE `subject_name` LIKE ? OR `description` LIKE ? OR `plate` LIKE ?
            ORDER BY created_at DESC LIMIT 50
        ]], { like, like, like })
    else
        rows = MySQL.query.await([[
            SELECT id, bolo_type, subject_name, description, last_seen, plate, issued_by, status,
                   DATE_FORMAT(created_at, '%Y-%m-%d') AS date
            FROM `mdt_bolos`
            ORDER BY created_at DESC LIMIT 50
        ]], {})
    end
    return rows or {}
end)

lib.callback.register('police_mdt:getRoster', function(source)
    local roster = {}
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        local job = getPlayerJob(pid)
        if isAllowedJob(job) then
            -- Get their identifier to check the database
            local identifier = nil
            if FrameworkName == 'esx' then
                local xPlayer = Framework.GetPlayerFromId(pid)
                identifier = xPlayer and xPlayer.identifier
            elseif FrameworkName == 'qbcore' then
                local Player = Framework.Functions.GetPlayer(pid)
                identifier = Player and Player.PlayerData.citizenid
            end

            local assignment = 'Unassigned'
            if identifier then
                local row = MySQL.single.await('SELECT `assignment` FROM `mdt_officer_assignments` WHERE `identifier` = ?', { identifier })
                if row then assignment = row.assignment end
            end

            table.insert(roster, { 
                id = pid, 
                name = getPlayerCharName(pid), 
                job = job,
                grade = getPlayerGradeLabel(pid), 
                status = 'ON DUTY',
                assignment = assignment 
            })
        end
    end
    return roster
end)

-- SAVE ASSIGNMENT CALLBACK
lib.callback.register('police_mdt:saveAssignment', function(source, assignment)
    if not isAllowedJob(getPlayerJob(source)) then return { ok = false } end
    
    local identifier = nil
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        identifier = xPlayer and xPlayer.identifier
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        identifier = Player and Player.PlayerData.citizenid
    end

    if identifier then
        MySQL.insert.await([[
            INSERT INTO `mdt_officer_assignments` (`identifier`, `assignment`) 
            VALUES (?, ?) 
            ON DUPLICATE KEY UPDATE `assignment` = VALUES(`assignment`)
        ]], { identifier, assignment })
        return { ok = true }
    end
    return { ok = false }
end)

lib.callback.register('police_mdt:createWarrant', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then return { ok = false, error = 'Not authorised' } end
    if not data or not data.subjectId or not data.charge then return { ok = false, error = 'Missing fields' } end
    
    local id = MySQL.insert.await('INSERT INTO `mdt_warrants` (subject_id, subject_name, charge, issued_by, status) VALUES (?, ?, ?, ?, ?)', { 
        data.subjectId, 
        data.subjectName or data.subjectId, 
        data.charge, 
        getPlayerCharName(source), 
        'ACTIVE' 
    })
    return { ok = true, id = id }
end)

lib.callback.register('police_mdt:createBOLO', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then return { ok = false, error = 'Not authorised' } end
    if not data or not data.description then return { ok = false, error = 'Missing description' } end
    
    local id = MySQL.insert.await('INSERT INTO `mdt_bolos` (bolo_type, description, last_seen, plate, issued_by, status) VALUES (?, ?, ?, ?, ?, ?)', { 
        data.boloType or 'person', 
        data.description, 
        data.lastSeen or '', 
        data.plate or '', 
        getPlayerCharName(source), 
        'ACTIVE' 
    })
    return { ok = true, id = id }
end)

lib.callback.register('police_mdt:createReport', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then return { ok = false, error = 'Not authorised' } end
    if not data or not data.details then return { ok = false, error = 'Missing details' } end
    
    local id = MySQL.insert.await('INSERT INTO `mdt_reports` (report_type, officer, subject, details, status) VALUES (?, ?, ?, ?, ?)', { 
        data.reportType or 'Incident Report', 
        getPlayerCharName(source), 
        data.subject or 'N/A', 
        data.details,
        'PENDING'
    })
    return { ok = true, id = id }
end)

lib.callback.register('police_mdt:getRecentActivity', function(source)
    local activities = {}
    local warrants = MySQL.query.await([[SELECT 'Warrant' AS type, subject_name AS subject, charge AS details, issued_by AS officer, created_at FROM `mdt_warrants` ORDER BY created_at DESC LIMIT 10]], {}) or {}
    local bolos = MySQL.query.await([[SELECT 'BOLO' AS type, bolo_type AS subject, description AS details, issued_by AS officer, created_at FROM `mdt_bolos` ORDER BY created_at DESC LIMIT 10]], {}) or {}
    local reports = MySQL.query.await([[SELECT 'Report' AS type, subject, details, officer, created_at FROM `mdt_reports` ORDER BY created_at DESC LIMIT 10]], {}) or {}
    
    for _, w in ipairs(warrants) do table.insert(activities, w) end
    for _, b in ipairs(bolos) do table.insert(activities, b) end
    for _, r in ipairs(reports) do table.insert(activities, r) end

    table.sort(activities, function(a, b) return a.created_at > b.created_at end)

    local result = {}
    for i = 1, math.min(10, #activities) do
        local act = activities[i]
        table.insert(result, { type = act.type, subject = act.subject, details = act.details, officer = act.officer, time = string.sub(act.created_at, 12, 16) })
    end
    return result
end)

-- SEARCH NAMES FOR AUTOCOMPLETE (Searches ALL citizens)
lib.callback.register('police_mdt:searchNames', function(source, data)
    local query = data.query
    if not query or query == '' then return {} end
    local like = '%' .. query .. '%'
    local results = {}

    if FrameworkName == 'esx' then
        local rows = MySQL.query.await(
            "SELECT identifier, CONCAT(firstname, ' ', lastname) as name FROM `users` WHERE CONCAT(firstname, ' ', lastname) LIKE ? OR identifier LIKE ? LIMIT 5",
            { like, like }
        )
        for _, r in ipairs(rows or {}) do
            table.insert(results, { id = r.identifier, name = r.name })
        end
    elseif FrameworkName == 'qbcore' then
        local rows = MySQL.query.await(
            "SELECT citizenid, charinfo FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ? LIMIT 5",
            { like, like }
        )
        for _, r in ipairs(rows or {}) do
            local ok, ci = pcall(json.decode, r.charinfo or '{}')
            if ok then
                local fullName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$','')
                table.insert(results, { id = r.citizenid, name = fullName })
            end
        end
    end
    return results
end)

-- GET SINGLE WARRANT
lib.callback.register('police_mdt:getWarrant', function(source, warrantId)
    local warrant = MySQL.query.await('SELECT * FROM `mdt_warrants` WHERE `id` = ?', { warrantId })
    if warrant and #warrant > 0 then
        return warrant[1]
    end
    return nil
end)

-- CREATE/UPDATE WARRANT
lib.callback.register('police_mdt:saveWarrant', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then
        return { ok = false, error = 'Not authorised' }
    end
    
    local officerName = getPlayerCharName(source)
    
    if data.id and data.id > 0 then
        -- Update existing warrant
        MySQL.update.await('UPDATE `mdt_warrants` SET subject_name = ?, subject_id = ?, charge = ?, description = ?, priority = ?, status = ? WHERE id = ?', {
            data.subjectName,
            data.subjectId,
            data.charge,
            data.description or '',
            data.priority or 'Medium',
            data.status or 'ACTIVE',
            data.id
        })
        return { ok = true, id = data.id }
    else
        -- Create new warrant
        local id = MySQL.insert.await('INSERT INTO `mdt_warrants` (subject_name, subject_id, charge, description, priority, issued_by, status) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            data.subjectName,
            data.subjectId,
            data.charge,
            data.description or '',
            data.priority or 'Medium',
            officerName,
            data.status or 'ACTIVE'
        })
        return { ok = true, id = id }
    end
end)

-- BOLOs LOOKUP CALLBACK (with filters)
lib.callback.register('police_mdt:lookupBOLOs', function(source, query, statusFilter, typeFilter)
    local conditions = {}
    local params = {}
    
    if query and query ~= '' then
        local like = '%' .. query .. '%'
        table.insert(conditions, '(`subject_name` LIKE ? OR `description` LIKE ? OR `plate` LIKE ?)')
        table.insert(params, like)
        table.insert(params, like)
        table.insert(params, like)
    end
    
    if statusFilter and statusFilter ~= '' then
        table.insert(conditions, '`status` = ?')
        table.insert(params, statusFilter)
    end
    
    if typeFilter and typeFilter ~= '' then
        table.insert(conditions, '`bolo_type` = ?')
        table.insert(params, typeFilter)
    end
    
    local whereClause = ''
    if #conditions > 0 then
        whereClause = 'WHERE ' .. table.concat(conditions, ' AND ')
    end
    
    local rows = MySQL.query.await(string.format(
        'SELECT id, bolo_type, subject_name, description, plate, priority, status, DATE_FORMAT(created_at, \'%%Y-%%m-%%d\') AS date FROM `mdt_bolos` %s ORDER BY created_at DESC LIMIT 100',
        whereClause
    ), params)
    
    return rows or {}
end)

-- GET SINGLE BOLO
lib.callback.register('police_mdt:getBOLO', function(source, boloId)
    local bolo = MySQL.query.await('SELECT * FROM `mdt_bolos` WHERE `id` = ?', { boloId })
    if bolo and #bolo > 0 then return bolo[1] end
    return nil
end)

-- CREATE/UPDATE BOLO
lib.callback.register('police_mdt:saveBOLO', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then
        return { ok = false, error = 'Not authorised' }
    end
    
    local officerName = getPlayerCharName(source)
    
    if data.id and data.id > 0 then
        MySQL.update.await('UPDATE `mdt_bolos` SET bolo_type = ?, subject_name = ?, description = ?, last_seen = ?, plate = ?, image_url = ?, priority = ?, status = ? WHERE id = ?', {
            data.boloType, data.subjectName, data.description, data.lastSeen or '', data.plate or '', data.imageUrl or '', data.priority or 'Medium', data.status or 'ACTIVE', data.id
        })
        return { ok = true, id = data.id }
    else
        local id = MySQL.insert.await('INSERT INTO `mdt_bolos` (bolo_type, subject_name, description, last_seen, plate, image_url, priority, issued_by, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            data.boloType, data.subjectName, data.description, data.lastSeen or '', data.plate or '', data.imageUrl or '', data.priority or 'Medium', officerName, data.status or 'ACTIVE'
        })
        return { ok = true, id = id }
    end
end)

-- EVIDENCE SEARCH CALLBACK
lib.callback.register('police_mdt:searchEvidence', function(source, query)
    local rows
    if query and query ~= '' then
        local like = '%' .. query .. '%'
        rows = MySQL.query.await([[
            SELECT id, locker_number, perpetrator, officer, notes, DATE_FORMAT(created_at, '%Y-%m-%d') AS date 
            FROM `mdt_evidence` 
            WHERE `perpetrator` LIKE ? OR `officer` LIKE ? OR CAST(`locker_number` AS CHAR) LIKE ? 
            ORDER BY created_at DESC LIMIT 50
        ]], { like, like, like })
    else
        rows = MySQL.query.await([[
            SELECT id, locker_number, perpetrator, officer, notes, DATE_FORMAT(created_at, '%Y-%m-%d') AS date 
            FROM `mdt_evidence` ORDER BY created_at DESC LIMIT 50
        ]], {})
    end
    return rows or {}
end)

-- Shared helper: fetch the current contents of an evidence locker's ox_inventory stash
local function getEvidenceLockerItems(lockerNumber)
    -- Assumes your evidence lockers are named 'evidence-{number}' in ox_inventory
    local stashName = 'evidence-' .. lockerNumber
    local stash = MySQL.single.await('SELECT `data` FROM `ox_inventory` WHERE `name` = ?', { stashName })

    local items = {}
    if stash and stash.data then
        local ok, decoded = pcall(json.decode, stash.data)
        if ok and decoded then
            for _, item in ipairs(decoded) do
                table.insert(items, {
                    name = item.name,
                    count = item.count,
                    metadata = item.metadata or {}
                })
            end
        end
    end
    return items
end

-- GET SINGLE EVIDENCE LOCKER (Fetches items from ox_inventory)
lib.callback.register('police_mdt:getEvidenceLocker', function(source, lockerNumber)
    local evidence = MySQL.single.await('SELECT * FROM `mdt_evidence` WHERE `locker_number` = ?', { lockerNumber })
    if not evidence then return nil end

    evidence.items = getEvidenceLockerItems(lockerNumber)
    return evidence
end)

-- Sends a Discord log embed whenever an evidence locker is created/updated
local function sendEvidenceWebhook(lockerNumber, perpetrator, officerName, notes, items)
    if not Config.EvidenceWebhook or Config.EvidenceWebhook == '' then return end

    local itemsText
    if items and #items > 0 then
        local lines = {}
        for _, item in ipairs(items) do
            table.insert(lines, ('• %s x%s'):format(item.name, item.count or 1))
        end
        itemsText = table.concat(lines, '\n')
    else
        itemsText = '*No items currently in locker*'
    end

    local embed = {
        {
            title = 'Evidence Locker Updated',
            color = 15105570, -- amber
            fields = {
                { name = 'Locker Number', value = tostring(lockerNumber),        inline = true },
                { name = 'Officer',       value = officerName or 'Unknown',      inline = true },
                { name = 'Perpetrator',   value = perpetrator or 'Unknown',      inline = true },
                { name = 'Date & Time',   value = os.date('%Y-%m-%d %H:%M:%S'),  inline = false },
                { name = 'Notes',         value = (notes ~= '' and notes) or '*None*', inline = false },
                { name = 'Items in Locker', value = itemsText, inline = false },
            },
            footer = { text = Config.Department and Config.Department.dispatchChannel or 'MDT' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%S'),
        }
    }

    PerformHttpRequest(Config.EvidenceWebhook, function(statusCode, _, _) end, 'POST', json.encode({
        username = 'Evidence Log',
        embeds = embed,
    }), { ['Content-Type'] = 'application/json' })
end

-- CREATE/UPDATE EVIDENCE RECORD
lib.callback.register('police_mdt:saveEvidence', function(source, data)
    if not isAllowedJob(getPlayerJob(source)) then
        return { ok = false, error = 'Not authorised' }
    end
    
    local officerName = data.officer or getPlayerCharName(source)
    local notes = data.notes or ''
    
    -- Upsert: Insert or Update on duplicate locker_number
    MySQL.insert.await([[
        INSERT INTO `mdt_evidence` (locker_number, perpetrator, officer, notes) 
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE perpetrator = VALUES(perpetrator), officer = VALUES(officer), notes = VALUES(notes)
    ]], {
        data.lockerNumber,
        data.perpetrator,
        officerName,
        notes
    })

    -- Fire off the Discord log with the locker's current contents
    local items = getEvidenceLockerItems(data.lockerNumber)
    sendEvidenceWebhook(data.lockerNumber, data.perpetrator, officerName, notes, items)
    
    return { ok = true }
end)

lib.callback.register('police_mdt:getDispatchCalls', function(source)
    local calls = MySQL.query.await('SELECT * FROM `mdt_dispatch_calls` WHERE `status` != "Cleared" ORDER BY `created_at` DESC', {})
    return calls or {}
end)

-- DISPATCH API: LISTEN FOR CALLS FROM OTHER SCRIPTS
RegisterNetEvent('scs_mdt:server:createDispatchCall', function(data)
    -- data should contain: type, x, y, z, priority, and optionally description
    local src = source
    local callType = data.type or 'Unknown'
    local priority = data.priority or 'Code 2'
    local x, y, z = data.x, data.y, data.z

    -- Prefer a human-readable description if one was supplied (e.g. "Robbery in
    -- progress at the Pacific Standard Bank"); otherwise fall back to coordinates.
    local locationStr = data.description or string.format("X: %.1f, Y: %.1f, Z: %.1f", x, y, z)

    -- Save to Database
    local id = MySQL.insert.await('INSERT INTO `mdt_dispatch_calls` (call_type, location, location_x, location_y, location_z, priority, status) VALUES (?, ?, ?, ?, ?, ?, "Pending")', {
        callType, locationStr, x, y, z, priority
    })

    -- Broadcast only to police players (server-side gate; client gate is secondary safety net)
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if isAllowedJob(getPlayerJob(pid)) then
            TriggerClientEvent('scs_mdt:client:newCall', pid, {
                id = id,
                type = callType,
                location = locationStr,
                x = x, y = y, z = z,
                priority = priority,
                status = 'Pending',
                unit = 'Unassigned'
            })
        end
    end
end)

RegisterNetEvent('scs_mdt:server:assignDispatchCall', function(callId)
    local source = source
    if not isAllowedJob(getPlayerJob(source)) then return end

    local officerName = getPlayerCharName(source)

    -- Only claim it if nobody else already has it (or it's already us — idempotent)
    local affected = MySQL.update.await([[
        UPDATE `mdt_dispatch_calls`
        SET `assigned_unit` = ?, `status` = "Assigned"
        WHERE `id` = ? AND `status` != "Cleared"
          AND (`assigned_unit` IS NULL OR `assigned_unit` = '' OR `assigned_unit` = ?)
    ]], { officerName, callId, officerName })

    if affected and affected > 0 then
        TriggerClientEvent('scs_mdt:client:updateDispatchCall', -1, callId, officerName)
    end
end)

-- DISPATCH API: UNASSIGN (officer presses G again to drop the call)
RegisterNetEvent('scs_mdt:server:unassignDispatchCall', function(callId)
    local source = source
    if not isAllowedJob(getPlayerJob(source)) then return end

    local officerName = getPlayerCharName(source)

    -- Only the officer who is currently assigned can unassign themselves
    local affected = MySQL.update.await([[
        UPDATE `mdt_dispatch_calls`
        SET `assigned_unit` = NULL, `status` = "Pending"
        WHERE `id` = ? AND `assigned_unit` = ? AND `status` != "Cleared"
    ]], { callId, officerName })

    if affected and affected > 0 then
        TriggerClientEvent('scs_mdt:client:updateDispatchCall', -1, callId, 'Unassigned')
    end
end)

-- DISPATCH API: CLEAR CALL (For when officers clear it via MDT or other scripts)
RegisterNetEvent('scs_mdt:server:clearDispatchCall', function(callId)
    MySQL.update.await('UPDATE `mdt_dispatch_calls` SET `status` = "Cleared" WHERE `id` = ?', { callId })
    TriggerClientEvent('scs_mdt:client:clearCall', -1, callId)
end)

-- AUTO-CLEAR DISPATCH CALLS AFTER 5 MINUTES
CreateThread(function()
    while true do
        Wait(60000) -- Check every 60 seconds
        
        -- Find calls older than 5 minutes that aren't already cleared
        local clearedCalls = MySQL.query.await(
            'SELECT `id` FROM `mdt_dispatch_calls` WHERE `status` != "Cleared" AND `created_at` < DATE_SUB(NOW(), INTERVAL 5 MINUTE)'
        )
        
        if clearedCalls and #clearedCalls > 0 then
            local ids = {}
            for _, call in ipairs(clearedCalls) do
                table.insert(ids, call.id)
            end
            
            -- 1. Update database status to "Cleared" (Hides it from the MDT UI)
            MySQL.update.await(
                'UPDATE `mdt_dispatch_calls` SET `status` = "Cleared" WHERE `id` IN (' .. table.concat(ids, ',') .. ')'
            )
            
            -- 2. Tell all clients to remove the minimap blips
            for _, id in ipairs(ids) do
                TriggerClientEvent('scs_mdt:client:clearCall', -1, id)
            end
        end
    end
end)

-- SAVE OFFICER PORTRAIT
lib.callback.register('police_mdt:savePortrait', function(source, imageUrl)
    if not imageUrl then return false end

    local identifier = nil
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        identifier = xPlayer and xPlayer.identifier
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        identifier = Player and Player.PlayerData.citizenid
    end

    if not identifier then
        print('^1[POLICE MDT] savePortrait failed: no identifier for source', source, '^7')
        return false
    end

    local success, result = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO `mdt_portraits` (`identifier`, `portrait_data`) 
            VALUES (?, ?) 
            ON DUPLICATE KEY UPDATE `portrait_data` = VALUES(`portrait_data`)
        ]], { identifier, imageUrl })
    end)

    if not success then
        print('^1[POLICE MDT] savePortrait SQL error: ' .. tostring(result) .. '^7')
        return false
    end

    return true
end)

-- GET OFFICER PORTRAIT
lib.callback.register('police_mdt:getPortrait', function(source)
    local identifier = nil
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        identifier = xPlayer and xPlayer.identifier
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        identifier = Player and Player.PlayerData.citizenid
    end
    
    if not identifier then return nil end

    local row = MySQL.single.await('SELECT `portrait_data` FROM `mdt_portraits` WHERE `identifier` = ?', { identifier })
    return row and row.portrait_data or nil
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- CITIZEN PROFILE
-- ─────────────────────────────────────────────────────────────────────────────

-- GET FULL CITIZEN PROFILE (portrait, vehicles, reports, warrants, notes)
lib.callback.register('police_mdt:getCitizenProfile', function(source, identifier, charName)
    if not isAllowedJob(getPlayerJob(source)) then return {} end
    if not identifier then return {} end

    -- Portrait / mugshot
    local portraitRow = MySQL.single.await('SELECT `portrait_data` FROM `mdt_portraits` WHERE `identifier` = ?', { identifier })
    local portrait = portraitRow and portraitRow.portrait_data or nil

    -- Officer notes
    local notesRow = MySQL.single.await('SELECT `notes` FROM `mdt_citizen_notes` WHERE `identifier` = ?', { identifier })
    local description = notesRow and notesRow.notes or ''

    -- Vehicles
    local vehicles = {}
    if FrameworkName == 'esx' then
        local vehTable = 'owned_vehicles'
        local tbls = MySQL.query.await("SHOW TABLES LIKE 'owned_vehicles'", {}) or {}
        if #tbls == 0 then vehTable = 'player_vehicles' end
        local rows = MySQL.query.await(string.format(
            'SELECT plate, vehicle FROM `%s` WHERE `owner` = ? LIMIT 20', vehTable
        ), { identifier })
        for _, r in ipairs(rows or {}) do
            local model = r.vehicle or 'Unknown'
            if model:sub(1,1) == '{' then
                local ok, veh = pcall(json.decode, model)
                if ok and veh then model = tostring(veh.model or veh.name or 'Unknown') end
            end
            local hasBolo = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `plate` = ? AND `status` = ?', { r.plate, 'ACTIVE' }) or 0
            table.insert(vehicles, { plate = r.plate, model = model, status = hasBolo > 0 and 'BOLO' or 'CLEAR' })
        end
    elseif FrameworkName == 'qbcore' then
        local rows = MySQL.query.await(
            'SELECT plate, vehicle FROM `player_vehicles` WHERE `citizenid` = ? LIMIT 20', { identifier }
        )
        for _, r in ipairs(rows or {}) do
            local model = r.vehicle or 'Unknown'
            if model:sub(1,1) == '{' then
                local ok, veh = pcall(json.decode, model)
                if ok and veh then model = tostring(veh.model or veh.name or 'Unknown') end
            end
            local hasBolo = MySQL.scalar.await('SELECT COUNT(*) FROM `mdt_bolos` WHERE `plate` = ? AND `status` = ?', { r.plate, 'ACTIVE' }) or 0
            table.insert(vehicles, { plate = r.plate, model = model, status = hasBolo > 0 and 'BOLO' or 'CLEAR' })
        end
    end

    -- Reports the citizen is named in
    local reportRows = {}
    if charName and charName ~= '' then
        local nameLike = '%' .. charName .. '%'
        reportRows = MySQL.query.await([[
            SELECT id, title, report_type, officer, DATE_FORMAT(created_at, '%Y-%m-%d') AS date
            FROM `mdt_reports`
            WHERE `subject` LIKE ? OR `involved_citizens` LIKE ?
            ORDER BY created_at DESC LIMIT 20
        ]], { nameLike, nameLike }) or {}
    end
    local reports = {}
    for _, r in ipairs(reportRows) do
        table.insert(reports, { id = r.id, title = r.title, type = r.report_type, officer = r.officer, date = r.date })
    end

    -- Warrants against this citizen
    local warrantRows = MySQL.query.await([[
        SELECT charge, status, issued_by, DATE_FORMAT(created_at, '%Y-%m-%d') AS date
        FROM `mdt_warrants`
        WHERE `subject_id` = ?
        ORDER BY created_at DESC LIMIT 20
    ]], { identifier }) or {}
    local warrants = {}
    for _, w in ipairs(warrantRows) do
        table.insert(warrants, { charge = w.charge, status = w.status, issued_by = w.issued_by, date = w.date })
    end

    return { portrait = portrait, description = description, vehicles = vehicles, reports = reports, warrants = warrants }
end)

-- SAVE CITIZEN OFFICER NOTES
lib.callback.register('police_mdt:saveCitizenDescription', function(source, identifier, notes)
    if not isAllowedJob(getPlayerJob(source)) then return { ok = false } end
    if not identifier then return { ok = false } end
    local officerName = getPlayerCharName(source)
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO `mdt_citizen_notes` (`identifier`, `notes`, `updated_by`)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `notes` = VALUES(`notes`), `updated_by` = VALUES(`updated_by`)
        ]], { identifier, notes or '', officerName or '' })
    end)
    if not ok then
        print('^1[POLICE MDT] saveCitizenDescription error: ' .. tostring(err) .. '^7')
        return { ok = false }
    end
    return { ok = true }
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- MUGSHOT SYSTEM
-- ─────────────────────────────────────────────────────────────────────────────

-- CALLBACK: Return nearby players to the officer (job-gated)
lib.callback.register('police_mdt:getNearbyPlayers', function(source)
    local job = getPlayerJob(source)
    if not isAllowedJob(job) then
        return { allowed = false, players = {} }
    end

    local officerCoords = GetEntityCoords(GetPlayerPed(source))
    local range         = Config.MugshotRange or 10.0
    local nearby        = {}

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= source then
            local coords = GetEntityCoords(GetPlayerPed(pid))
            if #(officerCoords - coords) <= range then
                table.insert(nearby, {
                    serverId = pid,
                    name     = getPlayerCharName(pid) or GetPlayerName(pid),
                })
            end
        end
    end

    table.sort(nearby, function(a, b) return a.name < b.name end)
    return { allowed = true, players = nearby }
end)

-- NET EVENT: Officer requests mugshot on a target
RegisterNetEvent('scs_mdt:server:requestMugshot', function(targetId)
    local source = source

    if not isAllowedJob(getPlayerJob(source)) then
        TriggerClientEvent('scs_mdt:client:mugshotDone', source, nil, nil)
        return
    end

    local ped = GetPlayerPed(targetId)
    if not ped or ped == 0 then
        TriggerClientEvent('scs_mdt:client:mugshotDone', source, nil, nil)
        return
    end

    -- Fire on the target's client; pass officer ID so result can route back
    TriggerClientEvent('scs_mdt:client:takeMugshot', targetId, source)
end)

-- NET EVENT: Target's screenshot result returns to server
RegisterNetEvent('scs_mdt:server:mugshotResult', function(officerId, imageUrl)
    local targetId    = source
    local subjectName = getPlayerCharName(targetId)
    local identifier  = getPlayerIdentifier(targetId)

    if imageUrl and identifier then
        local ok, err = pcall(function()
            MySQL.insert.await([[
                INSERT INTO `mdt_portraits` (`identifier`, `portrait_data`)
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE `portrait_data` = VALUES(`portrait_data`)
            ]], { identifier, imageUrl })
        end)

        if not ok then
            print('^1[POLICE MDT] mugshotResult SQL error: ' .. tostring(err) .. '^7')
        else
            print(string.format('^2[POLICE MDT] Mugshot saved for %s (%s) by officer %s^7',
                subjectName or 'unknown', identifier, GetPlayerName(officerId)))
        end
    end

    TriggerClientEvent('scs_mdt:client:mugshotDone', officerId, imageUrl or nil, subjectName)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SURVEILLANCE / CCTV CAMERAS
-- ─────────────────────────────────────────────────────────────────────────────

-- Push the full camera list to everyone; clients ignore it unless allowed/relevant.
local function broadcastCameraList()
    local rows = MySQL.query.await([[
        SELECT `id`, `name`, `pos_x`, `pos_y`, `pos_z`, `heading`, `placed_by`,
               DATE_FORMAT(`created_at`, '%Y-%m-%d %H:%i') AS date
        FROM `mdt_cameras`
        ORDER BY `created_at` DESC
    ]], {}) or {}
    TriggerClientEvent('scs_mdt:client:cameraListUpdate', -1, rows)
end

-- CALLBACK: Check if the player actually has a CCTV camera item before letting them
-- enter placement mode (so the placement screen never opens for nothing).
lib.callback.register('police_mdt:hasCCTVItem', function(source)
    if not isAllowedJob(getPlayerJob(source)) then return false end
    local count = exports.ox_inventory:Search(source, 'count', Config.CCTV.item)
    return (count or 0) > 0
end)

-- CALLBACK: Get all placed cameras (for the Surveillance tab)
lib.callback.register('police_mdt:getCameras', function(source)    if not isAllowedJob(getPlayerJob(source)) then return {} end
    return MySQL.query.await([[
        SELECT `id`, `name`, `pos_x`, `pos_y`, `pos_z`, `heading`, `placed_by`,
               DATE_FORMAT(`created_at`, '%Y-%m-%d %H:%i') AS date
        FROM `mdt_cameras`
        ORDER BY `created_at` DESC
    ]], {}) or {}
end)

-- CALLBACK: Delete a camera
lib.callback.register('police_mdt:deleteCamera', function(source, cameraId)
    if not isAllowedJob(getPlayerJob(source)) then return { ok = false, error = 'Not authorised' } end
    if not cameraId then return { ok = false, error = 'Missing camera id' } end

    MySQL.query.await('DELETE FROM `mdt_cameras` WHERE `id` = ?', { cameraId })
    broadcastCameraList()
    return { ok = true }
end)

-- EVENT: Officer used the CCTV camera item and confirmed a placement spot.
-- Validates the item is actually in their inventory before removing it,
-- so cancelling out of placement (ESC) never costs the item.
RegisterNetEvent('scs_mdt:server:placeCamera', function(coords, heading)
    local source = source
    if not isAllowedJob(getPlayerJob(source)) then return end
    if not coords or type(coords) ~= 'table' then return end

    local itemName = Config.CCTV.item
    local count = exports.ox_inventory:Search(source, 'count', itemName)
    if not count or count < 1 then
        TriggerClientEvent('scs_mdt:client:placementFailed', source, 'You don\'t have a CCTV camera.')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(source, itemName, 1)
    if not removed then
        TriggerClientEvent('scs_mdt:client:placementFailed', source, 'Failed to consume the CCTV camera.')
        return
    end

    local officerName = getPlayerCharName(source)
    local cameraId = MySQL.insert.await([[
        INSERT INTO `mdt_cameras` (`name`, `pos_x`, `pos_y`, `pos_z`, `heading`, `placed_by`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { 'Unnamed Camera', coords.x, coords.y, coords.z, heading or 0.0, officerName or 'Unknown' })

    broadcastCameraList()
    TriggerClientEvent('scs_mdt:client:promptCameraName', source, cameraId)
end)

-- EVENT: Officer named (or skipped naming) a freshly placed camera.
RegisterNetEvent('scs_mdt:server:nameCamera', function(cameraId, name)
    local source = source
    if not isAllowedJob(getPlayerJob(source)) then return end
    if not cameraId then return end

    name = (name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = 'Unnamed Camera #' .. tostring(cameraId) end
    if #name > 60 then name = name:sub(1, 60) end

    MySQL.query.await('UPDATE `mdt_cameras` SET `name` = ? WHERE `id` = ?', { name, cameraId })
    broadcastCameraList()
end)
-- ─────────────────────────────────────────────────────────────────────────────
-- BODYCAM SYSTEM
-- Runtime-only: no DB. Active bodycams stored in memory.
-- activeBodycams[src] = { name = string, viewers = { [viewerSrc] = true } }
-- ─────────────────────────────────────────────────────────────────────────────

local activeBodycams = {}

local function broadcastBodycamList()
    local list = {}
    for src, data in pairs(activeBodycams) do
        table.insert(list, { serverId = src, name = data.name })
    end
    TriggerClientEvent('scs_mdt:client:bodycamListUpdate', -1, list)
end

-- CALLBACK: Get current active bodycam list (for tab open)
lib.callback.register('police_mdt:getBodycams', function(source)
    if not isAllowedJob(getPlayerJob(source)) then return {} end
    local list = {}
    for src, data in pairs(activeBodycams) do
        table.insert(list, { serverId = src, name = data.name })
    end
    return list
end)

-- EVENT: Officer activates their bodycam (item used)
RegisterNetEvent('scs_mdt:server:activateBodycam', function()
    local source = source
    if not isAllowedJob(getPlayerJob(source)) then return end
    local name = getPlayerCharName(source) or GetPlayerName(source)
    activeBodycams[source] = { name = name, viewers = {} }
    broadcastBodycamList()
    print(string.format('^2[POLICE MDT] Bodycam activated by %s (%d)^7', name, source))
end)

-- EVENT: Officer deactivates their bodycam (off duty / respawn)
RegisterNetEvent('scs_mdt:server:deactivateBodycam', function()
    local source = source
    if not activeBodycams[source] then return end
    -- Kick all viewers out
    for viewerSrc in pairs(activeBodycams[source].viewers) do
        TriggerClientEvent('scs_mdt:client:bodycamFeedClosed', viewerSrc)
    end
    activeBodycams[source] = nil
    broadcastBodycamList()
end)

-- EVENT: Viewer requests to watch an officer's bodycam
RegisterNetEvent('scs_mdt:server:watchBodycam', function(targetSrc)
    local source = source
    if not isAllowedJob(getPlayerJob(source)) then return end
    if not activeBodycams[targetSrc] then
        TriggerClientEvent('scs_mdt:client:bodycamFeedClosed', source)
        return
    end
    activeBodycams[targetSrc].viewers[source] = true
    -- Tell the officer's client to start streaming to this viewer
    TriggerClientEvent('scs_mdt:client:bodycamAddViewer', targetSrc, source)
    -- Tell viewer the officer name
    TriggerClientEvent('scs_mdt:client:bodycamFeedStarted', source, activeBodycams[targetSrc].name)
end)

-- EVENT: Viewer stops watching
RegisterNetEvent('scs_mdt:server:stopWatchBodycam', function(targetSrc)
    local source = source
    if activeBodycams[targetSrc] then
        activeBodycams[targetSrc].viewers[source] = nil
        TriggerClientEvent('scs_mdt:client:bodycamRemoveViewer', targetSrc, source)
    end
end)

-- EVENT: Officer streams their position/heading to all current viewers
RegisterNetEvent('scs_mdt:server:bodycamFrame', function(data)
    local source = source
    if not activeBodycams[source] then return end
    for viewerSrc in pairs(activeBodycams[source].viewers) do
        TriggerClientEvent('scs_mdt:client:bodycamFrame', viewerSrc, data)
    end
end)

-- Clean up if officer disconnects
AddEventHandler('playerDropped', function()
    local source = source
    if activeBodycams[source] then
        for viewerSrc in pairs(activeBodycams[source].viewers) do
            TriggerClientEvent('scs_mdt:client:bodycamFeedClosed', viewerSrc)
        end
        activeBodycams[source] = nil
        broadcastBodycamList()
    end
end)
