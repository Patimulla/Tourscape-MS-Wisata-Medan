// ============================================================
// ADMIN PANEL JS - SIG Wisata Medan
// ============================================================
const API_BASE = window.location.origin + '/api';
let allApproved = [];
let allMobileAdmins = [];
let miniMaps = {};
let editMap = null;
let editMarker = null;
let detailMap = null;
let detailGalleryPhotos = [];
let detailGalleryIndex = 0;
let editCurrentPhotos = [];
let editPhotoReplacements = new Map();
let editResolveTimer = null;
const EDIT_DAY_ORDER = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
let confirmSubmitHandler = null;

// ============================================================
// INIT
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    loadPending();
    loadApproved();
    loadMobileUsers();
    window.addEventListener('resize', syncApprovedLayout);
    bindEditWilayahInputs();
    bindEditDaySelector();
});

// ============================================================
// TAB SWITCH
// ============================================================
function switchTab(tab) {
    document.querySelectorAll('.tab-btn').forEach(button => button.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.querySelector(`.tab-btn[data-tab="${tab}"]`).classList.add('active');
    document.getElementById(`tab-${tab}`).classList.add('active');
    if (tab === 'approved') {
        window.setTimeout(syncApprovedLayout, 60);
    }
}

// ============================================================
// LOAD STATS
// ============================================================
async function loadStats() {
    try {
        const [wisataRes, pendingRes, kategoriRes, mobileUsersRes] = await Promise.all([
            fetch(`${API_BASE}/wisata`),
            fetch(`${API_BASE}/admin/wisata/pending`),
            fetch(`${API_BASE}/kategori`),
            fetch(`${API_BASE}/admin/mobile-users`),
        ]);

        const wisata = await wisataRes.json();
        const pending = await pendingRes.json();
        const kategori = await kategoriRes.json();
        const mobileUsers = await mobileUsersRes.json();

        document.getElementById('stat-total-approved').textContent = wisata.data ? wisata.data.length : 0;
        document.getElementById('stat-total-pending').textContent = pending.data ? pending.data.length : 0;
        document.getElementById('stat-total-kategori').textContent = kategori.data ? kategori.data.length : 0;
        const rejectedStatEl = document.getElementById('stat-total-rejected');
        if (rejectedStatEl) {
            rejectedStatEl.textContent = '-';
        }

        populateApprovedKategoriFilter(kategori.data || []);
        populateApprovedAdminFilter(mobileUsers.data || []);
    } catch (err) {
        console.error('Error loading stats:', err);
    }
}

function populateApprovedKategoriFilter(kategoriList) {
    populateKategoriSelect('approved-filter-kategori', kategoriList, 'Semua Kategori');
    populateKategoriSelect('edit-kategori', kategoriList, 'Pilih Kategori');
}

function populateKategoriSelect(selectId, kategoriList, defaultLabel) {
    const select = document.getElementById(selectId);
    if (!select) return;

    const currentValue = select.value;
    select.innerHTML = `<option value="">${defaultLabel}</option>`;

    kategoriList.forEach(kategori => {
        const option = document.createElement('option');
        option.value = kategori.nama_kategori;
        option.textContent = kategori.nama_kategori;
        select.appendChild(option);
    });

    if (currentValue) {
        select.value = currentValue;
    }
}

// ============================================================
// LOAD PENDING
// ============================================================
async function loadPending() {
    const listEl = document.getElementById('pending-list');

    try {
        const res = await fetch(`${API_BASE}/admin/wisata/pending`);
        const json = await res.json();

        if (!json.status || !json.data || json.data.length === 0) {
            listEl.innerHTML = `
                <div class="empty-state">
                    <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                        <polyline points="22 4 12 14.01 9 11.01"></polyline>
                    </svg>
                    <p>Tidak ada wisata yang menunggu validasi</p>
                    <small>Semua data sudah divalidasi</small>
                </div>`;
            document.getElementById('tab-badge-pending').textContent = '0';
            return;
        }

        const data = json.data;
        document.getElementById('tab-badge-pending').textContent = String(data.length);

        listEl.innerHTML = data.map(w => {
            const imgSrc = w.foto && w.foto.length > 0 && w.foto[0] ? esc(w.foto[0]) : '';
            const desc = (w.deskripsi || 'Tidak ada deskripsi.').substring(0, 100) + ((w.deskripsi || '').length > 100 ? '...' : '');
            const lokasiParts = [
                w.kota_kabupaten || '-',
                w.kecamatan || '-',
                w.kelurahan || '-',
            ];
            
            return `
            <div class="pending-card" id="card-${w.id}">
                <div class="pending-media">
                    ${imgSrc ? `<img src="${imgSrc}" alt="${esc(w.nama_tempat)}">` : '<div class="no-foto">Tidak ada foto</div>'}
                </div>
                <div class="pending-info">
                    <span class="tm-chip">${esc(w.kategori || '-')}</span>
                    <h3>${esc(w.nama_tempat)}</h3>
                    <p class="pending-desc">${esc(desc)}</p>
                    <div class="pending-meta">
                        <span>${lokasiParts.map(part => esc(part)).join(' &middot; ')}</span>
                    </div>
                </div>
                <div class="pending-actions-wrapper">
                    <div class="pending-submitter-inline">
                        <div class="pending-submitter-avatar">
                            ${renderAvatar(w.submitter_foto_profil, w.submitter_nama || w.submitter_no_pegawai || 'A')}
                        </div>
                        <div class="pending-submitter-meta">
                            <div class="pending-submitter-name">${esc(w.submitter_nama || 'Tanpa Nama')}</div>
                            <div class="pending-submitter-nopeg">${esc(w.submitter_no_pegawai || '-')}</div>
                        </div>
                    </div>
                    <div class="pending-actions">
                        <button class="btn-detail" onclick="showDetail(${w.id})">Detail</button>
                        <button class="btn-approve" onclick="approveWisata(${w.id}, '${escAttr(w.nama_tempat)}')">Approve</button>
                        <button class="btn-reject" onclick="rejectWisata(${w.id}, '${escAttr(w.nama_tempat)}')">Reject</button>
                    </div>
                </div>
            </div>
            `;
        }).join('');


    } catch (err) {
        console.error('Error loading pending:', err);
        listEl.innerHTML = '<div class="empty-state"><p>Gagal memuat data pending.</p></div>';
    }
}

function initMiniMap(id, lat, lng) {
    if (miniMaps[id]) {
        miniMaps[id].remove();
        delete miniMaps[id];
    }

    const map = L.map(`minimap-${id}`, {
        center: [lat, lng],
        zoom: 15,
        zoomControl: false,
        attributionControl: false,
        dragging: false,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);

    L.circleMarker([lat, lng], {
        radius: 8,
        color: '#f59e0b',
        fillColor: '#f59e0b',
        fillOpacity: 0.8,
    }).addTo(map);

    miniMaps[id] = map;
}

// ============================================================
// LOAD APPROVED
// ============================================================
async function loadApproved() {
    try {
        const res = await fetch(`${API_BASE}/wisata`);
        const json = await res.json();
        allApproved = json.data || [];
        renderApprovedTable(allApproved);
        window.setTimeout(syncApprovedLayout, 30);
    } catch (err) {
        console.error('Error loading approved:', err);
    }
}

async function loadMobileUsers() {
    const grid = document.getElementById('admin-directory-grid');
    if (!grid) return;

    try {
        const res = await fetch(`${API_BASE}/admin/mobile-users`);
        const json = await res.json();
        allMobileAdmins = json.data || [];
        renderAdminDirectory(allMobileAdmins);
        populateApprovedAdminFilter(allMobileAdmins);
        window.setTimeout(syncApprovedLayout, 30);
    } catch (err) {
        console.error('Error loading mobile users:', err);
        grid.innerHTML = '<div class="empty-state"><p>Gagal memuat admin mobile.</p></div>';
        window.setTimeout(syncApprovedLayout, 30);
    }
}

function renderApprovedTable(data) {
    const tbody = document.getElementById('approved-tbody');
    if (!data || data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:40px;color:var(--text-muted);">Tidak ada data wisata approved.</td></tr>';
        syncApprovedLayout();
        return;
    }

    tbody.innerHTML = data.map((w, index) => `
        <tr>
            <td>${index + 1}</td>
            <td style="color:var(--text-primary);font-weight:500;">${esc(w.nama_tempat)}</td>
            <td>${formatSubmitter(w)}</td>
            <td><span class="pending-kategori">${esc(w.kategori || '-')}</span></td>
            <td>${esc(w.kecamatan || '-')}</td>
            <td>${esc(w.kelurahan || '-')}</td>
            <td>${Number(w.rating) > 0 ? 'Rating ' + esc(String(w.rating)) : '-'}</td>
            <td class="actions-cell">
                <button class="btn-tbl view" onclick="showDetail(${w.id})">Detail</button>
                <button class="btn-tbl edit" onclick="openEdit(${w.id})">Edit</button>
                <button class="btn-tbl delete" onclick="deleteWisata(${w.id}, '${escAttr(w.nama_tempat)}')">Hapus</button>
            </td>
        </tr>
    `).join('');
    syncApprovedLayout();
}

function filterApproved() {
    const query = document.getElementById('approved-search').value.toLowerCase().trim();
    const kategori = document.getElementById('approved-filter-kategori').value;
    const adminId = document.getElementById('approved-filter-admin').value;

    let filtered = allApproved;

    if (query) {
        filtered = filtered.filter(w =>
            (w.nama_tempat || '').toLowerCase().includes(query) ||
            (w.alamat || '').toLowerCase().includes(query) ||
            (w.kecamatan || '').toLowerCase().includes(query) ||
            (w.kelurahan || '').toLowerCase().includes(query) ||
            (w.kategori || '').toLowerCase().includes(query)
        );
    }

    if (kategori) {
        filtered = filtered.filter(w => w.kategori === kategori);
    }

    if (adminId) {
        filtered = filtered.filter(w => (w.submitter_user_id || '') === adminId);
    }

    renderApprovedTable(filtered);
    highlightSelectedAdminCard(adminId);
}

function bindEditWilayahInputs() {
    const kotaEl = document.getElementById('edit-kota');
    const kecamatanEl = document.getElementById('edit-kecamatan');
    const kelurahanEl = document.getElementById('edit-kelurahan');
    const latEl = document.getElementById('edit-lat');
    const lngEl = document.getElementById('edit-lng');
    const fotoExtraEl = document.getElementById('edit-foto-extra');

    kotaEl?.addEventListener('change', async () => {
        const kotaId = kotaEl.value;
        await loadEditKecamatanOptions(kotaId || null);
        clearEditKelurahanOptions();
    });

    kecamatanEl?.addEventListener('change', async () => {
        const kecamatanId = kecamatanEl.value;
        await loadEditKelurahanOptions(kecamatanId || null);
    });

    [latEl, lngEl].forEach(input => {
        input?.addEventListener('change', () => {
            const lat = parseFloat(latEl.value);
            const lng = parseFloat(lngEl.value);
            if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
            updateEditCoordinatePosition(lat, lng, true);
        });
    });

    fotoExtraEl?.addEventListener('change', () => {
        renderEditPhotoManager(editCurrentPhotos);
    });
}

function bindEditDaySelector() {
    document.querySelectorAll('#edit-hari-selector .edit-day-chip').forEach(button => {
        button.addEventListener('click', () => {
            button.classList.toggle('active');
        });
    });
}

function setEditHariOperasional(value) {
    const selectedDays = String(value || '')
        .split(',')
        .map(day => day.trim())
        .filter(Boolean);

    document.querySelectorAll('#edit-hari-selector .edit-day-chip').forEach(button => {
        button.classList.toggle('active', selectedDays.includes(button.dataset.day));
    });
}

function getEditHariOperasionalValue() {
    const selectedDays = Array.from(document.querySelectorAll('#edit-hari-selector .edit-day-chip.active'))
        .map(button => button.dataset.day)
        .filter(Boolean);

    selectedDays.sort((a, b) => EDIT_DAY_ORDER.indexOf(a) - EDIT_DAY_ORDER.indexOf(b));
    return selectedDays.join(', ');
}

function populateEditSelect(selectId, items, placeholder, selectedId = '', selectedName = '') {
    const select = document.getElementById(selectId);
    if (!select) return;

    select.innerHTML = `<option value="">${placeholder}</option>`;

    items.forEach(item => {
        const option = document.createElement('option');
        option.value = String(item.id ?? '');
        option.textContent = item.nama || '-';
        option.dataset.tipe = item.tipe || '';
        option.dataset.wilayah = item.wilayah || '';
        select.appendChild(option);
    });

    if (selectedId) {
        select.value = String(selectedId);
    } else if (selectedName) {
        const match = Array.from(select.options).find(option =>
            option.textContent.trim().toLowerCase() === String(selectedName).trim().toLowerCase()
        );
        if (match) {
            select.value = match.value;
        }
    }
}

function clearEditKelurahanOptions() {
    populateEditSelect('edit-kelurahan', [], 'Pilih Kelurahan / Desa');
}

async function loadEditKotaOptions(selectedId = '', selectedName = '') {
    const res = await fetch(`${API_BASE}/wilayah?kategori=kota,kabupaten&per_page=20`);
    const json = await res.json();
    populateEditSelect('edit-kota', json.data || [], 'Pilih Kota / Kabupaten', selectedId, selectedName);
}

async function loadEditKecamatanOptions(kotaId, selectedId = '', selectedName = '') {
    const select = document.getElementById('edit-kecamatan');
    if (!select) return;

    if (!kotaId) {
        populateEditSelect('edit-kecamatan', [], 'Pilih Kecamatan');
        return;
    }

    const res = await fetch(`${API_BASE}/wilayah/kecamatan?wilayah_id=${encodeURIComponent(kotaId)}`);
    const json = await res.json();
    populateEditSelect('edit-kecamatan', json.data || [], 'Pilih Kecamatan', selectedId, selectedName);
}

async function loadEditKelurahanOptions(kecamatanId, selectedId = '', selectedName = '') {
    const select = document.getElementById('edit-kelurahan');
    if (!select) return;

    if (!kecamatanId) {
        populateEditSelect('edit-kelurahan', [], 'Pilih Kelurahan / Desa');
        return;
    }

    const res = await fetch(`${API_BASE}/wilayah/kelurahan?kecamatan_id=${encodeURIComponent(kecamatanId)}`);
    const json = await res.json();
    populateEditSelect('edit-kelurahan', json.data || [], 'Pilih Kelurahan / Desa', selectedId, selectedName);
}

async function resolveEditWilayahByPoint(lat, lng) {
    const res = await fetch(`${API_BASE}/wilayah/resolve?lat=${encodeURIComponent(lat)}&lng=${encodeURIComponent(lng)}`);
    const json = await res.json();
    return json.data || null;
}

function getSelectedOptionText(selectId) {
    const select = document.getElementById(selectId);
    if (!select || !select.value) return '';
    return select.options[select.selectedIndex]?.textContent?.trim() || '';
}

function renderEditPhotoManager(photos) {
    const container = document.getElementById('edit-photo-manager');
    const extraInput = document.getElementById('edit-foto-extra');
    if (!container) return;

    const photoCards = (photos || []).map((url, index) => `
        <div class="edit-photo-card">
            <div class="edit-photo-preview">
                <img src="${esc(url)}" alt="Foto ${index + 1}" onerror="this.style.display='none'">
            </div>
            <div class="edit-photo-actions">
                <div class="edit-photo-label">Foto ${index === 0 ? 'Utama' : `Galeri ${index}`}</div>
                <label class="edit-photo-replace-btn">
                    Ganti Foto
                    <input type="file" accept="image/*" onchange="handleEditPhotoReplacement(${index}, event)">
                </label>
                <div class="edit-photo-selected" id="edit-photo-selected-${index}">
                    ${editPhotoReplacements.has(index) ? esc(editPhotoReplacements.get(index).name) : 'Belum ada file baru'}
                </div>
            </div>
        </div>
    `).join('');

    const extraPreview = Array.from(extraInput?.files || []).map(file => `
        <span class="tm-chip edit-photo-extra-chip">${esc(file.name)}</span>
    `).join('');

    container.innerHTML = `
        <div class="edit-photo-grid">
            ${photoCards || '<div class="edit-photo-empty">Belum ada foto tersimpan.</div>'}
        </div>
        ${extraPreview ? `<div class="edit-photo-extra-list">${extraPreview}</div>` : ''}
    `;
}

function handleEditPhotoReplacement(index, event) {
    const file = event.target?.files?.[0];
    if (!file) return;
    editPhotoReplacements.set(index, file);
    const label = document.getElementById(`edit-photo-selected-${index}`);
    if (label) {
        label.textContent = file.name;
    }
}

async function uploadPhotoFile(file) {
    const formData = new FormData();
    formData.append('foto', file);

    const res = await fetch(`${API_BASE}/upload`, {
        method: 'POST',
        body: formData,
    });

    const json = await res.json();
    if (!json.status || !json.data?.url) {
        throw new Error(json.message || 'Gagal upload foto');
    }

    return json.data.url;
}

async function collectEditedPhotoUrls() {
    const finalPhotos = [...editCurrentPhotos];

    for (const [index, file] of editPhotoReplacements.entries()) {
        finalPhotos[index] = await uploadPhotoFile(file);
    }

    const extraFiles = Array.from(document.getElementById('edit-foto-extra')?.files || []);
    for (const file of extraFiles) {
        finalPhotos.push(await uploadPhotoFile(file));
    }

    return finalPhotos.filter(Boolean);
}

async function applyEditWilayahFromCoordinates(lat, lng, fallbackData = {}) {
    const resolved = await resolveEditWilayahByPoint(lat, lng);

    if (resolved?.kota_id) {
        await loadEditKotaOptions(resolved.kota_id, fallbackData.kotaNama || '');
        await loadEditKecamatanOptions(resolved.kota_id, resolved.kecamatan_id || '', fallbackData.kecamatanNama || '');
        await loadEditKelurahanOptions(resolved.kecamatan_id || '', resolved.kelurahan_id || '', fallbackData.kelurahanNama || '');
        return;
    }

    await loadEditKotaOptions('', fallbackData.kotaNama || '');
    const kotaId = document.getElementById('edit-kota')?.value || '';
    await loadEditKecamatanOptions(kotaId || null, '', fallbackData.kecamatanNama || '');
    const kecamatanId = document.getElementById('edit-kecamatan')?.value || '';
    await loadEditKelurahanOptions(kecamatanId || null, '', fallbackData.kelurahanNama || '');
}

function scheduleEditWilayahResolve(lat, lng, fallbackData = {}) {
    if (editResolveTimer) {
        window.clearTimeout(editResolveTimer);
    }

    editResolveTimer = window.setTimeout(() => {
        applyEditWilayahFromCoordinates(lat, lng, fallbackData).catch(() => undefined);
    }, 180);
}

function updateEditCoordinatePosition(lat, lng, syncWilayah = false) {
    document.getElementById('edit-lat').value = Number(lat).toFixed(6);
    document.getElementById('edit-lng').value = Number(lng).toFixed(6);

    if (editMarker) {
        editMarker.setLatLng([lat, lng]);
    }

    if (editMap) {
        editMap.setView([lat, lng], Math.max(editMap.getZoom(), 16), { animate: true });
    }

    if (syncWilayah) {
        scheduleEditWilayahResolve(lat, lng, {});
    }
}

function renderAdminDirectory(admins) {
    const grid = document.getElementById('admin-directory-grid');
    if (!grid) return;

    if (!admins || admins.length === 0) {
        grid.innerHTML = '<div class="empty-state"><p>Belum ada admin mobile terdaftar.</p></div>';
        return;
    }

    const selectedAdminId = document.getElementById('approved-filter-admin')?.value || '';

    grid.innerHTML = admins.map(admin => `
        <button
            type="button"
            class="admin-profile-card${selectedAdminId === (admin.id || '') ? ' active' : ''}"
            data-admin-id="${escAttr(admin.id || '')}"
            onclick="selectApprovedAdminFilter('${escAttr(admin.id || '')}')"
        >
            <div class="admin-profile-avatar">
                ${renderAvatar(admin.foto_profil, admin.username || admin.no_pegawai || 'A')}
            </div>
            <div class="admin-profile-content">
                <div class="admin-profile-name">${esc(admin.username || 'Tanpa Nama')}</div>
                <div class="admin-profile-sub">${esc(admin.no_pegawai || '-')}</div>
                <div class="admin-profile-stats">
                    <span>${Number(admin.total_approved || 0)} approved</span>
                    <span>${Number(admin.total_pending || 0)} pending</span>
                    <span>${Number(admin.total_rejected || 0)} rejected</span>
                </div>
            </div>
        </button>
    `).join('');
}

function populateApprovedAdminFilter(admins) {
    const select = document.getElementById('approved-filter-admin');
    if (!select) return;

    const currentValue = select.value;
    select.innerHTML = '<option value="">Semua Pengaju</option>';

    admins.forEach(admin => {
        const option = document.createElement('option');
        option.value = admin.id || '';
        option.textContent = `${admin.username || 'Tanpa Nama'}${admin.no_pegawai ? ` (${admin.no_pegawai})` : ''}`;
        select.appendChild(option);
    });

    select.value = currentValue;
    highlightSelectedAdminCard(select.value);
}

function selectApprovedAdminFilter(adminId) {
    const select = document.getElementById('approved-filter-admin');
    if (!select) return;

    select.value = select.value === adminId ? '' : adminId;
    filterApproved();
}

function highlightSelectedAdminCard(adminId) {
    document.querySelectorAll('.admin-profile-card').forEach(card => {
        card.classList.toggle('active', !!adminId && card.dataset.adminId === adminId);
    });
}

function getDetailIcon(type) {
    const icons = {
        city: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M3 21h18"></path><path d="M5 21V7l8-4v18"></path><path d="M19 21V11l-6-4"></path></svg>`,
        address: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>`,
        district: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M8 21h8"></path><path d="M12 17v4"></path><path d="M7 4h10l1 6H6l1-6z"></path><path d="M6 10h12v3a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3v-3z"></path></svg>`,
        village: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4 21h16"></path><path d="M6 21v-8l6-5 6 5v8"></path><path d="M10 21v-4h4v4"></path><path d="M12 3v5"></path></svg>`,
        clock: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"></circle><path d="M12 7v5l3 3"></path></svg>`,
        calendar: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="3" y="4" width="18" height="18" rx="2"></rect><path d="M16 2v4"></path><path d="M8 2v4"></path><path d="M3 10h18"></path></svg>`,
        ticket: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M3 9a2 2 0 0 0 2-2h14a2 2 0 0 0 2 2v2a2 2 0 0 0-2 2H5a2 2 0 0 0-2-2V9z"></path><path d="M12 7v10"></path></svg>`,
        note: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16l6-3 6 3V8z"></path><path d="M14 2v6h6"></path></svg>`,
        phone: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.79 19.79 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.33 1.78.63 2.61a2 2 0 0 1-.45 2.11L8 9.91a16 16 0 0 0 6.09 6.09l1.47-1.29a2 2 0 0 1 2.11-.45c.83.3 1.71.51 2.61.63A2 2 0 0 1 22 16.92z"></path></svg>`,
        rating: `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"></path></svg>`,
        target: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="7" r="4"></circle><path d="M5.5 21a6.5 6.5 0 0 1 13 0"></path></svg>`,
        coordinates: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 3l-7 18-2-8-8-2 18-8z"></path></svg>`,
        facility: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6L9 17l-5-5"></path></svg>`,
        account: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="7" r="4"></circle><path d="M5.5 21a6.5 6.5 0 0 1 13 0"></path></svg>`,
    };

    return icons[type] || icons.note;
}

function buildAdminDetailInfoItem(iconKey, label, value, extraClass = '') {
    return `
        <div class="admin-detail-info-item ${extraClass}">
            <div class="admin-detail-info-icon">${getDetailIcon(iconKey)}</div>
            <div class="admin-detail-info-copy">
                <div class="admin-detail-info-label">${esc(label)}</div>
                <div class="admin-detail-info-value">${esc(value || '-')}</div>
            </div>
        </div>
    `;
}

function buildAdminDetailGallery(photos, placeName) {
    if (!Array.isArray(photos) || photos.length === 0) {
        return '';
    }

    detailGalleryPhotos = photos.filter(Boolean);
    detailGalleryIndex = 0;

    return `
        <div class="admin-detail-gallery ${detailGalleryPhotos.length > 1 ? 'has-controls' : ''}">
            <img
                id="admin-detail-gallery-image"
                class="admin-detail-hero-img"
                src="${esc(detailGalleryPhotos[0])}"
                alt="${esc(placeName)}"
                onerror="this.style.display='none'"
            >
            ${detailGalleryPhotos.length > 1 ? `
                <button class="admin-detail-gallery-nav prev" type="button" onclick="stepAdminDetailGallery(-1)" aria-label="Foto sebelumnya">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="15 18 9 12 15 6"></polyline>
                    </svg>
                </button>
                <button class="admin-detail-gallery-nav next" type="button" onclick="stepAdminDetailGallery(1)" aria-label="Foto berikutnya">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="9 18 15 12 9 6"></polyline>
                    </svg>
                </button>
                <div class="admin-detail-gallery-counter">
                    <span id="admin-detail-gallery-counter">1 / ${detailGalleryPhotos.length}</span>
                </div>
            ` : ''}
        </div>
    `;
}

function stepAdminDetailGallery(direction) {
    if (!detailGalleryPhotos.length) {
        return;
    }

    detailGalleryIndex = (detailGalleryIndex + direction + detailGalleryPhotos.length) % detailGalleryPhotos.length;
    const imageEl = document.getElementById('admin-detail-gallery-image');
    const counterEl = document.getElementById('admin-detail-gallery-counter');

    if (imageEl) {
        imageEl.classList.remove('is-slide-in', 'is-slide-out');
        imageEl.classList.add('is-slide-out');
        window.setTimeout(() => {
            imageEl.src = detailGalleryPhotos[detailGalleryIndex];
            imageEl.style.display = '';
            imageEl.classList.remove('is-slide-out');
            imageEl.classList.add('is-slide-in');
            window.setTimeout(() => imageEl.classList.remove('is-slide-in'), 220);
        }, 140);
    }

    if (counterEl) {
        counterEl.textContent = `${detailGalleryIndex + 1} / ${detailGalleryPhotos.length}`;
    }
}

// ============================================================
// DETAIL MODAL
// ============================================================
async function showDetail(id) {
    const modal = document.getElementById('detail-modal');
    const body = document.getElementById('detail-body');
    body.innerHTML = '<div class="loading"><div class="spinner"></div><p>Memuat detail...</p></div>';
    modal.classList.add('active');

    try {
        const res = await fetch(`${API_BASE}/admin/wisata/${id}`);
        const json = await res.json();

        if (!json.status || !json.data) {
            body.innerHTML = '<p>Data tidak ditemukan.</p>';
            return;
        }

        const w = json.data;
        document.getElementById('detail-title').textContent = w.nama_tempat;

        detailGalleryPhotos = [];
        detailGalleryIndex = 0;

        const galleryHtml = buildAdminDetailGallery(Array.isArray(w.foto) ? w.foto : [], w.nama_tempat);
        const ratingText = Number(w.rating) > 0 ? `${Number(w.rating).toFixed(1)} / 5` : 'Belum ada rating';
        const hargaText = Number(w.harga_tiket) > 0 ? formatRupiah(w.harga_tiket) : 'Gratis';
        const jamText = w.jam_buka || w.jam_tutup
            ? `${esc(w.jam_buka || '-')} - ${esc(w.jam_tutup || '-')}`
            : '-';
        const coordinatesText = w.latitude && w.longitude
            ? `${Number.parseFloat(w.latitude).toFixed(6)}, ${Number.parseFloat(w.longitude).toFixed(6)}`
            : '-';
        const fasilitasList = Array.isArray(w.fasilitas) ? w.fasilitas.filter(Boolean) : [];
        const infoGridHtml = `
            <div class="admin-detail-info-grid">
                ${buildAdminDetailInfoItem('city', 'Kota / Kabupaten', w.kota_kabupaten || '-')}
                ${buildAdminDetailInfoItem('address', 'Alamat', w.alamat || '-')}
                ${buildAdminDetailInfoItem('district', 'Kecamatan', w.kecamatan || '-')}
                ${buildAdminDetailInfoItem('village', 'Kelurahan / Desa', w.kelurahan || '-')}
                ${buildAdminDetailInfoItem('clock', 'Jam Operasional', jamText)}
                ${buildAdminDetailInfoItem('calendar', 'Hari Operasional', w.hari_operasional || '-')}
                ${buildAdminDetailInfoItem('ticket', 'Harga Tiket', hargaText)}
                ${buildAdminDetailInfoItem('note', 'Keterangan Harga', w.keterangan_harga || '-')}
                ${buildAdminDetailInfoItem('phone', 'No. Telepon', w.no_telepon || '-')}
                ${buildAdminDetailInfoItem('account', 'Akun Pengaju', formatSubmitter(w))}
                ${buildAdminDetailInfoItem('coordinates', 'Koordinat', coordinatesText, 'full')}
                ${buildAdminDetailInfoItem('note', 'Catatan Admin', w.catatan_admin || '-', 'full')}
            </div>
        `;
        const fasilitasHtml = fasilitasList.length > 0
            ? `
                <div class="admin-detail-subsection">
                    <h3>Fasilitas</h3>
                    <div class="admin-detail-facilities">
                        ${fasilitasList.map(fasilitas => `
                            <span class="tm-chip admin-detail-facility-chip">
                                ${getDetailIcon('facility')}
                                <span>${esc(fasilitas)}</span>
                            </span>
                        `).join('')}
                    </div>
                </div>
            `
            : '';

        body.innerHTML = `
            ${galleryHtml}
            <div class="detail-map-preview admin-detail-map-preview" id="detail-map-container"></div>
            ${renderSubmitterProfile(w)}
            <div class="admin-detail-section">
                <div class="admin-detail-header">
                    <h2>${esc(w.nama_tempat)}</h2>
                    <div class="admin-detail-badges">
                        <span class="admin-detail-kategori">${esc(w.kategori || 'Tanpa Kategori')}</span>
                        <span class="admin-detail-badge-inline">
                            ${getDetailIcon('target')}
                            <span>${esc(w.target_pengunjung || 'Target belum diatur')}</span>
                        </span>
                        <span class="admin-detail-badge-inline is-rating">
                            ${getDetailIcon('rating')}
                            <span>${esc(ratingText)}</span>
                        </span>
                    </div>
                </div>
                <p class="admin-detail-desc">${esc(w.deskripsi || 'Belum ada deskripsi untuk lokasi wisata ini.')}</p>
                ${infoGridHtml}
                ${fasilitasHtml}
            </div>
        `;

        setTimeout(() => {
            if (detailMap) {
                detailMap.remove();
                detailMap = null;
            }

            if (w.latitude && w.longitude) {
                const lat = parseFloat(w.latitude);
                const lng = parseFloat(w.longitude);
                detailMap = L.map('detail-map-container', {
                    center: [lat, lng],
                    zoom: 15,
                    zoomControl: true,
                    attributionControl: false,
                });

                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    maxZoom: 19,
                    attribution: '&copy; OpenStreetMap contributors',
                }).addTo(detailMap);

                L.marker([lat, lng]).addTo(detailMap);
            }
        }, 200);
    } catch (err) {
        body.innerHTML = '<p>Gagal memuat detail.</p>';
    }
}

// ============================================================
// EDIT MODAL
// ============================================================
async function openEdit(id) {
    const modal = document.getElementById('edit-modal');
    modal.classList.add('active');
    document.getElementById('edit-title').textContent = 'Memuat...';

    try {
        const res = await fetch(`${API_BASE}/admin/wisata/${id}`);
        const json = await res.json();

        if (!json.status || !json.data) {
            showToast('Data tidak ditemukan', 'error');
            closeModal('edit-modal');
            return;
        }

        const w = json.data;
        if ((w.status || '') !== 'approved') {
            showToast('Data pending atau rejected tidak dapat diedit dari panel web.', 'error');
            closeModal('edit-modal');
            return;
        }

        document.getElementById('edit-title').textContent = `Edit: ${w.nama_tempat}`;
        document.getElementById('edit-id').value = w.id;
        document.getElementById('edit-nama').value = w.nama_tempat || '';
        document.getElementById('edit-deskripsi').value = w.deskripsi || '';
        document.getElementById('edit-kategori').value = w.kategori || '';
        document.getElementById('edit-target').value = w.target_pengunjung || '';
        document.getElementById('edit-alamat').value = w.alamat || '';
        document.getElementById('edit-jam-buka').value = w.jam_buka || '';
        document.getElementById('edit-jam-tutup').value = w.jam_tutup || '';
        setEditHariOperasional(w.hari_operasional || '');
        document.getElementById('edit-harga').value = w.harga_tiket || 0;
        document.getElementById('edit-ket-harga').value = w.keterangan_harga || '';
        document.getElementById('edit-telp').value = w.no_telepon || '';
        document.getElementById('edit-rating').value = w.rating || 0;
        document.getElementById('edit-foto-extra').value = '';
        editCurrentPhotos = Array.isArray(w.foto) ? w.foto.filter(Boolean) : [];
        editPhotoReplacements = new Map();
        renderEditPhotoManager(editCurrentPhotos);

        const fasilitas = w.fasilitas || [];
        document.getElementById('edit-toilet').checked = fasilitas.includes('Toilet');
        document.getElementById('edit-parkir').checked = fasilitas.includes('Parkir');
        document.getElementById('edit-mushola').checked = fasilitas.includes('Mushola');
        document.getElementById('edit-wifi').checked = fasilitas.includes('WiFi');
        document.getElementById('edit-tempat-makan').checked = fasilitas.includes('Tempat Makan');
        document.getElementById('edit-area-bermain').checked = fasilitas.includes('Area Bermain Anak');

        const lat = parseFloat(w.latitude) || 3.5952;
        const lng = parseFloat(w.longitude) || 98.6722;
        document.getElementById('edit-lat').value = lat;
        document.getElementById('edit-lng').value = lng;
        await applyEditWilayahFromCoordinates(lat, lng, {
            kotaNama: w.kota_kabupaten || '',
            kecamatanNama: w.kecamatan || '',
            kelurahanNama: w.kelurahan || '',
        });

        setTimeout(() => {
            if (editMap) {
                editMap.remove();
                editMap = null;
            }

            editMap = L.map('edit-map', {
                center: [lat, lng],
                zoom: 16,
                attributionControl: false,
            });

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '&copy; OpenStreetMap contributors',
            }).addTo(editMap);

            editMarker = L.marker([lat, lng], { draggable: true }).addTo(editMap);
            editMarker.on('dragend', () => {
                const pos = editMarker.getLatLng();
                updateEditCoordinatePosition(pos.lat, pos.lng, true);
            });

            editMap.on('click', e => {
                updateEditCoordinatePosition(e.latlng.lat, e.latlng.lng, true);
            });
        }, 300);
    } catch (err) {
        showToast('Gagal memuat data untuk edit', 'error');
        closeModal('edit-modal');
    }
}

async function saveEdit(event) {
    event.preventDefault();

    const placeName = document.getElementById('edit-nama').value || 'data wisata ini';
    openConfirmModal({
        title: 'Simpan Perubahan',
        message: `Simpan perubahan untuk "${placeName}"?`,
        confirmLabel: 'Simpan Perubahan',
        confirmTone: 'primary',
        onConfirm: performSaveEdit,
    });
}

async function performSaveEdit() {
    try {
        const id = document.getElementById('edit-id').value;
        const photoUrls = await collectEditedPhotoUrls();
        const payload = {
            nama_tempat: document.getElementById('edit-nama').value,
            deskripsi: document.getElementById('edit-deskripsi').value,
            kategori: document.getElementById('edit-kategori').value,
            target_pengunjung: document.getElementById('edit-target').value,
            alamat: document.getElementById('edit-alamat').value,
            kecamatan: getSelectedOptionText('edit-kecamatan'),
            kelurahan: getSelectedOptionText('edit-kelurahan'),
            jam_buka: document.getElementById('edit-jam-buka').value,
            jam_tutup: document.getElementById('edit-jam-tutup').value,
            hari_operasional: getEditHariOperasionalValue(),
            harga_tiket: parseFloat(document.getElementById('edit-harga').value) || 0,
            keterangan_harga: document.getElementById('edit-ket-harga').value,
            no_telepon: document.getElementById('edit-telp').value,
            foto: photoUrls,
            rating: parseFloat(document.getElementById('edit-rating').value) || 0,
            toilet: document.getElementById('edit-toilet').checked,
            parkir: document.getElementById('edit-parkir').checked,
            mushola: document.getElementById('edit-mushola').checked,
            wifi: document.getElementById('edit-wifi').checked,
            tempat_makan: document.getElementById('edit-tempat-makan').checked,
            area_bermain: document.getElementById('edit-area-bermain').checked,
            latitude: parseFloat(document.getElementById('edit-lat').value),
            longitude: parseFloat(document.getElementById('edit-lng').value),
        };

        const res = await fetch(`${API_BASE}/wisata/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });

        const json = await res.json();
        if (json.status) {
            showToast('Data berhasil diperbarui.', 'success');
            closeModal('edit-modal');
            loadPending();
            loadApproved();
            loadStats();
        } else {
            showToast(`Gagal: ${json.message}`, 'error');
        }
    } catch (err) {
        showToast(`Error: ${err.message}`, 'error');
    }
}

