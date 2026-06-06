/**
 * ============================================================
 * SIG WISATA KOTA MEDAN — Web GIS JavaScript
 * Leaflet.js map with dynamic markers, filtering, and detail modal
 * ============================================================
 */

// ============================================================
// CONFIG
// ============================================================
const API_BASE = window.location.origin + '/api';
const LAYER_ENDPOINTS = {
    boundaryMedan: `${API_BASE}/boundaries/medan`,
    boundaryDeliSerdang: `${API_BASE}/boundaries/deli-serdang`,
    wilayahList: `${API_BASE}/wilayah`,
    wilayahKecamatan: `${API_BASE}/wilayah/kecamatan`,
    wilayahKelurahan: `${API_BASE}/wilayah/kelurahan`,
    wilayahChildren: (id) => `${API_BASE}/wilayah/children/${id}`,
    wilayahDetail: (id) => `${API_BASE}/wilayah/${id}`,
    roadsByWilayah: (id) => `${API_BASE}/roads/by-wilayah/${id}`,
    kecamatanList: `${API_BASE}/kecamatan`,
    kecamatanGeoJson: `${API_BASE}/kecamatan/geojson`,
    kecamatanDetail: (id) => `${API_BASE}/kecamatan/${id}`,
    roadsByKecamatan: (id) => `${API_BASE}/roads/by-kecamatan/${id}`,
};

// Medan city center coordinates
const MEDAN_CENTER = [3.5952, 98.6722];
const DEFAULT_ZOOM = 12;

// Category color mapping for markers
const CATEGORY_COLORS = {
    'Taman': '#10b981',
    'Waterpark': '#06b6d4',
    'Kebun Binatang': '#8b5cf6',
    'Museum': '#f59e0b',
    'Taman Bermain': '#ef4444',
    'Danau': '#3b82f6',
    'Kuliner': '#ec4899',
    'Religi': '#14b8a6',
};

const pageQuery = new URLSearchParams(window.location.search);
const initialFocusWisataId = Number.parseInt(pageQuery.get('focus') || '', 10) || null;
const initialFocusView = pageQuery.get('view') || 'popup';
const initialCategory = pageQuery.get('category') || '';

// ============================================================
// STATE
// ============================================================
let map;
let markersLayer;
const markerIndexByWisataId = new Map();
let lightBaseLayer = null;
let darkBaseLayer = null;
let allWisata = [];
let allKategori = [];
let userMarker = null;
let routingControl = null;
let layerControl = null;
let availableTopLevelWilayah = [];
let selectedKecamatanId = null;
let selectedTopLevelWilayahId = null;
let selectedLeafWilayahId = null;
let availableKecamatan = [];
let availableLeafWilayah = [];
let showAllKecamatan = false;
let showAllLeafWilayah = false;
let showRoadsByKecamatan = false;
const geoLayerDefinitions = {};
const geoLayerState = {};
let selectedRoadRefreshTimer = null;
let initialQueryHandled = false;
let activeModalGalleryPhotos = [];
let activeModalGalleryIndex = 0;

// ============================================================
// INITIALIZATION
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
    initMap();
    initGeoSpatialLayers();
    loadTopLevelWilayahOptions();
    loadKategori();
    loadWisata();
    initEventListeners();
});

/**
 * Initialize Leaflet map
 */
function initMap() {
    map = L.map('map', {
        center: MEDAN_CENTER,
        zoom: DEFAULT_ZOOM,
        zoomControl: false,
        attributionControl: true,
        preferCanvas: true,
    });

    L.control.zoom({ position: 'bottomright' }).addTo(map);

    map.createPane('boundaryDeliPane');
    map.getPane('boundaryDeliPane').style.zIndex = 345;

    map.createPane('boundaryMedanPane');
    map.getPane('boundaryMedanPane').style.zIndex = 355;

    map.createPane('boundariesPane');
    map.getPane('boundariesPane').style.zIndex = 350;

    map.createPane('roadsPane');
    map.getPane('roadsPane').style.zIndex = 360;

    lightBaseLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    });
    darkBaseLayer = L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        maxZoom: 19,
        subdomains: 'abcd',
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; CARTO',
    });

    // Theme toggle handler
    const savedDark = localStorage.getItem('terra-dark-mode') === 'true';
    let isDarkMode = savedDark;
    if (isDarkMode) document.body.classList.add('dark');
    syncMapTheme(isDarkMode);

    const toggleThemeBtn = document.getElementById('btn-dark-mode-beranda');
    if (toggleThemeBtn) {
        toggleThemeBtn.addEventListener('click', () => {
            isDarkMode = !isDarkMode;
            document.body.classList.toggle('dark', isDarkMode);
            localStorage.setItem('terra-dark-mode', isDarkMode);
            syncMapTheme(isDarkMode);
            
            // Sync icons
            const d = document.getElementById('beranda-icon-dark');
            const l = document.getElementById('beranda-icon-light');
            if (d) d.style.display = isDarkMode ? 'none' : 'block';
            if (l) l.style.display = isDarkMode ? 'block' : 'none';
        });
    }

    // MarkerCluster group
    markersLayer = L.markerClusterGroup({
        maxClusterRadius: 50,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: false,
        iconCreateFunction: function (cluster) {
            const count = cluster.getChildCount();
            return L.divIcon({
                html: `<div class="cluster-icon">${count}</div>`,
                className: 'custom-cluster',
                iconSize: L.point(44, 44),
            });
        },
    });

    map.addLayer(markersLayer);

    // Add cluster CSS dynamically
    const style = document.createElement('style');
    style.textContent = `
        .custom-cluster .cluster-icon {
            width: 44px;
            height: 44px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #10b981, #06b6d4);
            color: white;
            font-family: 'Inter', sans-serif;
            font-size: 14px;
            font-weight: 700;
            border-radius: 50%;
            box-shadow: 0 4px 15px rgba(16, 185, 129, 0.4);
            border: 3px solid rgba(255, 255, 255, 0.2);
        }
    `;
    document.head.appendChild(style);
}

function syncMapTheme(isDarkMode) {
    if (!map || !lightBaseLayer || !darkBaseLayer) {
        return;
    }

    const desiredLayer = isDarkMode ? darkBaseLayer : lightBaseLayer;
    const otherLayer = isDarkMode ? lightBaseLayer : darkBaseLayer;

    if (map.hasLayer(otherLayer)) {
        map.removeLayer(otherLayer);
    }

    if (!map.hasLayer(desiredLayer)) {
        desiredLayer.addTo(map);
    }
}

function initGeoSpatialLayers() {
    const definitions = [
        {
            key: 'allKecamatan',
            style: {
                color: '#0f766e',
                weight: 2,
                opacity: 0.85,
                fillColor: '#14b8a6',
                fillOpacity: 0.05,
                pane: 'boundariesPane',
            },
        },
        {
            key: 'selectedKecamatan',
            style: {
                color: '#dc2626',
                weight: 4.5,
                opacity: 0.98,
                fillColor: '#dc2626',
                fillOpacity: 0.12,
                pane: 'boundariesPane',
            },
        },
        {
            key: 'allLeafWilayah',
            style: {
                color: '#7c3aed',
                weight: 1.8,
                opacity: 0.86,
                fillColor: '#a78bfa',
                fillOpacity: 0.05,
                pane: 'boundariesPane',
            },
        },
        {
            key: 'roadsByKecamatan',
            style: {
                color: '#1d4ed8',
                weight: 1.5,
                opacity: 0.82,
                pane: 'roadsPane',
            },
        },
        {
            key: 'boundaryMedan',
            label: 'Batas Kota Medan',
            url: LAYER_ENDPOINTS.boundaryMedan,
            style: {
                color: '#f59e0b',
                weight: 4.5,
                opacity: 0.98,
                fillColor: '#f59e0b',
                fillOpacity: 0.1,
                pane: 'boundaryMedanPane',
            },
            popupLabel: 'Kota Medan',
        },
        {
            key: 'boundaryDeliSerdang',
            label: 'Batas Deli Serdang',
            url: LAYER_ENDPOINTS.boundaryDeliSerdang,
            style: {
                color: '#10b981',
                weight: 4,
                opacity: 0.92,
                fillColor: '#10b981',
                fillOpacity: 0.035,
                dashArray: '10 7',
                pane: 'boundaryDeliPane',
            },
            popupLabel: 'Kabupaten Deli Serdang',
        },
    ];

    const overlays = {};

    definitions.forEach(def => {
        geoLayerDefinitions[def.key] = def;
        geoLayerState[def.key] = {
            loaded: false,
            loading: false,
            error: null,
            requestId: 0,
            lastSelectionKey: null,
            layer: L.geoJSON(null, {
                style: (feature) => {
                    if (def.key === 'allKecamatan') {
                        const wilayah = feature?.properties?.wilayah;
                        return wilayah === 'medan'
                            ? {
                                ...def.style,
                                color: '#f59e0b',
                                fillColor: '#f59e0b',
                              }
                            : {
                                ...def.style,
                                color: '#10b981',
                                fillColor: '#10b981',
                              };
                    }

                    if (def.key === 'allLeafWilayah') {
                        return {
                            ...def.style,
                            color: '#7c3aed',
                            fillColor: '#a78bfa',
                        };
                    }

                    return def.style;
                },
                onEachFeature: def.popupLabel
                    ? (_, layer) => layer.bindPopup(`<strong>${def.popupLabel}</strong>`)
                    : (feature, layer) => {
                        if (['allKecamatan', 'selectedKecamatan', 'allLeafWilayah'].includes(def.key)) {
                            layer.bindPopup(formatWilayahPopup(feature?.properties || {}));
                        }
                    },
            }),
        };

        if (def.key === 'boundaryMedan' || def.key === 'boundaryDeliSerdang') {
            overlays[def.label] = geoLayerState[def.key].layer;
        }
    });

    layerControl = L.control.layers(null, overlays, {
        collapsed: false,
        position: 'topright',
    }).addTo(map);
    enhanceLayerControlPanel();

    map.on('overlayadd', async (event) => {
        const layerKey = findGeoLayerKey(event.layer);
        if (layerKey) {
            await refreshDynamicLayer(layerKey, true);
            syncBoundaryVisualOrder();
        }
    });

    map.on('overlayremove', (event) => {
        const layerKey = findGeoLayerKey(event.layer);
        if (!layerKey) {
            return;
        }

        if (layerKey === 'allKecamatan') {
            showAllKecamatan = false;
            const toggle = document.getElementById('toggle-all-kecamatan');
            if (toggle) toggle.checked = false;
        }

        if (layerKey === 'allLeafWilayah') {
            showAllLeafWilayah = false;
            const toggle = document.getElementById('toggle-all-leaf-wilayah');
            if (toggle) toggle.checked = false;
        }

        if (layerKey === 'roadsByKecamatan') {
            showRoadsByKecamatan = false;
            const toggle = document.getElementById('toggle-roads-kecamatan');
            if (toggle) toggle.checked = false;
        }
    });

    map.on('zoomend', scheduleSelectedRoadRefresh);

    syncBoundaryLayers();
}

