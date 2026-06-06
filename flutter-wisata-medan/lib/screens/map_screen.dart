/// ============================================================
/// Tourscape MS - Map Screen (OpenStreetMap)
/// Menampilkan point wisata dari Supabase + line/polygon dari Supabase RPC atau API CI4
/// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_theme.dart';
import '../main.dart';
import '../models/geojson_layer_model.dart';
import '../models/kategori_model.dart';
import '../models/wilayah_model.dart';
import '../models/wisata_model.dart';
import '../services/geojson_layer_service.dart';
import '../services/supabase_wisata_service.dart';
import '../services/wilayah_api_service.dart';
import '../utils/network_error_helper.dart';
import '../utils/polyline_decoder.dart';
import '../widgets/geojson_map_layers.dart';
import '../widgets/wilayah_filter_card.dart';
import 'input_wisata_screen.dart';

class MapScreen extends StatefulWidget {
  final Wisata? initialRouteTarget;
  final Wisata? initialDetailTarget;

  const MapScreen({
    super.key,
    this.initialRouteTarget,
    this.initialDetailTarget,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  static const String _allKategoriValue = '__all_categories__';
  static const double _detailPanelCollapsedSize = 0.18;
  static const double _detailPanelInitialSize = 0.48;
  static const double _detailPanelExpandedSize = 0.88;
  static const double _detailPanelExpandedThreshold = 0.7;

  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final PageController _detailPhotoController = PageController();
  final DraggableScrollableController _detailSheetController =
      DraggableScrollableController();
  AnimationController? _mapMoveController;
  final Map<int, Future<String>> _wisataListKotaKabupatenFutures = {};

  static const LatLng _medanCenter = LatLng(3.5952, 98.6722);

  String? _selectedKategori;
  List<String> _availableKategoriNames = const [];
  Position? _userPosition;

  List<LatLng>? _routePoints;
  Wisata? _routeTarget;
  double? _routeDistanceKm;
  double? _routeDurationMin;
  bool _isLoadingRoute = false;
  Wisata? _selectedWisataDetail;
  String? _selectedWisataKotaKabupaten;
  bool _isLoadingSelectedWisataDetail = false;
  int _selectedWisataPhotoIndex = 0;
  bool _isDetailPanelExpandedPhaseTwo = false;

  GeoLayerData? _selectedWilayahRoadLayer;
  GeoLayerData? _selectedWilayahPolygonLayer;
  GeoLayerData? _allKecamatanPolygonLayer;
  GeoLayerData? _allLeafWilayahPolygonLayer;
  GeoLayerData? _boundaryMedanLayer;
  GeoLayerData? _boundaryDeliSerdangLayer;

  bool _showSelectedRoads = false;
  bool _showSelectedKecamatan = false;
  bool _showAllKecamatan = false;
  bool _showAllLeafWilayah = false;
  bool _showBoundaryMedan = true;
  bool _showBoundaryDeliSerdang = true;
  bool _isWilayahPanelExpanded = false;
  bool _isLayerPanelExpanded = false;
  final Set<String> _loadingLayerKeys = <String>{};
  Timer? _selectedRoadRefreshDebounce;
  StreamSubscription<ServiceStatus>? _locationServiceSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _lastSelectedRoadKey;
  String? _lastAllKecamatanKey;
  String? _lastAllLeafKey;
  List<WilayahOption> _topLevelWilayahOptions = const [];
  List<WilayahOption> _kecamatanOptions = const [];
  List<WilayahOption> _leafWilayahOptions = const [];
  int? _selectedTopLevelWilayahId;
  int? _selectedKecamatanId;
  int? _selectedLeafWilayahId;
  bool _isLoadingWilayahOptions = false;
  bool _hasAttemptedInitialRoute = false;
  LatLng? _longPressPreviewPoint;
  LatLng? _coordinateQuickActionPoint;
  WilayahHierarchyResolution? _coordinateQuickActionResolution;
  bool _isResolvingCoordinateQuickAction = false;
  bool _hasCenteredOnUserLocation = false;
  String? _lastSnackbarMessage;
  DateTime? _lastSnackbarAt;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detailSheetController.addListener(_handleDetailSheetExtentChanged);
    _initializeLocationTracking();
    _loadInitialBoundaryLayers();
    _loadKategoriOptions();
    _loadTopLevelWilayahOptions();
    _prepareInitialDetailTarget();
    _prepareInitialRouteTarget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selectedRoadRefreshDebounce?.cancel();
    _locationServiceSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _mapMoveController?.dispose();
    _detailSheetController.removeListener(_handleDetailSheetExtentChanged);
    _detailSheetController.dispose();
    _detailPhotoController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleLocationServiceResumed();
    }
  }

  void _handleDetailSheetExtentChanged() {
    if (!_detailSheetController.isAttached) {
      return;
    }

    final isExpanded =
        _detailSheetController.size >= _detailPanelExpandedThreshold;
    if (isExpanded == _isDetailPanelExpandedPhaseTwo || !mounted) {
      return;
    }

    setState(() {
      _isDetailPanelExpandedPhaseTwo = isExpanded;
    });
  }

