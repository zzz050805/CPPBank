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

class BranchMapScreen extends StatefulWidget {
  const BranchMapScreen({super.key});

  @override
  State<BranchMapScreen> createState() => _BranchMapScreenState();
}

class _BranchMapScreenState extends State<BranchMapScreen> {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color mapBackground = Color(0xFFEFF3FB);
  static const double focusZoomLevel = 15.5;
  static const double userLocationZoomLevel = 15.0;
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
  Set<Polyline> _routePolylines = <Polyline>{};
  late List<BranchInfo> _displayBranches;

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
  ];

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _displayBranches = List<BranchInfo>.from(_allBranches);
    _initUserLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
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
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
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
        timeLimit: const Duration(seconds: 12),
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

    setState(() {
      _userLocation = userPosition;
      if (!_hasCenteredOnUser) {
        _currentCenter = userPosition;
      }
    });

    final bool shouldCenter = centerCamera || !_hasCenteredOnUser;
    if (shouldCenter && _mapController != null) {
      _hasCenteredOnUser = true;
      _animatedMove(userPosition, userLocationZoomLevel);
    }
  }

  Future<void> _moveToMyLocation() async {
    if (_userLocation != null) {
      _animatedMove(_userLocation!, userLocationZoomLevel);
      return;
    }

    await _initUserLocationTracking();
  }

  Future<List<LatLng>> _fetchDrivingRoute(
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
      return <LatLng>[];
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      return <LatLng>[];
    }

    final List<dynamic>? routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return <LatLng>[];
    }

    final Map<String, dynamic>? overview =
        (routes.first as Map<String, dynamic>)['overview_polyline']
            as Map<String, dynamic>?;
    final String encoded = overview?['points'] as String? ?? '';
    if (encoded.isEmpty) {
      return <LatLng>[];
    }

    return _decodePolyline(encoded);
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

    List<LatLng> routePoints = <LatLng>[];
    try {
      routePoints = await _fetchDrivingRoute(origin, branch.position);
    } catch (_) {
      routePoints = <LatLng>[];
    }

    if (routePoints.isEmpty) {
      routePoints = <LatLng>[origin, branch.position];
      _showLocationNotice(
        _t(
          'Không lấy được tuyến đường chi tiết, hiển thị đường thẳng tạm thời.',
          'Detailed route unavailable, showing a straight preview line.',
        ),
      );
    }

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
    });

    _fitCameraToPoints(<LatLng>[origin, ...routePoints, branch.position]);
  }

  void _handleSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      _displayBranches = _allBranches
          .where(
            (b) =>
                b.name.toLowerCase().contains(query) ||
                b.address.toLowerCase().contains(query),
          )
          .toList();
    });
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
              _moveToMyLocation();
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

          _buildDraggableSheet(),
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
                            Text(
                              branch.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              branch.address,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
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
                                    fontWeight: FontWeight.w600,
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