function findGeoLayerKey(layerInstance) {
    for (const [key, state] of Object.entries(geoLayerState)) {
        if (state.layer === layerInstance) {
            return key;
        }
    }
    return null;
}

function syncBoundaryVisualOrder() {
    const deliLayer = geoLayerState.boundaryDeliSerdang?.layer;
    const medanLayer = geoLayerState.boundaryMedan?.layer;

    if (deliLayer && map.hasLayer(deliLayer)) {
        deliLayer.bringToBack();
    }

    if (medanLayer && map.hasLayer(medanLayer)) {
        medanLayer.bringToFront();
    }
}

function enhanceLayerControlPanel() {
    const container = layerControl?.getContainer?.();
    if (!container || container.dataset.enhanced === 'true') {
        return;
    }

    const list = container.querySelector('.leaflet-control-layers-list');
    if (!list) {
        return;
    }

    container.dataset.enhanced = 'true';
    container.classList.add('webgis-legend-control');
    container.classList.add('is-collapsed');

    const header = document.createElement('button');
    header.type = 'button';
    header.className = 'legend-control-toggle';
    header.setAttribute('aria-expanded', 'false');
    header.innerHTML = `
        <span class="legend-control-title">Legenda Peta</span>
        <span class="legend-control-chevron" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"></polyline>
            </svg>
        </span>
    `;

    const legendSection = document.createElement('div');
    legendSection.className = 'map-legend-section';
    legendSection.innerHTML = `
        <div class="map-legend-group">
            <div class="map-legend-heading">Boundary</div>
            <div class="map-legend-item">
                <span class="legend-swatch legend-line legend-medan"></span>
                <span>Batas Kota Medan</span>
            </div>
            <div class="map-legend-item">
                <span class="legend-swatch legend-line legend-deli"></span>
                <span>Batas Deli Serdang</span>
            </div>
        </div>
        <div class="map-legend-group">
            <div class="map-legend-heading">Layer Jalan & Rute</div>
            <div class="map-legend-item">
                <span class="legend-swatch legend-line legend-road"></span>
                <span>Jalan wilayah aktif</span>
            </div>
            <div class="map-legend-item">
                <span class="legend-swatch legend-line legend-route"></span>
                <span>Rute navigasi</span>
            </div>
        </div>
        <div class="map-legend-group">
            <div class="map-legend-heading">Marker</div>
            <div class="map-legend-item">
                <span class="legend-swatch legend-marker legend-wisata"></span>
                <span>Marker wisata</span>
            </div>
            <div class="map-legend-item">
                <span class="legend-swatch legend-marker legend-user"></span>
                <span>Posisi pengguna</span>
            </div>
        </div>
    `;

    list.appendChild(legendSection);
    container.insertBefore(header, list);

    header.addEventListener('click', () => {
        const isCollapsed = container.classList.toggle('is-collapsed');
        header.setAttribute('aria-expanded', isCollapsed ? 'false' : 'true');
    });
}

