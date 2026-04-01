import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

import '../l10n/app_text.dart';
import '../widget/ccp_app_bar.dart';

class BranchInfo {
  const BranchInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.hours,
    required this.isOpen,
    required this.position,
  });

  final int id;
  final String name;
  final String address;
  final String phone;
  final String hours;
  final bool isOpen;
  final LatLng position;
}

class _RouteResult {
  const _RouteResult({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
  });

  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;
}

class BranchMapScreen extends StatefulWidget {
  const BranchMapScreen({super.key, this.autoSelectNearest = false});

  final bool autoSelectNearest;

  @override
  State<BranchMapScreen> createState() => _BranchMapScreenState();
}

class _BranchMapScreenState extends State<BranchMapScreen>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color mapBackground = Color(0xFFEFF3FB);
  static const double focusZoomLevel = 15.5;
  static const double userLocationZoomLevel = 15.0;
  static LatLng? _cachedUserLocation;
  static const String _directionsApiKey =
      'AIzaSyCnOT1cldbQw9V0buoOxfEj2Y6r25pD9Lo';

  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<Position>? _positionSubscription;

  int? _selectedBranchId;
  LatLng _currentCenter = const LatLng(10.7765, 106.7009);
  LatLng? _userLocation;
  bool _hasCenteredOnUser = false;
  bool _hasShownFakeLocationWarning = false;
  bool _hasShownEmulatorLocationHint = false;
  Set<Polyline> _routePolylines = <Polyline>{};
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  int? _routeBranchId;
  Map<int, double> _branchRouteDistanceMeters = <int, double>{};
  LatLng? _branchRouteDistanceOrigin;
  Timer? _branchRouteDebounce;
  DateTime? _lastBranchRouteFetchAt;
  bool _isRefreshingBranchRouteDistances = false;
  late List<BranchInfo> _displayBranches;
  bool _hasAutoSelectedNearest = false;

  final List<BranchInfo> _allBranches = const [
    BranchInfo(
      id: 1,
      name: 'CCPBank Quận 1',
      address: '126 Lý Tự Trọng, Quận 1, TP.HCM',
      phone: '028 3822 1234',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.7758, 106.7008),
    ),
    BranchInfo(
      id: 2,
      name: 'CCPBank Quận 7',
      address: '118 Nguyễn Thị Thập, Quận 7, TP.HCM',
      phone: '028 5410 8822',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.7338, 106.7212),
    ),
    BranchInfo(
      id: 3,
      name: 'CCPBank Tân Bình',
      address: '45 Cộng Hòa, Quận Tân Bình, TP.HCM',
      phone: '028 3811 6677',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.8019, 106.6535),
    ),
    BranchInfo(
      id: 4,
      name: 'CCPBank Bình Thạnh',
      address: '152 Điện Biên Phủ, Bình Thạnh, TP.HCM',
      phone: '028 3899 4455',
      hours: '08:00 - 17:00',
      isOpen: false,
      position: LatLng(10.8014, 106.7105),
    ),
    BranchInfo(
      id: 5,
      name: 'CCPBank Thủ Đức',
      address: '20 Võ Văn Ngân, TP. Thủ Đức, TP.HCM',
      phone: '028 3722 9900',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.8506, 106.7718),
    ),
    BranchInfo(
      id: 6,
      name: 'CCPBank Củ Chi',
      address: '238 Tỉnh lộ 8, Thị trấn Củ Chi, TP.HCM',
      phone: '028 3790 1188',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.9738, 106.4939),
    ),
    BranchInfo(
      id: 7,
      name: 'CCPBank Hóc Môn',
      address: '12 Lý Thường Kiệt, Thị trấn Hóc Môn, TP.HCM',
      phone: '028 3891 2233',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.8865, 106.5923),
    ),
    BranchInfo(
      id: 8,
      name: 'CCPBank Quận 12',
      address: '451 Lê Văn Khương, Quận 12, TP.HCM',
      phone: '028 3889 4567',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.8614, 106.6540),
    ),
    BranchInfo(
      id: 9,
      name: 'CCPBank Nhà Bè',
      address: '1016 Huỳnh Tấn Phát, Huyện Nhà Bè, TP.HCM',
      phone: '028 3777 8811',
      hours: '08:00 - 17:00',
      isOpen: false,
      position: LatLng(10.6979, 106.7398),
    ),
    BranchInfo(
      id: 10,
      name: 'CCPBank Bình Chánh',
      address: '68 Đường số 1, TT. Tân Túc, Bình Chánh, TP.HCM',
      phone: '028 3760 2399',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.7251, 106.5904),
    ),
    BranchInfo(
      id: 11,
      name: 'CCPBank Quận 3',
      address: '221 Võ Thị Sáu, Quận 3, TP.HCM',
      phone: '028 3930 2233',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.7829, 106.6866),
    ),
    BranchInfo(
      id: 12,
      name: 'CCPBank Phú Nhuận',
      address: '151 Nguyễn Văn Trỗi, Phú Nhuận, TP.HCM',
      phone: '028 3997 8800',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.8011, 106.6799),
    ),
    BranchInfo(
      id: 13,
      name: 'CCPBank Gò Vấp',
      address: '86 Quang Trung, Gò Vấp, TP.HCM',
      phone: '028 3589 1177',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.8396, 106.6655),
    ),
    BranchInfo(
      id: 14,
      name: 'CCPBank Tân Phú',
      address: '402 Lũy Bán Bích, Tân Phú, TP.HCM',
      phone: '028 3812 7744',
      hours: '08:00 - 17:00',
      isOpen: false,
      position: LatLng(10.7923, 106.6281),
    ),
    BranchInfo(
      id: 15,
      name: 'CCPBank Bình Tân',
      address: '170 Kinh Dương Vương, Bình Tân, TP.HCM',
      phone: '028 3756 6611',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.7656, 106.6039),
    ),
    BranchInfo(
      id: 16,
      name: 'CCPBank Tân An',
      address: '55 Hùng Vương, Phường 2, TP. Tân An, Long An',
      phone: '0272 3822 166',
      hours: '07:30 - 17:00',
      isOpen: true,
      position: LatLng(10.5354, 106.4120),
    ),
    BranchInfo(
      id: 17,
      name: 'CCPBank Bến Lức',
      address: '177 Nguyễn Hữu Thọ, TT. Bến Lức, Long An',
      phone: '0272 3876 118',
      hours: '07:30 - 17:00',
      isOpen: true,
      position: LatLng(10.6388, 106.4862),
    ),
    BranchInfo(
      id: 18,
      name: 'CCPBank Mỹ Tho',
      address: '12 Trần Hưng Đạo, Phường 1, TP. Mỹ Tho, Tiền Giang',
      phone: '0273 3879 422',
      hours: '07:30 - 17:00',
      isOpen: false,
      position: LatLng(10.3605, 106.3597),
    ),
    BranchInfo(
      id: 19,
      name: 'CCPBank Cai Lậy',
      address: '101 Quốc lộ 1A, Khu 4, Cai Lậy, Tiền Giang',
      phone: '0273 3922 705',
      hours: '07:30 - 17:00',
      isOpen: true,
      position: LatLng(10.4078, 106.1190),
    ),
    BranchInfo(
      id: 20,
      name: 'CCPBank Ninh Kiều',
      address: '82 Nguyễn Trãi, Ninh Kiều, Cần Thơ',
      phone: '0292 3765 919',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.0342, 105.7872),
    ),
    BranchInfo(
      id: 21,
      name: 'CCPBank Cái Răng',
      address: '255 Võ Nguyên Giáp, Cái Răng, Cần Thơ',
      phone: '0292 3890 221',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.0041, 105.7637),
    ),
    BranchInfo(
      id: 22,
      name: 'CCPBank Vũng Tàu',
      address: '164 Lê Hồng Phong, TP. Vũng Tàu, Bà Rịa - Vũng Tàu',
      phone: '0254 3578 889',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.3458, 107.0843),
    ),
    BranchInfo(
      id: 23,
      name: 'CCPBank Bà Rịa',
      address: '39 Cách Mạng Tháng Tám, TP. Bà Rịa, Bà Rịa - Vũng Tàu',
      phone: '0254 3733 118',
      hours: '08:00 - 17:00',
      isOpen: false,
      position: LatLng(10.4964, 107.1682),
    ),
    BranchInfo(
      id: 24,
      name: 'CCPBank Biên Hòa',
      address: '228 Phạm Văn Thuận, Biên Hòa, Đồng Nai',
      phone: '0251 3811 606',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.9447, 106.8244),
    ),
    BranchInfo(
      id: 25,
      name: 'CCPBank Long Khánh',
      address: '18 Hùng Vương, TP. Long Khánh, Đồng Nai',
      phone: '0251 3873 455',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.9285, 107.2431),
    ),
    BranchInfo(
      id: 26,
      name: 'CCPBank Thủ Dầu Một',
      address: '51 Đại lộ Bình Dương, Thủ Dầu Một, Bình Dương',
      phone: '0274 3827 119',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.9804, 106.6519),
    ),
    BranchInfo(
      id: 27,
      name: 'CCPBank Dĩ An',
      address: '105 Nguyễn An Ninh, Dĩ An, Bình Dương',
      phone: '0274 3791 126',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.9058, 106.7694),
    ),
    BranchInfo(
      id: 28,
      name: 'CCPBank Tây Ninh',
      address: '223 Cách Mạng Tháng 8, TP. Tây Ninh, Tây Ninh',
      phone: '0276 3822 044',
      hours: '07:30 - 17:00',
      isOpen: true,
      position: LatLng(11.3162, 106.0987),
    ),
    BranchInfo(
      id: 29,
      name: 'CCPBank Hòa Thành',
      address: '55 Phạm Hùng, Thị xã Hòa Thành, Tây Ninh',
      phone: '0276 3890 778',
      hours: '07:30 - 17:00',
      isOpen: false,
      position: LatLng(11.2762, 106.1397),
    ),
    BranchInfo(
      id: 30,
      name: 'CCPBank Long Xuyên',
      address: '92 Trần Hưng Đạo, TP. Long Xuyên, An Giang',
      phone: '0296 3852 611',
      hours: '08:00 - 17:00',
      isOpen: true,
      position: LatLng(10.3864, 105.4352),
    ),
  ];

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Reuse the last user location in this app session so the map opens there instantly.
    if (_cachedUserLocation != null) {
      _userLocation = _cachedUserLocation;
      _currentCenter = _cachedUserLocation!;
      _hasCenteredOnUser = true;
    }

    _displayBranches = _sortBranchesByDistance(_allBranches);

    _initUserLocationTracking();

    if (widget.autoSelectNearest && _userLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryAutoSelectNearestBranch();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _branchRouteDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          _branchRouteDistanceMeters = <int, double>{};
          _branchRouteDistanceOrigin = null;
        });
      }
      _lastBranchRouteFetchAt = null;
      _scheduleRefreshBranchRouteDistances(immediate: true);
      _startRealtimeLocationTracking();
    }
  }

  Future<void> _initUserLocationTracking() async {
    await _loadUserLocation();
    await _startRealtimeLocationTracking();
  }

  void _showLocationNotice(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  LocationSettings _buildCurrentLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        timeLimit: const Duration(seconds: 12),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        timeLimit: const Duration(seconds: 12),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 12),
    );
  }

  LocationSettings _buildStreamLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: Duration(seconds: 2),
        forceLocationManager: true,
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  bool _isLikelyDefaultEmulatorPosition(LatLng point) {
    const double defaultLat = 37.4219983;
    const double defaultLng = -122.084;
    return (point.latitude - defaultLat).abs() < 0.015 &&
        (point.longitude - defaultLng).abs() < 0.015;
  }

  bool _isReliablePosition(Position position) {
    final LatLng point = LatLng(position.latitude, position.longitude);
    if (_isLikelyDefaultEmulatorPosition(point)) {
      return false;
    }
    if (position.accuracy > 150) {
      return false;
    }
    return true;
  }

  bool _handleLikelyEmulatorDefaultPosition(Position position) {
    final bool isDefaultEmulatorPoint = _isLikelyDefaultEmulatorPosition(
      LatLng(position.latitude, position.longitude),
    );

    if (isDefaultEmulatorPoint && !_hasShownEmulatorLocationHint) {
      _hasShownEmulatorLocationHint = true;
      _showLocationNotice(
        _t(
          'Bạn đang dùng giả lập. Hãy mở Emulator > Extended controls > Location và nhập tọa độ thật.',
          'You are using an emulator. Open Extended controls > Location and set a mock location.',
        ),
      );
    }

    return isDefaultEmulatorPoint;
  }

  Future<bool> _ensureLocationPermission({
    bool openSettingsWhenDeniedForever = true,
  }) async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationNotice(
        _t(
          'Vui lòng bật GPS để hiển thị vị trí của bạn.',
          'Please enable GPS to show your location.',
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showLocationNotice(
        _t(
          'Bạn cần cấp quyền vị trí để hiển thị vị trí hiện tại.',
          'Location permission is needed to show your current position.',
        ),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationNotice(
        _t(
          'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở cài đặt ứng dụng.',
          'Location permission is permanently denied. Please open app settings.',
        ),
      );
      if (openSettingsWhenDeniedForever) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    return true;
  }

  Future<void> _loadUserLocation() async {
    final bool hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: _buildCurrentLocationSettings(),
      );
    } catch (_) {
      final Position? fallback = await Geolocator.getLastKnownPosition();
      if (fallback != null && _isReliablePosition(fallback)) {
        _setUserLocation(
          LatLng(fallback.latitude, fallback.longitude),
          centerCamera: true,
        );
      } else if (_userLocation == null) {
        _showLocationNotice(
          _t(
            'Không lấy được vị trí hiện tại. Vui lòng bật GPS chính xác cao.',
            'Unable to get your current location. Please enable high-accuracy GPS.',
          ),
        );
      }
      return;
    }

    if (_handleLikelyEmulatorDefaultPosition(position)) {
      return;
    }

    if (!_isReliablePosition(position)) {
      if (!_hasShownFakeLocationWarning) {
        _hasShownFakeLocationWarning = true;
        _showLocationNotice(
          _t(
            'Vị trí hiện tại chưa chính xác, vui lòng bật GPS chính xác cao.',
            'Current location is not accurate yet, please enable high-accuracy GPS.',
          ),
        );
      }
      return;
    }

    _setUserLocation(
      LatLng(position.latitude, position.longitude),
      centerCamera: true,
    );
  }

  Future<void> _startRealtimeLocationTracking() async {
    final bool hasPermission = await _ensureLocationPermission(
      openSettingsWhenDeniedForever: false,
    );
    if (!hasPermission) {
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _buildStreamLocationSettings(),
        ).listen(
          (Position position) {
            if (_handleLikelyEmulatorDefaultPosition(position)) {
              return;
            }
            if (!_isReliablePosition(position)) {
              return;
            }
            _setUserLocation(LatLng(position.latitude, position.longitude));
          },
          onError: (_) {
            _showLocationNotice(
              _t(
                'Không thể cập nhật vị trí realtime.',
                'Cannot update realtime location.',
              ),
            );
          },
        );
  }

  void _setUserLocation(LatLng userPosition, {bool centerCamera = false}) {
    if (!mounted) {
      return;
    }

    _cachedUserLocation = userPosition;

    final bool isRouteDistanceStale =
        _branchRouteDistanceOrigin != null &&
        _distanceBetween(_branchRouteDistanceOrigin!, userPosition) > 25;

    setState(() {
      _userLocation = userPosition;
      if (isRouteDistanceStale) {
        _branchRouteDistanceMeters = <int, double>{};
        _branchRouteDistanceOrigin = null;
      }
      _displayBranches = _sortBranchesByDistance(_displayBranches);
      if (!_hasCenteredOnUser) {
        _currentCenter = userPosition;
      }
    });

    _scheduleRefreshBranchRouteDistances(
      immediate: _branchRouteDistanceMeters.isEmpty,
    );

    final bool shouldCenter = centerCamera || !_hasCenteredOnUser;
    if (shouldCenter && _mapController != null) {
      _hasCenteredOnUser = true;
      _animatedMove(userPosition, userLocationZoomLevel);
    }

    _tryAutoSelectNearestBranch();
  }

  void _tryAutoSelectNearestBranch() {
    if (!widget.autoSelectNearest || _hasAutoSelectedNearest) {
      return;
    }

    if (_displayBranches.isEmpty || _userLocation == null) {
      return;
    }

    final List<BranchInfo> sorted = _sortBranchesByDistance(_displayBranches);
    if (sorted.isEmpty) {
      return;
    }

    _hasAutoSelectedNearest = true;
    _focusBranch(sorted.first);
  }

  Future<void> _moveToMyLocation() async {
    if (_userLocation != null) {
      _animatedMove(_userLocation!, userLocationZoomLevel);
      await _startRealtimeLocationTracking();
      return;
    }

    await _initUserLocationTracking();
  }

  Future<_RouteResult> _fetchDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final _RouteResult googleRoute = await _fetchGoogleDrivingRoute(
      origin,
      destination,
    );
    if (googleRoute.points.isNotEmpty) {
      return googleRoute;
    }

    return _fetchOsrmDrivingRoute(origin, destination);
  }

  Future<_RouteResult> _fetchGoogleDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final Uri uri =
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'language': Localizations.localeOf(context).languageCode,
          'key': _directionsApiKey,
        });

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return const _RouteResult(points: <LatLng>[]);
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      return const _RouteResult(points: <LatLng>[]);
    }

    final List<dynamic>? routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return const _RouteResult(points: <LatLng>[]);
    }

    final Map<String, dynamic> route = routes.first as Map<String, dynamic>;

    final Map<String, dynamic>? overview =
        route['overview_polyline'] as Map<String, dynamic>?;
    final String encoded = overview?['points'] as String? ?? '';
    if (encoded.isEmpty) {
      return const _RouteResult(points: <LatLng>[]);
    }

    final List<dynamic>? legs = route['legs'] as List<dynamic>?;
    final Map<String, dynamic>? firstLeg = (legs != null && legs.isNotEmpty)
        ? legs.first as Map<String, dynamic>
        : null;

    final double? distanceMeters =
        ((firstLeg?['distance'] as Map<String, dynamic>?)?['value'] as num?)
            ?.toDouble();
    final double? durationSeconds =
        ((firstLeg?['duration'] as Map<String, dynamic>?)?['value'] as num?)
            ?.toDouble();

    return _RouteResult(
      points: _decodePolyline(encoded),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  Future<_RouteResult> _fetchOsrmDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final Uri uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return const _RouteResult(points: <LatLng>[]);
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['code'] != 'Ok') {
      return const _RouteResult(points: <LatLng>[]);
    }

    final List<dynamic>? routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return const _RouteResult(points: <LatLng>[]);
    }

    final Map<String, dynamic> route = routes.first as Map<String, dynamic>;

    final Map<String, dynamic>? geometry =
        route['geometry'] as Map<String, dynamic>?;
    final List<dynamic>? coordinates =
        geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) {
      return const _RouteResult(points: <LatLng>[]);
    }

    final List<LatLng> points = <LatLng>[];
    for (final dynamic coordinate in coordinates) {
      if (coordinate is List && coordinate.length >= 2) {
        final double? lng = (coordinate[0] as num?)?.toDouble();
        final double? lat = (coordinate[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
        }
      }
    }

    return _RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble(),
      durationSeconds: (route['duration'] as num?)?.toDouble(),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  void _fitCameraToPoints(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final LatLng p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if ((maxLat - minLat).abs() < 0.0001) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }
    if ((maxLng - minLng).abs() < 0.0001) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = _displayBranches.map((branch) {
      final bool isSelected = branch.id == _selectedBranchId;
      return Marker(
        markerId: MarkerId(branch.id.toString()),
        position: branch.position,
        onTap: () => _focusBranch(branch),
        zIndexInt: isSelected ? 2 : 1,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueBlue,
        ),
      );
    }).toSet();

    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: _userLocation!,
          zIndexInt: 99,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _t('Vị trí của tôi', 'My location')),
        ),
      );
    }

    return markers;
  }

  void _animatedMove(LatLng destination, double zoom) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: destination, zoom: zoom),
      ),
    );
  }

  Future<void> _focusBranch(BranchInfo branch) async {
    setState(() {
      _selectedBranchId = branch.id;
    });

    _animatedMove(branch.position, focusZoomLevel);

    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        0.32,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    _showBranchDetailSheet(branch);
  }

  Future<void> _openDialer(BranchInfo branch) async {
    final String phone = branch.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openDirections(BranchInfo branch) async {
    if (_userLocation == null) {
      await _moveToMyLocation();
    }

    final LatLng? origin = _userLocation;
    if (origin == null) {
      _showLocationNotice(
        _t(
          'Chưa có vị trí hiện tại để chỉ đường.',
          'Current location is unavailable for directions.',
        ),
      );
      return;
    }

    setState(() {
      _selectedBranchId = branch.id;
    });

    _RouteResult route = const _RouteResult(points: <LatLng>[]);
    try {
      route = await _fetchDrivingRoute(origin, branch.position);
    } catch (_) {
      route = const _RouteResult(points: <LatLng>[]);
    }

    List<LatLng> routePoints = route.points;
    double? routeDistanceMeters = route.distanceMeters;
    double? routeDurationSeconds;

    if (routePoints.isEmpty) {
      routePoints = <LatLng>[origin, branch.position];
      routeDistanceMeters = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        branch.position.latitude,
        branch.position.longitude,
      );
      routeDurationSeconds = _estimateDurationSeconds(routeDistanceMeters);
      _showLocationNotice(
        _t(
          'Không lấy được tuyến đường chi tiết, hiển thị đường thẳng tạm thời.',
          'Detailed route unavailable, showing a straight preview line.',
        ),
      );
    }

    routeDistanceMeters ??= _polylineDistanceMeters(routePoints);
    routeDurationSeconds = _estimateDurationSeconds(routeDistanceMeters);

    setState(() {
      _routePolylines = <Polyline>{
        Polyline(
          polylineId: const PolylineId('active_route'),
          points: routePoints,
          color: Colors.blue,
          width: 6,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
      _routeDistanceMeters = routeDistanceMeters;
      _routeDurationSeconds = routeDurationSeconds;
      _routeBranchId = branch.id;
    });

    _fitCameraToPoints(<LatLng>[origin, ...routePoints, branch.position]);
  }

  double _distanceFromUser(BranchInfo branch) {
    final LatLng? userLocation = _userLocation;
    if (userLocation == null) {
      return double.infinity;
    }

    return _distanceBetween(userLocation, branch.position);
  }

  double _distanceBetween(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  double _polylineDistanceMeters(List<LatLng> points) {
    if (points.length < 2) {
      return 0;
    }

    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  double _estimateDurationSeconds(double distanceMeters) {
    // Use motorbike-focused estimate for urban traffic in Vietnam.
    const double averageCitySpeedKmh = 24;
    final double hours = (distanceMeters / 1000) / averageCitySpeedKmh;
    final double seconds = hours * 3600;
    return seconds < 60 ? 60 : seconds;
  }

  void _scheduleRefreshBranchRouteDistances({bool immediate = false}) {
    _branchRouteDebounce?.cancel();
    if (immediate) {
      _refreshBranchRouteDistances();
      return;
    }

    _branchRouteDebounce = Timer(const Duration(milliseconds: 700), () {
      _refreshBranchRouteDistances();
    });
  }

  Future<void> _refreshBranchRouteDistances() async {
    if (_isRefreshingBranchRouteDistances) {
      return;
    }

    final LatLng? origin = _userLocation;
    if (origin == null || _displayBranches.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastFetch = _lastBranchRouteFetchAt;
    if (lastFetch != null &&
        now.difference(lastFetch) < const Duration(seconds: 3)) {
      return;
    }
    _lastBranchRouteFetchAt = now;

    _isRefreshingBranchRouteDistances = true;

    Map<int, double> routeDistances = <int, double>{};
    try {
      routeDistances = await _fetchOsrmDistanceTable(origin, _displayBranches);
    } catch (_) {
      routeDistances = <int, double>{};
    } finally {
      _isRefreshingBranchRouteDistances = false;
    }

    if (routeDistances.isEmpty) {
      _lastBranchRouteFetchAt = null;
    }

    if (!mounted || routeDistances.isEmpty) {
      return;
    }

    setState(() {
      _branchRouteDistanceMeters = routeDistances;
      _branchRouteDistanceOrigin = origin;
      _displayBranches = _sortBranchesByDistance(_displayBranches);
    });
  }

  Future<Map<int, double>> _fetchOsrmDistanceTable(
    LatLng origin,
    List<BranchInfo> branches,
  ) async {
    if (branches.isEmpty) {
      return <int, double>{};
    }

    final String coordinates = [
      '${origin.longitude},${origin.latitude}',
      ...branches.map(
        (branch) => '${branch.position.longitude},${branch.position.latitude}',
      ),
    ].join(';');

    final Uri uri = Uri.parse(
      'https://router.project-osrm.org/table/v1/driving/$coordinates?sources=0&annotations=distance',
    );

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return <int, double>{};
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      return <int, double>{};
    }

    final List<dynamic>? distances = data['distances'] as List<dynamic>?;
    if (distances == null || distances.isEmpty || distances.first is! List) {
      return <int, double>{};
    }

    final List<dynamic> firstRow = distances.first as List<dynamic>;
    final Map<int, double> result = <int, double>{};
    for (int i = 0; i < branches.length; i++) {
      final int distanceIndex = i + 1;
      if (distanceIndex >= firstRow.length) {
        continue;
      }

      final double? meters = (firstRow[distanceIndex] as num?)?.toDouble();
      if (meters != null && meters > 0) {
        result[branches[i].id] = meters;
      }
    }

    return result;
  }

  BranchInfo? _selectedBranch() {
    final int? selectedBranchId = _selectedBranchId;
    if (selectedBranchId == null) {
      return null;
    }

    for (final BranchInfo branch in _allBranches) {
      if (branch.id == selectedBranchId) {
        return branch;
      }
    }
    return null;
  }

  double _resolvedRouteDistanceMeters() {
    final double? routeDistanceMeters = _routeDistanceMeters;
    if (routeDistanceMeters != null && routeDistanceMeters > 0) {
      return routeDistanceMeters;
    }

    final List<Polyline> polylines = _routePolylines.toList();
    if (polylines.isNotEmpty && polylines.first.points.length >= 2) {
      final double polylineDistance = _polylineDistanceMeters(
        polylines.first.points,
      );
      if (polylineDistance > 0) {
        return polylineDistance;
      }
    }

    final LatLng? userLocation = _userLocation;
    final BranchInfo? branch = _selectedBranch();
    if (userLocation != null && branch != null) {
      return _distanceBetween(userLocation, branch.position);
    }

    return 0;
  }

  double _resolvedRouteDurationSeconds() {
    final double? routeDurationSeconds = _routeDurationSeconds;
    if (routeDurationSeconds != null && routeDurationSeconds > 0) {
      return routeDurationSeconds;
    }

    return _estimateDurationSeconds(_resolvedRouteDistanceMeters());
  }

  double _distanceForBranchCard(BranchInfo branch) {
    final bool hasActiveRouteForBranch =
        _routePolylines.isNotEmpty && _routeBranchId == branch.id;
    if (hasActiveRouteForBranch) {
      return _resolvedRouteDistanceMeters();
    }

    final LatLng? userLocation = _userLocation;
    final LatLng? routeDistanceOrigin = _branchRouteDistanceOrigin;
    final bool isRouteDistanceStillValid =
        userLocation != null &&
        routeDistanceOrigin != null &&
        _distanceBetween(routeDistanceOrigin, userLocation) <= 25;

    if (isRouteDistanceStillValid) {
      final double? batchedRouteDistance =
          _branchRouteDistanceMeters[branch.id];
      if (batchedRouteDistance != null && batchedRouteDistance > 0) {
        return batchedRouteDistance;
      }
    }

    return _distanceFromUser(branch);
  }

  String _formatDistance(double? meters) {
    if (meters == null || meters.isNaN || meters.isInfinite) {
      return '--';
    }

    if (meters <= 0) {
      return '--';
    }

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null ||
        seconds.isNaN ||
        seconds.isInfinite ||
        seconds <= 0) {
      return _t('1 phút', '1 min');
    }

    final int totalMinutes = (seconds / 60).round().clamp(1, 24 * 60);
    if (totalMinutes < 60) {
      return _t('$totalMinutes phút', '$totalMinutes min');
    }

    final int hours = totalMinutes ~/ 60;
    final int remainMinutes = totalMinutes % 60;
    if (remainMinutes == 0) {
      return _t('$hours giờ', '$hours hr');
    }

    return _t('$hours giờ $remainMinutes phút', '$hours hr $remainMinutes min');
  }

  List<BranchInfo> _sortBranchesByDistance(List<BranchInfo> branches) {
    if (_userLocation == null || branches.length <= 1) {
      return List<BranchInfo>.from(branches);
    }

    final List<BranchInfo> sorted = List<BranchInfo>.from(branches);
    sorted.sort(
      (a, b) => _distanceForBranchCard(a).compareTo(_distanceForBranchCard(b)),
    );
    return sorted;
  }

  void _handleSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      _displayBranches = _sortBranchesByDistance(
        _allBranches
            .where(
              (b) =>
                  b.name.toLowerCase().contains(query) ||
                  b.address.toLowerCase().contains(query),
            )
            .toList(),
      );
    });

    _scheduleRefreshBranchRouteDistances(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mapBackground,
      appBar: CCPAppBar(
        title: _t('Chi nhánh', 'Branch'),
        backgroundColor: mapBackground,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 12.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              setState(() {
                _branchRouteDistanceMeters = <int, double>{};
                _branchRouteDistanceOrigin = null;
              });
              _lastBranchRouteFetchAt = null;
              _scheduleRefreshBranchRouteDistances(immediate: true);
              _moveToMyLocation();
              _startRealtimeLocationTracking();
            },
            markers: _buildMarkers(),
            polylines: _routePolylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 70, bottom: 250),
          ),

          Positioned(top: 10, left: 14, right: 14, child: _buildSearchBar()),

          Positioned(top: 74, right: 14, child: _buildLocateMeButton()),

          if (_routePolylines.isNotEmpty)
            Positioned(
              top: 74,
              left: 14,
              right: 66,
              child: _buildRouteSummaryBar(),
            ),

          _buildDraggableSheet(),
        ],
      ),
    );
  }

  Widget _buildRouteSummaryBar() {
    final double resolvedDistanceMeters = _resolvedRouteDistanceMeters();
    final double resolvedDurationSeconds = _resolvedRouteDurationSeconds();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000DC0),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.alt_route_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('Tuyến đường dự kiến', 'Estimated route'),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDistance(resolvedDistanceMeters)} • ${_formatDuration(resolvedDurationSeconds)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocateMeButton() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _moveToMyLocation,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: const Icon(Icons.my_location, color: primaryBlue, size: 22),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _handleSearchChanged,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _t('Tìm chi nhánh...', 'Find branch...'),
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      minChildSize: 0.32,
      initialChildSize: 0.36,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _displayBranches.length,
                  itemBuilder: (context, index) {
                    final branch = _displayBranches[index];
                    final bool isSelected = branch.id == _selectedBranchId;
                    final bool isNearest = index == 0 && _userLocation != null;
                    final double distanceMeters = _distanceForBranchCard(
                      branch,
                    );
                    return GestureDetector(
                      onTap: () => _focusBranch(branch),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF3FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? primaryBlue
                                : const Color(0xFFE4E7EF),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          branch.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (isNearest) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAF0FF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            _t('Gần nhất', 'Nearest'),
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_userLocation != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F4FA),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFFDDE2EE),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _formatDistance(distanceMeters),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3D4454),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              branch.address,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${_t('Giờ mở cửa', 'Hours')}: ${branch.hours}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF454B5A),
                                    ),
                                  ),
                                ),
                                Text(
                                  branch.isOpen
                                      ? _t('Đang mở', 'Open')
                                      : _t('Đóng cửa', 'Closed'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: branch.isOpen
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBranchDetailSheet(BranchInfo branch) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DBE5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF151824),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          branch.address,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF5E6270),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FD),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_t('Giờ mở cửa', 'Opening hours')}: ${branch.hours}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF454B5A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: branch.isOpen
                            ? Colors.green.withOpacity(0.12)
                            : Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        branch.isOpen
                            ? _t('Đang mở', 'Open')
                            : _t('Đóng cửa', 'Closed'),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: branch.isOpen ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openDialer(branch),
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: Text(
                        _t('Gọi điện', 'Call'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _openDirections(branch);
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 18),
                      label: Text(
                        _t('Chỉ đường', 'Directions'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        side: const BorderSide(color: primaryBlue, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
