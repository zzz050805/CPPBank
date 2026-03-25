import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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

class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});

  @override
  State<BranchScreen> createState() => _BranchScreenAliasState();
}

class _BranchScreenAliasState extends State<BranchScreen> {
  @override
  Widget build(BuildContext context) {
    return const BranchMapScreen();
  }
}

class _BranchMapScreenState extends State<BranchMapScreen>
    with TickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF000DC0);
  static const Color mapBackground = Color(0xFFEFF3FB);
  static const double focusZoomLevel = 15;
  static const double minSheetSize = 0.32;
  static const double initialSheetSize = 0.36;
  static const double maxSheetSize = 0.9;

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  ScrollController? _sheetListController;

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

  int? _selectedBranchId;
  LatLng _currentCenter = const LatLng(10.7765, 106.7009);
  double _currentZoom = 12.6;
  late List<BranchInfo> _displayBranches;

  String _t(String vi, String en) => AppText.tr(context, vi, en);

  @override
  void initState() {
    super.initState();
    _displayBranches = List<BranchInfo>.from(_allBranches);
    if (_displayBranches.isNotEmpty) {
      _selectedBranchId = _displayBranches.first.id;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scrollListToTop() async {
    final ScrollController? controller = _sheetListController;
    if (controller == null || !controller.hasClients) return;

    if (controller.offset <= 2) {
      controller.jumpTo(0);
      return;
    }
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _animatedMove(LatLng destination, double destinationZoom) {
    final AnimationController animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    final CurvedAnimation curvedAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    final Tween<double> latTween = Tween<double>(
      begin: _currentCenter.latitude,
      end: destination.latitude,
    );
    final Tween<double> lngTween = Tween<double>(
      begin: _currentCenter.longitude,
      end: destination.longitude,
    );
    final Tween<double> zoomTween = Tween<double>(
      begin: _currentZoom,
      end: destinationZoom,
    );

    animationController.addListener(() {
      _mapController.move(
        LatLng(
          latTween.evaluate(curvedAnimation),
          lngTween.evaluate(curvedAnimation),
        ),
        zoomTween.evaluate(curvedAnimation),
      );
    });

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animationController.dispose();
      }
    });

    _currentCenter = destination;
    _currentZoom = destinationZoom;
    animationController.forward();
  }

  Future<void> _focusBranch(
    BranchInfo branch, {
    bool collapseSheet = true,
  }) async {
    setState(() {
      _selectedBranchId = branch.id;

      final int oldIndex = _displayBranches.indexWhere(
        (b) => b.id == branch.id,
      );
      if (oldIndex > 0) {
        final BranchInfo selected = _displayBranches.removeAt(oldIndex);
        _displayBranches.insert(0, selected);
      }
    });

    _animatedMove(branch.position, focusZoomLevel);

    if (!collapseSheet &&
        _sheetController.isAttached &&
        _sheetController.size < initialSheetSize) {
      await _sheetController.animateTo(
        initialSheetSize,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    await _scrollListToTop();

    if (collapseSheet && _sheetController.isAttached) {
      await _sheetController.animateTo(
        minSheetSize,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openDialer(BranchInfo branch) async {
    final String normalizedPhone = branch.phone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    final Uri uri = Uri.parse('tel:$normalizedPhone');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong mo duoc trinh goi dien.')),
      );
    }
  }

  Future<void> _openDirections(BranchInfo branch) async {
    final String destination =
        '${branch.position.latitude},${branch.position.longitude}';
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    );

    if (!await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong mo duoc ung dung ban do.')),
      );
    }
  }

  void _handleSearchChanged(String value) {
    final String query = value.trim().toLowerCase();

    setState(() {
      _displayBranches = _allBranches
          .where(
            (branch) =>
                branch.name.toLowerCase().contains(query) ||
                branch.address.toLowerCase().contains(query),
          )
          .toList();

      if (_displayBranches.isEmpty) {
        _selectedBranchId = null;
        return;
      }

      final int selectedIdx = _displayBranches.indexWhere(
        (branch) => branch.id == _selectedBranchId,
      );
      if (selectedIdx > 0) {
        final BranchInfo selected = _displayBranches.removeAt(selectedIdx);
        _displayBranches.insert(0, selected);
      } else if (selectedIdx == -1) {
        _selectedBranchId = _displayBranches.first.id;
      }
    });

    if (_displayBranches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusBranch(_displayBranches.first, collapseSheet: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<BranchInfo> branches = _displayBranches;

    return Scaffold(
      backgroundColor: mapBackground,
      appBar: CCPAppBar(title: _t('Chi nhánh', 'Branch')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ccpbank.app',
              ),
              MarkerLayer(
                markers: branches.map((branch) {
                  final bool isSelected = branch.id == _selectedBranchId;
                  return Marker(
                    width: isSelected ? 46 : 40,
                    height: isSelected ? 46 : 40,
                    point: branch.position,
                    child: GestureDetector(
                      onTap: () => _focusBranch(branch, collapseSheet: true),
                      child: Icon(
                        Icons.location_on,
                        color: primaryBlue,
                        size: isSelected ? 42 : 35,
                      ),
                    ),
                  );
                }).toList(),
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            minChildSize: minSheetSize,
            maxChildSize: maxSheetSize,
            initialChildSize: initialSheetSize,
            builder: (context, scrollController) {
              _sheetListController = scrollController;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4D7E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            _t('Chi nhánh CCPBank', 'CCPBank Branches'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C21),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${branches.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: branches.isEmpty
                          ? Center(
                              child: Text(
                                _t(
                                  'Không tìm thấy chi nhánh phù hợp.',
                                  'No branch found.',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                              itemCount: branches.length,
                              itemBuilder: (context, index) {
                                final BranchInfo branch = branches[index];
                                final bool isSelected =
                                    branch.id == _selectedBranchId;

                                return GestureDetector(
                                  onTap: () =>
                                      _focusBranch(branch, collapseSheet: true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEFF3FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? primaryBlue.withOpacity(0.35)
                                            : const Color(0xFFE4E7EF),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            isSelected ? 0.1 : 0.05,
                                          ),
                                          blurRadius: isSelected ? 12 : 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          branch.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1C1C21),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          branch.address,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF5E6270),
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: branch.isOpen
                                                    ? Colors.green.withOpacity(
                                                        0.12,
                                                      )
                                                    : Colors.red.withOpacity(
                                                        0.12,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                branch.isOpen
                                                    ? _t('Đang mở cửa', 'Open')
                                                    : _t(
                                                        'Đã đóng cửa',
                                                        'Closed',
                                                      ),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: branch.isOpen
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${branch.hours}  •  ${branch.phone}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: const Color(
                                                    0xFF666B7A,
                                                  ),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _openDialer(branch),
                                                  icon: const Icon(
                                                    Icons.phone,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    _t('Gọi điện', 'Call'),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        primaryBlue,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _openDirections(branch),
                                                  icon: const Icon(
                                                    Icons.directions,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    _t(
                                                      'Chỉ đường',
                                                      'Directions',
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        primaryBlue,
                                                    side: const BorderSide(
                                                      color: primaryBlue,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
          ),
        ],
      ),
    );
  }
}
