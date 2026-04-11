import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserAccessInfo {
  const AdminUserAccessInfo({required this.role, required this.isLocked});

  final String role;
  final bool isLocked;
}

class AdminFirestoreSetupService {
  AdminFirestoreSetupService._();

  static final AdminFirestoreSetupService instance =
      AdminFirestoreSetupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _adminCollectionName = 'admin';
  static const String _adminSettingsDocId = 'settings';
  static const String _defaultAdminAccount = '00000000';
  static const String _defaultAdminPassword = 'Admin@1234';

  static const List<Map<String, dynamic>> _shoppingBundleDocs =
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shopee',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Shopee',
          'nameEn': 'Shopee',
          'logoPath': 'assets/images/shopee.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 50000, 'discountPercent': 0},
            <String, dynamic>{'price': 100000, 'discountPercent': 0},
            <String, dynamic>{'price': 200000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'riot_games',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Riot Games',
          'nameEn': 'Riot Games',
          'logoPath': 'assets/images/riot.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 50000, 'discountPercent': 0},
            <String, dynamic>{'price': 100000, 'discountPercent': 0},
            <String, dynamic>{'price': 200000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'netflix',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Netflix',
          'nameEn': 'Netflix',
          'logoPath': 'assets/images/netflix.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 108000, 'discountPercent': 0},
            <String, dynamic>{'price': 220000, 'discountPercent': 0},
            <String, dynamic>{'price': 260000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'apple_music',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Apple Music',
          'nameEn': 'Apple Music',
          'logoPath': 'assets/images/itunes.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 69000, 'discountPercent': 0},
            <String, dynamic>{'price': 109000, 'discountPercent': 0},
            <String, dynamic>{'price': 149000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'chatgpt',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'ChatGPT',
          'nameEn': 'ChatGPT',
          'logoPath': 'assets/images/chatgpt.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 120000, 'discountPercent': 0},
            <String, dynamic>{'price': 490000, 'discountPercent': 0},
            <String, dynamic>{'price': 990000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'steam',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Steam',
          'nameEn': 'Steam',
          'logoPath': 'assets/images/steam.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 50000, 'discountPercent': 0},
            <String, dynamic>{'price': 100000, 'discountPercent': 0},
            <String, dynamic>{'price': 200000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'spotify',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Spotify',
          'nameEn': 'Spotify',
          'logoPath': 'assets/images/spotify.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 59000, 'discountPercent': 0},
            <String, dynamic>{'price': 129000, 'discountPercent': 0},
            <String, dynamic>{'price': 179000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'xanh_sm',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Xanh SM',
          'nameEn': 'Xanh SM',
          'logoPath': 'assets/images/xanhsm.jpg',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 50000, 'discountPercent': 0},
            <String, dynamic>{'price': 100000, 'discountPercent': 0},
            <String, dynamic>{'price': 200000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
        <String, dynamic>{
          'id': 'grab',
          'kind': 'shopping_bundle',
          'category': 'shopping_entertainment',
          'nameVi': 'Grab',
          'nameEn': 'Grab',
          'logoPath': 'assets/images/grab.png',
          'packages': <Map<String, dynamic>>[
            <String, dynamic>{'price': 50000, 'discountPercent': 0},
            <String, dynamic>{'price': 100000, 'discountPercent': 0},
            <String, dynamic>{'price': 200000, 'discountPercent': 0},
          ],
          'isActive': true,
        },
      ];

  static const List<Map<String, dynamic>> _defaultBanners =
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'banner_1',
          'imageUrl': 'assets/images/banner1.jpg',
          'isActive': true,
          'order': 1,
        },
        <String, dynamic>{
          'id': 'banner_2',
          'imageUrl': 'assets/images/banner2.jpg',
          'isActive': true,
          'order': 2,
        },
        <String, dynamic>{
          'id': 'banner_3',
          'imageUrl': 'assets/images/banner3.jpg',
          'isActive': true,
          'order': 3,
        },
        <String, dynamic>{
          'id': 'banner_4',
          'imageUrl': 'assets/images/banner4.jpg',
          'isActive': true,
          'order': 4,
        },
      ];

  String _digitsOnly(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isAdminMarker(String value) {
    return _digitsOnly(value) == '00000000';
  }

  DocumentReference<Map<String, dynamic>> get _adminRootRef {
    return _firestore.collection(_adminCollectionName).doc(_adminSettingsDocId);
  }

  CollectionReference<Map<String, dynamic>> _adminCollection(String path) {
    return _adminRootRef.collection(path);
  }

  Future<void> _ensureAdminRootDoc() async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _adminRootRef
        .get();
    final Map<String, dynamic> existing = snap.data() ?? <String, dynamic>{};

    final Map<String, dynamic> patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      patch['createdAt'] = FieldValue.serverTimestamp();
    }
    if ((existing['cccd'] ?? '').toString().trim().isEmpty) {
      patch['cccd'] = _defaultAdminAccount;
    }
    if ((existing['phoneNumber'] ?? '').toString().trim().isEmpty) {
      patch['phoneNumber'] = _defaultAdminAccount;
    }
    if ((existing['password'] ?? '').toString().trim().isEmpty) {
      patch['password'] = _defaultAdminPassword;
    }
    if ((existing['fullName'] ?? '').toString().trim().isEmpty) {
      patch['fullName'] = 'System Admin';
    }
    if ((existing['fullname'] ?? '').toString().trim().isEmpty) {
      patch['fullname'] = 'System Admin';
    }
    if ((existing['role'] ?? '').toString().trim().isEmpty) {
      patch['role'] = 'admin';
    }
    if (!existing.containsKey('isLocked')) {
      patch['isLocked'] = false;
    }

    await _adminRootRef.set(patch, SetOptions(merge: true));
  }

  Future<void> ensureAdminSeed() async {
    await _ensureAdminRootDoc();
    await _seedServicesPricing();
    await _seedHomeBanners();
  }

  Future<void> _seedServicesPricing() async {
    final CollectionReference<Map<String, dynamic>> collection =
        _adminCollection('services_pricing');

    final List<Map<String, dynamic>> docs = <Map<String, dynamic>>[
      ..._shoppingBundleDocs,
    ];

    for (final Map<String, dynamic> item in docs) {
      final String id = item['id'] as String;
      final DocumentReference<Map<String, dynamic>> ref = collection.doc(id);
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      if (snap.exists) {
        continue;
      }

      await ref.set(<String, dynamic>{
        ...item,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _seedHomeBanners() async {
    final CollectionReference<Map<String, dynamic>> collection =
        _adminCollection('home_banners');

    for (final Map<String, dynamic> item in _defaultBanners) {
      final String id = item['id'] as String;
      final DocumentReference<Map<String, dynamic>> ref = collection.doc(id);
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      if (snap.exists) {
        continue;
      }

      await ref.set(<String, dynamic>{
        ...item,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<AdminUserAccessInfo> ensureRoleAndSeed({
    required String userId,
    String fallbackAccount = '',
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(userId);

    final DocumentSnapshot<Map<String, dynamic>> userSnapshot = await userRef
        .get();
    final Map<String, dynamic> data =
        userSnapshot.data() ?? <String, dynamic>{};

    final String phone = (data['phoneNumber'] ?? fallbackAccount)
        .toString()
        .trim();
    final String cccd = (data['cccd'] ?? fallbackAccount).toString().trim();

    final bool shouldBeAdmin = _isAdminMarker(phone) || _isAdminMarker(cccd);
    final String existingRole = (data['role'] ?? '').toString().toLowerCase();
    final String resolvedRole = shouldBeAdmin
        ? 'admin'
        : (existingRole == 'admin' || existingRole == 'user'
              ? existingRole
              : 'user');

    final bool isLocked = data['isLocked'] == true;

    final Map<String, dynamic> userPatch = <String, dynamic>{
      'role': resolvedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!data.containsKey('isLocked')) {
      userPatch['isLocked'] = false;
    }

    await userRef.set(userPatch, SetOptions(merge: true));

    if (resolvedRole == 'admin') {
      await ensureAdminSeed();
    }

    return AdminUserAccessInfo(role: resolvedRole, isLocked: isLocked);
  }
}