// ============================================================
// APPROVE / REJECT / DELETE
// ============================================================
async function approveWisata(id, name) {
    openConfirmModal({
        title: 'Setujui Pengajuan',
        message: `Approve wisata "${name}"?`,
        confirmLabel: 'Approve',
        confirmTone: 'success',
        onConfirm: async () => {
            try {
                const res = await fetch(`${API_BASE}/admin/wisata/${id}/approve`, {
                    method: 'PUT',
                });
                const json = await res.json();

                if (json.status) {
                    showToast(`${name} berhasil di-approve`, 'success');
                    removeCard(id);
                    loadStats();
                    loadApproved();
                    loadMobileUsers();
                } else {
                    showToast(`Gagal approve: ${json.message}`, 'error');
                }
            } catch (err) {
                showToast(`Error: ${err.message}`, 'error');
            }
        },
    });
}

async function rejectWisata(id, name) {
    openConfirmModal({
        title: 'Tolak Pengajuan',
        message: `Reject wisata "${name}" dan kirim catatan perbaikan ke pengaju.`,
        confirmLabel: 'Reject',
        confirmTone: 'danger',
        requireNote: true,
        noteLabel: 'Catatan Admin',
        notePlaceholder: 'Tulis alasan penolakan atau permintaan perbaikan...',
        onConfirm: async ({ note }) => {
            try {
                const res = await fetch(`${API_BASE}/admin/wisata/${id}/reject`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ catatan_admin: note.trim() }),
                });
                const json = await res.json();

                if (json.status) {
                    showToast(`${name} telah ditolak`, 'success');
                    removeCard(id);
                    loadStats();
                    loadMobileUsers();
                } else {
                    showToast(`Gagal reject: ${json.message}`, 'error');
                }
            } catch (err) {
                showToast(`Error: ${err.message}`, 'error');
            }
        },
    });
}