async function ensureGeoLayerLoaded(layerKey) {
    const layerState = geoLayerState[layerKey];
    const definition = geoLayerDefinitions[layerKey];

    if (!layerState || !definition || layerState.loaded || layerState.loading) {
        return;
    }

    layerState.loading = true;

    try {
        const res = await fetch(definition.url, {
            headers: { 'Accept': 'application/geo+json, application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const geojson = await res.json();
        if (geojson.type !== 'FeatureCollection') {
            throw new Error('Response bukan GeoJSON FeatureCollection.');
        }

        layerState.layer.clearLayers();
        layerState.layer.addData(geojson);
        layerState.loaded = true;
        layerState.error = null;
        syncBoundaryVisualOrder();
    } catch (err) {
        layerState.error = err;
        if (map.hasLayer(layerState.layer)) {
            map.removeLayer(layerState.layer);
        }
        console.error(`Error loading layer ${layerKey}:`, err);
    } finally {
        layerState.loading = false;
    }
}

async function refreshDynamicLayer(layerKey, force = false) {
    if (layerKey === 'allKecamatan') {
        await loadAllKecamatanPolygons(force);
        return;
    }

    if (layerKey === 'selectedKecamatan') {
        await loadSelectedKecamatanPolygon(force);
        return;
    }

    if (layerKey === 'roadsByKecamatan') {
        await loadSelectedKecamatanRoads(force);
        return;
    }

    await ensureGeoLayerLoaded(layerKey);
}

function clearDynamicLayer(layerKey) {
    const layerState = geoLayerState[layerKey];
    if (!layerState) {
        return;
    }

    layerState.layer.clearLayers();
    layerState.loaded = false;
    layerState.loading = false;
    layerState.error = null;
    layerState.lastSelectionKey = null;
}

function scheduleSelectedRoadRefresh() {
    if (selectedRoadRefreshTimer) {
        clearTimeout(selectedRoadRefreshTimer);
    }

    selectedRoadRefreshTimer = setTimeout(() => {
        const roadLayerState = geoLayerState.roadsByKecamatan;
        if (roadLayerState && map.hasLayer(roadLayerState.layer)) {
            loadSelectedKecamatanRoads();
        }
    }, 180);
}

function getSelectedTopLevelWilayah() {
    return availableTopLevelWilayah.find((item) => Number(item.id) === selectedTopLevelWilayahId) || null;
}

function getActiveWilayahId() {
    return selectedLeafWilayahId || selectedKecamatanId || selectedTopLevelWilayahId || null;
}

function getActiveRoadWilayahId() {
    return selectedLeafWilayahId || null;
}

function getPolygonZoomBucket(zoom) {
    if (zoom >= 15) return 15;
    if (zoom >= 13) return 13;
    if (zoom >= 11) return 11;
    return 10;
}

function getRoadZoomBucket(zoom) {
    if (zoom >= 15) return 15;
    if (zoom >= 13) return 13;
    return 12;
}

function formatWilayahPopup(props = {}) {
    const tipe = (props.tipe || (props.nama_kecamatan ? 'kecamatan' : '')).toString();
    const nama = (props.nama || props.nama_kecamatan || 'Wilayah').toString();
    const fallbackRootName = props.wilayah === 'medan'
        ? 'Kota Medan'
        : props.wilayah === 'deli_serdang'
            ? 'Kabupaten Deli Serdang'
            : '';
    const parentNama = (props.parent_nama || fallbackRootName || '').toString();
    const grandparentNama = (props.grandparent_nama || '').toString();

    const lines = [];

    if (tipe === 'kota' || tipe === 'kabupaten') {
        lines.push(`<strong>${escapeHtml(nama)}</strong>`);
        lines.push(`Wilayah: ${escapeHtml(nama)}`);
    } else if (tipe === 'kecamatan') {
        lines.push(`<strong>${escapeHtml(nama)}</strong>`);
        if (parentNama) lines.push(`Kota/Kabupaten: ${escapeHtml(parentNama)}`);
        lines.push(`Kecamatan: ${escapeHtml(nama)}`);
    } else if (tipe === 'kelurahan' || tipe === 'desa') {
        lines.push(`<strong>${escapeHtml(nama)}</strong>`);
        if (grandparentNama) lines.push(`Kota/Kabupaten: ${escapeHtml(grandparentNama)}`);
        if (parentNama) lines.push(`Kecamatan: ${escapeHtml(parentNama)}`);
        lines.push(`${tipe === 'desa' ? 'Desa' : 'Kelurahan'}: ${escapeHtml(nama)}`);
    } else {
        lines.push(`<strong>${escapeHtml(nama)}</strong>`);
    }

    return lines.join('<br>');
}

async function loadTopLevelWilayahOptions() {
    try {
        const url = new URL(LAYER_ENDPOINTS.wilayahList, window.location.origin);
        url.searchParams.set('kategori', 'kota,kabupaten');
        url.searchParams.set('per_page', '20');
        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const json = await res.json();
        const data = Array.isArray(json.data)
            ? json.data.map((item) => ({
                ...item,
                id: Number(item.id),
                parent_id: item.parent_id == null ? null : Number(item.parent_id),
            }))
            : [];
        availableTopLevelWilayah = data;

        const select = document.getElementById('filter-top-level-wilayah');
        select.innerHTML = '<option value="">Pilih kota atau kabupaten</option>';
        data.forEach((item) => {
            const opt = document.createElement('option');
            opt.value = String(item.id);
            opt.textContent = `${item.nama} (${item.tipe === 'kota' ? 'Kota' : 'Kabupaten'})`;
            select.appendChild(opt);
        });

        syncHierarchyControlState();
    } catch (err) {
        console.error('Error loading top-level wilayah list:', err);
    }
}

async function loadKecamatanOptions() {
    availableKecamatan = [];
    const select = document.getElementById('filter-kecamatan-visual');
    select.innerHTML = '<option value="">Pilih salah satu kecamatan</option>';

    if (!selectedTopLevelWilayahId) {
        return;
    }

    try {
        const url = new URL(LAYER_ENDPOINTS.wilayahChildren(selectedTopLevelWilayahId), window.location.origin);
        url.searchParams.set('kategori', 'kecamatan');

        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const json = await res.json();
        const data = Array.isArray(json.data)
            ? json.data.map((item) => ({
                ...item,
                id: Number(item.id),
                parent_id: item.parent_id == null ? null : Number(item.parent_id),
            }))
            : [];
        availableKecamatan = data;

        data.forEach((item) => {
            const opt = document.createElement('option');
            opt.value = String(item.id);
            opt.textContent = item.nama;
            select.appendChild(opt);
        });
        syncHierarchyControlState();
    } catch (err) {
        console.error('Error loading kecamatan list:', err);
    }
}

async function loadLeafWilayahOptions() {
    availableLeafWilayah = [];
    const select = document.getElementById('filter-leaf-wilayah-visual');
    select.innerHTML = '<option value="">Pilih kelurahan atau desa</option>';

    if (!selectedKecamatanId) {
        return;
    }

    try {
        const url = new URL(LAYER_ENDPOINTS.wilayahKelurahan, window.location.origin);
        url.searchParams.set('kecamatan_id', String(selectedKecamatanId));

        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const json = await res.json();
        const data = Array.isArray(json.data)
            ? json.data.map((item) => ({
                ...item,
                id: Number(item.id),
                parent_id: item.parent_id == null ? null : Number(item.parent_id),
            }))
            : [];
        availableLeafWilayah = data;

        data.forEach((item) => {
            const opt = document.createElement('option');
            opt.value = String(item.id);
            opt.textContent = `${item.nama} (${item.tipe})`;
            select.appendChild(opt);
        });
        syncHierarchyControlState();
    } catch (err) {
        console.error('Error loading kelurahan/desa list:', err);
    }
}

function syncHierarchyControlState() {
    const kecamatanSelect = document.getElementById('filter-kecamatan-visual');
    const leafSelect = document.getElementById('filter-leaf-wilayah-visual');
    const toggleAllKecamatan = document.getElementById('toggle-all-kecamatan');
    const toggleAllLeaf = document.getElementById('toggle-all-leaf-wilayah');
    const toggleRoads = document.getElementById('toggle-roads-kecamatan');

    if (kecamatanSelect) {
        kecamatanSelect.disabled = !selectedTopLevelWilayahId;
    }

    if (toggleAllKecamatan) {
        toggleAllKecamatan.disabled = !selectedTopLevelWilayahId;
    }

    if (leafSelect) {
        leafSelect.disabled = !selectedKecamatanId;
    }

    if (toggleAllLeaf) {
        toggleAllLeaf.disabled = !selectedKecamatanId;
    }

    if (toggleRoads) {
        toggleRoads.disabled = !selectedLeafWilayahId;
    }
}

async function handleKecamatanSelectionChange(rawId) {
    selectedKecamatanId = rawId ? Number(rawId) : null;
    selectedLeafWilayahId = null;
    showRoadsByKecamatan = false;

    const leafSelect = document.getElementById('filter-leaf-wilayah-visual');
    if (leafSelect) {
        leafSelect.value = '';
    }

    const roadsToggle = document.getElementById('toggle-roads-kecamatan');
    if (roadsToggle) {
        roadsToggle.checked = false;
    }

    clearDynamicLayer('selectedKecamatan');
    clearDynamicLayer('allLeafWilayah');
    clearDynamicLayer('roadsByKecamatan');

    await loadLeafWilayahOptions();
    syncHierarchyControlState();

    if (!getActiveWilayahId()) {
        applyFilters();
        return;
    }

    await loadSelectedKecamatanPolygon(true);
    if (showAllLeafWilayah) {
        await loadAllLeafWilayahPolygons(true);
    }
    if (showRoadsByKecamatan) {
        await loadSelectedKecamatanRoads(true);
    }
    applyFilters();
}

async function handleLeafWilayahSelectionChange(rawId) {
    selectedLeafWilayahId = rawId ? Number(rawId) : null;

    if (!selectedLeafWilayahId) {
        showRoadsByKecamatan = false;
        const roadsToggle = document.getElementById('toggle-roads-kecamatan');
        if (roadsToggle) {
            roadsToggle.checked = false;
        }
    }

    clearDynamicLayer('selectedKecamatan');
    clearDynamicLayer('allLeafWilayah');
    clearDynamicLayer('roadsByKecamatan');
    syncHierarchyControlState();

    if (!getActiveWilayahId()) {
        applyFilters();
        return;
    }

    await loadSelectedKecamatanPolygon(true);
    if (showRoadsByKecamatan) {
        await loadSelectedKecamatanRoads(true);
    }
    applyFilters();
}

async function handleTopLevelWilayahChange(rawId) {
    selectedTopLevelWilayahId = rawId ? Number(rawId) : null;
    selectedKecamatanId = null;
    selectedLeafWilayahId = null;
    showRoadsByKecamatan = false;

    const kecamatanSelect = document.getElementById('filter-kecamatan-visual');
    if (kecamatanSelect) {
        kecamatanSelect.value = '';
    }

    const leafSelect = document.getElementById('filter-leaf-wilayah-visual');
    if (leafSelect) {
        leafSelect.value = '';
    }

    const roadsToggle = document.getElementById('toggle-roads-kecamatan');
    if (roadsToggle) {
        roadsToggle.checked = false;
    }

    clearDynamicLayer('selectedKecamatan');
    clearDynamicLayer('allKecamatan');
    clearDynamicLayer('allLeafWilayah');
    clearDynamicLayer('roadsByKecamatan');

    await loadKecamatanOptions();
    await loadLeafWilayahOptions();
    syncHierarchyControlState();

    if (!getActiveWilayahId()) {
        applyFilters();
        return;
    }

    await loadSelectedKecamatanPolygon(true);
    if (showAllKecamatan) {
        await loadAllKecamatanPolygons(true);
    }
    applyFilters();
}

function syncBoundaryLayers() {
    syncLayerOnMap('boundaryMedan', true);
    syncLayerOnMap('boundaryDeliSerdang', true);
}

function syncLayerOnMap(layerKey, shouldShow) {
    const layerState = geoLayerState[layerKey];
    if (!layerState) {
        return;
    }

    if (shouldShow) {
        if (!map.hasLayer(layerState.layer)) {
            layerState.layer.addTo(map);
        }
        refreshDynamicLayer(layerKey, true);
        return;
    }

    if (map.hasLayer(layerState.layer)) {
        map.removeLayer(layerState.layer);
    }

    clearDynamicLayer(layerKey);
}

async function loadAllKecamatanPolygons(force = false) {
    const layerState = geoLayerState.allKecamatan;
    if (!layerState) {
        return;
    }

    if (!showAllKecamatan) {
        clearDynamicLayer('allKecamatan');
        return;
    }

    const selectedRoot = getSelectedTopLevelWilayah();
    if (!selectedRoot) {
        clearDynamicLayer('allKecamatan');
        return;
    }

    const wilayahKey = selectedRoot.wilayah;
    const zoomBucket = getPolygonZoomBucket(map.getZoom());
    const selectionKey = `${selectedRoot.id}:${zoomBucket}`;
    if (!force && (layerState.loading || layerState.lastSelectionKey === selectionKey)) {
        return;
    }

    layerState.loading = true;
    const requestId = ++layerState.requestId;

    try {
        const url = new URL(LAYER_ENDPOINTS.kecamatanGeoJson, window.location.origin);
        if (wilayahKey) {
            url.searchParams.set('wilayah', wilayahKey);
        }
        url.searchParams.set('zoom', String(zoomBucket));

        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/geo+json, application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const geojson = await res.json();
        if (requestId !== layerState.requestId) {
            return;
        }

        if (geojson.type !== 'FeatureCollection') {
            throw new Error('Response bukan GeoJSON FeatureCollection.');
        }

        layerState.layer.clearLayers();
        layerState.layer.addData(geojson);
        layerState.loaded = true;
        layerState.error = null;
        syncBoundaryVisualOrder();
        layerState.lastSelectionKey = selectionKey;
    } catch (err) {
        if (requestId !== layerState.requestId) {
            return;
        }

        layerState.error = err;
        layerState.layer.clearLayers();
        layerState.loaded = false;
        layerState.lastSelectionKey = null;
        console.error('Error loading all kecamatan polygons:', err);
    } finally {
        if (requestId === layerState.requestId) {
            layerState.loading = false;
        }
    }
}

async function loadSelectedKecamatanPolygon(force = false) {
    const layerState = geoLayerState.selectedKecamatan;
    if (!layerState) {
        return;
    }

    const activeWilayahId = getActiveWilayahId();
    if (!activeWilayahId) {
        clearDynamicLayer('selectedKecamatan');
        return;
    }

    const zoomBucket = getPolygonZoomBucket(map.getZoom());
    const selectionKey = `${activeWilayahId}:${zoomBucket}`;
    if (!force && (layerState.loading || layerState.lastSelectionKey === selectionKey)) {
        return;
    }

    layerState.loading = true;
    const requestId = ++layerState.requestId;

    try {
        const url = new URL(LAYER_ENDPOINTS.wilayahDetail(activeWilayahId), window.location.origin);
        url.searchParams.set('zoom', String(zoomBucket));

        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/geo+json, application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const geojson = await res.json();
        if (requestId !== layerState.requestId) {
            return;
        }

        if (geojson.type !== 'FeatureCollection') {
            throw new Error('Response bukan GeoJSON FeatureCollection.');
        }

        layerState.layer.clearLayers();
        layerState.layer.addData(geojson);
        layerState.loaded = true;
        layerState.error = null;
        syncBoundaryVisualOrder();
        layerState.lastSelectionKey = selectionKey;

        if (!map.hasLayer(layerState.layer)) {
            layerState.layer.addTo(map);
        }

        const bounds = layerState.layer.getBounds();
        if (bounds && bounds.isValid()) {
            map.fitBounds(bounds, {
                padding: [24, 24],
                maxZoom: 14,
            });
        }
    } catch (err) {
        if (requestId !== layerState.requestId) {
            return;
        }

        layerState.error = err;
        layerState.layer.clearLayers();
        layerState.loaded = false;
        layerState.lastSelectionKey = null;
        console.error('Error loading selected wilayah polygon:', err);
    } finally {
        if (requestId === layerState.requestId) {
            layerState.loading = false;
        }
    }
}

async function loadAllLeafWilayahPolygons(force = false) {
    const layerState = geoLayerState.allLeafWilayah;
    if (!layerState) {
        return;
    }

    if (!showAllLeafWilayah || !selectedKecamatanId) {
        clearDynamicLayer('allLeafWilayah');
        return;
    }

    const zoomBucket = getPolygonZoomBucket(map.getZoom());
    const selectionKey = `${selectedKecamatanId}:${zoomBucket}`;
    if (!force && (layerState.loading || layerState.lastSelectionKey === selectionKey)) {
        return;
    }

    layerState.loading = true;
    const requestId = ++layerState.requestId;

    try {
        const url = new URL(`${API_BASE}/wilayah/children-geojson/${selectedKecamatanId}`, window.location.origin);
        url.searchParams.set('kategori', 'kelurahan,desa');
        url.searchParams.set('zoom', String(zoomBucket));

        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/geo+json, application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const geojson = await res.json();
        if (requestId !== layerState.requestId) {
            return;
        }

        if (geojson.type !== 'FeatureCollection') {
            throw new Error('Response bukan GeoJSON FeatureCollection.');
        }

        layerState.layer.clearLayers();
        layerState.layer.addData(geojson);
        layerState.loaded = true;
        layerState.error = null;
        syncBoundaryVisualOrder();
        layerState.lastSelectionKey = selectionKey;

        if (!map.hasLayer(layerState.layer)) {
            layerState.layer.addTo(map);
        }
    } catch (err) {
        if (requestId !== layerState.requestId) {
            return;
        }

        layerState.error = err;
        layerState.layer.clearLayers();
        layerState.loaded = false;
        layerState.lastSelectionKey = null;
        console.error('Error loading all kelurahan/desa polygons:', err);
    } finally {
        if (requestId === layerState.requestId) {
            layerState.loading = false;
        }
    }
}

async function loadSelectedKecamatanRoads(force = false) {
    const layerState = geoLayerState.roadsByKecamatan;
    if (!layerState) {
        return;
    }

    const activeWilayahId = getActiveRoadWilayahId();
    if (!activeWilayahId) {
        clearDynamicLayer('roadsByKecamatan');
        return;
    }

    if (!showRoadsByKecamatan) {
        clearDynamicLayer('roadsByKecamatan');
        return;
    }

    if (!map.hasLayer(layerState.layer)) {
        layerState.layer.addTo(map);
    }

    if (!map.hasLayer(layerState.layer)) {
        clearDynamicLayer('roadsByKecamatan');
        return;
    }

    const zoomBucket = getRoadZoomBucket(map.getZoom());
    const selectionKey = `${activeWilayahId}:${zoomBucket}`;
    if (!force && (!map.hasLayer(layerState.layer) || layerState.loading || layerState.lastSelectionKey === selectionKey)) {
        return;
    }

    layerState.loading = true;
    const requestId = ++layerState.requestId;

    try {
        const url = new URL(LAYER_ENDPOINTS.roadsByWilayah(activeWilayahId), window.location.origin);
        url.searchParams.set('zoom', String(zoomBucket));
        url.searchParams.set('compact', '1');

        const res = await fetch(url.toString(), {
            headers: { 'Accept': 'application/geo+json, application/json' },
        });
        if (!res.ok) {
            throw new Error(`HTTP ${res.status}`);
        }

        const geojson = await res.json();
        if (requestId !== layerState.requestId) {
            return;
        }

        if (geojson.type !== 'FeatureCollection') {
            throw new Error('Response bukan GeoJSON FeatureCollection.');
        }

        layerState.layer.clearLayers();
        layerState.layer.addData(geojson);
        layerState.loaded = true;
        layerState.error = null;
        syncBoundaryVisualOrder();
        layerState.lastSelectionKey = selectionKey;
    } catch (err) {
        if (requestId !== layerState.requestId) {
            return;
        }

        layerState.error = err;
        layerState.layer.clearLayers();
        layerState.loaded = false;
        layerState.lastSelectionKey = null;
        console.error('Error loading roads by wilayah:', err);
    } finally {
        if (requestId === layerState.requestId) {
            layerState.loading = false;
        }
    }
}

// ============================================================
// DATA LOADING
// ============================================================

/**
 * Load kategori data for filter dropdown
 */
async function loadKategori() {
    try {
        const res = await fetch(`${API_BASE}/kategori`);
        const json = await res.json();

        if (json.status && json.data) {
            allKategori = json.data;
            const select = document.getElementById('filter-kategori');

            json.data.forEach(k => {
                const opt = document.createElement('option');
                opt.value = k.nama_kategori;
                opt.textContent = k.nama_kategori;
                select.appendChild(opt);
            });

            if (initialCategory) {
                select.value = initialCategory;
            }
        }
    } catch (err) {
        console.error('Error loading kategori:', err);
    }
}

/**
 * Load wisata data from API
 */
async function loadWisata(kategori = null) {
    const listEl = document.getElementById('wisata-list');
    listEl.innerHTML = `
        <div class="loading-spinner">
            <div class="spinner"></div>
            <p>Memuat data wisata...</p>
        </div>
    `;

    try {
        let url = `${API_BASE}/wisata`;

        const res = await fetch(url);
        const json = await res.json();

        if (json.status && json.data) {
            allWisata = json.data;
            // Awalnya terapkan filter dari state saat ini
            applyFilters();
        } else {
            listEl.innerHTML = `
                <div class="empty-state">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="8" x2="12" y2="12"></line>
                        <line x1="12" y1="16" x2="12.01" y2="16"></line>
                    </svg>
                    <p>Tidak ada data wisata</p>
                </div>
            `;
        }
    } catch (err) {
        console.error('Error loading wisata:', err);
        listEl.innerHTML = `
            <div class="empty-state">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="12" cy="12" r="10"></circle>
                    <line x1="15" y1="9" x2="9" y2="15"></line>
                    <line x1="9" y1="9" x2="15" y2="15"></line>
                </svg>
                <p>Gagal memuat data. Pastikan API berjalan.</p>
            </div>
        `;
    }
}

// ============================================================
// RENDERING
// ============================================================

/**
 * Render wisata cards in sidebar
 */
function renderWisataList(wisataList) {
    const listEl = document.getElementById('wisata-list');

    if (wisataList.length === 0) {
        listEl.innerHTML = `
            <div class="empty-state">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="11" cy="11" r="8"></circle>
                    <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                </svg>
                <p>Tidak ditemukan wisata yang cocok</p>
            </div>
        `;
        return;
    }

    listEl.innerHTML = wisataList.map(w => `
        <div class="wisata-card" data-id="${w.id}" onclick="flyToWisata(${w.id})">
            <div class="wisata-card-media">
                ${w.foto && w.foto.length > 0 
                    ? `<div class="wisata-card-img" style="background-image: url('${escapeHtml(w.foto[0])}')"></div>` 
                    : `<div class="wisata-card-img no-img">No Image</div>`}
                <button class="wisata-card-route-btn" type="button" onclick="event.stopPropagation(); routeToWisata(${w.id})">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                        <path d="M9 20l-5.447-2.724A1 1 0 0 1 3 16.382V5.618a1 1 0 0 1 .553-.894L9 2l6 3 5.447-2.724A1 1 0 0 1 21 3.17v10.764a1 1 0 0 1-.553.894L15 18l-6 2z"></path>
                        <line x1="9" y1="2" x2="9" y2="20"></line>
                        <line x1="15" y1="5" x2="15" y2="18"></line>
                    </svg>
                    <span>Rute</span>
                </button>
            </div>
            <div class="wisata-card-content">
                <div class="wisata-card-name">${escapeHtml(w.nama_tempat)}</div>
                <div class="wisata-card-topline">
                    <span class="wisata-card-kategori">${escapeHtml(w.kategori || 'Tanpa Kategori')}</span>
                    <span class="wisata-card-rating">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"></path>
                        </svg>
                        <span>${parseFloat(w.rating) > 0 ? escapeHtml(String(w.rating)) : 'Belum ada rating'}</span>
                    </span>
                </div>
                <div class="wisata-card-location-stack">
                    <div class="wisata-card-location-row">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <path d="M3 21h18"></path>
                            <path d="M5 21V7l8-4v18"></path>
                            <path d="M19 21V11l-6-4"></path>
                        </svg>
                        <span>${escapeHtml(w.kota_kabupaten || '-')}</span>
                    </div>
                    <div class="wisata-card-location-row">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path>
                            <circle cx="12" cy="10" r="3"></circle>
                        </svg>
                        <span>${escapeHtml(w.kecamatan || '-')}</span>
                    </div>
                    <div class="wisata-card-location-row">
                        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                            <path d="M8 21h8"></path>
                            <path d="M12 17v4"></path>
                            <path d="M7 4h10l1 6H6l1-6z"></path>
                            <path d="M6 10h12v3a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3v-3z"></path>
                        </svg>
                        <span>${escapeHtml(w.kelurahan || '-')}</span>
                    </div>
                </div>
                <div class="wisata-card-meta">
                    <span class="wisata-card-price">
                        ${w.harga_tiket > 0 ? formatRupiah(w.harga_tiket) : 'Gratis'}
                    </span>
                </div>
            </div>
        </div>
    `).join('');
}

/**
 * Render markers on the map
 */
function renderMarkers(wisataList) {
    markersLayer.clearLayers();
    markerIndexByWisataId.clear();

    wisataList.forEach(w => {
        if (!w.latitude || !w.longitude) return;

        const color = CATEGORY_COLORS[w.kategori] || '#10b981';

        // Custom div icon
        const icon = L.divIcon({
            html: `
                <div style="
                    width: 32px; height: 32px;
                    background: ${color};
                    border-radius: 50% 50% 50% 0;
                    transform: rotate(-45deg);
                    display: flex; align-items: center; justify-content: center;
                    box-shadow: 0 3px 12px ${color}66;
                    border: 2px solid rgba(255,255,255,0.3);
                ">
                    <div style="
                        transform: rotate(45deg);
                        color: white;
                        font-size: 14px;
                        font-weight: 700;
                    ">&#9679;</div>
                </div>
            `,
            className: '',
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32],
        });

        const marker = L.marker([parseFloat(w.latitude), parseFloat(w.longitude)], { icon });

        // Popup
        const popupHtml = `
            <div class="popup-content">
                ${w.foto && w.foto.length > 0
                    ? `<img class="popup-image" src="${escapeHtml(w.foto[0])}" alt="${escapeHtml(w.nama_tempat)}" onerror="this.style.display='none'">`
                    : ''}
                <h3>${escapeHtml(w.nama_tempat)}</h3>
                <div class="popup-badges">
                    <span class="popup-kategori">${escapeHtml(w.kategori || 'Tanpa Kategori')}</span>
                    <span class="popup-target">${escapeHtml(w.target_pengunjung || 'Umum')}</span>
                    <span class="popup-rating">
                        ${getModalIcon('rating')}
                        <span>${parseFloat(w.rating) > 0 ? escapeHtml(String(w.rating)) : 'Belum ada rating'}</span>
                    </span>
                </div>
                <p class="popup-desc">${escapeHtml(w.deskripsi || '')}</p>
                <div class="popup-meta">
                    <span class="popup-price">
                        ${getModalIcon('ticket')}
                        <span>${Number(w.harga_tiket) > 0 ? formatRupiah(w.harga_tiket) : 'Gratis'}</span>
                    </span>
                    <div class="popup-actions">
                        <button class="popup-btn" onclick="showDetail(${w.id})">
                            ${getModalIcon('note')}
                            <span>Detail</span>
                        </button>
                        <button class="popup-btn popup-btn-secondary" onclick="routeToWisata(${w.id})">
                            ${getModalIcon('route')}
                            <span>Rute</span>
                        </button>
                    </div>
                </div>
            </div>
        `;

        marker.bindPopup(popupHtml, {
            maxWidth: 320,
            className: 'custom-popup',
        });

        marker.on('click', () => {
            scrollToWisataCard(w.id);
        });

        marker.wisataId = w.id;
        markerIndexByWisataId.set(Number(w.id), marker);
        markersLayer.addLayer(marker);
    });
}

// ============================================================
// INTERACTIONS
// ============================================================

/**
 * Fly to wisata on map and open popup
 */
function flyToWisata(id) {
    const wisata = allWisata.find(w => w.id == id);
    if (!wisata) return;

    const targetLatLng = [parseFloat(wisata.latitude), parseFloat(wisata.longitude)];
    const targetMarker = markerIndexByWisataId.get(Number(id)) || null;

    if (targetMarker) {
        map.closePopup();
        markersLayer.zoomToShowLayer(targetMarker, () => {
            map.flyTo(targetLatLng, Math.max(map.getZoom(), 16), {
                duration: 0.85,
            });
            setTimeout(() => {
                targetMarker.openPopup();
            }, 260);
        });
    } else {
        map.flyTo(targetLatLng, 16, {
            duration: 1.2,
        });
    }

    // Close mobile sidebar
    document.getElementById('sidebar').classList.remove('mobile-open');
}

function scrollToWisataCard(id) {
    const listEl = document.getElementById('wisata-list');
    const cardEl = listEl?.querySelector(`.wisata-card[data-id="${id}"]`);
    if (!listEl || !cardEl) {
        return;
    }

    cardEl.scrollIntoView({
        behavior: 'smooth',
        block: 'nearest',
        inline: 'nearest',
    });

    cardEl.classList.remove('is-focused');
    void cardEl.offsetWidth;
    cardEl.classList.add('is-focused');

    window.clearTimeout(cardEl._focusTimerId);
    cardEl._focusTimerId = window.setTimeout(() => {
        cardEl.classList.remove('is-focused');
    }, 1800);
}

function getModalIcon(type) {
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
        route: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M9 20l-5.447-2.724A1 1 0 0 1 3 16.382V5.618a1 1 0 0 1 .553-.894L9 2l6 3 5.447-2.724A1 1 0 0 1 21 3.17v10.764a1 1 0 0 1-.553.894L15 18l-6 2z"></path><line x1="9" y1="2" x2="9" y2="20"></line><line x1="15" y1="5" x2="15" y2="18"></line></svg>`,
        facility: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 6L9 17l-5-5"></path></svg>`,
    };

    return icons[type] || icons.note;
}

function formatModalRating(avg, totalReview = 0) {
    const numericRating = parseFloat(avg) || 0;
    if (numericRating <= 0) {
        return 'Belum ada rating';
    }

    const total = Number(totalReview) || 0;
    return total > 0
        ? `${numericRating.toFixed(1)} / 5 - ${total} ulasan`
        : `${numericRating.toFixed(1)} / 5`;
}

function normalizeModalPhotos(wisata) {
    if (Array.isArray(wisata?.foto)) {
        return wisata.foto.filter(Boolean);
    }

    if (typeof wisata?.foto === 'string' && wisata.foto.trim()) {
        return [wisata.foto.trim()];
    }

    return [];
}

function buildModalInfoItem(iconKey, label, value, extraClass = '') {
    return `
        <div class="modal-info-item ${extraClass}">
            <div class="modal-info-icon">${getModalIcon(iconKey)}</div>
            <div class="modal-info-copy">
                <div class="info-label">${escapeHtml(label)}</div>
                <div class="info-value">${escapeHtml(value || '-')}</div>
            </div>
        </div>
    `;
}

function buildModalGallery(photos, placeName) {
    if (!Array.isArray(photos) || photos.length === 0) {
        return '';
    }

    activeModalGalleryPhotos = photos.slice();
    activeModalGalleryIndex = 0;

    return `
        <div class="modal-gallery ${photos.length > 1 ? 'has-controls' : ''}">
            <img
                id="modal-gallery-image"
                class="modal-hero-img"
                src="${escapeHtml(photos[0])}"
                alt="${escapeHtml(placeName)}"
                onerror="this.style.display='none'"
            >
            ${photos.length > 1 ? `
                <button class="modal-gallery-nav prev" type="button" onclick="stepModalGallery(-1)" aria-label="Foto sebelumnya">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="15 18 9 12 15 6"></polyline>
                    </svg>
                </button>
                <button class="modal-gallery-nav next" type="button" onclick="stepModalGallery(1)" aria-label="Foto berikutnya">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="9 18 15 12 9 6"></polyline>
                    </svg>
                </button>
                <div class="modal-gallery-counter">
                    <span id="modal-gallery-counter">1 / ${photos.length}</span>
                </div>
            ` : ''}
        </div>
    `;
}

function stepModalGallery(direction) {
    if (!activeModalGalleryPhotos.length) {
        return;
    }

    activeModalGalleryIndex = (activeModalGalleryIndex + direction + activeModalGalleryPhotos.length) % activeModalGalleryPhotos.length;
    const imageEl = document.getElementById('modal-gallery-image');
    const counterEl = document.getElementById('modal-gallery-counter');

    if (imageEl) {
        imageEl.classList.remove('is-slide-in', 'is-slide-out');
        imageEl.classList.add('is-slide-out');
        window.setTimeout(() => {
            imageEl.src = activeModalGalleryPhotos[activeModalGalleryIndex];
            imageEl.style.display = '';
            imageEl.classList.remove('is-slide-out');
            imageEl.classList.add('is-slide-in');
            window.setTimeout(() => {
                imageEl.classList.remove('is-slide-in');
            }, 220);
        }, 140);
    }

    if (counterEl) {
        counterEl.textContent = `${activeModalGalleryIndex + 1} / ${activeModalGalleryPhotos.length}`;
    }
}

function renderModalDetail(wisata) {
    activeModalGalleryPhotos = [];
    activeModalGalleryIndex = 0;
    const photos = normalizeModalPhotos(wisata);
    const ratingText = formatModalRating(wisata.rating_avg ?? wisata.rating, wisata.total_review);
    const hargaText = Number(wisata.harga_tiket) > 0 ? formatRupiah(wisata.harga_tiket) : 'Gratis';
    const jamText = wisata.jam_buka || wisata.jam_tutup
        ? `${wisata.jam_buka || '-'} - ${wisata.jam_tutup || '-'}`
        : '-';
    const coordinatesText = wisata.latitude && wisata.longitude
        ? `${Number.parseFloat(wisata.latitude).toFixed(6)}, ${Number.parseFloat(wisata.longitude).toFixed(6)}`
        : '-';
    const fasilitasList = Array.isArray(wisata.fasilitas) ? wisata.fasilitas.filter(Boolean) : [];
    const reviewsList = Array.isArray(wisata.reviews) ? wisata.reviews : [];

    return `
        ${buildModalGallery(photos, wisata.nama_tempat)}
        <div class="modal-section">
            <div class="modal-header">
                <h2>${escapeHtml(wisata.nama_tempat || 'Detail Wisata')}</h2>
                <div class="modal-badges">
                    <span class="modal-kategori">${escapeHtml(wisata.kategori || 'Tanpa Kategori')}</span>
                    <span class="modal-badge-inline">
                        ${getModalIcon('target')}
                        <span>${escapeHtml(wisata.target_pengunjung || 'Target belum diatur')}</span>
                    </span>
                    <span class="modal-badge-inline is-rating">
                        ${getModalIcon('rating')}
                        <span>${escapeHtml(ratingText)}</span>
                    </span>
                </div>
            </div>

            <p class="modal-desc">${escapeHtml(wisata.deskripsi || 'Belum ada deskripsi untuk lokasi wisata ini.')}</p>

            <div class="modal-info-grid">
                ${buildModalInfoItem('city', 'Kota / Kabupaten', wisata.kota_kabupaten || '-')}
                ${buildModalInfoItem('address', 'Alamat', wisata.alamat || '-')}
                ${buildModalInfoItem('district', 'Kecamatan', wisata.kecamatan || '-')}
                ${buildModalInfoItem('village', 'Kelurahan / Desa', wisata.kelurahan || '-')}
                ${buildModalInfoItem('clock', 'Jam Operasional', jamText)}
                ${buildModalInfoItem('calendar', 'Hari Operasional', wisata.hari_operasional || '-')}
                ${buildModalInfoItem('ticket', 'Harga Tiket', hargaText)}
                ${buildModalInfoItem('note', 'Keterangan Harga', wisata.keterangan_harga || '-')}
                ${buildModalInfoItem('phone', 'No. Telepon', wisata.no_telepon || '-')}
                ${buildModalInfoItem('coordinates', 'Koordinat', coordinatesText)}
            </div>

            ${fasilitasList.length > 0 ? `
                <div class="modal-subsection">
                    <h3>Fasilitas</h3>
                    <div class="modal-fasilitas">
                        ${fasilitasList.map((item) => `
                            <span class="tm-chip modal-facility-chip">
                                ${getModalIcon('facility')}
                                <span>${escapeHtml(item)}</span>
                            </span>
                        `).join('')}
                    </div>
                </div>
            ` : ''}

            ${reviewsList.length > 0 ? `
                <div class="modal-reviews">
                    <h3>Ulasan Pengunjung</h3>
                    ${reviewsList.map((review) => `
                        <div class="review-card">
                            <div class="review-header">
                                <span class="review-name">${escapeHtml(review.nama_reviewer || 'Pengunjung')}</span>
                                <span class="review-rating">${escapeHtml(formatModalRating(review.rating, 0))}</span>
                            </div>
                            <p class="review-text">${escapeHtml(review.ulasan || '')}</p>
                        </div>
                    `).join('')}
                </div>
            ` : ''}

            <div class="modal-actions">
                <button class="modal-route-btn" type="button" onclick="routeToWisata(${wisata.id})">
                    ${getModalIcon('route')}
                    <span>Rute</span>
                </button>
            </div>
        </div>
    `;
}

/**
 * Show detail in modal
 */
async function showDetail(id) {
    const modal = document.getElementById('detail-modal');
    const modalBody = document.getElementById('modal-body');

    modal.style.display = 'flex';

    modalBody.innerHTML = `
        <div class="loading-spinner" style="padding: 60px;">
            <div class="spinner"></div>
            <p>Memuat detail...</p>
        </div>
    `;

    try {
        const res = await fetch(`${API_BASE}/wisata/${id}`);
        const json = await res.json();

        if (!res.ok) {
            throw new Error(json?.message || `HTTP ${res.status}`);
        }

        if (json.status && json.data) {
            modalBody.innerHTML = renderModalDetail(json.data);
            return;
        }

        throw new Error(json?.message || 'Detail wisata tidak tersedia.');
    } catch (err) {
        console.error('Error loading detail:', err);
        const fallback = allWisata.find(w => Number(w.id) === Number(id));
        if (fallback) {
            modalBody.innerHTML = renderModalDetail(fallback);
            return;
        }

        modalBody.innerHTML = '<div class="empty-state"><p>Gagal memuat detail wisata.</p></div>';
    }
}

/**
 * Get user location
 */
function getUserLocation() {
    if (!navigator.geolocation) {
        alert('Geolocation tidak didukung browser Anda.');
        return;
    }

    navigator.geolocation.getCurrentPosition(
        (pos) => {
            const lat = pos.coords.latitude;
            const lng = pos.coords.longitude;

            // Remove old user marker
            if (userMarker) {
                map.removeLayer(userMarker);
            }

            // Add user marker
            const userIcon = L.divIcon({
                html: `
                    <div style="
                        width: 20px; height: 20px;
                        background: #3b82f6;
                        border-radius: 50%;
                        border: 4px solid rgba(59, 130, 246, 0.3);
                        box-shadow: 0 0 20px rgba(59, 130, 246, 0.5);
                        animation: pulse 2s infinite;
                    "></div>
                `,
                className: '',
                iconSize: [20, 20],
                iconAnchor: [10, 10],
            });

            // Add pulse animation
            if (!document.getElementById('pulse-style')) {
                const style = document.createElement('style');
                style.id = 'pulse-style';
                style.textContent = `
                    @keyframes pulse {
                        0% { box-shadow: 0 0 0 0 rgba(59, 130, 246, 0.5); }
                        70% { box-shadow: 0 0 0 15px rgba(59, 130, 246, 0); }
                        100% { box-shadow: 0 0 0 0 rgba(59, 130, 246, 0); }
                    }
                `;
                document.head.appendChild(style);
            }

            userMarker = L.marker([lat, lng], { icon: userIcon }).addTo(map);
            userMarker.bindPopup('<div class="popup-content"><h3>📍 Lokasi Anda</h3></div>');

            map.flyTo([lat, lng], 15, { duration: 1.5 });
        },
        (err) => {
            console.error('Geolocation error:', err);
            alert('Tidak dapat mengakses lokasi Anda. Pastikan izin lokasi aktif.');
        },
        { enableHighAccuracy: true, timeout: 10000 }
    );
}

/**
 * Route from user location to wisata
 */
function routeToWisata(id) {
    const wisata = allWisata.find(w => w.id == id);
    if (!wisata || !wisata.latitude || !wisata.longitude) return;

    // Close modal if open
    document.getElementById('detail-modal').style.display = 'none';

    if (!userMarker) {
        alert('Mohon izinkan akses lokasi Anda terlebih dahulu untuk mencari rute.');
        getUserLocation();
        return;
    }

    const userLatLng = userMarker.getLatLng();
    const destLatLng = L.latLng(parseFloat(wisata.latitude), parseFloat(wisata.longitude));

    if (routingControl) {
        map.removeControl(routingControl);
    }

    routingControl = L.Routing.control({
        waypoints: [
            userLatLng,
            destLatLng
        ],
        routeWhileDragging: false,
        addWaypoints: false,
        fitSelectedRoutes: true,
        showAlternatives: false,
        lineOptions: {
            styles: [{color: '#06b6d4', opacity: 0.9, weight: 6}]
        },
        createMarker: function() { return null; } // Use existing markers
    }).addTo(map);

    // Inject close button into routing container
    setTimeout(() => {
        const container = document.querySelector('.leaflet-routing-container');
        if (container && !document.getElementById('btn-close-route-web')) {
            const btn = document.createElement('button');
            btn.id = 'btn-close-route-web';
            btn.className = 'btn-close-route';
            btn.innerHTML = `
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
                Tutup Navigasi
            `;
            btn.onclick = clearRoute;
            container.insertBefore(btn, container.firstChild);
        }
    }, 100);
    
    // Close sidebar on mobile
    document.getElementById('sidebar').classList.remove('mobile-open');
}

/**
 * Clear the current route
 */
function clearRoute() {
    if (routingControl) {
        map.removeControl(routingControl);
        routingControl = null;
    }
}

// ============================================================
// EVENT LISTENERS
// ============================================================
function initEventListeners() {
    const advFilterButton = document.getElementById('btn-adv-filter');
    const advFilterPanel = document.getElementById('adv-filter-panel');
    const resetFilterButton = document.getElementById('btn-reset-filters');

    // Search
    document.getElementById('search-input').addEventListener('input', applyFilters);

    // Filter kategori
    document.getElementById('filter-kategori').addEventListener('change', applyFilters);
    document.getElementById('filter-rating').addEventListener('change', applyFilters);
    document.getElementById('filter-harga').addEventListener('change', applyFilters);
    document.getElementById('filter-target').addEventListener('change', applyFilters);
    document.querySelectorAll('.filter-fasilitas').forEach((input) => {
        input.addEventListener('change', applyFilters);
    });
    document.getElementById('filter-top-level-wilayah').addEventListener('change', async (event) => {
        await handleTopLevelWilayahChange(event.target.value);
    });
    document.getElementById('toggle-all-kecamatan').addEventListener('change', async (event) => {
        showAllKecamatan = event.target.checked;
        if (showAllKecamatan) {
            syncLayerOnMap('allKecamatan', true);
            await loadAllKecamatanPolygons(true);
        } else {
            syncLayerOnMap('allKecamatan', false);
        }
        applyFilters();
    });
    document.getElementById('filter-kecamatan-visual').addEventListener('change', (event) => {
        handleKecamatanSelectionChange(event.target.value);
    });
    document.getElementById('toggle-all-leaf-wilayah').addEventListener('change', async (event) => {
        showAllLeafWilayah = event.target.checked;
        if (showAllLeafWilayah && selectedKecamatanId) {
            syncLayerOnMap('allLeafWilayah', true);
            await loadAllLeafWilayahPolygons(true);
        } else {
            syncLayerOnMap('allLeafWilayah', false);
        }
        applyFilters();
    });
    document.getElementById('filter-leaf-wilayah-visual').addEventListener('change', (event) => {
        handleLeafWilayahSelectionChange(event.target.value);
    });
    document.getElementById('toggle-roads-kecamatan').addEventListener('change', async (event) => {
        showRoadsByKecamatan = event.target.checked;
        if (showRoadsByKecamatan && getActiveRoadWilayahId()) {
            syncLayerOnMap('roadsByKecamatan', true);
            await loadSelectedKecamatanRoads(true);
        } else {
            syncLayerOnMap('roadsByKecamatan', false);
        }
        applyFilters();
    });

    // Enter di search = apply filter
    document.getElementById('search-input').addEventListener('keypress', (e) => {
        if(e.key === 'Enter') applyFilters();
    });

    if (advFilterButton && advFilterPanel) {
        advFilterButton.addEventListener('click', () => {
            const isActive = advFilterPanel.classList.toggle('active');
            advFilterButton.setAttribute('aria-expanded', isActive ? 'true' : 'false');
        });

        document.addEventListener('click', (event) => {
            if (!advFilterPanel.classList.contains('active')) {
                return;
            }

            const clickedInsidePanel = advFilterPanel.contains(event.target);
            const clickedToggle = advFilterButton.contains(event.target);

            if (!clickedInsidePanel && !clickedToggle) {
                advFilterPanel.classList.remove('active');
                advFilterButton.setAttribute('aria-expanded', 'false');
            }
        });
    }

    if (resetFilterButton) {
        resetFilterButton.addEventListener('click', resetFilters);
    }

    // My Location
    const btnMyLocation = document.getElementById('btn-my-location');
    if (btnMyLocation) {
        btnMyLocation.addEventListener('click', getUserLocation);
    }

    // Toggle sidebar (close)
    document.getElementById('btn-toggle-sidebar').addEventListener('click', () => {
        const sidebar = document.getElementById('sidebar');
        const openBtn = document.getElementById('btn-open-sidebar');
        sidebar.classList.add('collapsed');
        openBtn.style.display = 'flex';
        setTimeout(() => map.invalidateSize(), 400);
    });

    // Open sidebar (reopen from collapsed)
    document.getElementById('btn-open-sidebar').addEventListener('click', () => {
        const sidebar = document.getElementById('sidebar');
        const openBtn = document.getElementById('btn-open-sidebar');
        sidebar.classList.remove('collapsed');
        openBtn.style.display = 'none';
        setTimeout(() => map.invalidateSize(), 400);
    });

    // Mobile sidebar toggle
    document.getElementById('btn-mobile-sidebar').addEventListener('click', () => {
        const sidebar = document.getElementById('sidebar');
        if (!sidebar.classList.contains('mobile-open')) {
            sidebar.classList.remove('collapsed');
        }
        sidebar.classList.toggle('mobile-open');
    });

    // Close modal
    document.getElementById('btn-close-modal').addEventListener('click', () => {
        document.getElementById('detail-modal').style.display = 'none';
    });

    document.getElementById('detail-modal').addEventListener('click', (e) => {
        if (e.target === e.currentTarget) {
            e.currentTarget.style.display = 'none';
        }
    });

    // Close modal on Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            document.getElementById('detail-modal').style.display = 'none';
            if (advFilterPanel) {
                advFilterPanel.classList.remove('active');
            }
            if (advFilterButton) {
                advFilterButton.setAttribute('aria-expanded', 'false');
            }
        }
    });

    syncHierarchyControlState();
}

