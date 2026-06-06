const MANAGE_API_BASE = `${window.location.origin}/api`;

let allManageLocations = [];
let manageDetailMap = null;
let manageEditMap = null;
let manageEditMarker = null;

document.addEventListener('DOMContentLoaded', () => {
    initManagePage().catch((error) => {
        console.error('Error initializing manage locations page:', error);
        renderManageEmpty('Gagal memuat data approved.');
    });
});

async function initManagePage() {
    initManageControls();
    initManageModalHandlers();
    await Promise.all([
        loadManageCategories(),
        loadManageLocations(),
    ]);
}

function initManageControls() {
    document.getElementById('manage-search')?.addEventListener('input', applyManageFilters);
    document.getElementById('manage-category')?.addEventListener('change', applyManageFilters);
    document.getElementById('manage-sort')?.addEventListener('change', applyManageFilters);
}

function initManageModalHandlers() {
    document.addEventListener('click', event => {
        if (event.target.classList.contains('modal-overlay')) {
            closeManageModal(event.target.id);
        }
    });
}

async function loadManageCategories() {
    const select = document.getElementById('manage-category');
    if (!select) return;

    try {
        const response = await fetch(`${MANAGE_API_BASE}/kategori`);
        const json = await response.json();
        const categories = json?.data || [];

        select.innerHTML = '<option value="">Semua Kategori</option>';
        categories.forEach(category => {
            const option = document.createElement('option');
            option.value = category.nama_kategori;
            option.textContent = category.nama_kategori;
            select.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading categories:', error);
    }
}

async function loadManageLocations() {
    const response = await fetch(`${MANAGE_API_BASE}/wisata`);
    const json = await response.json();
    allManageLocations = json?.data || [];
    updateManageStats(allManageLocations);
    applyManageFilters();
}

function updateManageStats(locations) {
    const total = locations.length;
    const categoryCount = new Set(
        locations.map(item => String(item.kategori || '').trim()).filter(Boolean)
    ).size;
    const ratingValues = locations
        .map(item => Number.parseFloat(item.rating) || 0)
        .filter(value => value > 0);
    const ratingAvg = ratingValues.length
        ? (ratingValues.reduce((sum, value) => sum + value, 0) / ratingValues.length).toFixed(1)
        : '0.0';

    setManageText('manage-stat-total', total);
    setManageText('manage-stat-kategori', categoryCount);
    setManageText('manage-stat-rating', ratingAvg);
}

function applyManageFilters() {
    const query = String(document.getElementById('manage-search')?.value || '').toLowerCase().trim();
    const category = document.getElementById('manage-category')?.value || '';
    const sort = document.getElementById('manage-sort')?.value || 'latest';

    let filtered = [...allManageLocations];

    if (query) {
        filtered = filtered.filter(item =>
            String(item.nama_tempat || '').toLowerCase().includes(query)
            || String(item.alamat || '').toLowerCase().includes(query)
            || String(item.kecamatan || '').toLowerCase().includes(query)
            || String(item.kelurahan || '').toLowerCase().includes(query)
        );
    }

    if (category) {
        filtered = filtered.filter(item => String(item.kategori || '') === category);
    }

    if (sort === 'name') {
        filtered.sort((a, b) => String(a.nama_tempat || '').localeCompare(String(b.nama_tempat || ''), 'id'));
    } else if (sort === 'rating') {
        filtered.sort((a, b) => (Number.parseFloat(b.rating) || 0) - (Number.parseFloat(a.rating) || 0));
    } else {
        filtered.sort((a, b) => Number(b.id || 0) - Number(a.id || 0));
    }

    renderManageRows(filtered);
}

function renderManageRows(locations) {
    const tbody = document.getElementById('manage-locations-body');
    if (!tbody) return;

    if (!locations.length) {
        renderManageEmpty('Tidak ada data yang cocok dengan filter saat ini.');
        return;
    }

    tbody.innerHTML = locations.map(location => `
        <tr>
            <td>
                <div class="table-name-cell">
                    <div class="table-avatar">
                        ${getManagePhoto(location)
                            ? `<img src="${escapeManage(getManagePhoto(location))}" alt="${escapeManage(location.nama_tempat || 'Wisata')}">`
                            : ''}
                    </div>
                    <div>
                        <div style="font-weight:700; color:var(--tm-primary);">${escapeManage(location.nama_tempat || 'Tanpa Nama')}</div>
                        <div style="font-size:0.8rem; color:var(--text-muted); margin-top:4px;">${escapeManage(location.kelurahan || '-')}</div>
                    </div>
                </div>
            </td>
            <td>${escapeManage(location.alamat || '-')}</td>
            <td>${escapeManage(location.kecamatan || '-')}</td>
            <td style="font-family:Consolas, monospace; font-size:0.8rem;">
                ${escapeManage(formatCoordinate(location.latitude))}, ${escapeManage(formatCoordinate(location.longitude))}
            </td>
            <td><span class="tm-chip">${escapeManage(location.kategori || 'Tanpa Kategori')}</span></td>
            <td>${Number.parseFloat(location.rating) > 0 ? Number.parseFloat(location.rating).toFixed(1) : 'Belum ada'}</td>
            <td>
                <div class="table-actions">
                    <button class="table-btn" onclick="showManageDetail(${location.id})">Detail</button>
                    <button class="table-btn primary" onclick="openManageEdit(${location.id})">Edit</button>
                    <button class="table-btn danger" onclick="deleteManageLocation(${location.id}, '${escapeManageAttr(location.nama_tempat || '')}')">Hapus</button>
                </div>
            </td>
        </tr>
    `).join('');
}

function renderManageEmpty(message) {
    const tbody = document.getElementById('manage-locations-body');
    if (!tbody) return;

    tbody.innerHTML = `
        <tr>
            <td colspan="7">
                <div class="empty-panel">${escapeManage(message)}</div>
            </td>
        </tr>
    `;
}

async function showManageDetail(id) {
    const modal = document.getElementById('detail-modal');
    const body = document.getElementById('detail-body');
    body.innerHTML = '<div class="loading"><div class="spinner"></div><p>Memuat detail...</p></div>';
    modal.classList.add('active');

    try {
        const response = await fetch(`${MANAGE_API_BASE}/admin/wisata/${id}`);
        const json = await response.json();

        if (!json?.status || !json?.data) {
            body.innerHTML = '<div class="empty-panel">Data tidak ditemukan.</div>';
            return;
        }

        const wisata = json.data;
        document.getElementById('detail-title').textContent = wisata.nama_tempat || 'Detail Wisata';
        body.innerHTML = buildManageDetailBody(wisata);

        setTimeout(() => {
            if (manageDetailMap) {
                manageDetailMap.remove();
                manageDetailMap = null;
            }

            if (wisata.latitude && wisata.longitude) {
                manageDetailMap = L.map('manage-detail-map', {
                    center: [parseFloat(wisata.latitude), parseFloat(wisata.longitude)],
                    zoom: 15,
                    zoomControl: true,
                    attributionControl: false,
                });

                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    maxZoom: 19,
                    attribution: '&copy; OpenStreetMap contributors',
                }).addTo(manageDetailMap);

                L.marker([parseFloat(wisata.latitude), parseFloat(wisata.longitude)]).addTo(manageDetailMap);
            }
        }, 120);
    } catch (error) {
        console.error('Error loading detail:', error);
        body.innerHTML = '<div class="empty-panel">Gagal memuat detail wisata.</div>';
    }
}