async function deleteWisata(id, name) {
    openConfirmModal({
        title: 'Hapus Data Approved',
        message: `Hapus permanen wisata "${name}"? Tindakan ini tidak bisa dibatalkan.`,
        confirmLabel: 'Hapus',
        confirmTone: 'danger',
        onConfirm: async () => {
            try {
                const res = await fetch(`${API_BASE}/wisata/${id}`, { method: 'DELETE' });
                const json = await res.json();

                if (json.status) {
                    showToast(`${name} berhasil dihapus`, 'success');
                    loadApproved();
                    loadStats();
                    loadMobileUsers();
                } else {
                    showToast(`Gagal hapus: ${json.message}`, 'error');
                }
            } catch (err) {
                showToast(`Error: ${err.message}`, 'error');
            }
        },
    });
}

function removeCard(id) {
    const card = document.getElementById(`card-${id}`);
    if (card) {
        card.style.transition = 'all 0.4s ease';
        card.style.opacity = '0';
        card.style.transform = 'translateX(40px)';
        setTimeout(() => {
            card.remove();
            const remaining = document.querySelectorAll('.pending-card').length;
            document.getElementById('tab-badge-pending').textContent = String(remaining);
            if (remaining === 0) {
                document.getElementById('pending-list').innerHTML = `
                    <div class="empty-state">
                        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                            <polyline points="22 4 12 14.01 9 11.01"></polyline>
                        </svg>
                        <p>Semua data telah divalidasi.</p>
                    </div>`;
            }
        }, 400);
    }

    if (miniMaps[id]) {
        miniMaps[id].remove();
        delete miniMaps[id];
    }
}