// ============================================================
// UTILS
// ============================================================
function updateStats(total, showing) {
    document.getElementById('stat-total').textContent = total;
    document.getElementById('stat-showing').textContent = showing;
}

function formatRupiah(num) {
    return 'Rp ' + Number(num).toLocaleString('id-ID');
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function getActivePolygonFeatureCollection() {
    const activeWilayahId = getActiveWilayahId();
    if (!activeWilayahId) {
        return null;
    }

    const layer = geoLayerState.selectedKecamatan?.layer;
    if (!layer) {
        return null;
    }

    const geojson = layer.toGeoJSON?.();
    if (!geojson || geojson.type !== 'FeatureCollection' || !Array.isArray(geojson.features) || geojson.features.length === 0) {
        return null;
    }

    return geojson;
}

function pointInRing(point, ring) {
    let inside = false;
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        const xi = ring[i][0];
        const yi = ring[i][1];
        const xj = ring[j][0];
        const yj = ring[j][1];

        const intersects = ((yi > point[1]) !== (yj > point[1]))
            && (point[0] < ((xj - xi) * (point[1] - yi)) / ((yj - yi) || Number.EPSILON) + xi);

        if (intersects) {
            inside = !inside;
        }
    }
    return inside;
}

function pointInPolygonGeometry(point, geometry) {
    if (!geometry || !geometry.type || !geometry.coordinates) {
        return false;
    }

    if (geometry.type === 'Polygon') {
        const [outerRing, ...holes] = geometry.coordinates;
        if (!outerRing || !pointInRing(point, outerRing)) {
            return false;
        }

        return !holes.some((hole) => pointInRing(point, hole));
    }

    if (geometry.type === 'MultiPolygon') {
        return geometry.coordinates.some((polygonCoords) => {
            const [outerRing, ...holes] = polygonCoords;
            if (!outerRing || !pointInRing(point, outerRing)) {
                return false;
            }

            return !holes.some((hole) => pointInRing(point, hole));
        });
    }

    return false;
}