function buildManageDetailBody(wisata) {
    const photos = normalizeManagePhotos(wisata.foto);
    const facilities = ['Toilet', 'Parkir', 'Area Bermain Anak', 'Tempat Makan', 'Mushola', 'WiFi'];
    const activeFacilities = wisata.fasilitas || [];

    const gallery = photos.length
        ? `<div class="detail-gallery">${photos.map(photo => `<img class="detail-foto" src="${escapeManage(photo)}" alt="${escapeManage(wisata.nama_tempat || 'Foto wisata')}" onerror="this.style.display='none'">`).join('')}</div>`
        : '<div class="empty-panel">Belum ada foto tambahan.</div>';

    return `
        ${gallery}
        <div style="display:flex; flex-wrap:wrap; gap:10px; margin-top:16px;">
            <a href="/wisata/detail/${wisata.id}" class="tm-btn tm-btn-secondary" style="text-decoration:none;">Lihat Halaman Publik</a>
            <a href="/peta?focus=${wisata.id}&view=detail" class="tm-btn tm-btn-ghost" style="text-decoration:none;">Buka di Peta Publik</a>
        </div>
        <div class="detail-grid" style="margin-top:16px;">
            <div class="detail-item full"><label>Deskripsi</label><span>${escapeManage(wisata.deskripsi || '-')}</span></div>
            <div class="detail-item"><label>Kategori</label><span>${escapeManage(wisata.kategori || '-')}</span></div>
            <div class="detail-item"><label>Target Pengunjung</label><span>${escapeManage(wisata.target_pengunjung || '-')}</span></div>
            <div class="detail-item full"><label>Alamat</label><span>${escapeManage(wisata.alamat || '-')}</span></div>
            <div class="detail-item"><label>Kecamatan</label><span>${escapeManage(wisata.kecamatan || '-')}</span></div>
            <div class="detail-item"><label>Kelurahan</label><span>${escapeManage(wisata.kelurahan || '-')}</span></div>
            <div class="detail-item"><label>Jam Operasional</label><span>${escapeManage(wisata.jam_buka || '-')} - ${escapeManage(wisata.jam_tutup || '-')}</span></div>
            <div class="detail-item"><label>Hari Operasional</label><span>${escapeManage(wisata.hari_operasional || '-')}</span></div>
            <div class="detail-item"><label>Harga Tiket</label><span>${Number(wisata.harga_tiket) > 0 ? formatManageRupiah(wisata.harga_tiket) : 'Gratis'}</span></div>
            <div class="detail-item"><label>No. Telepon</label><span>${escapeManage(wisata.no_telepon || '-')}</span></div>
            <div class="detail-item"><label>Rating</label><span>${Number.parseFloat(wisata.rating) > 0 ? Number.parseFloat(wisata.rating).toFixed(1) : 'Belum ada'}</span></div>
            <div class="detail-item"><label>Koordinat</label><span style="font-family:Consolas, monospace;">${escapeManage(formatCoordinate(wisata.latitude))}, ${escapeManage(formatCoordinate(wisata.longitude))}</span></div>
            <div class="detail-item full">
                <label>Fasilitas</label>
                <div style="display:flex; flex-wrap:wrap; gap:8px; margin-top:8px;">
                    ${facilities.map(label => {
                        const active = activeFacilities.includes(label);
                        return `<span class="tm-chip" style="opacity:${active ? '1' : '0.55'};">${active ? '&#10003;' : '&#10005;'} ${escapeManage(label)}</span>`;
                    }).join('')}
                </div>
            </div>
        </div>
        <div id="manage-detail-map" class="detail-map-preview"></div>
    `;
}