  Future<void> _loadInitialBoundaryLayers() async {
    try {
      await Future.wait([
        _ensureLayerLoaded('boundaryMedan', showError: false),
        _ensureLayerLoaded('boundaryDeliSerdang', showError: false),
      ]);
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          NetworkErrorHelper.normalizeMessage(
            e,
            fallback: 'Gagal memuat layer GIS.',
          ),
          isError: true,
        );
      }
    }
  }

  Future<void> _loadKategoriOptions() async {
    try {
      final response = await _supabase
          .from('kategori')
          .select('id, nama_kategori')
          .order('nama_kategori', ascending: true);

      final kategoriNames = (response as List)
          .map((item) => Kategori.fromJson(item).namaKategori.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _availableKategoriNames = kategoriNames;
      });
    } catch (error) {
      debugPrint('loadKategoriOptions error: $error');
    }
  }

  Future<void> _ensureLayerLoaded(String layerKey,
      {bool showError = true}) async {
    if (_isLayerLoaded(layerKey) || _loadingLayerKeys.contains(layerKey)) {
      return;
    }

    setState(() => _loadingLayerKeys.add(layerKey));

    try {
      final layerData = await _fetchLayerData(layerKey);
      if (!mounted) {
        return;
      }

      setState(() {
        switch (layerKey) {
          case 'boundaryMedan':
            _boundaryMedanLayer = layerData;
            break;
          case 'boundaryDeliSerdang':
            _boundaryDeliSerdangLayer = layerData;
            break;
        }
      });
    } catch (e) {
      if (mounted && showError) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _loadingLayerKeys.remove(layerKey));
      }
    }
  }

  Future<GeoLayerData> _fetchLayerData(String layerKey) {
    switch (layerKey) {
      case 'boundaryMedan':
        return GeoJsonLayerService.fetchBoundariesMedan();
      case 'boundaryDeliSerdang':
        return GeoJsonLayerService.fetchBoundariesDeliSerdang();
      default:
        throw Exception('Layer tidak dikenali: $layerKey');
    }
  }

  bool _isLayerLoaded(String layerKey) {
    switch (layerKey) {
      case 'boundaryMedan':
        return _boundaryMedanLayer != null;
      case 'boundaryDeliSerdang':
        return _boundaryDeliSerdangLayer != null;
      default:
        return false;
    }
  }

  Future<void> _toggleLayer(String layerKey, bool value) async {
    if (value &&
        (layerKey == 'boundaryMedan' || layerKey == 'boundaryDeliSerdang')) {
      await _ensureLayerLoaded(layerKey);
    } else if (mounted && layerKey == 'selectedRoads' && !value) {
      setState(() {
        _selectedWilayahRoadLayer = null;
        _lastSelectedRoadKey = null;
      });
    } else if (mounted && layerKey == 'selectedKecamatan' && !value) {
      setState(() {
        _selectedWilayahPolygonLayer = null;
      });
    } else if (mounted && layerKey == 'allKecamatan' && !value) {
      setState(() {
        _allKecamatanPolygonLayer = null;
        _lastAllKecamatanKey = null;
      });
    } else if (mounted && layerKey == 'allLeafWilayah' && !value) {
      setState(() {
        _allLeafWilayahPolygonLayer = null;
        _lastAllLeafKey = null;
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      switch (layerKey) {
        case 'selectedRoads':
          _showSelectedRoads = value;
          break;
        case 'selectedKecamatan':
          _showSelectedKecamatan = value;
          break;
        case 'allKecamatan':
          _showAllKecamatan = value;
          break;
        case 'allLeafWilayah':
          _showAllLeafWilayah = value;
          break;
        case 'boundaryMedan':
          _showBoundaryMedan = value;
          break;
        case 'boundaryDeliSerdang':
          _showBoundaryDeliSerdang = value;
          break;
      }
    });

    if (value && layerKey == 'selectedKecamatan' && _activeWilayahId != null) {
      await _loadSelectedWilayahPolygon(_activeWilayahId!, fitAfterLoad: false);
    }

    if (value &&
        layerKey == 'allKecamatan' &&
        _selectedTopLevelWilayahId != null) {
      await _loadAllKecamatanPolygons(force: true);
    }

    if (value && layerKey == 'allLeafWilayah' && _selectedKecamatanId != null) {
      await _loadAllLeafWilayahPolygons(force: true);
    }

    if (value && layerKey == 'selectedRoads' && _activeRoadWilayahId != null) {
      await _loadSelectedWilayahRoads(force: true);
    }
  }

  void _handleMapPositionChanged(MapCamera camera, bool hasGesture) {
    _scheduleSelectedRoadRefresh();
  }

  void _scheduleSelectedRoadRefresh({bool force = false}) {
    _selectedRoadRefreshDebounce?.cancel();
    _selectedRoadRefreshDebounce = Timer(
      const Duration(milliseconds: 220),
      () => _refreshSelectedRoadLayer(force: force),
    );
  }

  Future<void> _refreshSelectedRoadLayer({bool force = false}) async {
    if (!_showSelectedRoads || _activeRoadWilayahId == null) {
      return;
    }

    await _loadSelectedWilayahRoads(force: force);
  }

  int? get _activeWilayahId =>
      _selectedLeafWilayahId ??
      _selectedKecamatanId ??
      _selectedTopLevelWilayahId;
  int? get _activeRoadWilayahId => _selectedLeafWilayahId;

  Future<void> _loadTopLevelWilayahOptions() async {
    setState(() => _isLoadingWilayahOptions = true);

    try {
      final data = await WilayahApiService.fetchTopLevelWilayah();
      if (!mounted) {
        return;
      }

      setState(() {
        _topLevelWilayahOptions = data;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWilayahOptions = false);
      }
    }
  }

  Future<void> _loadKecamatanOptionsForTopLevel(int topLevelId) async {
    setState(() => _isLoadingWilayahOptions = true);

    try {
      final data = await WilayahApiService.fetchChildren(
        topLevelId,
        kategori: 'kecamatan',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _kecamatanOptions = data;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWilayahOptions = false);
      }
    }
  }

  Future<void> _loadLeafOptionsForKecamatan(int kecamatanId) async {
    setState(() => _isLoadingWilayahOptions = true);

    try {
      final data =
          await WilayahApiService.fetchKelurahan(kecamatanId: kecamatanId);
      if (!mounted) {
        return;
      }

      setState(() {
        _leafWilayahOptions = data;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWilayahOptions = false);
      }
    }
  }

  Future<void> _onTopLevelWilayahChanged(int? wilayahId) async {
    _selectedRoadRefreshDebounce?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTopLevelWilayahId = wilayahId;
      _selectedKecamatanId = null;
      _selectedLeafWilayahId = null;
      _kecamatanOptions = const [];
      _leafWilayahOptions = const [];
      _selectedWilayahPolygonLayer = null;
      _allKecamatanPolygonLayer = null;
      _allLeafWilayahPolygonLayer = null;
      _selectedWilayahRoadLayer = null;
      _lastSelectedRoadKey = null;
      _lastAllKecamatanKey = null;
      _lastAllLeafKey = null;
      _showSelectedKecamatan = wilayahId != null;
      _showSelectedRoads = false;
    });

    if (wilayahId == null) {
      return;
    }

    await _loadKecamatanOptionsForTopLevel(wilayahId);
    await _loadSelectedWilayahPolygon(wilayahId, fitAfterLoad: true);
    if (_showAllKecamatan) {
      await _loadAllKecamatanPolygons(force: true);
    }
  }

  Future<void> _onKecamatanChanged(int? kecamatanId) async {
    _selectedRoadRefreshDebounce?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedKecamatanId = kecamatanId;
      _selectedLeafWilayahId = null;
      _leafWilayahOptions = const [];
      _selectedWilayahPolygonLayer = null;
      _allLeafWilayahPolygonLayer = null;
      _selectedWilayahRoadLayer = null;
      _lastSelectedRoadKey = null;
      _lastAllLeafKey = null;
      _showSelectedKecamatan = _activeWilayahId != null;
      _showSelectedRoads = false;
    });

    if (kecamatanId != null) {
      await _loadLeafOptionsForKecamatan(kecamatanId);
    }

    if (_activeWilayahId == null) {
      return;
    }

    await _loadSelectedWilayahPolygon(_activeWilayahId!, fitAfterLoad: true);
    if (_showAllLeafWilayah) {
      await _loadAllLeafWilayahPolygons(force: true);
    }
  }

  Future<void> _onLeafWilayahChanged(int? wilayahId) async {
    _selectedRoadRefreshDebounce?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLeafWilayahId = wilayahId;
      _selectedWilayahPolygonLayer = null;
      _selectedWilayahRoadLayer = null;
      _lastSelectedRoadKey = null;
      _showSelectedKecamatan = _activeWilayahId != null;
      if (wilayahId == null) {
        _showSelectedRoads = false;
      }
    });

    if (_activeWilayahId == null) {
      return;
    }

    await _loadSelectedWilayahPolygon(_activeWilayahId!, fitAfterLoad: true);
    if (_showSelectedRoads) {
      await _loadSelectedWilayahRoads(force: true);
    }
  }

  void _resetWilayahFilters() {
    _selectedRoadRefreshDebounce?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTopLevelWilayahId = null;
      _selectedKecamatanId = null;
      _selectedLeafWilayahId = null;
      _kecamatanOptions = const [];
      _leafWilayahOptions = const [];
      _selectedWilayahPolygonLayer = null;
      _allKecamatanPolygonLayer = null;
      _allLeafWilayahPolygonLayer = null;
      _selectedWilayahRoadLayer = null;
      _lastSelectedRoadKey = null;
      _lastAllKecamatanKey = null;
      _lastAllLeafKey = null;
      _showSelectedKecamatan = false;
      _showAllKecamatan = false;
      _showAllLeafWilayah = false;
      _showSelectedRoads = false;
    });
  }

  Future<void> _loadAllKecamatanPolygons({bool force = false}) async {
    final topLevelId = _selectedTopLevelWilayahId;
    if (!_showAllKecamatan || topLevelId == null) {
      if (mounted) {
        setState(() {
          _allKecamatanPolygonLayer = null;
          _lastAllKecamatanKey = null;
        });
      }
      return;
    }

    final cacheKey = '$topLevelId:${_mapController.camera.zoom.round()}';
    if (!force && cacheKey == _lastAllKecamatanKey) {
      return;
    }

    if (_loadingLayerKeys.contains('allKecamatan')) {
      return;
    }

    setState(() => _loadingLayerKeys.add('allKecamatan'));

    try {
      final merged = await _loadMergedPolygonLayer(
        _kecamatanOptions.map((item) => item.id).toList(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _allKecamatanPolygonLayer = merged;
        _lastAllKecamatanKey = cacheKey;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLayerKeys.remove('allKecamatan'));
      }
    }
  }

  Future<void> _loadAllLeafWilayahPolygons({bool force = false}) async {
    final kecamatanId = _selectedKecamatanId;
    if (!_showAllLeafWilayah || kecamatanId == null) {
      if (mounted) {
        setState(() {
          _allLeafWilayahPolygonLayer = null;
          _lastAllLeafKey = null;
        });
      }
      return;
    }

    final cacheKey = '$kecamatanId:${_mapController.camera.zoom.round()}';
    if (!force && cacheKey == _lastAllLeafKey) {
      return;
    }

    if (_loadingLayerKeys.contains('allLeafWilayah')) {
      return;
    }

    setState(() => _loadingLayerKeys.add('allLeafWilayah'));

    try {
      final merged = await _loadMergedPolygonLayer(
        _leafWilayahOptions.map((item) => item.id).toList(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _allLeafWilayahPolygonLayer = merged;
        _lastAllLeafKey = cacheKey;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLayerKeys.remove('allLeafWilayah'));
      }
    }
  }

  Future<GeoLayerData> _loadMergedPolygonLayer(List<int> wilayahIds) async {
    if (wilayahIds.isEmpty) {
      return const GeoLayerData();
    }

    final results = await Future.wait(
      wilayahIds.map((wilayahId) async {
        try {
          return await GeoJsonLayerService.fetchWilayahPolygon(
            wilayahId,
            zoom: _mapController.camera.zoom,
          );
        } catch (_) {
          return const GeoLayerData();
        }
      }),
    );

    return GeoLayerData(
      lines: [
        for (final layer in results) ...layer.lines,
      ],
      polygons: [
        for (final layer in results) ...layer.polygons,
      ],
    );
  }

  void _toggleOverlayWindow(String panelKey) {
    setState(() {
      if (panelKey == 'wilayah') {
        _isWilayahPanelExpanded = !_isWilayahPanelExpanded;
        if (_isWilayahPanelExpanded) {
          _isLayerPanelExpanded = false;
        }
      } else {
        _isLayerPanelExpanded = !_isLayerPanelExpanded;
        if (_isLayerPanelExpanded) {
          _isWilayahPanelExpanded = false;
        }
      }
    });
  }

  void _closeTopOverlayPanels() {
    if (!_isWilayahPanelExpanded && !_isLayerPanelExpanded) {
      return;
    }

    setState(() {
      _isWilayahPanelExpanded = false;
      _isLayerPanelExpanded = false;
    });
  }

  Future<void> _loadSelectedWilayahPolygon(
    int wilayahId, {
    required bool fitAfterLoad,
  }) async {
    if (_loadingLayerKeys.contains('selectedKecamatan')) {
      return;
    }

    setState(() => _loadingLayerKeys.add('selectedKecamatan'));

    try {
      final layerData = await GeoJsonLayerService.fetchWilayahPolygon(
        wilayahId,
        zoom: _mapController.camera.zoom,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedWilayahPolygonLayer = layerData;
      });

      if (fitAfterLoad) {
        _fitMapToGeoLayer(layerData);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLayerKeys.remove('selectedKecamatan'));
      }
    }
  }

  Future<void> _loadSelectedWilayahRoads({bool force = false}) async {
    final wilayahId = _activeRoadWilayahId;
    if (wilayahId == null || !_showSelectedRoads) {
      if (mounted && _selectedWilayahRoadLayer != null) {
        setState(() => _selectedWilayahRoadLayer = null);
      }
      return;
    }

    final roadKey = '$wilayahId:${_mapController.camera.zoom.round()}';
    if (!force && roadKey == _lastSelectedRoadKey) {
      return;
    }

    if (_loadingLayerKeys.contains('selectedRoads')) {
      return;
    }

    setState(() => _loadingLayerKeys.add('selectedRoads'));

    try {
      final layerData = await GeoJsonLayerService.fetchRoadsByWilayah(
        wilayahId: wilayahId,
        zoom: _mapController.camera.zoom,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedWilayahRoadLayer = layerData;
        _lastSelectedRoadKey = roadKey;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _lastSelectedRoadKey = null);
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLayerKeys.remove('selectedRoads'));
      }
    }
  }

  void _fitMapToGeoLayer(GeoLayerData layerData) {
    final points = <LatLng>[
      for (final polygon in layerData.polygons) ...polygon.points,
      for (final line in layerData.lines) ...line.points,
    ];

    if (points.isEmpty) {
      return;
    }

    final fittedCamera = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(32),
    ).fit(_mapController.camera);
    _animateMapMove(fittedCamera.center, fittedCamera.zoom);
  }

  void _animateMapMove(
    LatLng destination,
    double destinationZoom, {
    Duration duration = const Duration(milliseconds: 700),
    Curve curve = Curves.easeInOutCubic,
  }) {
    _mapMoveController?.stop();
    _mapMoveController?.dispose();

    final camera = _mapController.camera;
    final startCenter = camera.center;
    final startZoom = camera.zoom;

    if ((startCenter.latitude - destination.latitude).abs() < 0.000001 &&
        (startCenter.longitude - destination.longitude).abs() < 0.000001 &&
        (startZoom - destinationZoom).abs() < 0.001) {
      _mapController.move(destination, destinationZoom);
      return;
    }

    final latTween =
        Tween<double>(begin: startCenter.latitude, end: destination.latitude);
    final lngTween =
        Tween<double>(begin: startCenter.longitude, end: destination.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: destinationZoom);

    final controller = AnimationController(duration: duration, vsync: this);
    _mapMoveController = controller;

    final animation = CurvedAnimation(parent: controller, curve: curve);
    controller.addListener(() {
      _mapController.move(
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (identical(_mapMoveController, controller)) {
          _mapMoveController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  IconData _getCategoryIcon(String? kategori) {
    switch (kategori) {
      case 'Taman':
        return Icons.park_rounded;
      case 'Waterpark':
        return Icons.pool_rounded;
      case 'Kebun Binatang':
        return Icons.pets_rounded;
      case 'Museum':
        return Icons.museum_rounded;
      case 'Taman Bermain':
        return Icons.attractions_rounded;
      case 'Danau':
        return Icons.water_rounded;
      case 'Kuliner':
        return Icons.restaurant_rounded;
      case 'Religi':
        return Icons.mosque_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _getCategoryColor(String? kategori) {
    switch (kategori) {
      case 'Taman':
        return const Color(0xFF22C55E);
      case 'Waterpark':
        return const Color(0xFF06B6D4);
      case 'Kebun Binatang':
        return const Color(0xFFA855F7);
      case 'Museum':
        return const Color(0xFFF59E0B);
      case 'Taman Bermain':
        return const Color(0xFFEF4444);
      case 'Danau':
        return const Color(0xFF3B82F6);
      case 'Kuliner':
        return const Color(0xFFEC4899);
      case 'Religi':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _initializeLocationTracking() async {
    await _refreshUserLocation();

    _locationServiceSubscription?.cancel();
    _locationServiceSubscription =
        Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) {
        return;
      }

      if (status == ServiceStatus.enabled) {
        _refreshUserLocation();
      } else {
        _positionStreamSubscription?.cancel();
      }
    });
  }

  Future<void> _handleLocationServiceResumed() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) {
      return;
    }

    if (serviceEnabled) {
      await _refreshUserLocation();
    }
  }

  Future<void> _refreshUserLocation({bool showInactiveMessage = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _positionStreamSubscription?.cancel();
        if (showInactiveMessage) {
          _showSnackbar('Layanan lokasi tidak aktif');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Izin lokasi ditolak');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackbar('Izin lokasi ditolak secara permanen');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _updateUserPosition(position, moveCamera: !_hasCenteredOnUserLocation);
      _startPositionStream();
      _tryStartInitialRoute();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _startPositionStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        if (!mounted) {
          return;
        }

        _updateUserPosition(position);
        _tryStartInitialRoute();
      },
      onError: (error) {
        debugPrint('Position stream error: $error');
      },
    );
  }

  void _updateUserPosition(Position position, {bool moveCamera = false}) {
    if (!mounted) {
      return;
    }

    setState(() => _userPosition = position);

    if (moveCamera) {
      _hasCenteredOnUserLocation = true;
      _goToUserLocation();
    }
  }

  void _prepareInitialRouteTarget() {
    final target = widget.initialRouteTarget;
    if (target == null) {
      return;
    }

    if (target.latitude != null && target.longitude != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _animateMapMove(
          LatLng(target.latitude!, target.longitude!),
          14.5,
        );
      });
    }

    _tryStartInitialRoute();
  }

  void _prepareInitialDetailTarget() {
    final target = widget.initialDetailTarget;
    if (target == null) {
      return;
    }

    _hasCenteredOnUserLocation = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showWisataDetail(target);
    });
  }

  void _tryStartInitialRoute() {
    if (_hasAttemptedInitialRoute) {
      return;
    }

    final target = widget.initialRouteTarget;
    if (target == null || _userPosition == null) {
      return;
    }

    _hasAttemptedInitialRoute = true;
    _fetchRoute(target);
  }

  void _goToUserLocation() {
    if (_userPosition != null) {
      _animateMapMove(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        15.0,
      );
      _hasCenteredOnUserLocation = true;
    }
  }

  Future<void> _fetchRoute(Wisata target) async {
    if (_userPosition == null) {
      _showSnackbar('Lokasi user belum tersedia. Aktifkan GPS.', isError: true);
      return;
    }
    if (target.latitude == null || target.longitude == null) {
      _showSnackbar('Koordinat wisata tidak tersedia.', isError: true);
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeTarget = target;
    });

    try {
      final userLat = _userPosition!.latitude;
      final userLng = _userPosition!.longitude;
      final destLat = target.latitude!;
      final destLng = target.longitude!;

      final url =
          'https://router.project-osrm.org/route/v1/driving/$userLng,$userLat;$destLng,$destLat?overview=full&geometries=polyline';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 'Ok' &&
            json['routes'] != null &&
            (json['routes'] as List).isNotEmpty) {
          final route = json['routes'][0];
          final geometry = route['geometry'] as String;
          final distanceM = (route['distance'] as num).toDouble();
          final durationS = (route['duration'] as num).toDouble();

          final latlngPoints = PolylineDecoder.decode(geometry);

          setState(() {
            _routePoints = latlngPoints;
            _routeDistanceKm = distanceM / 1000;
            _routeDurationMin = durationS / 60;
            _isLoadingRoute = false;
          });

          if (latlngPoints.isNotEmpty) {
            double centerLat = 0;
            double centerLng = 0;
            for (final point in latlngPoints) {
              centerLat += point.latitude;
              centerLng += point.longitude;
            }
            centerLat /= latlngPoints.length;
            centerLng /= latlngPoints.length;
            _animateMapMove(LatLng(centerLat, centerLng), 13.0);
          }
        } else {
          throw Exception('Rute tidak ditemukan');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoadingRoute = false);
      _showSnackbar('Gagal mengambil rute: $e', isError: true);
    }
  }

  void _clearRoute() {
    setState(() {
      _routePoints = null;
      _routeTarget = null;
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });
  }

  void _showWisataDetail(Wisata wisata) {
    final lat = wisata.latitude;
    final lng = wisata.longitude;

    if (lat != null && lng != null) {
      _animateMapMove(LatLng(lat, lng), 14.8);
    }

    setState(() {
      _coordinateQuickActionPoint = null;
      _longPressPreviewPoint = null;
      _coordinateQuickActionResolution = null;
      _isResolvingCoordinateQuickAction = false;
      _routePoints = null;
      _routeTarget = null;
      _routeDistanceKm = null;
      _routeDurationMin = null;
      _selectedWisataDetail = wisata;
      _selectedWisataKotaKabupaten = null;
      _selectedWisataPhotoIndex = 0;
      _isLoadingSelectedWisataDetail = true;
      _isDetailPanelExpandedPhaseTwo = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_detailSheetController.isAttached) {
        _detailSheetController.animateTo(
          _detailPanelInitialSize,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      if (_detailPhotoController.hasClients) {
        _detailPhotoController.jumpToPage(0);
      }
    });

    _loadSelectedWisataDetail(wisata);
  }

  Future<void> _loadSelectedWisataDetail(Wisata wisata) async {
    try {
      final detail = await SupabaseWisataService.fetchWisataDetail(
        wisata.id,
        seedWisata: wisata,
      );
      if (!mounted) {
        return;
      }

      final resolved = detail ?? wisata;

      setState(() {
        _selectedWisataDetail = resolved;
        _isLoadingSelectedWisataDetail = false;
      });

      _resolveSelectedWisataKotaKabupaten(resolved);
      _precacheSelectedWisataPhotos(resolved.foto);
    } catch (error) {
      debugPrint('loadSelectedWisataDetail error: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedWisataDetail = wisata;
        _isLoadingSelectedWisataDetail = false;
      });

      _resolveSelectedWisataKotaKabupaten(wisata);
    }
  }

  void _precacheSelectedWisataPhotos(List<String> photos) {
    if (!mounted || photos.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final url in photos.take(3)) {
        precacheImage(NetworkImage(url), context);
      }
    });
  }

  Future<void> _resolveSelectedWisataKotaKabupaten(Wisata wisata) async {
    final lat = wisata.latitude;
    final lng = wisata.longitude;
    if (lat == null || lng == null) {
      return;
    }

    try {
      final resolution = await WilayahApiService.resolveFromPoint(
        lat: lat,
        lng: lng,
      );
      if (!mounted || _selectedWisataDetail?.id != wisata.id) {
        return;
      }

      final topLevelName = resolution.topLevel?.nama?.trim();
      if (topLevelName == null || topLevelName.isEmpty) {
        return;
      }

      setState(() {
        _selectedWisataKotaKabupaten = topLevelName;
      });
    } catch (error) {
      debugPrint('resolveSelectedWisataKotaKabupaten error: $error');
    }
  }

  Future<void> _closeSelectedWisataDetailAnimated() async {
    if (_selectedWisataDetail == null) {
      return;
    }

    if (_detailSheetController.isAttached) {
      await _detailSheetController.animateTo(
        _detailPanelCollapsedSize,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    if (!mounted) {
      return;
    }

    _closeSelectedWisataDetail();
  }

  void _closeSelectedWisataDetail() {
    setState(() {
      _selectedWisataDetail = null;
      _selectedWisataKotaKabupaten = null;
      _selectedWisataPhotoIndex = 0;
      _isLoadingSelectedWisataDetail = false;
      _isDetailPanelExpandedPhaseTwo = false;
    });
  }

  Future<void> _handleMapLongPress(LatLng point) async {
    if (_routeTarget != null) {
      return;
    }

    if (_isWilayahPanelExpanded || _isLayerPanelExpanded) {
      setState(() {
        _isWilayahPanelExpanded = false;
        _isLayerPanelExpanded = false;
      });
    }

    if (!_isPointInsideSupportedArea(point)) {
      return;
    }

    if (_selectedWisataDetail != null) {
      await _closeSelectedWisataDetailAnimated();
      if (!mounted) {
        return;
      }
    }

    _showCoordinateQuickAction(point);
  }

  bool _isPointInsideSupportedArea(LatLng point) {
    return _containsPointInLayer(_boundaryMedanLayer, point) ||
        _containsPointInLayer(_boundaryDeliSerdangLayer, point);
  }

  bool _containsPointInLayer(GeoLayerData? layer, LatLng point) {
    if (layer == null || layer.polygons.isEmpty) {
      return false;
    }

    for (final polygon in layer.polygons) {
      if (_isPointInPolygon(point, polygon.points)) {
        final isInsideHole = polygon.holes.any(
          (hole) => _isPointInPolygon(point, hole),
        );
        if (!isInsideHole) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) {
      return false;
    }

    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) *
                      (point.latitude - yi) /
                      ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersects) {
        inside = !inside;
      }
    }

    return inside;
  }

  GeoLayerData? _getActiveWisataFilterLayer() {
    if (_activeWilayahId == null || !_showSelectedKecamatan) {
      return null;
    }

    final layer = _selectedWilayahPolygonLayer;
    if (layer == null || layer.polygons.isEmpty) {
      return null;
    }

    return layer;
  }

  bool _isWisataInsideActiveFilter(Wisata wisata) {
    final layer = _getActiveWisataFilterLayer();
    if (layer == null) {
      return true;
    }

    final lat = wisata.latitude;
    final lng = wisata.longitude;
    if (lat == null || lng == null || lat.isNaN || lng.isNaN) {
      return false;
    }

    return _containsPointInLayer(layer, LatLng(lat, lng));
  }

  void _showCoordinateQuickAction(LatLng point) {
    setState(() {
      _longPressPreviewPoint = point;
      _coordinateQuickActionPoint = point;
      _coordinateQuickActionResolution = null;
      _isResolvingCoordinateQuickAction = true;
    });

    _resolveCoordinateQuickActionWilayah(point);
  }

  Future<void> _resolveCoordinateQuickActionWilayah(LatLng point) async {
    try {
      final resolution = await WilayahApiService.resolveFromPoint(
        lat: point.latitude,
        lng: point.longitude,
      );

      if (!mounted || _coordinateQuickActionPoint != point) {
        return;
      }

      setState(() {
        _coordinateQuickActionResolution = resolution;
        _isResolvingCoordinateQuickAction = false;
      });
    } catch (_) {
      if (!mounted || _coordinateQuickActionPoint != point) {
        return;
      }

      setState(() {
        _coordinateQuickActionResolution = null;
        _isResolvingCoordinateQuickAction = false;
      });
    }
  }

  void _openInputScreenAtPoint(LatLng point) {
    _closeCoordinateQuickAction();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InputWisataScreen(
          userPosition: _userPosition,
          initialLatitude: point.latitude,
          initialLongitude: point.longitude,
        ),
      ),
    );
  }

  void _closeCoordinateQuickAction() {
    setState(() {
      _coordinateQuickActionPoint = null;
      _longPressPreviewPoint = null;
      _coordinateQuickActionResolution = null;
      _isResolvingCoordinateQuickAction = false;
    });
  }

  void _goToInputScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InputWisataScreen(userPosition: _userPosition),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    final normalizedMessage = NetworkErrorHelper.normalizeMessage(
      message,
      fallback: message,
    );
    final isOfflineMessage =
        normalizedMessage == NetworkErrorHelper.offlineMessage;

    if (isOfflineMessage &&
        (_lastSnackbarMessage == NetworkErrorHelper.offlineMessage ||
            NetworkErrorHelper.shouldSuppressOfflineMessage())) {
      return;
    }

    final now = DateTime.now();
    final isRepeatedMessage = _lastSnackbarMessage == normalizedMessage &&
        _lastSnackbarAt != null &&
        now.difference(_lastSnackbarAt!) < const Duration(seconds: 3);

    if (isRepeatedMessage) {
      return;
    }

    _lastSnackbarMessage = normalizedMessage;
    _lastSnackbarAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(normalizedMessage),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<String> _resolveWisataListKotaKabupaten(Wisata wisata) {
    return _wisataListKotaKabupatenFutures.putIfAbsent(wisata.id, () async {
      final lat = wisata.latitude;
      final lng = wisata.longitude;
      if (lat == null || lng == null) {
        return '-';
      }

      try {
        final resolution = await WilayahApiService.resolveFromPoint(
          lat: lat,
          lng: lng,
        );
        final topLevelName = resolution.topLevel?.nama?.trim();
        if (topLevelName == null || topLevelName.isEmpty) {
          return '-';
        }

        return topLevelName;
      } catch (_) {
        return '-';
      }
    });
  }

  void _showWisataListSheet(List<Wisata> wisataList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.place_rounded,
                        color: AppTheme.primary(ctx), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      '${wisataList.length} Wisata Ditemukan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(ctx),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppTheme.textSecondary(ctx)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: wisataList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final w = wisataList[i];
                    final color = _getCategoryColor(w.kategori);
                    final ratingValue = w.ratingAvg ?? w.rating ?? 0;
                    final hasRating =
                        (w.totalReview ?? 0) > 0 || ratingValue > 0;
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showWisataDetail(w);
                        },
                        onLongPress: () {
                          Navigator.pop(ctx);
                          _fetchRoute(w);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWisataListCoverImage(w),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.namaTempat,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary(ctx),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            w.kategori ?? 'Umum',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _buildWisataPreviewRating(
                                          context: ctx,
                                          hasRating: hasRating,
                                          ratingValue: ratingValue,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    FutureBuilder<String>(
                                      future: _resolveWisataListKotaKabupaten(
                                        w,
                                      ),
                                      builder: (context, snapshot) {
                                        final cityName = snapshot.data ?? '-';
                                        final kecamatan =
                                            (w.kecamatan?.trim().isNotEmpty ??
                                                    false)
                                                ? w.kecamatan!.trim()
                                                : '-';
                                        final kelurahan =
                                            (w.kelurahan?.trim().isNotEmpty ??
                                                    false)
                                                ? w.kelurahan!.trim()
                                                : '-';
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 12,
                                              color:
                                                  AppTheme.textSecondary(ctx),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '$cityName, $kecamatan, $kelurahan',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme
                                                      .textSecondary(ctx),
                                                  height: 1.35,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.textSecondary(ctx), size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWisataListCoverImage(Wisata wisata) {
    final coverUrl = wisata.foto.isNotEmpty ? wisata.foto.first : null;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl == null || coverUrl.trim().isEmpty
          ? Icon(
              Icons.landscape_rounded,
              color: AppTheme.textSecondary(context),
              size: 24,
            )
          : Image.network(
              coverUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_rounded,
                color: AppTheme.textSecondary(context),
                size: 22,
              ),
            ),
    );
  }

  Widget _buildWisataPreviewRating({
    required BuildContext context,
    required bool hasRating,
    required double ratingValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.border(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 12,
            color: hasRating
                ? const Color(0xFFF59E0B)
                : AppTheme.textSecondary(context),
          ),
          const SizedBox(width: 3),
          Text(
            hasRating ? ratingValue.toStringAsFixed(1) : 'Belum ada rating',
            style: TextStyle(
              fontSize: 10,
              color: hasRating
                  ? AppTheme.textPrimary(context)
                  : AppTheme.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _activeKategoriLabel => _selectedKategori ?? 'Semua Kategori';

  Color _allKecamatanFillColor(BuildContext context) {
    return AppTheme.isDark(context)
        ? const Color(0x2438BDF8)
        : const Color(0x1838BDF8);
  }

  Color _allKecamatanBorderColor(BuildContext context) {
    return AppTheme.isDark(context)
        ? const Color(0xFF7DD3FC)
        : const Color(0xFF0284C7);
  }

  Color _selectedPolygonFillColor(BuildContext context) {
    return AppTheme.isDark(context)
        ? const Color(0x24F97316)
        : const Color(0x18EA580C);
  }

  Color _selectedPolygonBorderColor(BuildContext context) {
    return AppTheme.isDark(context)
        ? const Color(0xFFFBBF24)
        : const Color(0xFFEA580C);
  }

  Color _allLeafFillColor(BuildContext context) {
    return AppTheme.isDark(context)
        ? const Color(0x227C3AED)
        : const Color(0x167C3AED);
  }

  Widget _buildActiveKategoriChip(BuildContext context) {
    final hasCustomSelection = _selectedKategori != null;
    final activeColor = hasCustomSelection
        ? _getCategoryColor(_selectedKategori)
        : AppTheme.primary(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasCustomSelection
                ? _getCategoryIcon(_selectedKategori)
                : Icons.grid_view_rounded,
            size: 16,
            color: activeColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _activeKategoriLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          if (hasCustomSelection) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _selectedKategori = null),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Marker> _buildSpreadMarkers(List<_SpreadMarkerEntry> entries) {
    if (entries.isEmpty) {
      return const <Marker>[];
    }

    return entries
        .map(
          (entry) => Marker(
            point: entry.originalPoint,
            width: entry.width,
            height: entry.height,
            child: entry.child,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('wisata')
          .stream(primaryKey: ['id']).eq('status', 'approved'),
      builder: (context, snapshot) {
        var wisataList = <Wisata>[];
        var categories = <String>[];

        if (snapshot.hasData) {
          wisataList = snapshot.data!.map((e) => Wisata.fromJson(e)).toList();
          categories = wisataList
              .map((w) => w.kategori)
              .whereType<String>()
              .toSet()
              .toList();
        }

        final dbCategories = _availableKategoriNames
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
        final wisataCategories = categories
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
        final categoryOptions = <String>{
          ...dbCategories,
          ...wisataCategories,
        }.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        final filteredWisata = wisataList
            .where((w) =>
                _selectedKategori == null ||
                (w.kategori?.trim() ?? '') == _selectedKategori)
            .where(_isWisataInsideActiveFilter)
            .toList();

        final markerEntries = <_SpreadMarkerEntry>[];
        if (_longPressPreviewPoint != null) {
          markerEntries.add(
            _SpreadMarkerEntry(
              originalPoint: _longPressPreviewPoint!,
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          );
        }

        for (final w in filteredWisata) {
          if (w.latitude != null &&
              w.longitude != null &&
              !w.latitude!.isNaN &&
              !w.longitude!.isNaN) {
            final isSelectedDetail = _selectedWisataDetail?.id == w.id;
            markerEntries.add(
              _SpreadMarkerEntry(
                originalPoint: LatLng(w.latitude!, w.longitude!),
                width: isSelectedDetail ? 46 : 40,
                height: isSelectedDetail ? 46 : 40,
                child: GestureDetector(
                  onTap: () => _showWisataDetail(w),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelectedDetail
                          ? const Color(0xFFE53935)
                          : _getCategoryColor(w.kategori),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: isSelectedDetail ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: isSelectedDetail ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isSelectedDetail
                          ? Icons.place_rounded
                          : _getCategoryIcon(w.kategori),
                      color: Colors.white,
                      size: isSelectedDetail ? 24 : 20,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        if (_userPosition != null &&
            !_userPosition!.latitude.isNaN &&
            !_userPosition!.longitude.isNaN) {
          markerEntries.add(
            _SpreadMarkerEntry(
              originalPoint:
                  LatLng(_userPosition!.latitude, _userPosition!.longitude),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          );
        }

        final markers = _buildSpreadMarkers(markerEntries);

        final routePolylines = <Polyline>[];
        if (_routePoints != null && _routePoints!.isNotEmpty) {
          routePolylines.add(
            Polyline(
              points: _routePoints!,
              strokeWidth: 8,
              color: AppTheme.routeGlow,
            ),
          );
          routePolylines.add(
            Polyline(
              points: _routePoints!,
              strokeWidth: 4,
              color: AppTheme.routeColor,
            ),
          );
        }

        final isDark = themeNotifier.value == ThemeMode.dark;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 8,
            leadingWidth: 48,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/branding/app_icon_source.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            flexibleSpace: Container(
              decoration:
                  BoxDecoration(gradient: AppTheme.appBarGradient(context)),
            ),
            title: const Text(
              'Tourscape MS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildActiveKategoriChip(context),
              ),
              PopupMenuButton<String?>(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter Kategori',
                onSelected: (value) {
                  setState(() {
                    _selectedKategori =
                        value == _allKategoriValue ? null : value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _allKategoriValue,
                    child: Text('Semua Kategori'),
                  ),
                  ...categoryOptions.map(
                    (c) => PopupMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(_getCategoryIcon(c),
                              size: 18, color: _getCategoryColor(c)),
                          const SizedBox(width: 10),
                          Text(c),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              Listener(
                onPointerDown: (_) => _closeTopOverlayPanels(),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _medanCenter,
                    initialZoom: 12.0,
                    onPositionChanged: _handleMapPositionChanged,
                    onTap: (_, __) => _closeTopOverlayPanels(),
                    onLongPress: (_, point) => _handleMapLongPress(point),
                  ),
                  children: [
                    TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.example.flutter_wisata_medan',
                    ),
                    GeoJsonFeatureLayer(
                    data: _boundaryDeliSerdangLayer,
                    visible: _showBoundaryDeliSerdang,
                    polygonFillColor: const Color(0x1410B981),
                    polygonBorderColor: const Color(0xFF10B981),
                    polygonBorderWidth: 3.5,
                  ),
                  GeoJsonFeatureLayer(
                    data: _boundaryMedanLayer,
                    visible: _showBoundaryMedan,
                    polygonFillColor: const Color(0x14F59E0B),
                    polygonBorderColor: const Color(0xFFF59E0B),
                    polygonBorderWidth: 3.5,
                  ),
                  GeoJsonFeatureLayer(
                    data: _allKecamatanPolygonLayer,
                    visible: _showAllKecamatan,
                    polygonFillColor: _allKecamatanFillColor(context),
                    polygonBorderColor: _allKecamatanBorderColor(context),
                    polygonBorderWidth: 2.8,
                  ),
                  GeoJsonFeatureLayer(
                    data: _allLeafWilayahPolygonLayer,
                    visible: _showAllLeafWilayah,
                    polygonFillColor: _allLeafFillColor(context),
                    polygonBorderColor: const Color(0xFF7C3AED),
                    polygonBorderWidth: 2.0,
                  ),
                  GeoJsonFeatureLayer(
                    data: _selectedWilayahPolygonLayer,
                    visible: _showSelectedKecamatan,
                    polygonFillColor: _selectedPolygonFillColor(context),
                    polygonBorderColor: _selectedPolygonBorderColor(context),
                    polygonBorderWidth: 3.8,
                  ),
                  GeoJsonFeatureLayer(
                    data: _selectedWilayahRoadLayer,
                    visible: _showSelectedRoads,
                    lineColor: const Color(0xFF1D4ED8),
                    lineWidth: 1.6,
                  ),
                  PolylineLayer(polylines: routePolylines),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              if (!snapshot.hasData && !snapshot.hasError)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              if (_isLoadingRoute)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primary(context),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Menghitung rute...',
                          style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                top: _isDetailPanelExpandedPhaseTwo ? -180 : 16,
                left: 12,
                right: 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isDetailPanelExpandedPhaseTwo ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: _isDetailPanelExpandedPhaseTwo,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMapLauncherButton(
                                  label: 'Filter Wilayah',
                                  icon: Icons.account_tree_rounded,
                                  isActive: _isWilayahPanelExpanded,
                                  onTap: () => _toggleOverlayWindow('wilayah'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildMapLauncherButton(
                                  label: 'Legenda Peta',
                                  icon: Icons.layers_rounded,
                                  isActive: _isLayerPanelExpanded,
                                  onTap: () => _toggleOverlayWindow('layer'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _isWilayahPanelExpanded
                                ? Center(
                                    key: const ValueKey('wilayah-panel'),
                                    child: WilayahFilterCard(
                                      topLevelOptions: _topLevelWilayahOptions,
                                      kecamatanOptions: _kecamatanOptions,
                                      leafOptions: _leafWilayahOptions,
                                      selectedTopLevelId:
                                          _selectedTopLevelWilayahId,
                                      selectedKecamatanId: _selectedKecamatanId,
                                      selectedLeafId: _selectedLeafWilayahId,
                                      showAllKecamatan: _showAllKecamatan,
                                      showAllLeafWilayah:
                                          _showAllLeafWilayah,
                                      showSelectedRoads: _showSelectedRoads,
                                      isLoading: _isLoadingWilayahOptions,
                                      onResetFilters: _resetWilayahFilters,
                                      onTopLevelChanged:
                                          _onTopLevelWilayahChanged,
                                      onKecamatanChanged: _onKecamatanChanged,
                                      onLeafChanged: _onLeafWilayahChanged,
                                      onShowAllKecamatanChanged: (value) =>
                                          _toggleLayer(
                                              'allKecamatan', value),
                                      onShowAllLeafWilayahChanged: (value) =>
                                          _toggleLayer(
                                              'allLeafWilayah', value),
                                      onShowSelectedRoadsChanged: (value) =>
                                          _toggleLayer(
                                              'selectedRoads', value),
                                    ),
                                  )
                                : _isLayerPanelExpanded
                                    ? Center(
                                        key: const ValueKey('layer-panel'),
                                        child: GeoLayerTogglePanel(
                                          showBoundaryMedan:
                                              _showBoundaryMedan,
                                          showBoundaryDeliSerdang:
                                              _showBoundaryDeliSerdang,
                                          isLoading:
                                              _loadingLayerKeys.isNotEmpty,
                                          onBoundaryMedanChanged: (value) =>
                                              _toggleLayer(
                                                  'boundaryMedan', value),
                                          onBoundaryDeliSerdangChanged:
                                              (value) => _toggleLayer(
                                                  'boundaryDeliSerdang',
                                                  value),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('overlay-empty')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOut,
                bottom: 30,
                left: 16,
                child: GestureDetector(
                  onTap: filteredWisata.isNotEmpty
                      ? () => _showWisataListSheet(filteredWisata)
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${filteredWisata.length} wisata ditemukan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.expand_less_rounded,
                            size: 18, color: AppTheme.primary(context)),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: 30,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'location',
                      onPressed: _goToUserLocation,
                      backgroundColor: AppTheme.surface(context),
                      foregroundColor: AppTheme.primary(context),
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'add',
                      onPressed: _goToInputScreen,
                      backgroundColor: AppTheme.vibrantPrimary,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: const Text(
                        'Input Wisata',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomOverlayEntrance(
                  keyValue: _routeTarget != null &&
                          _routeDistanceKm != null &&
                          _routeDurationMin != null
                      ? 'route-panel-${_routeTarget!.id}'
                      : 'route-panel-empty',
                  child: _routeTarget != null &&
                          _routeDistanceKm != null &&
                          _routeDurationMin != null
                      ? _buildRouteInfoPanel()
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: _buildBottomOverlayEntrance(
                    keyValue: _coordinateQuickActionPoint != null
                        ? 'coordinate-panel-${_coordinateQuickActionPoint!.latitude.toStringAsFixed(6)}-${_coordinateQuickActionPoint!.longitude.toStringAsFixed(6)}'
                        : 'coordinate-panel-empty',
                    child: _coordinateQuickActionPoint != null
                        ? _buildCoordinateQuickActionPanel(
                            _coordinateQuickActionPoint!,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              if (_selectedWisataDetail != null)
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DraggableScrollableSheet(
                        controller: _detailSheetController,
                        initialChildSize: _detailPanelInitialSize,
                        minChildSize: _detailPanelCollapsedSize,
                        maxChildSize: _detailPanelExpandedSize,
                        snap: true,
                        snapSizes: const [
                          _detailPanelCollapsedSize,
                          _detailPanelInitialSize,
                          _detailPanelExpandedSize,
                        ],
                        builder: (context, scrollController) =>
                            _buildInlineWisataDetailPanel(
                              scrollController,
                              _selectedWisataDetail!,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomOverlayEntrance({
    required String keyValue,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 920),
      reverseDuration: const Duration(milliseconds: 920),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(keyValue),
        child: child,
      ),
    );
  }

  Widget _buildCoordinateQuickActionPanel(LatLng point) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.place_rounded,
                    color: AppTheme.primary(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoordinateQuickActionSummary(),
                ),
                IconButton(
                  onPressed: _closeCoordinateQuickAction,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondary(context),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.bg(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latitude',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.latitude.toStringAsFixed(6),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Longitude',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.longitude.toStringAsFixed(6),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInputScreenAtPoint(point),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text(
                  'Input Lokasi Baru',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.vibrantPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateQuickActionSummary() {
    if (_isResolvingCoordinateQuickAction) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Wilayah',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sedang mengambil nama kota/kabupaten, kecamatan, dan kelurahan/desa dari titik yang dipilih.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      );
    }

    final resolution = _coordinateQuickActionResolution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Wilayah',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        _buildCoordinateQuickActionInfoRow(
          'Kota / Kabupaten',
          resolution?.topLevel?.nama ?? '-',
        ),
        const SizedBox(height: 4),
        _buildCoordinateQuickActionInfoRow(
          'Kecamatan',
          resolution?.kecamatan?.nama ?? '-',
        ),
        const SizedBox(height: 4),
        _buildCoordinateQuickActionInfoRow(
          'Kelurahan / Desa',
          resolution?.leaf?.nama ?? '-',
        ),
      ],
    );
  }

  Widget _buildCoordinateQuickActionInfoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12.5,
          height: 1.45,
          color: AppTheme.textSecondary(context),
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildInlineWisataDetailPanel(
    ScrollController scrollController,
    Wisata wisata,
  ) {
    final photos = wisata.foto.where((item) => item.trim().isNotEmpty).toList();
    final categoryColor = _getCategoryColor(wisata.kategori);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _InlineDetailHeaderDelegate(
                height: 164,
                child: _buildInlineWisataDetailHeader(wisata, categoryColor),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInlineWisataPhotoGallery(photos),
                    const SizedBox(height: 16),
                    Text(
                      wisata.deskripsi?.trim().isNotEmpty == true
                          ? wisata.deskripsi!
                          : 'Tidak ada deskripsi.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildInlineWisataInfoSection(wisata),
                    const SizedBox(height: 18),
                    _buildInlineWisataFacilities(wisata),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _closeSelectedWisataDetail();
                          _fetchRoute(wisata);
                        },
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text(
                          'Mulai Navigasi',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.vibrantPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingSelectedWisataDetail)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: AppTheme.primary(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineWisataDetailHeader(Wisata wisata, Color categoryColor) {
    final ratingValue = wisata.ratingAvg ?? wisata.rating ?? 0;
    final hasRating = (wisata.totalReview ?? 0) > 0 || ratingValue > 0;
    final ratingLabel = hasRating
        ? '${ratingValue.toStringAsFixed(1)}${(wisata.totalReview ?? 0) > 0 ? ' • ${wisata.totalReview} ulasan' : ''}'
        : 'Belum ada rating';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border(context),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wisata.namaTempat,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildDetailBadge(
                            wisata.kategori?.isNotEmpty == true
                                ? wisata.kategori!
                                : 'Lainnya',
                            categoryColor,
                            Icons.category_rounded,
                          ),
                          _buildDetailBadge(
                            wisata.targetPengunjung?.isNotEmpty == true
                                ? _capitalizeFirstLetter(
                                    wisata.targetPengunjung!,
                                  )
                                : 'Umum',
                            const Color(0xFF3B82F6),
                            Icons.groups_rounded,
                          ),
                          _buildDetailBadge(
                            ratingLabel,
                            hasRating
                                ? const Color(0xFFF59E0B)
                                : AppTheme.textSecondary(context),
                            Icons.star_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _closeSelectedWisataDetail,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondary(context),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.bg(context),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: AppTheme.border(context).withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineWisataPhotoGallery(List<String> photos) {
    return Container(
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photos.isEmpty
                ? Container(
                    color: AppTheme.card(context),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.landscape_rounded,
                      size: 82,
                      color:
                          AppTheme.textPrimary(context).withValues(alpha: 0.22),
                    ),
                  )
                : PageView.builder(
                    controller: _detailPhotoController,
                    itemCount: photos.length,
                    onPageChanged: (index) {
                      setState(() => _selectedWisataPhotoIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        color: Colors.black,
                        child: Image.network(
                          photos[index],
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                          frameBuilder: (context, child, frame, _) {
                            if (frame != null) {
                              return child;
                            }

                            return Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppTheme.primary(context),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.card(context),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 70,
                              color: AppTheme.textPrimary(context)
                                  .withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (photos.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Wrap(
                spacing: 6,
                children: List.generate(
                  photos.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _selectedWisataPhotoIndex == index ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _selectedWisataPhotoIndex == index
                          ? AppTheme.primary(context)
                          : AppTheme.border(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineWisataInfoSection(Wisata wisata) {
    final infoItems = <_InlineInfoItem>[
      _InlineInfoItem(
        'Alamat',
        _fallbackText(wisata.alamat),
        Icons.home_work_rounded,
      ),
      _InlineInfoItem(
        'Kota / Kabupaten',
        _buildSelectedWisataKotaKabupatenText(),
        Icons.apartment_rounded,
      ),
      _InlineInfoItem(
        'Kecamatan',
        _fallbackText(wisata.kecamatan),
        Icons.map_rounded,
      ),
      _InlineInfoItem(
        'Kelurahan / Desa',
        _fallbackText(wisata.kelurahan),
        Icons.location_city_rounded,
      ),
      _InlineInfoItem(
        'Harga Tiket',
        _buildHargaText(wisata.hargaTiket),
        Icons.confirmation_number_rounded,
      ),
      _InlineInfoItem(
        'Telepon',
        _fallbackText(wisata.noTelepon),
        Icons.phone_rounded,
      ),
      _InlineInfoItem(
        'Jam Operasional',
        _buildOperationalHoursText(wisata),
        Icons.schedule_rounded,
      ),
      _InlineInfoItem(
        'Koordinat',
        _buildCoordinateText(wisata),
        Icons.explore_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Detail',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        ...infoItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildInlineInfoCard(item.label, item.value, item.icon),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineWisataFacilities(Wisata wisata) {
    final facilities = <MapEntry<String, bool>>[
      MapEntry('Toilet', wisata.toilet),
      MapEntry('Parkir', wisata.parkir),
      MapEntry('Area Bermain', wisata.areaBermain),
      MapEntry('Tempat Makan', wisata.tempatMakan),
      MapEntry('Mushola', wisata.mushola),
      MapEntry('WiFi', wisata.wifi),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fasilitas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facilities.map((item) {
            final isActive = item.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primary(context).withValues(alpha: 0.12)
                    : AppTheme.card(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? AppTheme.primary(context).withValues(alpha: 0.35)
                      : AppTheme.border(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: isActive
                        ? AppTheme.primary(context)
                        : AppTheme.textSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppTheme.primary(context)
                          : AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInlineInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: AppTheme.primary(context),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSelectedWisataKotaKabupatenText() {
    final text = _selectedWisataKotaKabupaten?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }

    return '-';
  }

  String _capitalizeFirstLetter(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return text;
    }

    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  String _buildOperationalHoursText(Wisata wisata) {
    final open = wisata.jamBuka?.trim() ?? '';
    final close = wisata.jamTutup?.trim() ?? '';

    if (open.isEmpty && close.isEmpty) {
      return '-';
    }
    if (open.isEmpty) {
      return close;
    }
    if (close.isEmpty) {
      return open;
    }

    return '$open - $close';
  }

  String _buildHargaText(double? harga) {
    if (harga == null) {
      return '-';
    }
    if (harga == 0) {
      return 'Gratis';
    }
    if (harga % 1 == 0) {
      return 'Rp ${harga.toStringAsFixed(0)}';
    }

    return 'Rp ${harga.toString()}';
  }

  String _buildCoordinateText(Wisata wisata) {
    if (wisata.latitude == null || wisata.longitude == null) {
      return '-';
    }

    return '${wisata.latitude!.toStringAsFixed(6)}, ${wisata.longitude!.toStringAsFixed(6)}';
  }

  String _fallbackText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Widget _buildRouteInfoPanel() {
    final target = _routeTarget!;
    final distKm = _routeDistanceKm!;
    final durMin = _routeDurationMin!;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppTheme.border(context))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.navigation_rounded,
                        color: AppTheme.primary(context), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Navigasi ke',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context)),
                        ),
                        Text(
                          target.namaTempat,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _clearRoute,
                    icon: Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary(context)),
                    style: IconButton.styleFrom(
                        backgroundColor: AppTheme.bg(context)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildRouteStatCard(
                      icon: Icons.straighten_rounded,
                      label: 'Jarak',
                      value: distKm < 1
                          ? '${(distKm * 1000).toStringAsFixed(0)} m'
                          : '${distKm.toStringAsFixed(1)} km',
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRouteStatCard(
                      icon: Icons.schedule_rounded,
                      label: 'Estimasi Waktu',
                      value: durMin < 60
                          ? '${durMin.toStringAsFixed(0)} menit'
                          : '${(durMin / 60).toStringAsFixed(0)} jam ${(durMin % 60).toStringAsFixed(0)} mnt',
                      color: AppTheme.primary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapLauncherButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? AppTheme.primary(context).withValues(alpha: 0.55)
                  : AppTheme.border(context),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? AppTheme.primary(context)
                    : AppTheme.textPrimary(context),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppTheme.primary(context)
                        : AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  _InlineDetailHeaderDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _InlineDetailHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _SpreadMarkerEntry {
  const _SpreadMarkerEntry({
    required this.originalPoint,
    required this.width,
    required this.height,
    required this.child,
  });

  final LatLng originalPoint;
  final double width;
  final double height;
  final Widget child;
}

class _InlineInfoItem {
  const _InlineInfoItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