function isWisataInsideActivePolygon(wisata) {
    const activeFeatureCollection = getActivePolygonFeatureCollection();
    if (!activeFeatureCollection) {
        return true;
    }

    const lng = Number.parseFloat(wisata.longitude);
    const lat = Number.parseFloat(wisata.latitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        return false;
    }

    const point = [lng, lat];
    return activeFeatureCollection.features.some((feature) => pointInPolygonGeometry(point, feature.geometry));
}

function resetFilters() {
    document.getElementById('search-input').value = '';
    document.getElementById('filter-kategori').value = '';
    document.getElementById('filter-rating').value = '0';
    document.getElementById('filter-harga').value = 'all';
    document.getElementById('filter-target').value = '';
    document.querySelectorAll('.filter-fasilitas').forEach((input) => {
        input.checked = false;
    });

    selectedTopLevelWilayahId = null;
    selectedKecamatanId = null;
    selectedLeafWilayahId = null;
    showAllKecamatan = false;
    showAllLeafWilayah = false;
    showRoadsByKecamatan = false;

    const wilayahSelect = document.getElementById('filter-top-level-wilayah');
    const kecamatanSelect = document.getElementById('filter-kecamatan-visual');
    const leafSelect = document.getElementById('filter-leaf-wilayah-visual');
    const toggleAllKecamatan = document.getElementById('toggle-all-kecamatan');
    const toggleAllLeaf = document.getElementById('toggle-all-leaf-wilayah');
    const toggleRoads = document.getElementById('toggle-roads-kecamatan');

    if (wilayahSelect) wilayahSelect.value = '';
    if (kecamatanSelect) kecamatanSelect.value = '';
    if (leafSelect) leafSelect.value = '';
    if (toggleAllKecamatan) toggleAllKecamatan.checked = false;
    if (toggleAllLeaf) toggleAllLeaf.checked = false;
    if (toggleRoads) toggleRoads.checked = false;

    clearDynamicLayer('selectedKecamatan');
    clearDynamicLayer('allKecamatan');
    clearDynamicLayer('allLeafWilayah');
    clearDynamicLayer('roadsByKecamatan');
    syncLayerOnMap('allKecamatan', false);
    syncLayerOnMap('allLeafWilayah', false);
    syncLayerOnMap('roadsByKecamatan', false);
    syncHierarchyControlState();
    applyFilters();
}