async function openManageEdit(id) {
    const modal = document.getElementById('edit-modal');
    modal.classList.add('active');

    try {
        const response = await fetch(`${MANAGE_API_BASE}/admin/wisata/${id}`);
        const json = await response.json();

        if (!json?.status || !json?.data) {
            showManageToast('Data tidak ditemukan', 'error');
            closeManageModal('edit-modal');
            return;
        }

        const wisata = json.data;
        fillManageEditForm(wisata);

        setTimeout(() => {
            initManageEditMap(parseFloat(wisata.latitude), parseFloat(wisata.longitude));
        }, 120);
    } catch (error) {
        console.error('Error opening edit modal:', error);
        showManageToast('Gagal memuat data untuk diedit', 'error');
        closeManageModal('edit-modal');
    }
}

function fillManageEditForm(wisata) {
    document.getElementById('edit-id').value = wisata.id || '';
    document.getElementById('edit-title').textContent = `Edit: ${wisata.nama_tempat || 'Wisata'}`;
    document.getElementById('edit-nama').value = wisata.nama_tempat || '';
    document.getElementById('edit-deskripsi').value = wisata.deskripsi || '';
    document.getElementById('edit-kategori').value = wisata.kategori || '';
    document.getElementById('edit-target').value = wisata.target_pengunjung || '';
    document.getElementById('edit-alamat').value = wisata.alamat || '';
    document.getElementById('edit-kecamatan').value = wisata.kecamatan || '';
    document.getElementById('edit-kelurahan').value = wisata.kelurahan || '';
    document.getElementById('edit-jam-buka').value = wisata.jam_buka || '';
    document.getElementById('edit-jam-tutup').value = wisata.jam_tutup || '';
    document.getElementById('edit-hari').value = wisata.hari_operasional || '';
    document.getElementById('edit-harga').value = Number(wisata.harga_tiket || 0);
    document.getElementById('edit-ket-harga').value = wisata.keterangan_harga || '';
    document.getElementById('edit-telp').value = wisata.no_telepon || '';
    document.getElementById('edit-foto').value = normalizeManagePhotos(wisata.foto).join(', ');
    document.getElementById('edit-rating').value = wisata.rating || 0;
    document.getElementById('edit-lat').value = formatCoordinate(wisata.latitude, 6);
    document.getElementById('edit-lng').value = formatCoordinate(wisata.longitude, 6);

    const activeFacilities = wisata.fasilitas || [];
    document.getElementById('edit-toilet').checked = activeFacilities.includes('Toilet') || Boolean(wisata.toilet);
    document.getElementById('edit-parkir').checked = activeFacilities.includes('Parkir') || Boolean(wisata.parkir);
    document.getElementById('edit-mushola').checked = activeFacilities.includes('Mushola') || Boolean(wisata.mushola);
    document.getElementById('edit-wifi').checked = activeFacilities.includes('WiFi') || Boolean(wisata.wifi);
    document.getElementById('edit-tempat-makan').checked = activeFacilities.includes('Tempat Makan') || Boolean(wisata.tempat_makan);
    document.getElementById('edit-area-bermain').checked = activeFacilities.includes('Area Bermain Anak') || Boolean(wisata.area_bermain);
}

