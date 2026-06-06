/// ============================================================
/// Tourscape MS — Input Wisata Screen
/// Form input data wisata baru + GPS koordinat
/// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_theme.dart';
import '../models/kategori_model.dart';
import '../models/wisata_model.dart';
import '../models/wilayah_model.dart';
import '../services/supabase_wisata_service.dart';
import '../services/wilayah_api_service.dart';
import '../utils/network_error_helper.dart';

class InputWisataScreen extends StatefulWidget {
  final Position? userPosition;
  final Wisata? existingWisata;
  final double? initialLatitude;
  final double? initialLongitude;

  const InputWisataScreen({
    super.key,
    this.userPosition,
    this.existingWisata,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<InputWisataScreen> createState() => _InputWisataScreenState();
}

class _InputWisataScreenState extends State<InputWisataScreen> {
  static const LatLng _defaultPreviewCenter = LatLng(3.5952, 98.6722);
  static const double _coordinatePreviewZoom = 15.5;

  final _formKey = GlobalKey<FormState>();
  final MapController _coordinatePreviewMapController = MapController();

  // Controllers
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _alamatController = TextEditingController();
  final _hargaController = TextEditingController();
  final _teleponController = TextEditingController();
  final _jamBukaController = TextEditingController();
  final _jamTutupController = TextEditingController();
  final _latManualController = TextEditingController();
  final _lngManualController = TextEditingController();

  // State
  List<Kategori> _kategoriList = [];
  List<WilayahOption> _topLevelWilayah = [];
  List<WilayahOption> _kecamatanOptions = [];
  List<WilayahOption> _kelurahanOptions = [];
  Kategori? _selectedKategori;
  String? _selectedKota;
  String? _selectedKecamatan;
  String? _selectedKelurahan;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isLoadingWilayah = false;
  bool _isResolvingWilayah = false;
  String _targetPengunjung = 'umum';
  bool _useGps = true; // true = GPS, false = manual input
  int _rating = 0; // 0 = belum dirating, 1-5
  List<String> _selectedHari = []; // hari operasional
  String? _wilayahResolutionMessage;
  String? _lastResolvedCoordinateKey;
  Timer? _coordinatePreviewResolveDebounce;
  bool _isCoordinatePreviewMapSyncing = false;
  String? _lastSnackbarMessage;
  DateTime? _lastSnackbarAt;

  // Fasilitas
  bool _toilet = false;
  bool _parkir = false;
  bool _areaBermain = false;
  bool _tempatMakan = false;
  bool _mushola = false;
  bool _wifi = false;

  // Foto
  List<String> _existingImageUrls = [];
  List<File> _imageFiles = [];
  Wisata? _editingWisataDetail;

  bool get _isEditingSubmission => widget.existingWisata != null;
  bool get _isRejectedSubmission =>
      (_editingWisataDetail ?? widget.existingWisata)?.status == 'rejected';
  int get _totalPhotoCount => _existingImageUrls.length + _imageFiles.length;

  @override
  void initState() {
    super.initState();
    _loadKategori();
    _loadTopLevelWilayah();

    if (widget.existingWisata != null) {
      _applyWisataToForm(widget.existingWisata!);
      _loadExistingSubmissionDetail();
    }

    // Set koordinat dari posisi user jika ada
    if (widget.existingWisata == null &&
        widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      _setCoordinateState(widget.initialLatitude!, widget.initialLongitude!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _resolveWilayahFromCurrentCoordinates(force: true);
      });
    } else if (widget.userPosition != null && widget.existingWisata == null) {
      _setCoordinateState(
        widget.userPosition!.latitude,
        widget.userPosition!.longitude,
      );
    }
  }

  @override
  void dispose() {
    _coordinatePreviewResolveDebounce?.cancel();
    _coordinatePreviewMapController.dispose();
    _namaController.dispose();
    _deskripsiController.dispose();
    _alamatController.dispose();
    _hargaController.dispose();
    _teleponController.dispose();
    _jamBukaController.dispose();
    _jamTutupController.dispose();
    _latManualController.dispose();
    _lngManualController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSubmissionDetail() async {
    final existing = widget.existingWisata;
    if (existing == null) {
      return;
    }

    try {
      final detail = await SupabaseWisataService.fetchWisataDetail(
        existing.id,
        seedWisata: existing,
      );
      if (!mounted || detail == null) {
        return;
      }

      _applyWisataToForm(detail);
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          NetworkErrorHelper.normalizeMessage(
            e,
            fallback: 'Gagal memuat detail pengajuan untuk diedit.',
          ),
          isError: true,
        );
      }
    }
  }