// ============================================================
// MODALS
// ============================================================
function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');

    if (modalId === 'edit-modal' && editMap) {
        editMap.remove();
        editMap = null;
    }

    if (modalId === 'detail-modal' && detailMap) {
        detailMap.remove();
        detailMap = null;
    }
}

document.addEventListener('click', event => {
    if (event.target.classList.contains('modal-overlay')) {
        if (event.target.id === 'confirm-modal') {
            closeConfirmModal();
            return;
        }
        closeModal(event.target.id);
    }
});

function openConfirmModal({
    title = 'Konfirmasi Aksi',
    message = '',
    confirmLabel = 'Lanjutkan',
    confirmTone = 'primary',
    requireNote = false,
    noteLabel = 'Catatan Admin',
    notePlaceholder = '',
    onConfirm = null,
}) {
    const modal = document.getElementById('confirm-modal');
    const titleEl = document.getElementById('confirm-title');
    const messageEl = document.getElementById('confirm-message');
    const noteGroupEl = document.getElementById('confirm-note-group');
    const noteInputEl = document.getElementById('confirm-note-input');
    const noteErrorEl = document.getElementById('confirm-note-error');
    const noteLabelEl = noteGroupEl?.querySelector('label');
    const submitBtn = document.getElementById('confirm-submit-btn');

    titleEl.textContent = title;
    messageEl.textContent = message;
    noteGroupEl.style.display = requireNote ? 'flex' : 'none';
    noteInputEl.value = '';
    noteInputEl.placeholder = notePlaceholder || '';
    noteLabelEl.textContent = noteLabel;
    noteErrorEl.textContent = '';
    submitBtn.textContent = confirmLabel;
    submitBtn.classList.remove('is-success', 'is-danger');
    if (confirmTone === 'success') submitBtn.classList.add('is-success');
    if (confirmTone === 'danger') submitBtn.classList.add('is-danger');

    confirmSubmitHandler = async () => {
        const note = noteInputEl.value.trim();
        if (requireNote && !note) {
            noteErrorEl.textContent = 'Catatan admin wajib diisi.';
            noteInputEl.focus();
            return;
        }

        noteErrorEl.textContent = '';
        submitBtn.disabled = true;

        try {
            if (typeof onConfirm === 'function') {
                await onConfirm({ note });
            }
            closeConfirmModal();
        } finally {
            submitBtn.disabled = false;
        }
    };

    submitBtn.onclick = () => confirmSubmitHandler?.();
    modal.classList.add('active');
    if (requireNote) {
        window.setTimeout(() => noteInputEl.focus(), 60);
    }
}

