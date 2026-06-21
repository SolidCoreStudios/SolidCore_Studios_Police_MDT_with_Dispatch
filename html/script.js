// ────────────────────────────────────────────────
//  POLICE MDT  |  script.js
// ────────────────────────────────────────────────

// ── Helpers ──────────────────────────────────────
function nuiFetch(event, data) {
    return fetch(`https://${GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then(r => r.json()).catch(() => ({}));
}

// ── Toast Notifications ───────────────────────────
function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => toast.classList.add('show'), 10);

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ── Officer Portrait ──────────────────────────────
function takePortrait() {
    showToast('Taking photo... Please wait.', 'info');
    
    nuiFetch('takePortrait', {}).then(res => {
        if (res.ok && res.image) {
            showToast('Portrait updated successfully!', 'success');
            // Update the dept logo spot with the officer's portrait
            const logoEl = document.getElementById('deptLogo');
            if (logoEl) {
                logoEl.style.backgroundImage = `url('${res.image}')`;
            }
        } else {
            showToast('Failed to take portrait.', 'error');
        }
    });
}

function loadOfficerPortrait() {
    nuiFetch('getPortrait', {}).then(res => {
        if (res && res.image) {
            const logoEl = document.getElementById('deptLogo');
            if (logoEl) {
                logoEl.style.backgroundImage = `url('${res.image}')`;
            }
        }
    });
}

function emptyRow(cols, msg) {
    return `<tr><td colspan="${cols}" style="color:#566b80;text-align:center;padding:18px;">${msg || 'No results found.'}</td></tr>`;
}

function statusBadge(status) {
    const map = {
        'WARRANT': 'active', 'ACTIVE': 'active', 'STOLEN': 'active',
        'BOLO':    'bolo',
        'CLEAR':   'clear',  'APPROVED': 'clear', 'ON DUTY': 'clear',
        'PENDING': 'pending',
    };
    const cls = map[(status || '').toUpperCase()] || 'pending';
    return `<span class="badge ${cls}">${status || '—'}</span>`;
}

// ── Login Screen ──────────────────────────────────
function showLoginScreen(department) {
    if (department) {
        const d = department;
        if (d.nameLine1) document.getElementById('loginLine1').textContent = d.nameLine1;
        if (d.nameLine2) document.getElementById('loginLine2').textContent = d.nameLine2;
        if (d.motto)     document.getElementById('loginMotto').textContent = d.motto;
        if (d.logoUrl)   document.getElementById('loginLogo').style.backgroundImage = `url('${d.logoUrl}')`;
    }
    document.getElementById('loginBtn').disabled = false;
    document.body.style.display = 'flex';
    document.getElementById('tablet').style.display = 'none';
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('loginError').style.display = 'none';
}

function hideLoginScreen() {
    document.getElementById('loginBtn').disabled = false;
    document.getElementById('loginScreen').style.display = 'none';
}

function showLoginError(job) {
    const btn = document.getElementById('loginBtn');
    btn.disabled = false;
    const errEl  = document.getElementById('loginError');
    const msgEl  = document.getElementById('loginErrorMsg');
    msgEl.textContent = job
        ? `ACCESS DENIED - YOU ARE NOT AUTHORISED TO USE THIS`
        : 'ACCESS DENIED - AUTHORIZED PERSONNEL ONLY';
    errEl.style.display = 'none';
    void errEl.offsetWidth;
    errEl.style.display = 'flex';
}

function attemptLogin() {
    const btn = document.getElementById('loginBtn');
    btn.disabled = true;
    document.getElementById('loginError').style.display = 'none';
    
    nuiFetch('attemptLogin', {}).then(res => {
        if (res && res.ok) {
            // Server will fire back openMDT via SendNUIMessage
        } else {
            showLoginError(res && res.job);
        }
    }).catch(() => {
        btn.disabled = false;
    });
}

// ─ NUI Message Handler ───────────────────────────
window.addEventListener('message', (event) => {
    const data = event.data;
    switch (data.action) {
        case 'showLogin':
            showLoginScreen(data.department);
            break;
        case 'hideForScreenshot':
            document.getElementById('tablet').style.display = 'none';
            document.getElementById('loginScreen').style.display = 'none';
            break;
        case 'showAfterScreenshot':
            document.getElementById('tablet').style.display = 'flex';
            break;
        case 'openMDT':
            mdtIsOpen = true;
            hideLoginScreen();
            document.getElementById('tablet').style.display = 'flex';
            document.body.style.display = 'flex';
            document.getElementById('miniDispatch').style.display = 'none';

            if (data.department) {
                const d = data.department;
                if (d.nameLine1)       document.getElementById('deptLine1').textContent = d.nameLine1;
                if (d.nameLine2)       document.getElementById('deptLine2').textContent = d.nameLine2;
                if (d.motto)           document.getElementById('deptMotto').textContent = d.motto;
                if (d.logoUrl)         document.getElementById('deptLogo').style.backgroundImage = `url('${d.logoUrl}')`;
                if (d.dispatchChannel) document.getElementById('dispatchChannel').textContent = d.dispatchChannel;
            }

            if (data.officer) {
                const o = data.officer;
                const nameEl  = document.getElementById('officerName');
                const idEl    = document.getElementById('officerBadge');
                const gradeEl = document.getElementById('officerJob');
                if (nameEl)  nameEl.textContent  = o.name || 'Unknown Officer';
                if (idEl)    idEl.textContent    = '#' + (o.id || '0');
                if (gradeEl) gradeEl.textContent = (o.grade || 'Unknown').toUpperCase();
                if (o.name)  myOfficerName = o.name;
            }

            if (data.dashboard) applyDashboardData(data.dashboard);
            if (data.roster)    applyRoster(data.roster);

            loadOfficerPortrait();

            setTimeout(() => {
                loadRecentActivity();
                if (document.getElementById('page-surveillance').classList.contains('active')) {
                    searchSurveillance();
                }
            }, 150);
            
            break;

        case 'closeMDT':
            mdtIsOpen = false;
            document.getElementById('tablet').style.display = 'none';
            document.getElementById('loginScreen').style.display = 'none';
            // Do NOT hide body so the mini dispatch remains visible
            updateMiniDispatchUI();
            break;

        case 'loginDenied':
            showLoginError(data.job);
            break;

        case 'showLocked':
            showLoginScreen(null);
            showLoginError(data.job);
            break;

        case 'dashboardUpdate':
            if (data.dashboard) applyDashboardData(data.dashboard);
            break;

        case 'initMiniDispatch':
            if (data.myName) myOfficerName = data.myName;
            miniDispatchCalls = (data.calls || []).map(c => {
                const unitName = c.assigned_unit || 'Unassigned';
                return {
                    id: c.id,
                    type: c.call_type,
                    location: c.location,
                    priority: c.priority,
                    status: c.status,
                    unit: (myOfficerName && unitName === myOfficerName) ? 'You' : unitName
                };
            });
            updateMiniDispatchUI();
            break;
        
        case 'newDispatchCall':
            if (!miniDispatchCalls.find(c => c.id === data.call.id)) {
                miniDispatchCalls.push(data.call);
                updateMiniDispatchUI();
                playDispatchSound();
            }
            // Add the new call to the top of the dispatch cards instantly
            if (document.getElementById('page-dispatch').classList.contains('active')) {
                const container = document.getElementById('dispatchCards');
                // Remove empty/loading message if present
                const emptyEl = container.querySelector('.dispatch-empty');
                if (emptyEl) emptyEl.remove();

                const c = data.call;
                container.insertAdjacentHTML('afterbegin', buildDispatchCard(c));
                // Update count
                const cardCount = container.querySelectorAll('.dispatch-card').length;
                updateDispatchCount(cardCount);
            }
            break;

        case 'clearDispatchCall':
            miniDispatchCalls = miniDispatchCalls.filter(c => c.id !== data.id);
            if (currentMdIndex >= miniDispatchCalls.length) currentMdIndex = Math.max(0, miniDispatchCalls.length - 1);
            updateMiniDispatchUI();
            // Remove the card from the MDT instantly
            const row = document.getElementById(`call-row-${data.id}`);
            if (row) {
                row.remove();
                const container = document.getElementById('dispatchCards');
                if (container) {
                    const remaining = container.querySelectorAll('.dispatch-card').length;
                    updateDispatchCount(remaining);
                    if (remaining === 0) container.innerHTML = '<div class="dispatch-empty">No active dispatch calls.</div>';
                }
            }
            break;
        
        case 'scrollMiniDispatch':
            currentMdIndex += data.dir;
            if (currentMdIndex < 0) currentMdIndex = miniDispatchCalls.length - 1;
            if (currentMdIndex >= miniDispatchCalls.length) currentMdIndex = 0;
            updateMiniDispatchUI();
            break;

        case 'toggleAssignDispatch':
            if (miniDispatchCalls[currentMdIndex]) {
                const call = miniDispatchCalls[currentMdIndex];
                if (call.unit === 'You') {
                    // Already assigned to me -> unassign
                    nuiFetch('unassignSelfFromDispatch', { callId: call.id });
                    call.unit = 'Unassigned';
                    call.status = 'Pending';
                } else {
                    // Not assigned to me (could be unassigned, or someone else's) -> claim it
                    nuiFetch('assignSelfToDispatch', { callId: call.id });
                    call.unit = 'You';
                    call.status = 'Assigned';
                }
                updateMiniDispatchUI();
            }
            break;

        case 'updateDispatchCall': {
            const call = miniDispatchCalls.find(c => c.id === data.id);
            if (call) {
                if (data.unit === 'Unassigned') {
                    call.unit = 'Unassigned';
                    call.status = 'Pending';
                } else {
                    call.unit = (myOfficerName && data.unit === myOfficerName) ? 'You' : data.unit;
                    call.status = 'Assigned';
                }
                updateMiniDispatchUI();
            }

            // Keep the full Dispatch page card in sync too, if that card exists.
            const tableRow = document.getElementById(`call-row-${data.id}`);
            if (tableRow) {
                const isAssigned = data.unit && data.unit !== 'Unassigned';
                const displayUnit = isAssigned
                    ? ((myOfficerName && data.unit === myOfficerName) ? 'You' : data.unit)
                    : 'Unassigned';

                const unitEl = tableRow.querySelector('.dc-unit');
                if (unitEl) {
                    unitEl.textContent = displayUnit;
                    unitEl.classList.toggle('assigned', isAssigned);
                }
                const statusBadgeEl = tableRow.querySelector('.dc-status-badge');
                if (statusBadgeEl) statusBadgeEl.innerHTML = statusBadge(isAssigned ? 'Assigned' : 'Pending');
                tableRow.classList.toggle('status-assigned', isAssigned);
            }
            break;
        }

        case 'hideForScreenshot':
            document.getElementById('tablet').style.display = 'none';
            document.getElementById('loginScreen').style.display = 'none';
            break;

        case 'showAfterScreenshot':
            document.getElementById('tablet').style.display = 'flex';
            break;

        case 'promptCameraName':
            document.body.style.display = 'flex'; // body may be hidden if the tablet was closed
            openCameraNameModal(data.cameraId, '', true);
            break;

        case 'cameraListUpdate':
            _surveillanceCache = {};
            (data.cameras || []).forEach(c => { _surveillanceCache[c.id] = c; });
            if (document.getElementById('page-surveillance').classList.contains('active')) {
                renderSurveillanceTable(data.cameras || []);
            }
            break;

        case 'cctvFeedActive':
            document.getElementById('tablet').style.display = 'none';
            document.getElementById('cctvFeedName').textContent = (data.name || 'CAMERA').toUpperCase();
            document.getElementById('cctvFeedOverlay').style.display = 'block';
            _cctvFeedActive = true;
            startCctvClock();
            startCCTVInput();
            break;

        case 'cctvFeedClosed':
            document.getElementById('cctvFeedOverlay').style.display = 'none';
            _cctvFeedActive = false;
            stopCctvClock();
            stopCCTVInput();
            if (mdtIsOpen) document.getElementById('tablet').style.display = 'flex';
            break;

        case 'bodycamListUpdate':
            renderBodycamList(data.bodycams || []);
            break;

        case 'bodycamFeedActive':
            document.getElementById('tablet').style.display = 'none';
            document.getElementById('bodycamFeedName').textContent = (data.name || 'OFFICER').toUpperCase();
            document.getElementById('bodycamFeedOverlay').style.display = 'block';
            _bodycamFeedActive = true;
            startBodycamClock();
            startBodycamRecTimer();
            startBodycamBatterySim();
            startBodycamTimestamp(data.serverId);
            break;

        case 'bodycamFeedClosed':
            document.getElementById('bodycamFeedOverlay').style.display = 'none';
            _bodycamFeedActive = false;
            stopBodycamClock();
            stopBodycamRecTimer();
            stopBodycamBatterySim();
            stopBodycamTimestamp();
            if (mdtIsOpen) document.getElementById('tablet').style.display = 'flex';
            break;
    }
});

// ── Surveillance / CCTV ───────────────────────────
let _surveillanceCache = {};
let _cctvFeedActive = false;
let _cctvClockInterval = null;
let mdtIsOpen = false; // tracked so the feed overlay knows whether to restore the tablet on exit

function searchSurveillance() {
    const q = (document.getElementById('surveillanceSearch').value || '').trim().toLowerCase();
    nuiFetch('getCameras', {}).then(res => {
        const rows = res.results || [];
        _surveillanceCache = {};
        rows.forEach(c => { _surveillanceCache[c.id] = c; });
        const filtered = q
            ? rows.filter(c => (c.name || '').toLowerCase().includes(q) || (c.placed_by || '').toLowerCase().includes(q))
            : rows;
        renderSurveillanceTable(filtered);
    });
}

function renderSurveillanceTable(rows) {
    const tbody = document.getElementById('surveillanceTbody');
    if (!rows || rows.length === 0) {
        tbody.innerHTML = emptyRow(4, 'No cameras placed yet.');
        return;
    }
    tbody.innerHTML = rows.map(c => `
        <tr>
            <td>${c.name || 'Unnamed Camera'}</td>
            <td>${c.placed_by || '—'}</td>
            <td>${c.date || '—'}</td>
            <td>
                <div class="surv-actions">
                    <button class="surv-btn surv-btn-view" onclick="viewCameraFeed(${c.id})">VIEW</button>
                    <button class="surv-btn surv-btn-rename" onclick="openCameraNameModal(${c.id}, '${(c.name || '').replace(/'/g, "\\'")}', false)">RENAME</button>
                    <button class="surv-btn surv-btn-delete" onclick="deleteCameraConfirm(${c.id})">DELETE</button>
                </div>
            </td>
        </tr>
    `).join('');
}

function viewCameraFeed(id) {
    const cam = _surveillanceCache[id];
    nuiFetch('viewCamera', { id, name: cam ? cam.name : '' });
}

function placeCameraButton() {
    nuiFetch('requestPlaceCamera', {}).then(res => {
        if (res && res.ok) {
            showToast('Tablet closing — aim and press E to place, ESC to cancel.', 'info');
        } else {
            showToast('You don\'t have a CCTV camera.', 'error');
        }
    });
}

function exitCameraView() {
    nuiFetch('exitCameraView', {});
}

function deleteCameraConfirm(id) {
    mdtConfirm('Remove this camera? This cannot be undone.').then(ok => {
        if (!ok) return;
        nuiFetch('deleteCamera', { id }).then(res => {
            if (res.ok) {
                showToast('Camera removed.', 'success');
                searchSurveillance();
            } else {
                showToast('Failed to remove camera.', 'error');
            }
        });
    });
}

// ── Generic styled confirm (replaces native confirm()) ────
let _mdtConfirmCallback = null;
function mdtConfirm(message) {
    document.getElementById('mdtConfirmMessage').textContent = message;
    document.getElementById('mdtConfirmModal').style.display = 'flex';
    return new Promise(resolve => { _mdtConfirmCallback = resolve; });
}
function _mdtConfirmResolve(result) {
    document.getElementById('mdtConfirmModal').style.display = 'none';
    if (_mdtConfirmCallback) { _mdtConfirmCallback(result); _mdtConfirmCallback = null; }
}

function openCameraNameModal(cameraId, currentName, isNew) {
    document.getElementById('cctvNameModal').dataset.cameraId = cameraId;
    document.getElementById('cctvNameModal').dataset.isNew = isNew ? '1' : '0';
    document.getElementById('cctvNameModalTitle').textContent = isNew ? 'Name This Camera' : 'Rename Camera';
    document.getElementById('cctvNameInput').value = currentName || '';
    document.getElementById('cctvNameModal').style.display = 'flex';
    setTimeout(() => document.getElementById('cctvNameInput').focus(), 50);
}

function closeCameraNameModal() {
    document.getElementById('cctvNameModal').style.display = 'none';
    if (!mdtIsOpen) document.body.style.display = 'none';
}

function saveCameraName() {
    const modal = document.getElementById('cctvNameModal');
    const cameraId = modal.dataset.cameraId;
    const isNew = modal.dataset.isNew === '1';
    const name = document.getElementById('cctvNameInput').value.trim();
    nuiFetch('saveCameraName', { cameraId, name }).then(() => {
        closeCameraNameModal();
        showToast('Camera saved.', 'success');
        if (!isNew && document.getElementById('page-surveillance').classList.contains('active')) searchSurveillance();
    });
}

function skipCameraName() {
    const modal = document.getElementById('cctvNameModal');
    const cameraId = modal.dataset.cameraId;
    nuiFetch('skipCameraName', { cameraId }).then(() => {
        closeCameraNameModal();
    });
}

function startCctvClock() {
    const el = document.getElementById('cctvFeedClock');
    const tick = () => { el.textContent = new Date().toLocaleTimeString('en-GB'); };
    tick();
    _cctvClockInterval = setInterval(tick, 1000);
}

function stopCctvClock() {
    if (_cctvClockInterval) { clearInterval(_cctvClockInterval); _cctvClockInterval = null; }
}

// ── CCTV pan/tilt input (driven from NUI since SetNuiFocus owns the keyboard) ──
const _cctvHeld = { w: false, a: false, s: false, d: false, ArrowUp: false, ArrowLeft: false, ArrowDown: false, ArrowRight: false };
let _cctvInputInterval = null;

function startCCTVInput() {
    stopCCTVInput(); // clear any leftover interval
    _cctvInputInterval = setInterval(() => {
        const pan  = (_cctvHeld.a || _cctvHeld.ArrowLeft  ? -1 : 0) + (_cctvHeld.d || _cctvHeld.ArrowRight ? 1 : 0);
        const tilt = (_cctvHeld.w || _cctvHeld.ArrowUp    ?  1 : 0) + (_cctvHeld.s || _cctvHeld.ArrowDown  ? -1 : 0);
        // Always send so the Lua loop gets a zero-input tick when keys are released
        nuiFetch('cctvInput', { pan, tilt });
    }, 16); // ~60 fps
}

function stopCCTVInput() {
    if (_cctvInputInterval) { clearInterval(_cctvInputInterval); _cctvInputInterval = null; }
    Object.keys(_cctvHeld).forEach(k => _cctvHeld[k] = false);
    nuiFetch('cctvInput', { pan: 0, tilt: 0 }); // zero out any residual movement
}

document.addEventListener('keydown', (e) => {
    if (_cctvFeedActive) {
        if (e.key in _cctvHeld) { e.preventDefault(); _cctvHeld[e.key] = true; return; }
        if (e.key === 'Escape') { e.preventDefault(); stopCCTVInput(); exitCameraView(); return; }
    }
    if (_bodycamFeedActive && e.key === 'Escape') { e.preventDefault(); exitBodycamView(); return; }
});

document.addEventListener('keyup', (e) => {
    if (e.key in _cctvHeld) _cctvHeld[e.key] = false;
});

// ── Bodycam ────────────────────────────────────────
let _bodycamFeedActive = false;
let _bodycamClockInterval = null;

function startBodycamClock() {
    const el = document.getElementById('bodycamFeedClock');
    const tick = () => { el.textContent = new Date().toLocaleTimeString('en-GB'); };
    tick();
    _bodycamClockInterval = setInterval(tick, 1000);
}

function stopBodycamClock() {
    if (_bodycamClockInterval) { clearInterval(_bodycamClockInterval); _bodycamClockInterval = null; }
}

// REC elapsed-time counter (top-left timer next to the REC dot)
let _bodycamRecInterval = null;
let _bodycamRecStart = null;

function startBodycamRecTimer() {
    stopBodycamRecTimer();
    _bodycamRecStart = Date.now();
    const el = document.getElementById('bodycamFeedTimer');
    const tick = () => {
        const secs = Math.floor((Date.now() - _bodycamRecStart) / 1000);
        const h = String(Math.floor(secs / 3600)).padStart(2, '0');
        const m = String(Math.floor((secs % 3600) / 60)).padStart(2, '0');
        const s = String(secs % 60).padStart(2, '0');
        el.textContent = `${h}:${m}:${s}`;
    };
    tick();
    _bodycamRecInterval = setInterval(tick, 1000);
}

function stopBodycamRecTimer() {
    if (_bodycamRecInterval) { clearInterval(_bodycamRecInterval); _bodycamRecInterval = null; }
    _bodycamRecStart = null;
}

// Axon-style bottom-right timestamp + device serial readout
let _bodycamTsInterval = null;

function pad2(n) { return String(n).padStart(2, '0'); }

function formatTsLine(d) {
    const y = d.getFullYear();
    const mo = pad2(d.getMonth() + 1);
    const da = pad2(d.getDate());
    const hh = pad2(d.getHours());
    const mi = pad2(d.getMinutes());
    const ss = pad2(d.getSeconds());
    const offsetMin = -d.getTimezoneOffset();
    const sign = offsetMin >= 0 ? '+' : '-';
    const offH = pad2(Math.floor(Math.abs(offsetMin) / 60));
    return `${y}-${mo}-${da} ${hh}:${mi}:${ss} ${sign}${offH}00`;
}

function startBodycamTimestamp(serverId) {
    stopBodycamTimestamp();
    const dateEl = document.getElementById('bodycamTsDate');
    const serialEl = document.getElementById('bodycamTsSerial');
    if (serialEl) {
        const serial = String(serverId || Math.floor(Math.random() * 90000000) + 10000000).padStart(8, '0');
        serialEl.textContent = `SCS BODY 3 X${serial}`;
    }
    const tick = () => { if (dateEl) dateEl.textContent = formatTsLine(new Date()); };
    tick();
    _bodycamTsInterval = setInterval(tick, 1000);
}

function stopBodycamTimestamp() {
    if (_bodycamTsInterval) { clearInterval(_bodycamTsInterval); _bodycamTsInterval = null; }
}

// Battery drain simulation for the HUD readout
let _bodycamBatteryInterval = null;
let _bodycamBatteryPct = 87;

function startBodycamBatterySim() {
    stopBodycamBatterySim();
    _bodycamBatteryPct = 80 + Math.floor(Math.random() * 15); // start 80-94%
    const fillEl = document.querySelector('#bodycamFeedOverlay .bwc-battery-fill');
    const pctEl = document.getElementById('bodycamBatteryPct');
    const render = () => {
        if (pctEl) pctEl.textContent = `${_bodycamBatteryPct}%`;
        if (fillEl) {
            fillEl.style.width = `${_bodycamBatteryPct}%`;
            fillEl.style.background = _bodycamBatteryPct <= 20 ? '#ff5d5d' : (_bodycamBatteryPct <= 45 ? '#f4c542' : '#6fff8f');
        }
    };
    render();
    // Drain roughly 1% every 45s of real-time viewing
    _bodycamBatteryInterval = setInterval(() => {
        _bodycamBatteryPct = Math.max(0, _bodycamBatteryPct - 1);
        render();
    }, 45000);
}

function stopBodycamBatterySim() {
    if (_bodycamBatteryInterval) { clearInterval(_bodycamBatteryInterval); _bodycamBatteryInterval = null; }
}

function exitBodycamView() {
    nuiFetch('exitBodycamView', {});
}

function renderBodycamList(bodycams) {
    const tbody = document.getElementById('bodycamTbody');
    if (!tbody) return;
    if (!bodycams || bodycams.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="color:#566b80;text-align:center;padding:18px;">No active bodycams.</td></tr>';
        return;
    }
    tbody.innerHTML = bodycams.map(b => `
        <tr>
            <td>${b.name || 'Unknown'}</td>
            <td>#${b.serverId}</td>
            <td><span style="color:#27ae60;font-weight:700;">● LIVE</span></td>
            <td><button class="search-btn" style="font-size:10px;padding:5px 10px;" onclick="watchBodycam(${b.serverId})">▶ WATCH</button></td>
        </tr>
    `).join('');
}

function watchBodycam(serverId) {
    nuiFetch('watchBodycam', { serverId });
}

// Load bodycam list when tab opens
function loadBodycams() {
    nuiFetch('getBodycams', {}).then(r => {
        renderBodycamList(r && r.results ? r.results : []);
    });
}

// ── Dashboard data ────────────────────────────────
function applyDashboardData(d) {
    const set = (id, val) => {
        const el = document.getElementById(id);
        if (el && val !== undefined && val !== null) el.textContent = val;
    };
    set('statActiveWarrants',  d.activeWarrants);
    set('statActiveBOLOs',     d.activeBOLOs);
    set('statUnitsOnDuty',     d.unitsOnDuty);
    set('statUnitsOnDuty2',    d.unitsOnDuty);
    set('statPendingReports',  d.pendingReports);
    set('statActiveCalls',     d.activeCalls);
    set('statUnassignedCalls', d.unassignedCalls);
    if (d.dispatchChannel) set('dispatchChannel', d.dispatchChannel);
    loadRecentActivity();
}

// ─ Recent Activity ───────────────────────────────
function loadRecentActivity() {
    const list = document.getElementById('recentActivityList');
    if (!list) return;
    list.innerHTML = '<div style="padding:18px; text-align:center; color:#566b80; font-size:11px;">Loading activity…</div>';
    
    nuiFetch('getRecentActivity', {}).then(res => {
        const acts = res.activities || [];
        if (acts.length === 0) {
            list.innerHTML = '<div style="padding:18px; text-align:center; color:#566b80; font-size:11px;">No recent activity.</div>';
            return;
        }
        let html = '';
        acts.forEach(a => {
            let iconClass = 'report';
            let iconSvg = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>';

            if (a.type === 'Warrant') {
                iconClass = 'warrant';
                iconSvg = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z"/></svg>';
            } else if (a.type === 'BOLO') {
                iconClass = 'warrant';
                iconSvg = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>';
            }

            let timeStr = '';
            if (a.time) {
                const parts = a.time.split(' ');
                if (parts[1]) timeStr = parts[1].substring(0, 5);
            }

            const detailsShort = a.details ? (a.details.length > 40 ? a.details.substring(0, 40) + '...' : a.details) : '';

            html += `
                <div class="activity-item">
                    <div class="act-icon ${iconClass}">${iconSvg}</div>
                    <div class="act-body">
                        <div class="act-title"><span>${a.type}</span> — ${a.subject || 'Unknown'}</div>
                        <div class="act-sub">By ${a.officer} • ${detailsShort}</div>
                    </div>
                    <div class="act-time">${timeStr}</div>
                </div>
            `;
        });
        list.innerHTML = html;
    });
}

// ── Roster & Assignments ──────────────────────────
function applyRoster(roster) {
    const tbody = document.getElementById('officerRosterBody');
    if (!tbody) return;
    
    if (!roster || roster.length === 0) {
        tbody.innerHTML = emptyRow(5, 'No officers currently on duty.');
        return;
    }
    
    // Define available assignments
    const assignments = ['Unassigned', 'Patrol', 'K9 Unit', 'Traffic', 'Detective', 'SWAT', 'Air Support'];
    
    tbody.innerHTML = roster.map(o => {
        // Create dropdown options
        let optionsHtml = assignments.map(a => 
            `<option value="${a}" ${o.assignment === a ? 'selected' : ''}>${a}</option>`
        ).join('');

        return `
        <tr>
            <td>#${o.id}</td>
            <td>${o.name}</td>
            <td>${(o.grade || 'Unknown').toUpperCase()}</td>
            <td>${statusBadge(o.status || 'ON DUTY')}</td>
            <td>
                <select class="search-input" style="padding: 4px 8px; font-size: 11px; width: 120px;" 
                        onchange="updateAssignment(this.value)">
                    ${optionsHtml}
                </select>
            </td>
        </tr>`;
    }).join('');
}

function updateAssignment(newAssignment) {
    nuiFetch('saveAssignment', { assignment: newAssignment }).then(res => {
        if (res.ok) {
            showToast('Assignment updated!', 'success');
            // Optional: Refresh roster to confirm save
            // lib.callback('police_mdt:getRoster'...) 
        } else {
            showToast('Failed to update assignment.', 'error');
        }
    });
}

// ─ Citizens search ───────────────────────────────
let _activeCitizenId = null;
let _citizenResultsCache = {};

function searchCitizens() {
    const q = document.getElementById('citizenSearch').value.trim();
    const tbody = document.getElementById('citizenTbody');
    closeCitizenProfile();
    _citizenResultsCache = {};
    tbody.innerHTML = emptyRow(5, 'Searching…');
    nuiFetch('searchCitizens', { query: q }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(5); return; }
        rows.forEach((r, i) => { _citizenResultsCache[i] = r; });
        tbody.innerHTML = rows.map((r, i) => `
            <tr>
                <td>${r.name}</td>
                <td>${r.dob || '—'}</td>
                <td>${r.job || '—'}</td>
                <td>${statusBadge(r.status)}</td>
                <td style="text-align:center;">
                    <button class="cp-expand-btn" data-idx="${i}" onclick="expandCitizenProfile(${i}, this)" title="View Profile">+</button>
                </td>
            </tr>
        `).join('');
    });
}

function closeCitizenProfile() {
    document.getElementById('citizenProfile').style.display = 'none';
    // Reset all expand buttons
    document.querySelectorAll('.cp-expand-btn').forEach(b => { b.classList.remove('active'); b.textContent = '+'; });
    _activeCitizenId = null;
}

function expandCitizenProfile(idx, btn) {
    const citizen = _citizenResultsCache[idx];
    if (!citizen) return;
    // Toggle off if already open for same citizen
    if (_activeCitizenId === citizen.id) {
        closeCitizenProfile();
        return;
    }
    _activeCitizenId = citizen.id;

    // Reset all buttons then activate this one
    document.querySelectorAll('.cp-expand-btn').forEach(b => { b.classList.remove('active'); b.textContent = '+'; });
    btn.classList.add('active');
    btn.textContent = '−';

    // Populate static fields immediately
    document.getElementById('cpName').textContent = citizen.name || '—';
    document.getElementById('cpStatusBadge').innerHTML = statusBadge(citizen.status);
    document.getElementById('cpDob').textContent = citizen.dob || '—';
    document.getElementById('cpId').textContent = citizen.id || '—';
    document.getElementById('cpJob').textContent = (citizen.job || '—').toUpperCase();
    document.getElementById('cpWarrantCount').textContent = '…';
    document.getElementById('cpDescription').value = '';

    // Reset photo
    const mugshotEl = document.getElementById('cpMugshot');
    mugshotEl.style.backgroundImage = '';
    mugshotEl.innerHTML = '<div class="cp-mugshot-placeholder">NO PHOTO ON FILE</div>';

    // Reset lists
    ['cpVehicles','cpReports','cpWarrants'].forEach(id => {
        document.getElementById(id).innerHTML = '<div class="cp-loading">Loading…</div>';
    });

    // Show panel
    document.getElementById('citizenProfile').style.display = 'block';

    // Fetch full profile from server
    nuiFetch('getCitizenProfile', { id: citizen.id, name: citizen.name }).then(res => {
        if (!res) return;

        // Mugshot / portrait
        if (res.portrait) {
            mugshotEl.style.backgroundImage = `url('${res.portrait}')`;
            mugshotEl.innerHTML = '';
        }

        // Notes/description
        document.getElementById('cpDescription').value = res.description || '';

        // Warrant count
        document.getElementById('cpWarrantCount').textContent = (res.warrants || []).length;

        // Vehicles
        const vEl = document.getElementById('cpVehicles');
        if (!res.vehicles || res.vehicles.length === 0) {
            vEl.innerHTML = '<div class="cp-empty">No registered vehicles.</div>';
        } else {
            vEl.innerHTML = res.vehicles.map(v => `
                <div class="cp-vehicle-row">
                    <span class="cp-vehicle-plate">${v.plate}</span>
                    <span class="cp-vehicle-model">${v.model}</span>
                    <span>${statusBadge(v.status)}</span>
                </div>
            `).join('');
        }

        // Reports
        const rEl = document.getElementById('cpReports');
        if (!res.reports || res.reports.length === 0) {
            rEl.innerHTML = '<div class="cp-empty">No reports on file.</div>';
        } else {
            rEl.innerHTML = res.reports.map(r => `
                <div class="cp-report-row">
                    <span class="cp-report-title">${r.title}</span>
                    <span class="cp-report-sub">${r.type} • ${r.date} • By ${r.officer}</span>
                </div>
            `).join('');
        }

        // Warrants
        const wEl = document.getElementById('cpWarrants');
        if (!res.warrants || res.warrants.length === 0) {
            wEl.innerHTML = '<div class="cp-empty">No warrants on file.</div>';
        } else {
            wEl.innerHTML = res.warrants.map(w => `
                <div class="cp-warrant-row">
                    <span class="cp-warrant-charge">${w.charge}</span>
                    <span class="cp-warrant-sub">${statusBadge(w.status)} • Issued ${w.date} • By ${w.issued_by}</span>
                </div>
            `).join('');
        }
    });
}

function saveCitizenDescription() {
    if (!_activeCitizenId) return;
    const notes = document.getElementById('cpDescription').value.trim();
    nuiFetch('saveCitizenDescription', { id: _activeCitizenId, notes }).then(res => {
        if (res && res.ok) showToast('Notes saved.', 'success');
        else showToast('Failed to save notes.', 'error');
    });
}

// ── Citizen Search Autocomplete ─────────────────────
let _citizenSearchTimeout = null;

function handleCitizenSearch(query) {
    clearTimeout(_citizenSearchTimeout);
    const box = document.getElementById('citizenSearchSuggestions');
    if (!query || query.length < 2) {
        if (box) box.style.display = 'none';
        return;
    }

    _citizenSearchTimeout = setTimeout(() => {
        // Reuses your existing backend searchNames callback
        nuiFetch('searchNames', { type: 'citizen', query: query }).then(res => {
            const results = res.results || [];
            if (!box) return;
            
            if (results.length === 0) {
                box.style.display = 'none';
                return;
            }

            let html = '';
            results.forEach(item => {
                const safeName = item.name.replace(/'/g, "\\'");
                const safeId = item.id.replace(/'/g, "\\'");
                html += `<div class="suggestion-item" onclick="selectCitizenSuggestion('${safeName}', '${safeId}')">
                            ${item.name} 
                            <span style="color:#566b80; font-size:10px; float:right;">ID: ${item.id}</span>
                         </div>`;
            });

            box.innerHTML = html;
            box.style.display = 'block';
        });
    }, 300); // 300ms debounce
}

function selectCitizenSuggestion(name, id) {
    document.getElementById('citizenSearch').value = name;
    document.getElementById('citizenSearchSuggestions').style.display = 'none';
    searchCitizens(); // Automatically trigger the full search when a name is clicked
}

// ── Vehicles search ───────────────────────────────
function searchVehicles() {
    const q = document.getElementById('vehicleSearch').value.trim();
    const tbody = document.querySelector('#page-vehicles .mdt-table tbody');
    tbody.innerHTML = emptyRow(5, 'Searching…');
    nuiFetch('searchVehicles', { query: q }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(5); return; }
        tbody.innerHTML = rows.map(r =>
            `<tr><td>${r.plate}</td><td>${r.model}</td><td>${r.color || '—'}</td><td>${r.owner}</td><td>${statusBadge(r.status)}</td></tr>`
        ).join('');
    });
}

// ── Reports search ────────────────────────────────
function searchReports() {
    const q = document.getElementById('reportSearch').value.trim();
    const tbody = document.querySelector('#page-reports .mdt-table tbody');
    tbody.innerHTML = emptyRow(7, 'Searching…'); // Changed to 7
    nuiFetch('searchReports', { query: q }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(7); return; }
        tbody.innerHTML = rows.map(r => 
            `<tr>
                <td>#${r.id}</td>
                <td>${r.report_type}</td>
                <td>${r.title || 'Untitled'}</td> <!-- CHANGED from r.subject -->
                <td>${r.officer}</td>
                <td>${r.date || '—'}</td>
                <td>${statusBadge(r.status)}</td>
                <td><button class="search-btn" style="background:#2a6496; padding:4px 10px; font-size:10px;" onclick="openReport(${r.id})">VIEW</button></td>
            </tr>`
        ).join('');
    });
}

// ── Warrants search ───────────────────────────────
function searchWarrants() {
    const q = document.getElementById('warrantSearch').value.trim();
    const statusFilter = document.getElementById('warrantStatusFilter').value;
    const priorityFilter = document.getElementById('warrantPriorityFilter').value;
    
    const tbody = document.querySelector('#page-warrants .mdt-table tbody');
    tbody.innerHTML = emptyRow(7, 'Searching…');
    
    nuiFetch('searchWarrants', { 
        query: q, 
        status: statusFilter, 
        priority: priorityFilter 
    }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(7, 'No warrants found matching your filters.'); return; }
        tbody.innerHTML = rows.map(r => 
            `<tr>
                <td>W-${String(r.id).padStart(4, '0')}</td>
                <td>${r.subject_name} (${r.subject_id})</td>
                <td>${r.charge}</td>
                <td>${r.issued_by}</td>
                <td><span class="badge ${getPriorityClass(r.priority)}">${r.priority || 'Medium'}</span></td>
                <td>${statusBadge(r.status)}</td>
                <td><button class="search-btn" style="background:#e74c3c; padding:4px 10px; font-size:10px;" onclick="openWarrant(${r.id})">VIEW</button></td>
            </tr>`
        ).join('');
    });
}

// Helper for priority badge colors
function getPriorityClass(priority) {
    const map = {
        'Low': 'clear',
        'Medium': 'pending',
        'High': 'bolo',
        'Critical': 'active'
    };
    return map[priority] || 'pending';
}

// ── BOLOs search ──────────────────────────────────
function searchBOLOs() {
    const q = document.getElementById('boloSearch').value.trim();
    const tbody = document.querySelector('#page-bolos .mdt-table tbody');
    tbody.innerHTML = emptyRow(5, 'Searching…');
    nuiFetch('searchBOLOs', { query: q }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(5); return; }
        tbody.innerHTML = rows.map(r => 
            `<tr><td>B-${String(r.id).padStart(4, '0')}</td><td>${r.bolo_type}</td><td>${r.description || '—'}</td><td>${r.last_seen || '—'}</td><td>${r.plate || '—'}</td><td>${statusBadge(r.status)}</td><td><button class="search-btn" style="background:#e67e22; padding:4px 10px; font-size:10px;" onclick="openBOLO(${r.id})">VIEW</button></td></tr>`
        ).join('');
    });
}

// ── Create modals ─────────────────────────────────
function showModal(id) { document.getElementById(id).style.display = 'flex'; }
function hideModal(id) { document.getElementById(id).style.display = 'none'; }

function submitWarrant() {
    const subjectId   = document.getElementById('wSubjectId').value.trim();
    const subjectName = document.getElementById('wSubjectName').value.trim();
    const charge      = document.getElementById('wCharge').value.trim();
    if (!subjectId || !charge) { 
        showToast('Subject ID and Charge are required.', 'error'); 
        return; 
    }

    nuiFetch('createWarrant', { subjectId, subjectName, charge }).then(res => {
        if (res.ok) {
            hideModal('modalWarrant');
            document.getElementById('wSubjectId').value   = '';
            document.getElementById('wSubjectName').value = '';
            document.getElementById('wCharge').value      = '';
            searchWarrants();
            showToast('Warrant issued successfully!', 'success');
        } else {
            showToast('Failed to create warrant: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

function submitBOLO() {
    const boloType    = document.getElementById('bType').value;
    const description = document.getElementById('bDescription').value.trim();
    const lastSeen    = document.getElementById('bLastSeen').value.trim();
    const plate       = document.getElementById('bPlate').value.trim();
    if (!description) { 
        showToast('Description is required.', 'error'); 
        return; 
    }

    nuiFetch('createBOLO', { boloType, description, lastSeen, plate }).then(res => {
        if (res.ok) {
            hideModal('modalBOLO');
            document.getElementById('bDescription').value = '';
            document.getElementById('bLastSeen').value    = '';
            document.getElementById('bPlate').value       = '';
            searchBOLOs();
            showToast('BOLO issued successfully!', 'success');
        } else {
            showToast('Failed to create BOLO: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

function submitReport() {
    const reportType = document.getElementById('rType').value;
    const subject    = document.getElementById('rSubject').value.trim();
    const details    = document.getElementById('rDetails').value.trim();
    if (!details) { 
        showToast('Details are required.', 'error'); 
        return; 
    }

    nuiFetch('createReport', { reportType, subject, details }).then(res => {
        if (res.ok) {
            hideModal('modalReport');
            document.getElementById('rSubject').value = '';
            document.getElementById('rDetails').value = '';
            searchReports();
            showToast('Report filed successfully!', 'success');
        } else {
            showToast('Failed to create report: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

// ── Close MDT ─────────────────────────────────────
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeMDTUI();
});

function closeMDTUI() {
    nuiFetch('closeTablet', {});
    mdtIsOpen = false;
    document.getElementById('tablet').style.display = 'none';
    document.getElementById('loginScreen').style.display = 'none';
    // updateMiniDispatchUI also manages body visibility (shows it if there
    // are active calls, hides it otherwise)
    updateMiniDispatchUI();
}

// ── Clock ─────────────────────────────────────────
function updateClock() {
    const now = new Date();
    document.getElementById('clock').textContent =
        now.getHours().toString().padStart(2,'0') + ':' +
        now.getMinutes().toString().padStart(2,'0');
    document.getElementById('dateStr').textContent =
        now.toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }).toUpperCase();
}
updateClock();
setInterval(updateClock, 1000);

// ── Navigation ────────────────────────────────────
document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
        document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
        document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
        item.classList.add('active');
        document.getElementById('page-' + item.dataset.page).classList.add('active');
        
        const page = item.dataset.page;
        if (page === 'reports')   searchReports();
        if (page === 'warrants')  searchWarrants();
        if (page === 'bolos')     searchBOLOs();
        if (page === 'evidence')  searchEvidence();
        if (page === 'surveillance') searchSurveillance();
        if (page === 'dispatch')  refreshDispatch();
        if (page === 'bodycam')   loadBodycams();
    });
});

// ── Search input: Enter key support ──────────────
[
    { inputId: 'citizenSearch', fn: searchCitizens },
    { inputId: 'vehicleSearch', fn: searchVehicles },
    { inputId: 'reportSearch',  fn: searchReports  },
    { inputId: 'warrantSearch', fn: searchWarrants },
    { inputId: 'boloSearch',    fn: searchBOLOs    },
    { inputId: 'evidenceSearch', fn: searchEvidence },
    { inputId: 'surveillanceSearch', fn: searchSurveillance },
].forEach(({ inputId, fn }) => {
    const el = document.getElementById(inputId);
    if (el) el.addEventListener('keydown', e => { if (e.key === 'Enter') fn(); });
});

document.querySelectorAll('#page-settings input').forEach(inp => {
    inp.addEventListener('keydown', e => { if (e.key === 'Enter') applySettings(); });
});

// ── Report Editor ─────────────────────────────────
let currentReportId = null;
let involvedOfficers = [];
let involvedCitizens = [];
let evidenceList = [];

function openNewReport() {
    currentReportId = null;
    involvedOfficers = [];
    involvedCitizens = [];
    evidenceList = [];
    
    document.getElementById('reportListView').style.display = 'none';
    document.getElementById('reportEditorView').style.display = 'block';
    document.getElementById('reportEditorTitle').textContent = 'New Report';
    
    // Clear form
    document.getElementById('reportTitle').value = ''; // NEW
    document.getElementById('reportType').value = 'Incident Report';
    document.getElementById('reportSubject').value = '';
    document.getElementById('reportDetails').value = '';
    document.getElementById('reportCharges').value = '';
    document.getElementById('reportStatus').value = 'OPEN';
    
    renderInvolvedOfficers();
    renderInvolvedCitizens();
    renderEvidence();
}

function openReport(id) {
    currentReportId = id;
    nuiFetch('getReport', { id: id }).then(res => {
        if (res.report) {
            const r = res.report;
            document.getElementById('reportListView').style.display = 'none';
            document.getElementById('reportEditorView').style.display = 'block';
            document.getElementById('reportEditorTitle').textContent = 'Report #' + r.id;
            
            document.getElementById('reportTitle').value = r.title || '';
            document.getElementById('reportType').value = r.report_type;
            document.getElementById('reportSubject').value = r.subject;
            document.getElementById('reportDetails').value = r.details;
            document.getElementById('reportCharges').value = r.charges;
            document.getElementById('reportStatus').value = r.status;
            
            try { involvedOfficers = JSON.parse(r.involved_officers) || []; } catch(e) { involvedOfficers = []; }
            try { involvedCitizens = JSON.parse(r.involved_citizens) || []; } catch(e) { involvedCitizens = []; }
            try { evidenceList = JSON.parse(r.evidence) || []; } catch(e) { evidenceList = []; }
            
            renderInvolvedOfficers();
            renderInvolvedCitizens();
            renderEvidence();
        }
    });
}

function backToReportList() {
    document.getElementById('reportListView').style.display = 'block';
    document.getElementById('reportEditorView').style.display = 'none';
    searchReports();
}

// ── Autocomplete Logic ────────────────────────────
let searchTimeouts = { officer: null, citizen: null };

function handleNameSearch(type, query) {
    clearTimeout(searchTimeouts[type]);
    const box = document.getElementById(type + 'Suggestions');
    
    if (query.length < 2) {
        box.style.display = 'none';
        return;
    }

    searchTimeouts[type] = setTimeout(() => {
        nuiFetch('searchNames', { type: type, query: query }).then(res => {
            const results = res.results || [];
            if (results.length === 0) {
                box.style.display = 'none';
                return;
            }
            
            let html = '';
            results.forEach(item => {
                const safeName = item.name.replace(/'/g, "\\'");
                html += `<div class="suggestion-item" onclick="selectSuggestion('${type}', '${safeName}')">${item.name}</div>`;
            });
            
            box.innerHTML = html;
            box.style.display = 'block';
        });
    }, 300);
}

function selectSuggestion(type, name) {
    const input = document.getElementById(type + 'Input');
    input.value = '';
    document.getElementById(type + 'Suggestions').style.display = 'none';
    if (!name) return;

    if (type === 'officer') {
        if (!involvedOfficers.includes(name)) {
            involvedOfficers.push(name);
            renderInvolvedOfficers();
        }
    } else {
        if (!involvedCitizens.includes(name)) {
            involvedCitizens.push(name);
            renderInvolvedCitizens();
        }
    }
}

// Close suggestions when clicking anywhere else on the screen
document.addEventListener('click', (e) => {
    if (!e.target.closest('#officerInput') && !e.target.closest('#officerSuggestions')) {
        const box = document.getElementById('officerSuggestions');
        if (box) box.style.display = 'none';
    }
    if (!e.target.closest('#citizenInput') && !e.target.closest('#citizenSuggestions')) {
        const box = document.getElementById('citizenSuggestions');
        if (box) box.style.display = 'none';
    }
    if (!e.target.closest('#citizenSearch') && !e.target.closest('#citizenSearchSuggestions')) {
        const box = document.getElementById('citizenSearchSuggestions');
        if (box) box.style.display = 'none';
    }
});

function addInvolvedOfficer() {
    const input = document.getElementById('officerInput');
    const name = input.value.trim();
    if (name) {
        involvedOfficers.push(name);
        input.value = '';
        renderInvolvedOfficers();
    }
}

function removeInvolvedOfficer(index) {
    involvedOfficers.splice(index, 1);
    renderInvolvedOfficers();
}

function renderInvolvedOfficers() {
    const list = document.getElementById('officerList');
    if (involvedOfficers.length === 0) {
        list.innerHTML = '<div style="color:#566b80; font-size:11px; text-align:center; padding:10px;">No officers added</div>';
        return;
    }
    list.innerHTML = involvedOfficers.map((name, i) => `
        <div style="display:flex; justify-content:space-between; align-items:center; padding:8px; background:#0d1826; border:1px solid #1a2d45; border-radius:4px; margin-bottom:6px;">
            <span style="font-size:11px; color:#c8d6e8;">${name}</span>
            <button onclick="removeInvolvedOfficer(${i})" style="background:none; border:none; color:#e74c3c; cursor:pointer; font-size:14px;">×</button>
        </div>
    `).join('');
}

function addInvolvedCitizen() {
    const input = document.getElementById('citizenInput');
    const name = input.value.trim();
    if (name) {
        involvedCitizens.push(name);
        input.value = '';
        renderInvolvedCitizens();
    }
}

function removeInvolvedCitizen(index) {
    involvedCitizens.splice(index, 1);
    renderInvolvedCitizens();
}

function renderInvolvedCitizens() {
    const list = document.getElementById('citizenList');
    if (involvedCitizens.length === 0) {
        list.innerHTML = '<div style="color:#566b80; font-size:11px; text-align:center; padding:10px;">No citizens added</div>';
        return;
    }
    list.innerHTML = involvedCitizens.map((name, i) => `
        <div style="display:flex; justify-content:space-between; align-items:center; padding:8px; background:#0d1826; border:1px solid #1a2d45; border-radius:4px; margin-bottom:6px;">
            <span style="font-size:11px; color:#c8d6e8;">${name}</span>
            <button onclick="removeInvolvedCitizen(${i})" style="background:none; border:none; color:#e74c3c; cursor:pointer; font-size:14px;">×</button>
        </div>
    `).join('');
}

function addEvidence() {
    const input = document.getElementById('evidenceInput');
    const url = input.value.trim();
    if (url) {
        evidenceList.push(url);
        input.value = '';
        renderEvidence();
    }
}

function removeEvidence(index) {
    evidenceList.splice(index, 1);
    renderEvidence();
}

function renderEvidence() {
    const list = document.getElementById('evidenceList');
    if (evidenceList.length === 0) {
        list.innerHTML = '<div style="color:#566b80; font-size:11px; text-align:center; padding:20px; grid-column: 1/-1;">No evidence added</div>';
        return;
    }
    list.innerHTML = evidenceList.map((url, i) => `
        <div style="position:relative; background:#0d1826; border:1px solid #1a2d45; border-radius:4px; overflow:hidden;">
            <img src="${url}" style="width:100%; height:100px; object-fit:cover;" onerror="this.style.display='none'">
            <button onclick="removeEvidence(${i})" style="position:absolute; top:4px; right:4px; background:rgba(231,76,60,0.9); border:none; color:#fff; width:20px; height:20px; border-radius:50%; cursor:pointer; font-size:12px;">×</button>
            <div style="padding:4px; font-size:9px; color:#566b80; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${url}</div>
        </div>
    `).join('');
}

// ── Warrant Editor ────────────────────────────────
let currentWarrantId = null;

function openNewWarrant() {
    currentWarrantId = null;
    document.getElementById('warrantListView').style.display = 'none';
    document.getElementById('warrantEditorView').style.display = 'block';
    document.getElementById('warrantEditorTitle').textContent = 'New Warrant';

    document.getElementById('warrantSubjectName').value = '';
    document.getElementById('warrantSubjectId').value = '';
    document.getElementById('warrantCharges').value = '';
    document.getElementById('warrantDescription').value = '';
    document.getElementById('warrantPriority').value = 'Medium';
    document.getElementById('warrantStatus').value = 'ACTIVE';
}

function openWarrant(id) {
    currentWarrantId = id;
    nuiFetch('getWarrant', { id: id }).then(res => {
        if (res.warrant) {
            const w = res.warrant;
            document.getElementById('warrantListView').style.display = 'none';
            document.getElementById('warrantEditorView').style.display = 'block';
            document.getElementById('warrantEditorTitle').textContent = 'Warrant #' + w.id;

            document.getElementById('warrantSubjectName').value = w.subject_name;
            document.getElementById('warrantSubjectId').value = w.subject_id;
            document.getElementById('warrantCharges').value = w.charge;
            document.getElementById('warrantDescription').value = w.description || '';
            document.getElementById('warrantPriority').value = w.priority || 'Medium';
            document.getElementById('warrantStatus').value = w.status;
        }
    });
}

function backToWarrantList() {
    document.getElementById('warrantListView').style.display = 'block';
    document.getElementById('warrantEditorView').style.display = 'none';
    searchWarrants();
}

// ── Warrant Subject Autocomplete ──────────────────
let warrantSearchTimeout = null;

function handleWarrantSubjectSearch(query) {
    clearTimeout(warrantSearchTimeout);
    const box = document.getElementById('warrantSubjectSuggestions');
    const idInput = document.getElementById('warrantSubjectId');

    if (query.length < 2) {
        box.style.display = 'none';
        return;
    }

    warrantSearchTimeout = setTimeout(() => {
        // We pass type: 'citizen' to search the general population
        nuiFetch('searchNames', { type: 'citizen', query: query }).then(res => {
            const results = res.results || [];
            if (results.length === 0) {
                box.style.display = 'none';
                return;
            }

            let html = '';
            results.forEach(item => {
                const safeName = item.name.replace(/'/g, "\\'");
                const safeId = item.id.replace(/'/g, "\\'");
                html += `<div class="suggestion-item" onclick="selectWarrantSubject('${safeName}', '${safeId}')">${item.name}</div>`;
            });

            box.innerHTML = html;
            box.style.display = 'block';
        });
    }, 300);
}

function selectWarrantSubject(name, id) {
    document.getElementById('warrantSubjectName').value = name;
    document.getElementById('warrantSubjectId').value = id;
    document.getElementById('warrantSubjectSuggestions').style.display = 'none';
}

// Close suggestions when clicking anywhere else on the screen
document.addEventListener('click', (e) => {
    if (!e.target.closest('#warrantSubjectName') && !e.target.closest('#warrantSubjectSuggestions')) {
        const box = document.getElementById('warrantSubjectSuggestions');
        if (box) box.style.display = 'none';
    }
});

// Auto-search when warrant filters change
['warrantStatusFilter', 'warrantPriorityFilter'].forEach(filterId => {
    const el = document.getElementById(filterId);
    if (el) el.addEventListener('change', searchWarrants);
});

function saveWarrant() {
    const data = {
        id: currentWarrantId,
        subjectName: document.getElementById('warrantSubjectName').value.trim(),
        subjectId: document.getElementById('warrantSubjectId').value.trim(),
        charge: document.getElementById('warrantCharges').value.trim(),
        description: document.getElementById('warrantDescription').value.trim(),
        priority: document.getElementById('warrantPriority').value,
        status: document.getElementById('warrantStatus').value
    };

    if (!data.subjectName || !data.charge) {
        showToast('Subject Name and Charges are required.', 'error');
        return;
    }

    nuiFetch('saveWarrant', data).then(res => {
        if (res.ok) {
            showToast('Warrant saved successfully!', 'success');
            setTimeout(() => {
                backToWarrantList();
            }, 1000);
        } else {
            showToast('Failed to save warrant: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

// ── BOLO Editor ───────────────────────────────────
let currentBOLOId = null;

function openNewBOLO() {
    currentBOLOId = null;
    document.getElementById('boloListView').style.display = 'none';
    document.getElementById('boloEditorView').style.display = 'block';
    document.getElementById('boloEditorTitle').textContent = 'New BOLO';

    document.getElementById('boloType').value = 'person';
    document.getElementById('boloSubject').value = '';
    document.getElementById('boloDescription').value = '';
    document.getElementById('boloLastSeen').value = '';
    document.getElementById('boloPlate').value = '';
    document.getElementById('boloImage').value = '';
    document.getElementById('boloPriority').value = 'Medium';
    document.getElementById('boloStatus').value = 'ACTIVE';
    document.getElementById('boloImagePreview').style.display = 'none';
}

function openBOLO(id) {
    currentBOLOId = id;
    nuiFetch('getBOLO', { id: id }).then(res => {
        if (res.bolo) {
            const b = res.bolo;
            document.getElementById('boloListView').style.display = 'none';
            document.getElementById('boloEditorView').style.display = 'block';
            document.getElementById('boloEditorTitle').textContent = 'BOLO #' + b.id;

            document.getElementById('boloType').value = b.bolo_type;
            document.getElementById('boloSubject').value = b.subject_name || '';
            document.getElementById('boloDescription').value = b.description;
            document.getElementById('boloLastSeen').value = b.last_seen || '';
            document.getElementById('boloPlate').value = b.plate || '';
            document.getElementById('boloPriority').value = b.priority || 'Medium';
            document.getElementById('boloStatus').value = b.status;
            
            const imgInput = document.getElementById('boloImage');
            imgInput.value = b.image_url || '';
            updateBOLOImagePreview(imgInput.value);
        }
    });
}

function backToBOLOList() {
    document.getElementById('boloListView').style.display = 'block';
    document.getElementById('boloEditorView').style.display = 'none';
    searchBOLOs();
}

function updateBOLOImagePreview(url) {
    const preview = document.getElementById('boloImagePreview');
    const img = document.getElementById('boloImagePreviewImg');
    if (url && url.startsWith('http')) {
        img.src = url;
        preview.style.display = 'block';
    } else {
        preview.style.display = 'none';
    }
}

// Add event listener for image preview
document.addEventListener('DOMContentLoaded', () => {
    const imgInput = document.getElementById('boloImage');
    if (imgInput) {
        imgInput.addEventListener('input', (e) => updateBOLOImagePreview(e.target.value));
    }
});

function saveBOLO() {
    const data = {
        id: currentBOLOId,
        boloType: document.getElementById('boloType').value,
        subjectName: document.getElementById('boloSubject').value.trim(),
        description: document.getElementById('boloDescription').value.trim(),
        lastSeen: document.getElementById('boloLastSeen').value.trim(),
        plate: document.getElementById('boloPlate').value.trim(),
        imageUrl: document.getElementById('boloImage').value.trim(),
        priority: document.getElementById('boloPriority').value,
        status: document.getElementById('boloStatus').value
    };

    if (!data.description) {
        showToast('Description is required.', 'error');
        return;
    }

    nuiFetch('saveBOLO', data).then(res => {
        if (res.ok) {
            showToast('BOLO saved successfully!', 'success');
            setTimeout(() => {
                backToBOLOList();
            }, 1000);
        } else {
            showToast('Failed to save BOLO: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

function searchBOLOs() {
    const q = document.getElementById('boloSearch').value.trim();
    const statusFilter = document.getElementById('boloStatusFilter').value;
    const typeFilter = document.getElementById('boloTypeFilter').value;
    
    const tbody = document.querySelector('#page-bolos .mdt-table tbody');
    tbody.innerHTML = emptyRow(7, 'Searching…');
    
    nuiFetch('searchBOLOs', { 
        query: q, 
        status: statusFilter, 
        type: typeFilter 
    }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(7, 'No BOLOs found matching your filters.'); return; }
        tbody.innerHTML = rows.map(r => 
            `<tr>
                <td>B-${String(r.id).padStart(4, '0')}</td>
                <td>${r.bolo_type}</td>
                <td>${r.subject_name || '—'}</td>
                <td>${r.description.substring(0, 30)}${r.description.length > 30 ? '...' : ''}</td>
                <td><span class="badge ${getPriorityClass(r.priority)}">${r.priority || 'Medium'}</span></td>
                <td>${statusBadge(r.status)}</td>
                <td><button class="search-btn" style="background:#e67e22; padding:4px 10px; font-size:10px;" onclick="openBOLO(${r.id})">VIEW</button></td>
            </tr>`
        ).join('');
    });
}

// Helper for priority badge colors (reuse from warrants)
function getPriorityClass(priority) {
    const map = { 'Low': 'clear', 'Medium': 'pending', 'High': 'bolo', 'Critical': 'active' };
    return map[priority] || 'pending';
}

// Auto-search when BOLO filters change
document.addEventListener('DOMContentLoaded', () => {
    ['boloStatusFilter', 'boloTypeFilter'].forEach(filterId => {
        const el = document.getElementById(filterId);
        if (el) el.addEventListener('change', searchBOLOs);
    });
});

// ── Evidence Editor ───────────────────────────────
let currentEvidenceLocker = null;

function openNewEvidence() {
    currentEvidenceLocker = null;
    document.getElementById('evidenceListView').style.display = 'none';
    document.getElementById('evidenceEditorView').style.display = 'block';
    document.getElementById('evidenceEditorTitle').textContent = 'New Evidence Record';

    document.getElementById('evidenceLockerNumber').value = '';
    document.getElementById('evidencePerpetrator').value = '';
    document.getElementById('evidenceOfficer').value = '';
    document.getElementById('evidenceNotes').value = '';
    document.getElementById('evidenceItemsGrid').innerHTML = '<div style="grid-column: 1/-1; text-align:center; color:#566b80; font-size:11px; padding:20px;">Save the record to load locker contents from ox_inventory.</div>';
    document.getElementById('lockerItemCount').textContent = '(0 items)';
}

function openEvidence(lockerNumber) {
    currentEvidenceLocker = lockerNumber;
    nuiFetch('getEvidenceLocker', { lockerNumber: lockerNumber }).then(res => {
        if (res.evidence) {
            const e = res.evidence;
            document.getElementById('evidenceListView').style.display = 'none';
            document.getElementById('evidenceEditorView').style.display = 'block';
            document.getElementById('evidenceEditorTitle').textContent = 'Locker #' + e.locker_number;

            document.getElementById('evidenceLockerNumber').value = e.locker_number;
            document.getElementById('evidencePerpetrator').value = e.perpetrator;
            document.getElementById('evidenceOfficer').value = e.officer;
            document.getElementById('evidenceNotes').value = e.notes || '';

            renderEvidenceItems(e.items || []);
        }
    });
}

function backToEvidenceList() {
    document.getElementById('evidenceListView').style.display = 'block';
    document.getElementById('evidenceEditorView').style.display = 'none';
    searchEvidence();
}

function renderEvidenceItems(items) {
    const grid = document.getElementById('evidenceItemsGrid');
    document.getElementById('lockerItemCount').textContent = `(${items.length} items)`;
    
    if (items.length === 0) {
        grid.innerHTML = '<div style="grid-column: 1/-1; text-align:center; color:#566b80; font-size:11px; padding:20px;">Locker is empty.</div>';
        return;
    }

    grid.innerHTML = items.map(item => {
        // Format item name nicely (replace underscores with spaces, capitalize)
        const formattedName = item.name.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
        const serial = item.metadata && item.metadata.serial ? `<div style="font-size:9px; color:#e67e22; margin-top:4px;">S/N: ${item.metadata.serial}</div>` : '';
        
        return `
            <div style="background:#0d1826; border:1px solid #1a2d45; border-radius:4px; padding:10px; text-align:center;">
                <div style="font-size:11px; font-weight:700; color:#c8d6e8; text-transform:uppercase;">${formattedName}</div>
                <div style="font-size:10px; color:#566b80; margin-top:4px;">Qty: ${item.count}</div>
                ${serial}
            </div>
        `;
    }).join('');
}

function saveEvidence() {
    const data = {
        lockerNumber: document.getElementById('evidenceLockerNumber').value.trim(),
        perpetrator: document.getElementById('evidencePerpetrator').value.trim(),
        officer: document.getElementById('evidenceOfficer').value.trim(),
        notes: document.getElementById('evidenceNotes').value.trim()
    };

    if (!data.lockerNumber || !data.perpetrator) {
        showToast('Locker Number and Perpetrator are required.', 'error');
        return;
    }

    nuiFetch('saveEvidence', data).then(res => {
        if (res.ok) {
            showToast('Evidence record saved!', 'success');
            // Reload the locker to show items from ox_inventory
            openEvidence(data.lockerNumber);
        } else {
            showToast('Failed to save evidence: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

function searchEvidence() {
    const q = document.getElementById('evidenceSearch').value.trim();
    const tbody = document.querySelector('#page-evidence .mdt-table tbody');
    tbody.innerHTML = emptyRow(6, 'Searching…');
    
    nuiFetch('searchEvidence', { query: q }).then(res => {
        const rows = res.results || [];
        if (rows.length === 0) { tbody.innerHTML = emptyRow(6, 'No evidence records found.'); return; }
        tbody.innerHTML = rows.map(r => 
            `<tr>
                <td>#${r.locker_number}</td>
                <td>${r.perpetrator}</td>
                <td>${r.officer}</td>
                <td>${r.notes ? r.notes.substring(0, 30) + (r.notes.length > 30 ? '...' : '') : '—'}</td>
                <td>${r.date || '—'}</td>
                <td><button class="search-btn" style="background:#8e44ad; padding:4px 10px; font-size:10px;" onclick="openEvidence(${r.locker_number})">VIEW</button></td>
            </tr>`
        ).join('');
    });
}

// ── Evidence Autocomplete ─────────────────────────
let evidenceSearchTimeouts = { perpetrator: null, officer: null };

function handleEvidenceNameSearch(type, query) {
    clearTimeout(evidenceSearchTimeouts[type]);
    const box = document.getElementById('evidence' + type.charAt(0).toUpperCase() + type.slice(1) + 'Suggestions');
    
    if (query.length < 2) {
        box.style.display = 'none';
        return;
    }

    evidenceSearchTimeouts[type] = setTimeout(() => {
        // For officer, search police jobs; for perpetrator, search all citizens
        const searchType = type === 'officer' ? 'officer' : 'citizen';
        
        nuiFetch('searchNames', { type: searchType, query: query }).then(res => {
            const results = res.results || [];
            if (results.length === 0) {
                box.style.display = 'none';
                return;
            }
            
            let html = '';
            results.forEach(item => {
                const safeName = item.name.replace(/'/g, "\\'");
                html += `<div class="suggestion-item" onclick="selectEvidenceSuggestion('${type}', '${safeName}')">${item.name}</div>`;
            });
            
            box.innerHTML = html;
            box.style.display = 'block';
        });
    }, 300);
}

function selectEvidenceSuggestion(type, name) {
    const input = document.getElementById('evidence' + type.charAt(0).toUpperCase() + type.slice(1));
    input.value = name;
    document.getElementById('evidence' + type.charAt(0).toUpperCase() + type.slice(1) + 'Suggestions').style.display = 'none';
}

// Close evidence suggestions when clicking elsewhere
document.addEventListener('click', (e) => {
    if (!e.target.closest('#evidencePerpetrator') && !e.target.closest('#evidencePerpetratorSuggestions')) {
        const box = document.getElementById('evidencePerpetratorSuggestions');
        if (box) box.style.display = 'none';
    }
    if (!e.target.closest('#evidenceOfficer') && !e.target.closest('#evidenceOfficerSuggestions')) {
        const box = document.getElementById('evidenceOfficerSuggestions');
        if (box) box.style.display = 'none';
    }
});

function saveReport() {
    const data = {
        id: currentReportId,
        reportType: document.getElementById('reportType').value,
        title: document.getElementById('reportTitle').value.trim(), // NEW
        subject: document.getElementById('reportSubject').value.trim(),
        details: document.getElementById('reportDetails').value.trim(),
        charges: document.getElementById('reportCharges').value.trim(),
        status: document.getElementById('reportStatus').value,
        involvedOfficers: involvedOfficers,
        involvedCitizens: involvedCitizens,
        evidence: evidenceList
    };
    if (!data.details) {
        showToast('Description is required.', 'error');
        return;
    }

    nuiFetch('saveReport', data).then(res => {
        if (res.ok) {
            showToast('Report saved successfully!', 'success');
            setTimeout(() => {
                backToReportList();
            }, 1000);
        } else {
            showToast('Failed to save report: ' + (res.error || 'Unknown error'), 'error');
        }
    });
}

// ── Charges Modal Logic ───────────────────────────
const penalCode = [
    { category: "Traffic Offenses", charges: [
        { code: "VC-1", name: "Speeding (1-15 mph over limit)" },
        { code: "VC-2", name: "Speeding (15+ mph over limit)" },
        { code: "VC-3", name: "Reckless Driving" },
        { code: "VC-4", name: "Driving Under the Influence (DUI)" },
        { code: "VC-5", name: "Hit and Run (Property Damage)" },
        { code: "VC-6", name: "Hit and Run (Injury)" },
        { code: "VC-7", name: "Failure to Yield" },
        { code: "VC-8", name: "Running a Red Light / Stop Sign" },
        { code: "VC-9", name: "Illegal U-Turn" },
        { code: "VC-10", name: "Driving Without a License" },
        { code: "VC-11", name: "Driving on Suspended License" },
        { code: "VC-12", name: "Failure to Obey Traffic Control Device" },
    ]},
    { category: "Misdemeanors", charges: [
        { code: "PC-101", name: "Trespassing" },
        { code: "PC-102", name: "Vandalism / Property Damage" },
        { code: "PC-103", name: "Petty Theft (Under $950)" },
        { code: "PC-104", name: "Disorderly Conduct" },
        { code: "PC-105", name: "Resisting Arrest (Non-Violent)" },
        { code: "PC-106", name: "Public Intoxication" },
        { code: "PC-107", name: "Disturbing the Peace" },
        { code: "PC-108", name: "Jaywalking" },
        { code: "PC-109", name: "Littering" },
        { code: "PC-110", name: "Failure to Identify" },
        { code: "PC-111", name: "Impersonating an Officer" },
        { code: "PC-112", name: "Tampering with Evidence" },
    ]},
    { category: "Felonies", charges: [
        { code: "PC-201", name: "Assault with a Deadly Weapon" },
        { code: "PC-202", name: "Battery on a Peace Officer" },
        { code: "PC-203", name: "Grand Theft Auto (Vehicle Theft)" },
        { code: "PC-204", name: "Robbery (Armed)" },
        { code: "PC-205", name: "Burglary (Residential)" },
        { code: "PC-206", name: "Burglary (Commercial)" },
        { code: "PC-207", name: "Kidnapping" },
        { code: "PC-208", name: "Possession of an Illegal Firearm" },
        { code: "PC-209", name: "Fleeing and Eluding (Felony)" },
        { code: "PC-210", name: "Attempted Murder" },
        { code: "PC-211", name: "Manslaughter" },
        { code: "PC-212", name: "First Degree Murder" },
        { code: "PC-213", name: "Second Degree Murder" },
        { code: "PC-214", name: "Hostage Taking" },
    ]},
    { category: "Drug & Narcotics", charges: [
        { code: "HS-1", name: "Possession of Controlled Substance" },
        { code: "HS-2", name: "Possession with Intent to Distribute" },
        { code: "HS-3", name: "Cultivation of Controlled Substance" },
        { code: "HS-4", name: "Manufacturing Controlled Substance" },
        { code: "HS-5", name: "Drug Trafficking" },
        { code: "HS-6", name: "Possession of Drug Paraphernalia" },
    ]},
    { category: "Other / Miscellaneous", charges: [
        { code: "PC-301", name: "Contempt of Court" },
        { code: "PC-302", name: "Obstruction of Justice" },
        { code: "PC-303", name: "Perjury" },
        { code: "PC-304", name: "Bribery" },
        { code: "PC-305", name: "Extortion / Blackmail" },
        { code: "PC-306", name: "Money Laundering" },
        { code: "PC-307", name: "Racketeering" },
    ]}
];

let currentChargesTarget = 'reportCharges';

function openChargesModal(targetId = 'reportCharges') {
    currentChargesTarget = targetId;
    const modal = document.getElementById('modalCharges');
    const textarea = document.getElementById(targetId);
    
    const existingCharges = textarea.value.split('\n').map(c => c.trim()).filter(c => c !== '');
    currentSelectedCharges = existingCharges;

    renderChargesList();
    document.getElementById('chargeSearchInput').value = '';
    modal.style.display = 'flex';
}

function applySelectedCharges() {
    const textarea = document.getElementById(currentChargesTarget);
    textarea.value = currentSelectedCharges.join('\n');
    closeChargesModal();
}

function closeChargesModal() {
    document.getElementById('modalCharges').style.display = 'none';
}

function renderChargesList() {
    const container = document.getElementById('chargesListContainer');
    container.innerHTML = '';
    const searchTerm = document.getElementById('chargeSearchInput').value.toLowerCase();

    penalCode.forEach(category => {
        const filteredCharges = category.charges.filter(c => 
            c.name.toLowerCase().includes(searchTerm) || 
            c.code.toLowerCase().includes(searchTerm)
        );

        if (filteredCharges.length > 0) {
            const catDiv = document.createElement('div');
            catDiv.className = 'charge-category';
            catDiv.textContent = category.category;
            container.appendChild(catDiv);

            filteredCharges.forEach(charge => {
                const fullChargeString = `${charge.code} - ${charge.name}`;
                const isChecked = currentSelectedCharges.includes(fullChargeString);

                const itemDiv = document.createElement('div');
                itemDiv.className = 'charge-item';
                itemDiv.innerHTML = `
                    <input type="checkbox" id="charge-${charge.code}" ${isChecked ? 'checked' : ''} onchange="toggleCharge('${fullChargeString}', this.checked)">
                    <span class="charge-code">${charge.code}</span>
                    <label for="charge-${charge.code}">${charge.name}</label>
                `;
                container.appendChild(itemDiv);
            });
        }
    });
}

function filterCharges() {
    renderChargesList();
}

function toggleCharge(chargeString, isChecked) {
    if (isChecked) {
        if (!currentSelectedCharges.includes(chargeString)) {
            currentSelectedCharges.push(chargeString);
        }
    } else {
        currentSelectedCharges = currentSelectedCharges.filter(c => c !== chargeString);
    }
}

// ── Mini Dispatch Logic ─────────────────────────────
let miniDispatchCalls = [];
let currentMdIndex = 0;
let myOfficerName = null;

function updateMiniDispatchUI() {
    const list = document.getElementById('md-list');
    const counter = document.getElementById('md-counter');
    const el = document.getElementById('miniDispatch');

    if (miniDispatchCalls.length === 0) {
        el.style.display = 'none';
        // Only hide the body if the MDT itself isn't open
        if (!mdtIsOpen) document.body.style.display = 'none';
        return;
    }

    // There's at least one call: body must be visible so the overlay can render,
    // regardless of whether the MDT has been opened yet this session.
    document.body.style.display = 'flex';
    el.style.display = mdtIsOpen ? 'none' : 'flex';

    if (currentMdIndex >= miniDispatchCalls.length) currentMdIndex = miniDispatchCalls.length - 1;
    if (currentMdIndex < 0) currentMdIndex = 0;

    list.innerHTML = miniDispatchCalls.map((c, i) => {
        const isActive = i === currentMdIndex ? 'active' : '';
        const priorityClass = c.priority === 'Code 3' ? 'p3' : (c.priority === 'Code 2' ? 'p2' : 'p1');
        const unitHtml = c.unit && c.unit !== 'Unassigned'
            ? `<div class="md-call-unit">● ${c.unit}</div>`
            : '';
        return `
            <div class="md-call ${isActive}">
                <span class="md-call-priority ${priorityClass}">${c.priority}</span>
                <div class="md-call-type">${c.type}</div>
                <div class="md-call-loc">${c.location}</div>
                ${unitHtml}
            </div>
        `;
    }).join('');

    // Counter
    if (miniDispatchCalls.length > 1) {
        counter.textContent = `${currentMdIndex + 1} / ${miniDispatchCalls.length} CALLS`;
    } else {
        counter.textContent = '1 CALL';
    }

    // Footer hint: swap to UNASSIGN once the currently-viewed call is mine
    const controlsEl = document.querySelector('#miniDispatch .md-controls');
    if (controlsEl) {
        const current = miniDispatchCalls[currentMdIndex];
        const isMine = current && current.unit === 'You';
        controlsEl.innerHTML = `[←/→] SCROLL&nbsp;&nbsp;[G] ${isMine ? 'UNASSIGN' : 'ASSIGN'}`;
    }
}

// ── Dispatch refresh ──────────────────────────────
function dispatchPriorityClass(priority) {
    if (!priority) return '';
    const p = priority.toLowerCase();
    if (p.includes('3')) return 'priority-code3';
    if (p.includes('2')) return 'priority-code2';
    if (p.includes('1')) return 'priority-code1';
    return '';
}

function buildDispatchCard(c) {
    const isAssigned  = c.assigned_unit && c.assigned_unit !== 'Unassigned' && c.assigned_unit !== '';
    const unit        = c.assigned_unit || 'Unassigned';
    const priorityCls = dispatchPriorityClass(c.priority || '');
    const statusCls   = isAssigned ? 'status-assigned' : '';
    const type        = c.call_type || c.type || '—';
    const location    = c.location || '—';
    const prioBadge   = c.priority === 'Code 3' ? 'active' : (c.priority === 'Code 2' ? 'bolo' : 'pending');

    return `<div class="dispatch-card ${priorityCls} ${statusCls}" id="call-row-${c.id}">
        <div class="dc-header">
            <div class="dc-header-left">
                <span class="dc-callnum">#${c.id}</span>
                <span class="dc-type">${type}</span>
                <span class="badge ${prioBadge}">${c.priority || 'Code 2'}</span>
                <span class="dc-status-badge">${statusBadge(c.status || 'Pending')}</span>
            </div>
            <div class="dc-header-right">
                <button class="dc-btn respond" onclick="respondToCall(${c.id})">&#9654; RESPOND</button>
                <button class="dc-btn clear"   onclick="clearDispatchCall(${c.id})">&#x2715; CLEAR</button>
            </div>
        </div>
        <div class="dc-body">
            <div class="dc-detail">
                <span class="dc-detail-icon">&#128205;</span>
                <span class="dc-location" title="${location}">${location}</span>
            </div>
            <div class="dc-detail dc-unit-row">
                <span class="dc-detail-icon">&#128100;</span>
                <span class="dc-unit ${isAssigned ? 'assigned' : ''}">${unit}</span>
            </div>
        </div>
    </div>`;
}

function updateDispatchCount(n) {
    const el = document.getElementById('dispatchCallCount');
    if (el) el.textContent = n > 0 ? `${n} ACTIVE CALL${n !== 1 ? 'S' : ''}` : '';
}

function respondToCall(id) {
    nuiFetch('assignSelfToDispatch', { callId: id });

    const miniCall = miniDispatchCalls.find(c => c.id === id);
    if (miniCall) {
        miniCall.unit = 'You';
        miniCall.status = 'Assigned';
        updateMiniDispatchUI();
    }

    const card = document.getElementById(`call-row-${id}`);
    if (card) {
        card.classList.remove('priority-code3','priority-code2','priority-code1');
        card.classList.add('status-assigned');
        const unitEl = card.querySelector('.dc-unit');
        if (unitEl) { unitEl.textContent = 'You'; unitEl.classList.add('assigned'); }
        const statusBadgeEl = card.querySelector('.dc-status-badge');
        if (statusBadgeEl) statusBadgeEl.innerHTML = statusBadge('Assigned');
    }
}

function clearDispatchCall(id) {
    nuiFetch('clearDispatchCallRequest', { callId: id });
}

function refreshDispatch() {
    const container = document.getElementById('dispatchCards');
    container.innerHTML = '<div class="dispatch-empty">Loading…</div>';

    nuiFetch('refreshDispatch', {}).then(res => {
        const calls = res.calls || [];
        updateDispatchCount(calls.length);
        if (calls.length === 0) {
            container.innerHTML = '<div class="dispatch-empty">No active dispatch calls.</div>';
            return;
        }
        container.innerHTML = calls.map(buildDispatchCard).join('');
    });
}

// ── Settings: Scale ───────────────────────────────
let currentScale = 100;

function updateScale() {
    const scaleValue = currentScale / 100;
    const tablet = document.getElementById('tablet');
    const loginScreen = document.getElementById('loginScreen');
    
    if (tablet) tablet.style.transform = `scale(${scaleValue})`;
    if (loginScreen) loginScreen.style.transform = `scale(${scaleValue})`;
    
    const display = document.getElementById('scaleDisplay');
    if (display) display.textContent = `${currentScale}%`;
    
    localStorage.setItem('mdt_scale', currentScale);
}

function loadSettings() {
    const savedScale = localStorage.getItem('mdt_scale');
    if (savedScale) {
        currentScale = parseInt(savedScale);
        updateScale();
    }
}

// Initialize settings on load
loadSettings();

// Event listeners for settings buttons
const scaleDownBtn = document.getElementById('scaleDownBtn');
const scaleUpBtn = document.getElementById('scaleUpBtn');
const scaleResetBtn = document.getElementById('scaleResetBtn');

if (scaleDownBtn) scaleDownBtn.addEventListener('click', () => {
    if (currentScale > 50) { currentScale -= 5; updateScale(); }
});
if (scaleUpBtn) scaleUpBtn.addEventListener('click', () => {
    if (currentScale < 150) { currentScale += 5; updateScale(); }
});
if (scaleResetBtn) scaleResetBtn.addEventListener('click', () => {
    currentScale = 100; updateScale();
});

// ── Settings: Dispatch Call Sound ─────────────────
let dispatchSoundEnabled = true;

function loadDispatchSoundSetting() {
    const saved = localStorage.getItem('mdt_dispatch_sound');
    dispatchSoundEnabled = saved === null ? true : saved === 'true';
    const toggle = document.getElementById('dispatchSoundToggle');
    if (toggle) toggle.checked = dispatchSoundEnabled;
}

const dispatchSoundToggle = document.getElementById('dispatchSoundToggle');
if (dispatchSoundToggle) {
    dispatchSoundToggle.addEventListener('change', (e) => {
        dispatchSoundEnabled = e.target.checked;
        localStorage.setItem('mdt_dispatch_sound', dispatchSoundEnabled);
    });
}

loadDispatchSoundSetting();

// ── Settings: Mini Dispatch Opacity ───────────────
let miniDispatchOpacity = 50; // default 50%

function updateMiniDispatchOpacity() {
    const el = document.getElementById('miniDispatch');
    if (el) {
        const alpha = miniDispatchOpacity / 100;
        el.style.background = `rgba(8, 11, 17, ${alpha})`;
    }
    const display = document.getElementById('opacityDisplay');
    if (display) display.textContent = `${miniDispatchOpacity}%`;
    localStorage.setItem('mdt_dispatch_opacity', miniDispatchOpacity);
}

function loadMiniDispatchOpacity() {
    const saved = localStorage.getItem('mdt_dispatch_opacity');
    if (saved !== null) miniDispatchOpacity = parseInt(saved);
    updateMiniDispatchOpacity();
}

const opacityDownBtn  = document.getElementById('opacityDownBtn');
const opacityUpBtn    = document.getElementById('opacityUpBtn');
const opacityResetBtn = document.getElementById('opacityResetBtn');

if (opacityDownBtn) opacityDownBtn.addEventListener('click', () => {
    if (miniDispatchOpacity > 10) { miniDispatchOpacity -= 10; updateMiniDispatchOpacity(); }
});
if (opacityUpBtn) opacityUpBtn.addEventListener('click', () => {
    if (miniDispatchOpacity < 100) { miniDispatchOpacity += 10; updateMiniDispatchOpacity(); }
});
if (opacityResetBtn) opacityResetBtn.addEventListener('click', () => {
    miniDispatchOpacity = 50; updateMiniDispatchOpacity();
});

loadMiniDispatchOpacity();

// Generates a short two-tone alert beep via the Web Audio API — no sound
// file/asset needed. Respects the Settings toggle.
let dispatchAudioCtx = null;

function playDispatchSound() {
    if (!dispatchSoundEnabled) return;
    try {
        if (!dispatchAudioCtx) {
            dispatchAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }
        const ctx = dispatchAudioCtx;
        const now = ctx.currentTime;

        const playTone = (freq, startOffset, duration) => {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.value = freq;
            gain.gain.setValueAtTime(0, now + startOffset);
            gain.gain.linearRampToValueAtTime(0.18, now + startOffset + 0.02);
            gain.gain.linearRampToValueAtTime(0, now + startOffset + duration);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now + startOffset);
            osc.stop(now + startOffset + duration);
        };

        playTone(880, 0, 0.14);
        playTone(660, 0.16, 0.16);
    } catch (e) {
        // Audio not available; fail silently
    }
}

// ── Settings: Mini Dispatch Position ──────────────
let dispatchEditMode = false;
let dispatchDrag = null;

function applyDispatchPosition() {
    const el = document.getElementById('miniDispatch');
    if (!el) return;
    const saved = localStorage.getItem('mdt_dispatch_pos');
    if (saved) {
        try {
            const pos = JSON.parse(saved);
            el.style.left = pos.left + 'px';
            el.style.top = pos.top + 'px';
            el.style.transform = 'none';
        } catch (e) { /* ignore malformed saved position */ }
    }
}

function onDispatchDragStart(e) {
    if (!dispatchEditMode) return;
    const el = document.getElementById('miniDispatch');
    const rect = el.getBoundingClientRect();
    dispatchDrag = { offsetX: e.clientX - rect.left, offsetY: e.clientY - rect.top };
    document.addEventListener('mousemove', onDispatchDragMove);
    document.addEventListener('mouseup', onDispatchDragEnd);
    e.preventDefault();
}

function onDispatchDragMove(e) {
    if (!dispatchDrag) return;
    const el = document.getElementById('miniDispatch');
    let left = e.clientX - dispatchDrag.offsetX;
    let top = e.clientY - dispatchDrag.offsetY;
    left = Math.max(0, Math.min(left, window.innerWidth - el.offsetWidth));
    top = Math.max(0, Math.min(top, window.innerHeight - el.offsetHeight));
    el.style.left = left + 'px';
    el.style.top = top + 'px';
}

function onDispatchDragEnd() {
    document.removeEventListener('mousemove', onDispatchDragMove);
    document.removeEventListener('mouseup', onDispatchDragEnd);
    dispatchDrag = null;
}

function enterDispatchEditMode() {
    const el = document.getElementById('miniDispatch');
    if (!el) return;

    // Lock the currently-rendered position to explicit px values (in case
    // it's still using the default top:50%/transform centering) so dragging
    // moves it from exactly where it visually sits right now.
    const rect = el.getBoundingClientRect();
    el.style.left = rect.left + 'px';
    el.style.top = rect.top + 'px';
    el.style.transform = 'none';

    dispatchEditMode = true;
    el.style.display = 'flex';
    el.style.pointerEvents = 'auto';
    el.classList.add('dispatch-edit-mode');
    el.addEventListener('mousedown', onDispatchDragStart);

    // Show a placeholder card while editing if there's nothing real to display
    if (miniDispatchCalls.length === 0) {
        const list = document.getElementById('md-list');
        const counter = document.getElementById('md-counter');
        if (list) {
            list.innerHTML = `
                <div class="md-call active">
                    <span class="md-call-priority p1">PREVIEW</span>
                    <div class="md-call-type">Sample Call</div>
                    <div class="md-call-loc">Drag me anywhere on screen</div>
                </div>`;
        }
        if (counter) counter.textContent = 'PREVIEW';
    }

    const btn = document.getElementById('dispatchPositionBtn');
    if (btn) { btn.textContent = 'SAVE POSITION'; btn.style.background = '#1f7a4d'; }
}

function exitDispatchEditMode() {
    const el = document.getElementById('miniDispatch');
    if (!el) return;

    dispatchEditMode = false;
    el.classList.remove('dispatch-edit-mode');
    el.style.pointerEvents = 'none';
    el.removeEventListener('mousedown', onDispatchDragStart);
    onDispatchDragEnd();

    const rect = el.getBoundingClientRect();
    localStorage.setItem('mdt_dispatch_pos', JSON.stringify({ left: rect.left, top: rect.top }));

    const btn = document.getElementById('dispatchPositionBtn');
    if (btn) { btn.textContent = 'CHANGE POSITION'; btn.style.background = '#2a6496'; }

    // Restore real content + correct visibility (hidden while MDT is open)
    updateMiniDispatchUI();
    showToast('Dispatch position saved', 'success');
}

const dispatchPositionBtn = document.getElementById('dispatchPositionBtn');
if (dispatchPositionBtn) {
    dispatchPositionBtn.addEventListener('click', () => {
        if (!dispatchEditMode) enterDispatchEditMode();
        else exitDispatchEditMode();
    });
}

const dispatchPositionResetBtn = document.getElementById('dispatchPositionResetBtn');
if (dispatchPositionResetBtn) {
    dispatchPositionResetBtn.addEventListener('click', () => {
        localStorage.removeItem('mdt_dispatch_pos');
        const el = document.getElementById('miniDispatch');
        if (el) {
            el.style.left = '20px';
            el.style.top = '50%';
            el.style.transform = 'translateY(-50%)';
        }
        showToast('Dispatch position reset to default', 'success');
    });
}

applyDispatchPosition();