function initManageEditMap(lat, lng) {
    const safeLat = Number.isFinite(lat) ? lat : 3.5952;
    const safeLng = Number.isFinite(lng) ? lng : 98.6722;

    if (manageEditMap) {
        manageEditMap.remove();
        manageEditMap = null;
    }

    manageEditMap = L.map('edit-map', {
        center: [safeLat, safeLng],
        zoom: 16,
        attributionControl: false,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
    }).addTo(manageEditMap);

    manageEditMarker = L.marker([safeLat, safeLng], { draggable: true }).addTo(manageEditMap);
    manageEditMarker.on('dragend', () => {
        const position = manageEditMarker.getLatLng();
        document.getElementById('edit-lat').value = position.lat.toFixed(6);
        document.getElementById('edit-lng').value = position.lng.toFixed(6);
    });

    manageEditMap.on('click', event => {
        manageEditMarker.setLatLng(event.latlng);
        document.getElementById('edit-lat').value = event.latlng.lat.toFixed(6);
        document.getElementById('edit-lng').value = event.latlng.lng.toFixed(6);
    });
}

async function saveManageEdit(event) {
    event.preventDefault();

    const id = document.getElementById('edit-id').value;
    const payload = {
        nama_tempat: document.getElementById('edit-nama').value,
        deskripsi: document.getElementById('edit-deskripsi').value,
        kategori: document.getElementById('edit-kategori').value,
        target_pengunjung: document.getElementById('edit-target').value,
        alamat: document.getElementById('edit-alamat').value,
        kecamatan: document.getElementById('edit-kecamatan').value,
        kelurahan: document.getElementById('edit-kelurahan').value,
        jam_buka: document.getElementById('edit-jam-buka').value,
        jam_tutup: document.getElementById('edit-jam-tutup').value,
        hari_operasional: document.getElementById('edit-hari').value,
        harga_tiket: parseFloat(document.getElementById('edit-harga').value) || 0,
        keterangan_harga: document.getElementById('edit-ket-harga').value,
        no_telepon: document.getElementById('edit-telp').value,
        foto: document.getElementById('edit-foto').value,
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

    try {
        const response = await fetch(`${MANAGE_API_BASE}/wisata/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });

        const json = await response.json();
        if (json?.status) {
            showManageToast('Data wisata berhasil diperbarui', 'success');
            closeManageModal('edit-modal');
            await loadManageLocations();
        } else {
            showManageToast(`Gagal: ${json?.message || 'Terjadi kesalahan'}`, 'error');
        }
    } catch (error) {
        console.error('Error saving edit:', error);
        showManageToast('Gagal menyimpan perubahan', 'error');
    }
}

async function deleteManageLocation(id, name) {
    if (!confirm(`Hapus permanen wisata "${name}"?`)) {
        return;
    }

    try {
        const response = await fetch(`${MANAGE_API_BASE}/wisata/${id}`, { method: 'DELETE' });
        const json = await response.json();

        if (json?.status) {
            showManageToast(`"${name}" berhasil dihapus`, 'success');
            await loadManageLocations();
        } else {
            showManageToast(`Gagal hapus: ${json?.message || 'Terjadi kesalahan'}`, 'error');
        }
    } catch (error) {
        console.error('Error deleting location:', error);
        showManageToast('Gagal menghapus data wisata', 'error');
    }
}

function closeManageModal(modalId) {
    document.getElementById(modalId)?.classList.remove('active');

    if (modalId === 'detail-modal' && manageDetailMap) {
        manageDetailMap.remove();
        manageDetailMap = null;
    }

    if (modalId === 'edit-modal' && manageEditMap) {
        manageEditMap.remove();
        manageEditMap = null;
        manageEditMarker = null;
    }
}

function showManageToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(30px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 2800);
}

function getManagePhoto(location) {
    if (Array.isArray(location?.foto) && location.foto.length > 0) {
        return location.foto[0];
    }

    if (typeof location?.foto === 'string' && location.foto.trim()) {
        return location.foto.trim();
    }

    return '';
}

function normalizeManagePhotos(raw) {
    if (Array.isArray(raw)) {
        return raw.filter(Boolean);
    }

    if (typeof raw === 'string' && raw.trim()) {
        return raw
            .split(',')
            .map(item => item.trim())
            .filter(Boolean);
    }

    return [];
}

function setManageText(id, value) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = String(value);
    }
}

function formatManageRupiah(value) {
    return `Rp ${Number(value).toLocaleString('id-ID')}`;
}

function formatCoordinate(value, decimals = 4) {
    const number = Number.parseFloat(value);
    return Number.isFinite(number) ? number.toFixed(decimals) : '-';
}

function escapeManage(value) {
    const div = document.createElement('div');
    div.textContent = value ?? '';
    return div.innerHTML;
}

function escapeManageAttr(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}