function closeConfirmModal() {
    const modal = document.getElementById('confirm-modal');
    const submitBtn = document.getElementById('confirm-submit-btn');
    const noteErrorEl = document.getElementById('confirm-note-error');
    const noteInputEl = document.getElementById('confirm-note-input');
    confirmSubmitHandler = null;
    submitBtn.onclick = null;
    submitBtn.disabled = false;
    noteErrorEl.textContent = '';
    noteInputEl.value = '';
    modal.classList.remove('active');
}

// ============================================================
// UTILS
// ============================================================
function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(40px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

function formatRupiah(numberValue) {
    return 'Rp ' + Number(numberValue).toLocaleString('id-ID');
}

function formatCompactRupiah(numberValue) {
    const value = Number(numberValue) || 0;
    if (value >= 1000000) {
        return `Rp ${(value / 1000000).toFixed(value % 1000000 === 0 ? 0 : 1).replace('.', ',')} jt`;
    }
    if (value >= 1000) {
        return `Rp ${(value / 1000).toFixed(value % 1000 === 0 ? 0 : 1).replace('.', ',')} rb`;
    }
    return `Rp ${value}`;
}

function syncApprovedLayout() {
    const mediaQuery = window.matchMedia('(max-width: 1024px)');
    const directorySection = document.querySelector('.admin-directory-section');
    const approvedShell = document.querySelector('.approved-data-shell');
    const tableWrapper = document.querySelector('.approved-data-shell .table-wrapper');
    const sectionHead = approvedShell?.querySelector('.section-head');
    const toolbar = approvedShell?.querySelector('.approved-toolbar');

    if (!directorySection || !approvedShell || !tableWrapper || !sectionHead || !toolbar) {
        return;
    }

    if (mediaQuery.matches) {
        approvedShell.style.height = '';
        tableWrapper.style.maxHeight = '';
        return;
    }

    const leftHeight = directorySection.offsetHeight;
    if (!leftHeight) {
        return;
    }

    approvedShell.style.height = `${leftHeight}px`;
    const shellStyles = window.getComputedStyle(approvedShell);
    const verticalPadding = (Number.parseFloat(shellStyles.paddingTop) || 0) + (Number.parseFloat(shellStyles.paddingBottom) || 0);
    const availableTableHeight = leftHeight - sectionHead.offsetHeight - toolbar.offsetHeight - verticalPadding - 12;
    tableWrapper.style.maxHeight = `${Math.max(220, availableTableHeight)}px`;
}

function formatSubmitter(w) {
    const nama = (w.submitter_nama || '').trim();
    const noPegawai = (w.submitter_no_pegawai || '').trim();
    const userId = (w.submitter_user_id || '').trim();

    if (nama && noPegawai) return `${esc(nama)} (${esc(noPegawai)})`;
    if (nama) return esc(nama);
    if (noPegawai) return esc(noPegawai);
    if (userId) return esc(userId);
    return '-';
}

function renderSubmitterProfile(w) {
    const hasProfileData =
        (w.submitter_nama || '').trim() ||
        (w.submitter_no_pegawai || '').trim() ||
        (w.submitter_foto_profil || '').trim();

    if (!hasProfileData) {
        return '';
    }

    return `
        <div class="submitter-profile-card">
            <div class="submitter-profile-avatar">
                ${renderAvatar(w.submitter_foto_profil, w.submitter_nama || w.submitter_no_pegawai || 'A')}
            </div>
                <div class="submitter-profile-meta">
                    <div class="submitter-profile-eyebrow">Akun Pengaju</div>
                    <div class="submitter-profile-name">${formatSubmitter(w)}</div>
                </div>
            </div>
        `;
}

function renderAvatar(url, label) {
    const safeLabel = esc(label || 'A');
    const initials = esc(getInitials(label || 'A'));

    if ((url || '').trim()) {
        return `<img src="${esc(url)}" alt="${safeLabel}" onerror="this.parentElement.innerHTML='${initials}'">`;
    }

    return initials;
}

function getInitials(value) {
    const text = String(value || '').trim();
    if (!text) return 'A';

    return text
        .split(/\s+/)
        .slice(0, 2)
        .map(part => part.charAt(0).toUpperCase())
        .join('');
}

function esc(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function escAttr(text) {
    return String(text || '')
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}
