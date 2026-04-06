import 'service_model.dart';

final List<ServiceModel> shoppingServices = <ServiceModel>[
  const ServiceModel(
    id: 'shopee',
    name: <String, String>{'vi': 'Shopee', 'en': 'Shopee'},
    logoPath: 'assets/images/shopee.png',
    description: <String, String>{
      'vi': 'Voucher mua sam truc tuyen voi giao dich an toan.',
      'en': 'Official digital vouchers with secure checkout support.',
    },
    packages: <int>[50000, 100000, 200000, 500000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'phone',
        label: <String, String>{'vi': 'So dien thoai', 'en': 'Phone Number'},
        hint: <String, String>{
          'vi': 'Nhap so dien thoai Shopee',
          'en': 'Enter your Shopee phone number',
        },
        type: ServiceAccountInputType.phone,
        regexPattern: r'^[0-9]{9,11}$',
        errorText: <String, String>{
          'vi': 'So dien thoai phai gom 9 den 11 chu so.',
          'en': 'Phone number must contain 9 to 11 digits.',
        },
        maxLength: 11,
        digitsOnly: true,
      ),
      ServiceAccountField(
        id: 'email',
        label: <String, String>{'vi': 'Email', 'en': 'Email'},
        hint: <String, String>{
          'vi': 'Nhap email nhan hoa don',
          'en': 'Enter your billing email',
        },
        type: ServiceAccountInputType.email,
        regexPattern: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        errorText: <String, String>{
          'vi': 'Vui long nhap Email hop le.',
          'en': 'Please enter a valid email address.',
        },
      ),
    ],
  ),
  const ServiceModel(
    id: 'riot_games',
    name: <String, String>{'vi': 'Riot Games', 'en': 'Riot Games'},
    logoPath: 'assets/images/riot.png',
    description: <String, String>{
      'vi': 'Kenh nap the chinh thuc cho game thu.',
      'en': 'Official top-up channel for fast and secure game credits.',
    },
    packages: <int>[50000, 100000, 200000, 500000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'riot_tag',
        label: <String, String>{
          'vi': 'Ten nguoi dung#RiotID',
          'en': 'Username#RiotID',
        },
        hint: <String, String>{
          'vi': 'Vi du: Chii#1234',
          'en': 'Example: Chii#1234',
        },
        type: ServiceAccountInputType.riotTag,
        regexPattern: r'^[^\s]+#[0-9]{4}$',
        errorText: <String, String>{
          'vi': 'RiotID phai theo dinh dang Ten#1234.',
          'en': 'Riot ID must follow the format Username#1234.',
        },
      ),
    ],
  ),
  const ServiceModel(
    id: 'netflix',
    name: <String, String>{'vi': 'Netflix', 'en': 'Netflix'},
    logoPath: 'assets/images/netflix.png',
    description: <String, String>{
      'vi': 'Dang ky goi xem phim nhanh gon va an toan.',
      'en': 'Official channel, safe and secure.',
    },
    packages: <int>[108000, 220000, 260000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'email',
        label: <String, String>{'vi': 'Email', 'en': 'Email'},
        hint: <String, String>{
          'vi': 'Nhap email tai khoan Netflix',
          'en': 'Enter your Netflix account email',
        },
        type: ServiceAccountInputType.email,
        regexPattern: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        errorText: <String, String>{
          'vi': 'Vui long nhap Email hop le.',
          'en': 'Please enter a valid email address.',
        },
      ),
    ],
  ),
  const ServiceModel(
    id: 'apple_music',
    name: <String, String>{'vi': 'Apple Music', 'en': 'Apple Music'},
    logoPath: 'assets/images/itunes.png',
    description: <String, String>{
      'vi': 'Gia han goi Apple Music voi xu ly an toan.',
      'en': 'Renew Apple Music plans with secure processing.',
    },
    packages: <int>[69000, 109000, 149000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'icloud',
        label: <String, String>{'vi': 'iCloud', 'en': 'iCloud'},
        hint: <String, String>{
          'vi': 'Vi du: name@icloud.com',
          'en': 'Example: name@icloud.com',
        },
        type: ServiceAccountInputType.icloud,
        regexPattern: r'^[\w-\.]+@icloud\.com$',
        errorText: <String, String>{
          'vi': 'Vui long nhap Email iCloud hop le.',
          'en': 'Please enter a valid iCloud email address.',
        },
      ),
    ],
  ),
  const ServiceModel(
    id: 'chatgpt',
    name: <String, String>{'vi': 'ChatGPT', 'en': 'ChatGPT'},
    logoPath: 'assets/images/chatgpt.png',
    description: <String, String>{
      'vi': 'Mo khoa tinh nang AI nang cao cho hoc tap va cong viec.',
      'en': 'Activate premium AI tools for work and study.',
    },
    packages: <int>[120000, 490000, 990000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'email',
        label: <String, String>{'vi': 'Email', 'en': 'Email'},
        hint: <String, String>{
          'vi': 'Nhap email tai khoan ChatGPT',
          'en': 'Enter your ChatGPT account email',
        },
        type: ServiceAccountInputType.email,
        regexPattern: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        errorText: <String, String>{
          'vi': 'Vui long nhap Email hop le.',
          'en': 'Please enter a valid email address.',
        },
      ),
    ],
  ),
  const ServiceModel(
    id: 'steam',
    name: <String, String>{'vi': 'Steam', 'en': 'Steam'},
    logoPath: 'assets/images/steam.png',
    description: <String, String>{
      'vi': 'Nap vi Steam de mua game va vat pham.',
      'en': 'Top up your Steam wallet for games and add-ons.',
    },
    packages: <int>[50000, 100000, 200000, 500000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'steam_id',
        label: <String, String>{'vi': 'SteamID', 'en': 'SteamID'},
        hint: <String, String>{
          'vi': 'Nhap SteamID gom dung 10 chu so',
          'en': 'Enter your 10-digit SteamID',
        },
        type: ServiceAccountInputType.steamId,
        regexPattern: r'^[0-9]{10}$',
        errorText: <String, String>{
          'vi': 'SteamID phai gom dung 10 chu so.',
          'en': 'SteamID must contain exactly 10 digits.',
        },
        maxLength: 10,
        digitsOnly: true,
      ),
    ],
  ),
  const ServiceModel(
    id: 'spotify',
    name: <String, String>{'vi': 'Spotify', 'en': 'Spotify'},
    logoPath: 'assets/images/spotify.png',
    description: <String, String>{
      'vi': 'Nang cap Spotify Premium kich hoat nhanh.',
      'en': 'Upgrade to Spotify Premium with instant activation.',
    },
    packages: <int>[59000, 129000, 179000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'user_id',
        label: <String, String>{'vi': 'UserID', 'en': 'UserID'},
        hint: <String, String>{
          'vi': 'Nhap UserID Spotify',
          'en': 'Enter your Spotify UserID',
        },
        type: ServiceAccountInputType.userId,
        regexPattern: r'^[A-Za-z0-9._-]{3,32}$',
        errorText: <String, String>{
          'vi': 'UserID Spotify phai tu 3-32 ky tu (chu, so, ., _, -).',
          'en':
              'Spotify UserID must be 3-32 characters (letters, numbers, ., _, -).',
        },
      ),
    ],
  ),
  const ServiceModel(
    id: 'xanh_sm',
    name: <String, String>{'vi': 'Xanh SM', 'en': 'Xanh SM'},
    logoPath: 'assets/images/xanhsm.jpg',
    description: <String, String>{
      'vi': 'Nap tien tai khoan Xanh SM cho chuyen di hang ngay.',
      'en': 'Top up your Xanh SM account for daily rides.',
    },
    packages: <int>[50000, 100000, 200000, 500000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'phone',
        label: <String, String>{'vi': 'So dien thoai', 'en': 'Phone Number'},
        hint: <String, String>{
          'vi': 'Nhap so dien thoai tai khoan Xanh SM',
          'en': 'Enter your Xanh SM phone number',
        },
        type: ServiceAccountInputType.phone,
        regexPattern: r'^[0-9]{9,11}$',
        errorText: <String, String>{
          'vi': 'So dien thoai phai gom 9 den 11 chu so.',
          'en': 'Phone number must contain 9 to 11 digits.',
        },
        maxLength: 11,
        digitsOnly: true,
      ),
    ],
  ),
  const ServiceModel(
    id: 'grab',
    name: <String, String>{'vi': 'Grab', 'en': 'Grab'},
    logoPath: 'assets/images/grab.png',
    description: <String, String>{
      'vi': 'Nap vi Grab cho dat xe va giao do an.',
      'en': 'Top up your Grab wallet for transport and food delivery.',
    },
    packages: <int>[50000, 100000, 200000, 500000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'phone',
        label: <String, String>{'vi': 'So dien thoai', 'en': 'Phone Number'},
        hint: <String, String>{
          'vi': 'Nhap so dien thoai tai khoan Grab',
          'en': 'Enter your Grab phone number',
        },
        type: ServiceAccountInputType.phone,
        regexPattern: r'^[0-9]{9,11}$',
        errorText: <String, String>{
          'vi': 'So dien thoai phai gom 9 den 11 chu so.',
          'en': 'Phone number must contain 9 to 11 digits.',
        },
        maxLength: 11,
        digitsOnly: true,
      ),
    ],
  ),
  const ServiceModel(
    id: 'gemini',
    name: <String, String>{'vi': 'Gemini', 'en': 'Gemini'},
    logoPath: 'assets/images/gemini.png',
    description: <String, String>{
      'vi': 'Su dung goi Gemini AI cho sang tao noi dung.',
      'en': 'Unlock Gemini AI plans for content and productivity.',
    },
    packages: <int>[120000, 490000, 990000],
    accountFields: <ServiceAccountField>[
      ServiceAccountField(
        id: 'email',
        label: <String, String>{'vi': 'Email', 'en': 'Email'},
        hint: <String, String>{
          'vi': 'Nhap email tai khoan Gemini',
          'en': 'Enter your Gemini account email',
        },
        type: ServiceAccountInputType.email,
        regexPattern: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        errorText: <String, String>{
          'vi': 'Vui long nhap Email hop le.',
          'en': 'Please enter a valid email address.',
        },
      ),
    ],
  ),
];