/**
 * Advanced Filters Logic
 */
function applyFilters() {
    const query = document.getElementById('search-input').value.toLowerCase().trim();
    const kategori = document.getElementById('filter-kategori').value;
    const rating = parseFloat(document.getElementById('filter-rating').value) || 0;
    const harga = document.getElementById('filter-harga').value;
    const target = document.getElementById('filter-target').value;
    
    // Checked fasilitas
    const fasilitasCheckboxes = document.querySelectorAll('.filter-fasilitas:checked');
    const requiredFasilitas = Array.from(fasilitasCheckboxes).map(cb => cb.value);

    const filtered = allWisata.filter(w => {
        // 1. Search Query
        if (query) {
            const matchSearch = w.nama_tempat.toLowerCase().includes(query) ||
                                (w.deskripsi && w.deskripsi.toLowerCase().includes(query)) ||
                                (w.alamat && w.alamat.toLowerCase().includes(query));
            if (!matchSearch) return false;
        }

        // 2. Kategori
        if (kategori && w.kategori !== kategori) return false;

        // 3. Rating
        if (rating > 0) {
            const wRating = parseFloat(w.rating) || 0;
            if (wRating < rating) return false;
        }

        // 4. Harga Tiket
        if (harga === 'free' && parseFloat(w.harga_tiket) > 0) return false;
        if (harga === 'paid' && parseFloat(w.harga_tiket) === 0) return false;

        // 5. Target Pengunjung
        if (target && w.target_pengunjung !== target) return false;

        // 6. Fasilitas
        if (requiredFasilitas.length > 0) {
            // Cek apakah data wisata ini punya fasilitas dari tabel wisata_fasilitas
            if (!w.fasilitas) return false; // jika tidak ada fasilitas sama sekali
            
            // Cek setiap fasilitas yang dicentang
            for (let f of requiredFasilitas) {
                // asumsi API mereturn relasi fasilitas dalam bentuk array string atau boolean object
                // Berdasarkan rpc Supabase sebelumnya: json_agg(f.nama_fasilitas) -> array of string
                // Let's assume w.fasilitas is an array of strings ["toilet", "parkir"] etc.
                const hasFacility = Array.isArray(w.fasilitas) && w.fasilitas.some(fac => fac.toLowerCase() === f.toLowerCase());
                
                // Atau jika formatnya boolean (w.toilet = true)
                const hasBooleanFacility = w[f] === true;
                
                if (!hasFacility && !hasBooleanFacility) {
                    return false;
                }
            }
        }

        // 7. Filter wilayah aktif berdasarkan polygon yang sedang dipilih
        if (!isWisataInsideActivePolygon(w)) {
            return false;
        }

        return true;
    });

    renderWisataList(filtered);
    renderMarkers(filtered);
    updateStats(allWisata.length, filtered.length);
    handleInitialQueryState(filtered);
}

window.showDetail = showDetail;
window.routeToWisata = routeToWisata;
window.stepModalGallery = stepModalGallery;

function handleInitialQueryState(filteredWisata) {
    if (initialQueryHandled) {
        return;
    }

    if (!initialFocusWisataId) {
        initialQueryHandled = true;
        return;
    }

    const target = (filteredWisata || []).find(w => Number(w.id) === initialFocusWisataId)
        || allWisata.find(w => Number(w.id) === initialFocusWisataId);

    if (!target || !target.latitude || !target.longitude) {
        initialQueryHandled = true;
        return;
    }

    initialQueryHandled = true;

    const targetLat = parseFloat(target.latitude);
    const targetLng = parseFloat(target.longitude);

    map.flyTo([targetLat, targetLng], 16, {
        duration: 1.15,
    });

    if (initialFocusView === 'detail') {
        setTimeout(() => {
            showDetail(target.id);
        }, 650);
        return;
    }

    markersLayer.eachLayer(layer => {
        if (layer.wisataId === target.id) {
            setTimeout(() => layer.openPopup(), 650);
        }
    });
}