  void _applyWisataToForm(Wisata wisata) {
    _editingWisataDetail = wisata;
    _namaController.text = wisata.namaTempat;
    _deskripsiController.text = wisata.deskripsi ?? '';
    _alamatController.text = wisata.alamat ?? '';
    _hargaController.text = (() {
      final harga = wisata.hargaTiket ?? 0;
      return harga % 1 == 0 ? harga.toStringAsFixed(0) : harga.toString();
    })();
    _teleponController.text = wisata.noTelepon ?? '';
    _jamBukaController.text = _normalizeEditableTime(wisata.jamBuka);
    _jamTutupController.text = _normalizeEditableTime(wisata.jamTutup);
    _selectedKecamatan = wisata.kecamatan;
    _selectedKelurahan = wisata.kelurahan;
    _targetPengunjung = wisata.targetPengunjung?.trim().isNotEmpty == true
        ? wisata.targetPengunjung!
        : 'umum';
    _rating = (wisata.rating ?? 0).round();
    _selectedHari = _parseHariOperasional(wisata.hariOperasional);
    _toilet = wisata.toilet;
    _parkir = wisata.parkir;
    _areaBermain = wisata.areaBermain;
    _tempatMakan = wisata.tempatMakan;
    _mushola = wisata.mushola;
    _wifi = wisata.wifi;
    _existingImageUrls =
        wisata.foto.where((item) => item.trim().isNotEmpty).toList();

    if (wisata.latitude != null && wisata.longitude != null) {
      _setCoordinateState(wisata.latitude!, wisata.longitude!);
    }

    _syncSelectedKategoriFromName(wisata.kategori);

    if (_topLevelWilayah.isNotEmpty &&
        wisata.latitude != null &&
        wisata.longitude != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _resolveWilayahFromCurrentCoordinates(force: true);
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  void _syncSelectedKategoriFromName(String? kategoriName) {
    if (kategoriName == null || kategoriName.trim().isEmpty) {
      return;
    }

    final normalized = kategoriName.trim().toLowerCase();
    final match = _kategoriList.cast<Kategori?>().firstWhere(
          (item) => item?.namaKategori.trim().toLowerCase() == normalized,
          orElse: () => null,
        );

    if (match != null) {
      _selectedKategori = match;
    }
  }

  List<String> _parseHariOperasional(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return <String>[];
    }

    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _normalizeEditableTime(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '';
    }

    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  Future<void> _loadKategori() async {
    try {
      final response = await Supabase.instance.client
          .from('kategori')
          .select('id, nama_kategori')
          .order('nama_kategori', ascending: true);

      final list =
          (response as List).map((item) => Kategori.fromJson(item)).toList();

      if (mounted) {
        setState(() {
          _kategoriList = list;
          _syncSelectedKategoriFromName(widget.existingWisata?.kategori);
        });
      }
    } catch (e) {
      print('Error load kategori: $e');
    }
  }

  Future<void> _loadTopLevelWilayah() async {
    setState(() => _isLoadingWilayah = true);

    try {
      final items = await WilayahApiService.fetchTopLevelWilayah();
      if (!mounted) return;

      setState(() {
        _topLevelWilayah = items;
      });

      if (_latitude != null && _longitude != null) {
        await _resolveWilayahFromCurrentCoordinates();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWilayah = false);
      }
    }
  }

  Future<void> _loadKecamatanForSelectedKota({
    int? preselectedId,
    String? preselectedName,
    bool loadLeafAfter = false,
    int? preselectedLeafId,
    String? preselectedLeafName,
  }) async {
    final topLevel = _findOptionByName(_topLevelWilayah, _selectedKota);
    if (topLevel == null) {
      if (mounted) {
        setState(() {
          _kecamatanOptions = [];
          _kelurahanOptions = [];
          _selectedKecamatan = null;
          _selectedKelurahan = null;
        });
      }
      return;
    }

    setState(() => _isLoadingWilayah = true);

    try {
      final items = await WilayahApiService.fetchChildren(
        topLevel.id,
        kategori: 'kecamatan',
      );
      if (!mounted) return;

      final matchedKecamatan = _findOptionByIdOrName(
        items,
        id: preselectedId,
        name: preselectedName ?? _selectedKecamatan,
      );

      setState(() {
        _kecamatanOptions = items;
        _selectedKecamatan = matchedKecamatan?.nama;
        _kelurahanOptions = [];
        _selectedKelurahan = null;
      });

      if (loadLeafAfter && matchedKecamatan != null) {
        await _loadKelurahanForSelectedKecamatan(
          preselectedId: preselectedLeafId,
          preselectedName: preselectedLeafName,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWilayah = false);
      }
    }
  }

  Future<void> _loadKelurahanForSelectedKecamatan({
    int? preselectedId,
    String? preselectedName,
  }) async {
    final kecamatan = _findOptionByName(_kecamatanOptions, _selectedKecamatan);
    if (kecamatan == null) {
      if (mounted) {
        setState(() {
          _kelurahanOptions = [];
          _selectedKelurahan = null;
        });
      }
      return;
    }

    setState(() => _isLoadingWilayah = true);

    try {
      final items = await WilayahApiService.fetchKelurahan(
        kecamatanId: kecamatan.id,
      );
      if (!mounted) return;

      final matchedLeaf = _findOptionByIdOrName(
        items,
        id: preselectedId,
        name: preselectedName ?? _selectedKelurahan,
      );

      setState(() {
        _kelurahanOptions = items;
        _selectedKelurahan = matchedLeaf?.nama;
      });
    } catch (e) {
      if (mounted) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWilayah = false);
      }
    }
  }

  Future<void> _applyCoordinates(
    double lat,
    double lng, {
    String? successMessage,
    bool showResolveFeedback = false,
  }) async {
    _setCoordinateState(lat, lng);

    final isWithinCoverage = await _resolveWilayahFromCurrentCoordinates(
      showFeedback: showResolveFeedback,
      force: true,
    );

    if (isWithinCoverage && successMessage != null && mounted) {
      _showSnackbar(successMessage);
    }
  }

  void _setCoordinateState(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    _latManualController.text = lat.toStringAsFixed(6);
    _lngManualController.text = lng.toStringAsFixed(6);
    _scheduleCoordinatePreviewSync();
  }

  LatLng get _coordinatePreviewCenter {
    final lat = _latitude;
    final lng = _longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    return _defaultPreviewCenter;
  }

  void _handleManualCoordinateInputChanged() {
    final parsedLat = double.tryParse(_latManualController.text.trim());
    final parsedLng = double.tryParse(_lngManualController.text.trim());

    setState(() {
      _latitude = parsedLat;
      _longitude = parsedLng;
    });

    if (_hasValidCoordinatePair(parsedLat, parsedLng)) {
      _scheduleCoordinatePreviewSync();
    }
  }

  bool _hasValidCoordinatePair(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return false;
    }

    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  void _scheduleCoordinatePreviewSync() {
    final lat = _latitude;
    final lng = _longitude;
    if (!_hasValidCoordinatePair(lat, lng)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      try {
        final currentZoom = _coordinatePreviewMapController.camera.zoom;
        _isCoordinatePreviewMapSyncing = true;
        _coordinatePreviewMapController.move(
          LatLng(lat!, lng!),
          currentZoom.isFinite ? currentZoom : _coordinatePreviewZoom,
        );
      } catch (_) {
        // Preview map belum terpasang di tree. Biarkan initialCenter menangani state awal.
      } finally {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isCoordinatePreviewMapSyncing = false;
        });
      }
    });
  }

  void _handleCoordinatePreviewPositionChanged(
    MapCamera camera,
    bool hasGesture,
  ) {
    if (_isCoordinatePreviewMapSyncing || !hasGesture) {
      return;
    }

    final center = camera.center;
    final nextLat = center.latitude;
    final nextLng = center.longitude;

    if (_latitude != null &&
        _longitude != null &&
        (_latitude! - nextLat).abs() < 0.000001 &&
        (_longitude! - nextLng).abs() < 0.000001) {
      return;
    }

    setState(() {
      _latitude = nextLat;
      _longitude = nextLng;
      _latManualController.text = nextLat.toStringAsFixed(6);
      _lngManualController.text = nextLng.toStringAsFixed(6);
    });

    _coordinatePreviewResolveDebounce?.cancel();
    _coordinatePreviewResolveDebounce = Timer(
      const Duration(milliseconds: 450),
      () async {
        if (!mounted) {
          return;
        }

        await _resolveWilayahFromCurrentCoordinates(force: true);
      },
    );
  }

  Future<bool> _resolveWilayahFromCurrentCoordinates({
    bool showFeedback = false,
    bool force = false,
  }) async {
    final lat = _latitude;
    final lng = _longitude;

    if (lat == null || lng == null) {
      return false;
    }

    if (_topLevelWilayah.isEmpty) {
      return false;
    }

    final coordinateKey = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    if (!force &&
        _lastResolvedCoordinateKey == coordinateKey &&
        _selectedKota != null) {
      return true;
    }

    setState(() {
      _isResolvingWilayah = true;
      _wilayahResolutionMessage =
          'Mencocokkan koordinat dengan wilayah administratif...';
    });

    try {
      final resolution = await WilayahApiService.resolveFromPoint(
        lat: lat,
        lng: lng,
      );

      if (!mounted) return false;

      _lastResolvedCoordinateKey = coordinateKey;

      if (!resolution.hasResolvedHierarchy) {
        setState(() {
          _selectedKota = null;
          _selectedKecamatan = null;
          _selectedKelurahan = null;
          _kecamatanOptions = [];
          _kelurahanOptions = [];
          _wilayahResolutionMessage =
              'Lokasi yang dipilih berada di luar jangkauan Kota Medan dan Kabupaten Deli Serdang. Silakan pilih lokasi lain atau ubah wilayah secara manual.';
        });

        if (showFeedback) {
          _showSnackbar(
            'Lokasi yang dipilih di luar jangkauan Kota Medan dan Kabupaten Deli Serdang',
            isError: true,
          );
        }
        return false;
      }

      final topLevel = _findOptionByIdOrName(
        _topLevelWilayah,
        id: resolution.topLevel?.id,
        name: resolution.topLevel?.nama,
      );

      if (topLevel == null) {
        setState(() {
          _selectedKota = null;
          _selectedKecamatan = null;
          _selectedKelurahan = null;
          _kecamatanOptions = [];
          _kelurahanOptions = [];
          _wilayahResolutionMessage =
              'Wilayah terdeteksi, tetapi daftar kota/kabupaten belum sinkron.';
        });
        return false;
      }

      setState(() {
        _selectedKota = topLevel.nama;
        _selectedKecamatan = null;
        _selectedKelurahan = null;
        _kecamatanOptions = [];
        _kelurahanOptions = [];
      });

      await _loadKecamatanForSelectedKota(
        preselectedId: resolution.kecamatan?.id,
        preselectedName: resolution.kecamatan?.nama,
        loadLeafAfter: true,
        preselectedLeafId: resolution.leaf?.id,
        preselectedLeafName: resolution.leaf?.nama,
      );

      if (!mounted) return false;

      setState(() {
        _wilayahResolutionMessage = resolution.summaryLabel.isEmpty
            ? 'Wilayah berhasil dicocokkan dari koordinat.'
            : 'Wilayah otomatis terisi: ${resolution.summaryLabel}';
      });

      if (showFeedback) {
        _showSnackbar('Wilayah berhasil disesuaikan dari koordinat');
      }
      return true;
    } catch (e) {
      if (!mounted) return false;

      setState(() {
        _wilayahResolutionMessage =
            'Gagal mencocokkan wilayah dari koordinat. Anda masih bisa memilih manual.';
      });

      if (showFeedback) {
        _showSnackbar(NetworkErrorHelper.offlineMessage, isError: true);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isResolvingWilayah = false);
      }
    }
  }

  WilayahOption? _findOptionByName(List<WilayahOption> items, String? name) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }

    final normalizedTarget = _normalizeLabel(name);
    for (final item in items) {
      if (_normalizeLabel(item.nama) == normalizedTarget) {
        return item;
      }
    }
    return null;
  }

  WilayahOption? _findOptionByIdOrName(
    List<WilayahOption> items, {
    int? id,
    String? name,
  }) {
    if (id != null) {
      for (final item in items) {
        if (item.id == id) {
          return item;
        }
      }
    }

    return _findOptionByName(items, name);
  }

  String _normalizeLabel(String value) {
    return value.trim().toLowerCase();
  }

  /// Ambil koordinat GPS saat ini
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Layanan lokasi tidak aktif', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Izin lokasi ditolak', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
            'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.',
            isError: true);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _applyCoordinates(
        position.latitude,
        position.longitude,
        successMessage: 'Koordinat berhasil diambil',
        showResolveFeedback: true,
      );
    } catch (e) {
      _showSnackbar(
        NetworkErrorHelper.normalizeMessage(
          e,
          fallback: 'Gagal mendapatkan lokasi.',
        ),
        isError: true,
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    Duration initialTimer = const Duration(hours: 8, minutes: 0);
    if (controller.text.isNotEmpty) {
      final parts = controller.text.split(':');
      if (parts.length == 2) {
        initialTimer = Duration(
          hours: int.tryParse(parts[0]) ?? 8,
          minutes: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Duration tempTimer = initialTimer;
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppTheme.border(context))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal',
                          style: TextStyle(
                              color: AppTheme.textSecondary(context))),
                    ),
                    Text('Pilih Waktu',
                        style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        final hour =
                            tempTimer.inHours.toString().padLeft(2, '0');
                        final minute = (tempTimer.inMinutes % 60)
                            .toString()
                            .padLeft(2, '0');
                        controller.text = '$hour:$minute';
                        Navigator.pop(context);
                      },
                      child: Text('Selesai',
                          style: TextStyle(
                              color: AppTheme.primary(context),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(
                          color: AppTheme.textPrimary(context), fontSize: 22),
                    ),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: initialTimer,
                    onTimerDurationChanged: (Duration newTimer) {
                      tempTimer = newTimer;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pick Image (Show Bottom Sheet)
  Future<void> _showImagePickerModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded,
                  color: AppTheme.primary(context)),
              title: Text('Ambil dari Kamera',
                  style: TextStyle(color: AppTheme.textPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                _pickSingleImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary(context)),
              title: Text('Pilih dari Galeri',
                  style: TextStyle(color: AppTheme.textPrimary(context))),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImagesFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSingleImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (pickedFile != null) {
        _addPickedFiles([pickedFile]);
      }
    } catch (e) {
      _showSnackbar('Gagal membuka kamera: $e', isError: true);
    }
  }

  Future<void> _pickMultipleImagesFromGallery() async {
    final picker = ImagePicker();
    try {
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFiles.isNotEmpty) {
        _addPickedFiles(pickedFiles);
      }
    } catch (e) {
      _showSnackbar('Gagal membuka galeri: $e', isError: true);
    }
  }

  void _addPickedFiles(List<XFile> pickedFiles) {
    final existingPaths = _imageFiles.map((file) => file.path).toSet();
    final newFiles = pickedFiles
        .map((file) => File(file.path))
        .where((file) => !existingPaths.contains(file.path))
        .toList();

    if (newFiles.isEmpty) {
      return;
    }

    setState(() {
      _imageFiles = [..._imageFiles, ...newFiles];
    });
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _imageFiles.length) {
      return;
    }

    setState(() {
      _imageFiles = List<File>.from(_imageFiles)..removeAt(index);
    });
  }

  void _removeExistingImageAt(int index) {
    if (index < 0 || index >= _existingImageUrls.length) {
      return;
    }

    setState(() {
      _existingImageUrls = List<String>.from(_existingImageUrls)
        ..removeAt(index);
    });
  }

  Future<List<String>> _uploadSelectedImages() async {
    if (_imageFiles.isEmpty) {
      return const [];
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan login ulang.');
    }

    final storage = Supabase.instance.client.storage.from('wisata');
    final uploadedUrls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var index = 0; index < _imageFiles.length; index++) {
      final imageFile = _imageFiles[index];
      final ext = imageFile.path.split('.').last;
      final fileName = 'mobile-submissions/$userId/${timestamp}_$index.$ext';

      await storage.upload(fileName, imageFile);
      uploadedUrls.add(storage.getPublicUrl(fileName));
    }

    return uploadedUrls;
  }

  Future<bool> _isSubmissionOwnershipRecorded(int? wisataId) async {
    if (wisataId == null) {
      return false;
    }

    try {
      final row = await Supabase.instance.client
          .from('wisata')
          .select('id, submitter_user_id')
          .eq('id', wisataId)
          .maybeSingle();

      if (row == null) {
        return false;
      }

      return (row['submitter_user_id']?.toString().trim().isNotEmpty ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Submit form ke API
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedKategori == null) {
      _showSnackbar('Pilih kategori terlebih dahulu', isError: true);
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showSnackbar('Ambil koordinat GPS terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uploadedNewUrls = await _uploadSelectedImages();
      final allPhotoUrls = <String>[
        ..._existingImageUrls,
        ...uploadedNewUrls,
      ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();

      final fotoUtama = allPhotoUrls.isNotEmpty ? allPhotoUrls.first : '';
      final fotoTambahan =
          allPhotoUrls.length > 1 ? allPhotoUrls.sublist(1) : <String>[];

      final rpcParams = {
        'p_nama_tempat': _namaController.text.trim(),
        'p_deskripsi': _deskripsiController.text.trim(),
        'p_alamat': _alamatController.text.trim(),
        'p_kecamatan': _selectedKecamatan ?? '',
        'p_kelurahan': _selectedKelurahan ?? '',
        'p_kategori': _selectedKategori!.namaKategori,
        'p_target_pengunjung': _targetPengunjung,
        'p_jam_buka': _jamBukaController.text.isNotEmpty
            ? '${_jamBukaController.text.trim()}:00'
            : '08:00:00',
        'p_jam_tutup': _jamTutupController.text.isNotEmpty
            ? '${_jamTutupController.text.trim()}:00'
            : '17:00:00',
        'p_harga_tiket': double.tryParse(_hargaController.text) ?? 0,
        'p_no_telepon': _teleponController.text.trim(),
        'p_foto': fotoUtama,
        'p_rating': _rating > 0 ? _rating.toDouble() : null,
        'p_hari_operasional': (() {
          const dayOrder = [
            'Senin',
            'Selasa',
            'Rabu',
            'Kamis',
            'Jumat',
            'Sabtu',
            'Minggu'
          ];
          final sorted = List<String>.from(_selectedHari)
            ..sort(
              (a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)),
            );
          return sorted.join(', ');
        })(),
        'p_lat': _latitude!,
        'p_lng': _longitude!,
        'p_toilet': _toilet,
        'p_parkir': _parkir,
        'p_area_bermain': _areaBermain,
        'p_tempat_makan': _tempatMakan,
        'p_mushola': _mushola,
        'p_wifi': _wifi,
      };

      int? wisataId;

      if (_isEditingSubmission) {
        final updatedId = await Supabase.instance.client.rpc(
          'update_wisata_submission',
          params: {
            'p_id': widget.existingWisata!.id,
            ...rpcParams,
            'p_gallery_urls': fotoTambahan,
          },
        );

        wisataId = updatedId is num
            ? updatedId.toInt()
            : int.tryParse(updatedId?.toString() ?? '');
      } else {
        final insertedId = await Supabase.instance.client
            .rpc('insert_wisata', params: rpcParams);

        wisataId = insertedId is num
            ? insertedId.toInt()
            : int.tryParse(insertedId?.toString() ?? '');

        if (wisataId != null && fotoTambahan.isNotEmpty) {
          await Supabase.instance.client.rpc('insert_wisata_gallery', params: {
            'p_wisata_id': wisataId,
            'p_foto_urls': fotoTambahan,
          });
        }
      }

      final ownershipRecorded = await _isSubmissionOwnershipRecorded(wisataId);

      setState(() => _isLoading = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary(context), size: 28),
                SizedBox(width: 10),
                Text('Berhasil!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              (() {
                final baseMessage = _isEditingSubmission
                    ? 'Perubahan pengajuan berhasil disimpan.\n\nStatus: PENDING\nMenunggu validasi admin web.'
                    : 'Data wisata berhasil dikirim.\n\nStatus: PENDING\nMenunggu validasi admin.';

                if (ownershipRecorded) {
                  return baseMessage;
                }

                return '$baseMessage\n\nCatatan: riwayat per akun belum aktif di database. Jalankan migrasi backend terbaru agar pengajuan ini tercatat ke akun pengaju.';
              })(),
              style: TextStyle(
                  color: AppTheme.textSecondary(context), height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: Text('OK',
                    style: TextStyle(color: AppTheme.primary(context))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar(
        NetworkErrorHelper.normalizeMessage(
          e,
          fallback: 'Gagal mengirim data.',
        ),
        isError: true,
      );
    }
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
        backgroundColor:
            isError ? Colors.red.shade700 : AppTheme.primary(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      // Hero Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.vibrantGradient(context),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.vibrantGlow,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isEditingSubmission
                            ? 'Edit Pengajuan Wisata'
                            : 'Input Wisata Baru',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _isEditingSubmission
                            ? 'Perbarui data lalu ajukan kembali'
                            : 'Tambahkan tempat seru di Medan',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.map_rounded,
                        color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Keterangan
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary(context).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary(context).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppTheme.primary(context), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEditingSubmission
                            ? 'Perubahan pengajuan akan kembali berstatus PENDING dan diverifikasi oleh admin web.'
                            : 'Data yang dikirim akan berstatus PENDING dan perlu divalidasi oleh admin.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRejectedSubmission &&
                  ((_editingWisataDetail ?? widget.existingWisata)
                          ?.catatanAdmin
                          ?.trim()
                          .isNotEmpty ==
                      true)) ...[
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.feedback_rounded,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Catatan Admin Web',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        (_editingWisataDetail ?? widget.existingWisata)!
                            .catatanAdmin!
                            .trim(),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24),

              // === SECTION: Identitas ===
              _buildSectionTitle('Identitas'),
              SizedBox(height: 12),
              _buildTextField(
                controller: _namaController,
                label: 'Nama Tempat Wisata',
                hint: 'Contoh: Taman Sri Deli',
                icon: Icons.place_rounded,
                required: true,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _deskripsiController,
                label: 'Deskripsi',
                hint: 'Deskripsikan tempat wisata ini...',
                icon: Icons.description_rounded,
                maxLines: 3,
              ),
              SizedBox(height: 24),

              // === SECTION: Lokasi ===
              _buildSectionTitle('Lokasi'),
              SizedBox(height: 12),
              _buildTextField(
                controller: _alamatController,
                label: 'Alamat',
                hint: 'Jl. Brigjen Katamso, Medan',
                icon: Icons.home_rounded,
              ),
              SizedBox(height: 16),
              // Dropdown Kota / Kabupaten
              DropdownButtonFormField<String>(
                key: const ValueKey('kota'),
                value: _selectedKota,
                decoration: _inputDecoration(
                    'Kota / Kabupaten', Icons.apartment_rounded),
                dropdownColor: AppTheme.card(context),
                isExpanded: true,
                items: _topLevelWilayah
                    .map((item) => DropdownMenuItem(
                          value: item.nama,
                          child: Text(item.nama),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedKota = val;
                    _selectedKecamatan = null;
                    _selectedKelurahan = null;
                    _kecamatanOptions = [];
                    _kelurahanOptions = [];
                    _wilayahResolutionMessage = null;
                  });
                  _loadKecamatanForSelectedKota();
                },
                validator: (val) => val == null ? 'Pilih kota/kabupaten' : null,
              ),
              SizedBox(height: 16),
              // Dropdown Kecamatan (tergantung kota)
              DropdownButtonFormField<String>(
                key: ValueKey('kec_$_selectedKota'),
                value: _selectedKecamatan,
                decoration:
                    _inputDecoration('Kecamatan', Icons.location_city_rounded),
                dropdownColor: AppTheme.card(context),
                isExpanded: true,
                items: _kecamatanOptions
                    .map((item) => DropdownMenuItem(
                          value: item.nama,
                          child: Text(item.nama),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedKecamatan = val;
                    _selectedKelurahan = null;
                    _kelurahanOptions = [];
                    _wilayahResolutionMessage = null;
                  });
                  _loadKelurahanForSelectedKecamatan();
                },
                validator: (val) => val == null ? 'Pilih kecamatan' : null,
              ),
              SizedBox(height: 16),
              // Dropdown Kelurahan/Desa (tergantung kota + kecamatan)
              DropdownButtonFormField<String>(
                key: ValueKey('kel_$_selectedKecamatan'),
                value: _selectedKelurahan,
                decoration: _inputDecoration(
                    'Kelurahan / Desa', Icons.holiday_village_rounded),
                dropdownColor: AppTheme.card(context),
                isExpanded: true,
                items: _kelurahanOptions
                    .map((item) => DropdownMenuItem(
                          value: item.nama,
                          child: Text(item.nama),
                        ))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedKelurahan = val;
                  _wilayahResolutionMessage = null;
                }),
                validator: (val) => val == null ? 'Pilih kelurahan/desa' : null,
              ),
              if (_isLoadingWilayah ||
                  _isResolvingWilayah ||
                  _wilayahResolutionMessage != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoadingWilayah || _isResolvingWilayah)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary(context),
                          ),
                        )
                      else
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: AppTheme.primary(context),
                        ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isResolvingWilayah
                              ? 'Sedang mencocokkan wilayah dari koordinat...'
                              : _isLoadingWilayah
                                  ? 'Sedang memuat daftar wilayah...'
                                  : _wilayahResolutionMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16),

              // === Koordinat: Pilih Mode ===
              Container(
                padding: EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary(context).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.explore_rounded,
                              color: AppTheme.primary(context), size: 18),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Koordinat Lokasi',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),

                    // Segmented toggle: GPS vs Manual
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141720),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _useGps = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _useGps
                                      ? AppTheme.primary(context)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _useGps
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primary(context)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.gps_fixed_rounded,
                                      size: 16,
                                      color: _useGps
                                          ? AppTheme.textPrimary(context)
                                          : const Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'GPS Otomatis',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _useGps
                                            ? AppTheme.textPrimary(context)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _useGps = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_useGps
                                      ? const Color(0xFFD4A855)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_useGps
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFD4A855)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_location_alt_rounded,
                                      size: 16,
                                      color: !_useGps
                                          ? AppTheme.textPrimary(context)
                                          : const Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Input Manual',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: !_useGps
                                            ? AppTheme.textPrimary(context)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // === MODE 1: GPS Otomatis ===
                    if (_useGps) ...[
                      // Ambil GPS button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isGettingLocation ? null : _getCurrentLocation,
                          icon: _isGettingLocation
                              ? Container(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary(context),
                                  ),
                                )
                              : Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            _isGettingLocation
                                ? 'Melacak lokasi...'
                                : 'Ambil Lokasi dari GPS',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary(context),
                            side: BorderSide(
                                color: AppTheme.primary(context), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // Display koordinat result
                      if (_latitude != null && _longitude != null) ...[
                        SizedBox(height: 12),
                        _buildCoordinatePreviewMap(),
                        SizedBox(height: 12),
                        _buildCoordinateDisplay(),
                      ],
                    ],

                    // === MODE 2: Input Manual ===
                    if (!_useGps) ...[
                      // Hint text
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A855).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFD4A855).withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 16, color: Color(0xFFD4A855)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Masukkan koordinat secara manual, contoh: Lat 3.5952, Lng 98.6722',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary(context)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      // Lat & Lng input fields
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latManualController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: AppTheme.primary(context)),
                              decoration: InputDecoration(
                                labelText: 'Latitude',
                                hintText: '3.5952',
                                prefixIcon: Icon(Icons.north_rounded,
                                    size: 18, color: AppTheme.primary(context)),
                                labelStyle: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 13),
                                hintStyle: TextStyle(
                                    color: Color(0xFF475569), fontSize: 13),
                                filled: true,
                                fillColor: AppTheme.card(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppTheme.border(context)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppTheme.border(context)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppTheme.primary(context),
                                      width: 1.5),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onChanged: (val) {
                                _handleManualCoordinateInputChanged();
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lngManualController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: Color(0xFFD4A855)),
                              decoration: InputDecoration(
                                labelText: 'Longitude',
                                hintText: '98.6722',
                                prefixIcon: Icon(Icons.east_rounded,
                                    size: 18, color: Color(0xFFD4A855)),
                                labelStyle: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 13),
                                hintStyle: TextStyle(
                                    color: Color(0xFF475569), fontSize: 13),
                                filled: true,
                                fillColor: AppTheme.card(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppTheme.border(context)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppTheme.border(context)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Color(0xFFD4A855), width: 1.5),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onChanged: (val) {
                                _handleManualCoordinateInputChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      // Apply manual coordinates button
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final lat = double.tryParse(
                                _latManualController.text.trim());
                            final lng = double.tryParse(
                                _lngManualController.text.trim());
                            if (lat == null || lng == null) {
                              _showSnackbar(
                                  'Masukkan latitude dan longitude yang valid',
                                  isError: true);
                              return;
                            }
                            if (lat < -90 || lat > 90) {
                              _showSnackbar('Latitude harus antara -90 dan 90',
                                  isError: true);
                              return;
                            }
                            if (lng < -180 || lng > 180) {
                              _showSnackbar(
                                  'Longitude harus antara -180 dan 180',
                                  isError: true);
                              return;
                            }
                            await _applyCoordinates(
                              lat,
                              lng,
                              successMessage:
                                  'Koordinat manual berhasil diterapkan',
                              showResolveFeedback: true,
                            );
                          },
                          icon: Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          label: Text(
                            'Terapkan Koordinat',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A855),
                            foregroundColor: AppTheme.textPrimary(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // Display koordinat result
                      if (_latitude != null && _longitude != null) ...[
                        SizedBox(height: 12),
                        _buildCoordinatePreviewMap(),
                        SizedBox(height: 12),
                        _buildCoordinateDisplay(),
                      ],
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24),

              // === SECTION: Kategori ===
              _buildSectionTitle('Kategori'),
              SizedBox(height: 12),
              DropdownButtonFormField<Kategori>(
                initialValue: _selectedKategori,
                decoration:
                    _inputDecoration('Pilih Kategori', Icons.category_rounded),
                dropdownColor: AppTheme.card(context),
                items: _kategoriList
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.namaKategori),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedKategori = val),
                validator: (val) => val == null ? 'Pilih kategori' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _targetPengunjung,
                decoration:
                    _inputDecoration('Target Pengunjung', Icons.people_rounded),
                dropdownColor: AppTheme.card(context),
                items: const [
                  DropdownMenuItem(value: 'umum', child: Text('Umum')),
                  DropdownMenuItem(value: 'keluarga', child: Text('Keluarga')),
                  DropdownMenuItem(
                      value: 'anak-anak', child: Text('Anak-anak')),
                ],
                onChanged: (val) =>
                    setState(() => _targetPengunjung = val ?? 'umum'),
              ),
              SizedBox(height: 24),

              // === SECTION: Operasional ===
              _buildSectionTitle('Operasional & Harga'),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _jamBukaController,
                      label: 'Jam Buka',
                      hint: '08:00',
                      icon: Icons.access_time_rounded,
                      readOnly: true,
                      onTap: () => _selectTime(context, _jamBukaController),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _jamTutupController,
                      label: 'Jam Tutup',
                      hint: '17:00',
                      icon: Icons.access_time_filled_rounded,
                      readOnly: true,
                      onTap: () => _selectTime(context, _jamTutupController),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _hargaController,
                      label: 'Harga Tiket (Rp)',
                      hint: '0',
                      icon: Icons.monetization_on_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _teleponController,
                      label: 'No. Telepon',
                      hint: '061-xxx',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // === SECTION: Hari Operasional ===
              _buildSectionTitle('Hari Operasional'),
              SizedBox(height: 12),
              _buildHariSelector(),
              SizedBox(height: 24),

              // === SECTION: Rating ===
              _buildSectionTitle('Rating Tempat'),
              SizedBox(height: 12),
              _buildStarRating(),
              SizedBox(height: 24),

              // === SECTION: Fasilitas ===
              _buildSectionTitle('Fasilitas Tersedia'),
              SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildCheckbox(
                      'Toilet', _toilet, (v) => setState(() => _toilet = v!)),
                  _buildCheckbox(
                      'Parkir', _parkir, (v) => setState(() => _parkir = v!)),
                  _buildCheckbox('Area Bermain', _areaBermain,
                      (v) => setState(() => _areaBermain = v!)),
                  _buildCheckbox('Tempat Makan', _tempatMakan,
                      (v) => setState(() => _tempatMakan = v!)),
                  _buildCheckbox('Mushola', _mushola,
                      (v) => setState(() => _mushola = v!)),
                  _buildCheckbox(
                      'WiFi', _wifi, (v) => setState(() => _wifi = v!)),
                ],
              ),
              SizedBox(height: 24),

              // === SECTION: Foto ===
              _buildSectionTitle('Foto Wisata'),
              SizedBox(height: 12),
              GestureDetector(
                onTap: _showImagePickerModal,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: AppTheme.primary(context)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _totalPhotoCount == 0
                                  ? 'Tap untuk memilih satu atau beberapa foto'
                                  : '$_totalPhotoCount foto siap diajukan',
                              style: TextStyle(
                                color: AppTheme.textPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _totalPhotoCount == 0
                                ? ''
                                : 'Foto pertama jadi cover',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      if (_totalPhotoCount == 0)
                        SizedBox(
                          height: 110,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined,
                                    size: 40, color: Color(0xFF64748B)),
                                SizedBox(height: 10),
                                Text(
                                  'Belum ada foto dipilih',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _totalPhotoCount + 1,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemBuilder: (context, index) {
                            if (index == _totalPhotoCount) {
                              return InkWell(
                                onTap: _showImagePickerModal,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.border(context),
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded,
                                          color: AppTheme.primary(context),
                                          size: 28),
                                      SizedBox(height: 4),
                                      Text(
                                        'Tambah',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppTheme.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final isExisting =
                                index < _existingImageUrls.length;
                            final imageFile = !isExisting
                                ? _imageFiles[index - _existingImageUrls.length]
                                : null;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: isExisting
                                      ? Image.network(
                                          _existingImageUrls[index],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: AppTheme.card(context),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                              color: AppTheme.textSecondary(
                                                  context),
                                            ),
                                          ),
                                        )
                                      : Image.file(
                                          imageFile!,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                if (isExisting)
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Tersimpan',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (index == 0)
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Cover',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      iconSize: 14,
                                      icon: Icon(Icons.close,
                                          color: AppTheme.textPrimary(context)),
                                      onPressed: () => isExisting
                                          ? _removeExistingImageAt(index)
                                          : _removeImageAt(
                                              index - _existingImageUrls.length,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary(context),
                    foregroundColor: AppTheme.textPrimary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? Container(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.textPrimary(context),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              _isEditingSubmission
                                  ? 'Simpan & Ajukan Ulang'
                                  : 'Kirim Data Wisata',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _buildCoordinatePreviewMap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 16,
                  color: AppTheme.primary(context),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview lokasi. Geser peta untuk menyesuaikan titik koordinat.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isKeyboardVisible
                  ? Container(
                      key: const ValueKey('preview-map-collapsed'),
                      height: 68,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      color: AppTheme.card(context),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primary(context)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              color: AppTheme.primary(context),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Preview peta disembunyikan sementara saat mengetik agar input lebih lancar.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('preview-map-expanded'),
                      height: 180,
                      child: RepaintBoundary(
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _coordinatePreviewMapController,
                              options: MapOptions(
                                initialCenter: _coordinatePreviewCenter,
                                initialZoom: _coordinatePreviewZoom,
                                onPositionChanged:
                                    _handleCoordinatePreviewPositionChanged,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: isDark
                                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c', 'd'],
                                  userAgentPackageName:
                                      'com.example.flutter_wisata_medan',
                                ),
                              ],
                            ),
                            IgnorePointer(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 34,
                                      color: Colors.redAccent,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black26,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.redAccent,
                                          width: 2,
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
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared coordinate display widget
  Widget _buildCoordinateDisplay() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary(context).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Lat
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.north_rounded,
                        size: 12, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Latitude',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  _latitude!.toStringAsFixed(6),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: AppTheme.primary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: AppTheme.border(context),
          ),
          // Lng
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.east_rounded,
                        size: 12, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text('Longitude',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  _longitude!.toStringAsFixed(6),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: Color(0xFFD4A855),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary(context),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(fontSize: 14),
      decoration: _inputDecoration(label, icon, hint: hint),
      validator: required
          ? (val) =>
              (val == null || val.trim().isEmpty) ? '$label harus diisi' : null
          : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: const Color(0xFF64748B))
          : null,
      labelStyle:
          TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
      hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 13),
      filled: true,
      fillColor: AppTheme.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.primary(context), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? AppTheme.primary(context) : AppTheme.border(context),
        ),
      ),
      child: CheckboxListTile(
        title: Text(title,
            style:
                TextStyle(fontSize: 13, color: AppTheme.textPrimary(context))),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary(context),
        checkColor: AppTheme.textPrimary(context),
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Hari Operasional — multi-select day chips
  Widget _buildHariSelector() {
    const allDays = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const dayAbbrev = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih hari buka (bisa lebih dari satu)',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary(context)),
                ),
              ),
              // Select all / clear all
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedHari.length == allDays.length) {
                      _selectedHari = [];
                    } else {
                      _selectedHari = List.from(allDays);
                    }
                  });
                },
                child: Text(
                  _selectedHari.length == allDays.length
                      ? 'Hapus Semua'
                      : 'Pilih Semua',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: List.generate(allDays.length, (i) {
              final isSelected = _selectedHari.contains(allDays[i]);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedHari.remove(allDays[i]);
                      } else {
                        _selectedHari.add(allDays[i]);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : AppTheme.card(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF59E0B)
                            : AppTheme.border(context),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        dayAbbrev[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Star Rating Widget — interactive 1-5 stars
  Widget _buildStarRating() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.star_rate_rounded, size: 18, color: Color(0xFFFBBF24)),
              SizedBox(width: 8),
              Text(
                'Berikan rating (opsional)',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
              const Spacer(),
              if (_rating > 0)
                GestureDetector(
                  onTap: () => setState(() => _rating = 0),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary(context)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final isActive = starIndex <= _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isActive
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF475569),
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0) ...[
            SizedBox(height: 8),
            Text(
              _getRatingLabel(_rating),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFBBF24),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return '⭐ Kurang';
      case 2:
        return '⭐⭐ Cukup';
      case 3:
        return '⭐⭐⭐ Baik';
      case 4:
        return '⭐⭐⭐⭐ Sangat Baik';
      case 5:
        return '⭐⭐⭐⭐⭐ Luar Biasa!';
      default:
        return '';
    }
  }
}
