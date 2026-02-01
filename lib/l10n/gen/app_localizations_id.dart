// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'MyChatolic';

  @override
  String get commonLoading => 'Memuat…';

  @override
  String get commonErrorGeneric => 'Terjadi kesalahan.';

  @override
  String get commonNoData => 'Tidak ada data.';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonRetry => 'Coba Lagi';

  @override
  String get commonSave => 'Simpan';

  @override
  String get commonBack => 'Kembali';

  @override
  String get commonNext => 'Lanjut';

  @override
  String get commonSubmit => 'Kirim';

  @override
  String get loginTitle => 'Selamat Datang Kembali';

  @override
  String get loginSubtitle => 'Masuk untuk melanjutkan perjalanan imanmu';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'Masukkan email';

  @override
  String get emailInvalidFormat => 'Format email tidak valid';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Masukkan password';

  @override
  String get confirmPasswordLabel => 'Konfirmasi Password';

  @override
  String get confirmPasswordHint => 'Ulangi password';

  @override
  String get loginButton => 'Masuk';

  @override
  String get loginProcessing => 'Memproses...';

  @override
  String get loginNoAccount => 'Belum punya akun?';

  @override
  String get loginGoToRegister => 'DAFTAR';

  @override
  String get loginForgotPassword => 'Lupa Password?';

  @override
  String get loginPasswordRequired => 'Masukkan password anda';

  @override
  String get loginEmailUnverified =>
      'Email belum diverifikasi. Cek inbox Anda.';

  @override
  String get loginProfileCorrupt => 'Data profil korup. Silakan daftar ulang.';

  @override
  String get loginBannedTitle => 'Akses Ditolak';

  @override
  String get loginBannedMessage =>
      'Akun Anda telah dinonaktifkan/ditangguhkan. Harap hubungi admin paroki untuk info lebih lanjut.';

  @override
  String get loginInvalidCredentials => 'Email atau sandi salah.';

  @override
  String get loginNetworkError => 'Periksa koneksi internet.';

  @override
  String loginUnknownError(Object error) {
    return 'Terjadi kesalahan: $error';
  }

  @override
  String get registerTitleStep1 => 'Buat Akun';

  @override
  String get registerSubtitleStep1 => 'Mulai perjalanan iman anda sekarang.';

  @override
  String get registerTitleStep2 => 'Data Diri';

  @override
  String get registerSubtitleStep2 => 'Beritahu kami sedikit tentang anda.';

  @override
  String get registerTitleStep3 => 'Lokasi';

  @override
  String get registerSubtitleStep3 => 'Dimana anda bergereja saat ini?';

  @override
  String get registerTitleStep4 => 'Peran & Status';

  @override
  String get registerSubtitleStep4 => 'Bagaimana anda melayani gereja?';

  @override
  String get registerEmailPasswordRequired => 'Email dan Password wajib diisi';

  @override
  String get registerPasswordsNotMatch => 'Password tidak sama';

  @override
  String get registerPasswordMin => 'Password minimal 6 karakter';

  @override
  String get registerNameRequired => 'Nama Lengkap wajib diisi';

  @override
  String get registerDobRequired => 'Tanggal Lahir wajib diisi';

  @override
  String get registerMaritalRequired => 'Status Pernikahan wajib dipilih';

  @override
  String get registerCountryRequired => 'Negara wajib dipilih';

  @override
  String get registerRoleRequired => 'Pilih peran pelayanan anda';

  @override
  String get registerAgreeTermsRequired =>
      'Anda harus menyetujui Syarat & Ketentuan';

  @override
  String get registerFullNameLabel => 'Nama Lengkap';

  @override
  String get registerFullNameHint => 'Sesuai dengan KTP';

  @override
  String get registerBaptismNameLabel => 'Nama Baptis (Opsional)';

  @override
  String get registerBaptismNameHint => 'Masukkan nama baptis jika ada';

  @override
  String get registerDobLabel => 'Tanggal Lahir';

  @override
  String get registerDobHint => 'DD/MM/YYYY';

  @override
  String get registerMaritalStatusLabel => 'STATUS PERNIKAHAN';

  @override
  String get registerSelectMaritalStatus => 'Pilih Status Pernikahan';

  @override
  String get registerEthnicityLabel => 'Suku / Etnis';

  @override
  String get registerEthnicityHint => 'Contoh: Batak, Jawa, Chinese';

  @override
  String get registerCountryLabel => 'Negara';

  @override
  String get registerCountryHint => 'Pilih Negara';

  @override
  String get registerDioceseLabel => 'Keuskupan';

  @override
  String get registerDioceseHint => 'Pilih Keuskupan';

  @override
  String get registerParishLabel => 'Gereja Paroki';

  @override
  String get registerParishHint => 'Pilih Gereja Paroki';

  @override
  String get registerRoleLabel => 'PILIH PERAN';

  @override
  String get registerRoleUmat => 'Umat';

  @override
  String get registerRolePriest => 'Imam';

  @override
  String get registerRoleReligious => 'Biarawan/wati';

  @override
  String get registerRoleCatechist => 'Katekis';

  @override
  String get registerCatechumenLabel =>
      'Saya calon katekumen / sedang belajar agama Katolik';

  @override
  String get registerTermsText =>
      'Saya menyetujui S&K dan bersedia data iman saya diverifikasi.';

  @override
  String registerPickLabel(Object label) {
    return 'Pilih $label';
  }

  @override
  String get registerCancel => 'Batal';

  @override
  String get registerNext => 'LANJUT';

  @override
  String get registerBack => 'KEMBALI';

  @override
  String get registerSubmit => 'DAFTAR';

  @override
  String get registerProcessing => 'Memproses...';

  @override
  String get registerStepLabelAccount => 'Akun';

  @override
  String get registerStepLabelData => 'Data';

  @override
  String get registerStepLabelLocation => 'Lokasi';

  @override
  String get registerStepLabelRole => 'Peran';

  @override
  String get registerMaritalSingle => 'Belum Pernah Menikah';

  @override
  String get registerMaritalWidowed => 'Cerai Mati';

  @override
  String get registerSuccessTitle => 'Registrasi Berhasil';

  @override
  String get registerSuccessMessage =>
      'Akun Anda telah dibuat. Silakan verifikasi email terlebih dahulu, lalu login kembali.';

  @override
  String get registerSuccessAction => 'Masuk Aplikasi';

  @override
  String registerSearchHint(Object label) {
    return 'Cari $label...';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileEdit => 'Edit Profil';

  @override
  String get profileShare => 'Bagikan Profil';

  @override
  String get profileFollow => 'Follow';

  @override
  String get profileUnfollow => 'Mengikuti';

  @override
  String get profileChat => 'Chat';

  @override
  String get profileInviteMass => 'Ajak Misa';

  @override
  String get profileGalleryTab => 'GALERI';

  @override
  String get profileStatusTab => 'STATUS';

  @override
  String get profileSavedTab => 'DISIMPAN';

  @override
  String get profileEmptyPosts => 'Belum ada postingan';

  @override
  String get profileEmptySaved => 'Belum ada postingan disimpan';

  @override
  String get profileNoProfile => 'Profil belum tersedia';

  @override
  String get profileRetry => 'Coba lagi';

  @override
  String profileShareMessage(Object name, Object id) {
    return 'Cek profil saya di MyChatolic!\nNama: $name\nID: $id';
  }

  @override
  String profileBaptismName(Object name) {
    return 'Nama Baptis: $name';
  }

  @override
  String profileAge(Object age) {
    return '$age Tahun';
  }

  @override
  String get profileStatsPosts => 'Post';

  @override
  String get profileStatsFollowers => 'Pengikut';

  @override
  String get profileStatsFollowing => 'Mengikuti';

  @override
  String get profileVerified => 'Terverifikasi';

  @override
  String get profileNotVerified => 'Belum terverifikasi';

  @override
  String get profileVerificationPending =>
      'Dokumen Anda sedang ditinjau oleh Admin.';

  @override
  String get profileVerificationNeeded =>
      'Akun belum terverifikasi. Upload dokumen untuk akses fitur penuh.';

  @override
  String get profileVerifyAction => 'VERIFIKASI';

  @override
  String get profileTrustCatholic => '100% Katolik';

  @override
  String profileTrustVerifiedClergy(Object role) {
    return '$role Terverifikasi';
  }

  @override
  String get profileTrustPending => 'Menunggu Verifikasi';

  @override
  String get profileTrustCatechumen => 'Katekumen';

  @override
  String get profileTrustUnverified => 'Belum Verifikasi';

  @override
  String get profileViewBanner => 'Lihat Banner';

  @override
  String get profileChangeBanner => 'Ganti Banner';

  @override
  String get profileBannerUnavailable => 'Banner belum tersedia';

  @override
  String get profileViewPhoto => 'Lihat Foto';

  @override
  String get profileChangePhoto => 'Ganti Foto Profil';

  @override
  String get a11yChangeBanner => 'Ganti Banner';

  @override
  String get a11yBack => 'Kembali';

  @override
  String get a11yProfileBanner => 'Banner profil';

  @override
  String get a11yProfileAvatar => 'Foto profil';

  @override
  String get a11yChatSearch => 'Cari chat';

  @override
  String get a11yChatCreate => 'Buat chat';

  @override
  String get scheduleTitle => 'Kalender & Misa';

  @override
  String get scheduleCalendarLabel => 'Kalender';

  @override
  String get scheduleSearchTitle => 'Cari Jadwal Misa';

  @override
  String get scheduleSearchButton => 'Lihat Jadwal';

  @override
  String get scheduleResetDaily => 'Reset ke Tampilan Harian';

  @override
  String get scheduleResultsChurch => 'Jadwal Lengkap Gereja';

  @override
  String get scheduleResultsToday => 'Jadwal Misa Hari Ini';

  @override
  String get scheduleLoading => 'Memuat jadwal...';

  @override
  String get scheduleEmptyTitleDaily => 'Belum Ada Jadwal';

  @override
  String get scheduleEmptyTitleChurch => 'Jadwal Tidak Ditemukan';

  @override
  String get scheduleEmptyMessageDaily =>
      'Tidak ada jadwal untuk tanggal ini. Gunakan pencarian gereja di bawah.';

  @override
  String get scheduleEmptyMessageChurch =>
      'Coba ganti paroki atau reset ke tampilan harian.';

  @override
  String get scheduleRetry => 'Coba Lagi';

  @override
  String get schedulePickChurchFirst => 'Pilih Gereja terlebih dahulu';

  @override
  String get scheduleLiturgyLoading => 'Memuat info liturgi…';

  @override
  String get scheduleLiturgyMissing => 'Info liturgi belum tersedia';

  @override
  String scheduleLiturgyColor(Object color) {
    return 'Warna Liturgi: $color';
  }

  @override
  String get scheduleReadingUnavailable => 'Data bacaan belum tersedia.';

  @override
  String get scheduleReadingLoading => 'Memuat ayat.';

  @override
  String get scheduleReadingError => 'Gagal memuat ayat.';

  @override
  String get scheduleLegendWhite => 'Putih';

  @override
  String get scheduleLegendRed => 'Merah';

  @override
  String get scheduleLegendGreen => 'Hijau';

  @override
  String get scheduleLegendPurple => 'Ungu';

  @override
  String get scheduleLegendRose => 'Rose';

  @override
  String get scheduleLegendBlack => 'Hitam';

  @override
  String get scheduleCachedLiturgyShown => 'Menampilkan liturgi tersimpan.';

  @override
  String get scheduleCachedScheduleShown =>
      'Koneksi bermasalah, menampilkan jadwal tersimpan.';

  @override
  String get scheduleCheckInSuccess =>
      'Berhasil Check-in! Lihat status di Radar Misa.';

  @override
  String get scheduleLoadErrorTitle => 'Gagal memuat jadwal';

  @override
  String get scheduleLoadErrorMessage => 'Terjadi kesalahan saat memuat data.';

  @override
  String get scheduleSearchChurchButton => 'Cari Gereja';

  @override
  String get scheduleFeastFallback => 'Hari Biasa';

  @override
  String get scheduleReadingLabel1 => 'Bacaan 1';

  @override
  String get scheduleReadingLabelPsalm => 'Mazmur';

  @override
  String get scheduleReadingLabelGospel => 'Injil';

  @override
  String get scheduleBibleDisabled => 'Fitur Alkitab dinonaktifkan.';

  @override
  String get scheduleActiveLabel => 'AKTIF';

  @override
  String get scheduleLanguageGeneral => 'Umum';

  @override
  String get scheduleCheckInButton => 'Check-in';

  @override
  String get scheduleParishLoading => 'Memuat paroki...';

  @override
  String get scheduleParishLoadError => 'Gagal memuat data paroki.';

  @override
  String get scheduleParishEmpty => 'Data paroki belum tersedia.';

  @override
  String get scheduleParishScheduleLoading => 'Memuat jadwal paroki...';

  @override
  String get scheduleParishScheduleError => 'Gagal memuat jadwal paroki.';

  @override
  String get scheduleParishHeader => 'Jadwal Paroki Anda';

  @override
  String get scheduleParishEmptySchedule => 'Belum ada jadwal.';

  @override
  String get scheduleParishSetupTitleUpdate => 'Jadwal Paroki Belum Tersedia';

  @override
  String get scheduleParishSetupTitle => 'Atur Paroki Anda';

  @override
  String get scheduleParishSetupMessageUpdate =>
      'Perbarui profil untuk melihat jadwal paroki yang benar.';

  @override
  String get scheduleParishSetupMessage =>
      'Pilih paroki di profil untuk lihat jadwal otomatis.';

  @override
  String get scheduleParishSetupAction => 'Atur';

  @override
  String get chatTitle => 'Pesan';

  @override
  String get chatEmptyTitle => 'Belum ada pesan';

  @override
  String get chatEmptyMessage => 'Mulai percakapan baru dari tombol +';

  @override
  String get chatLoadErrorTitle => 'Gagal memuat chat';

  @override
  String get chatLoadErrorMessage => 'Koneksi bermasalah. Coba lagi.';

  @override
  String get chatSessionExpiredTitle => 'Sesi berakhir';

  @override
  String get chatSessionExpiredMessage => 'Silakan login ulang.';

  @override
  String get chatDeleteTitle => 'Hapus Chat?';

  @override
  String get chatDeleteMessage => 'Obrolan ini akan dihapus permanen.';

  @override
  String get chatDeleteCancel => 'Batal';

  @override
  String get chatDeleteConfirm => 'Hapus';

  @override
  String get chatDeleteSuccess => 'Chat berhasil dihapus';

  @override
  String get chatDeleteFailed => 'Gagal hapus chat.';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsAccountSection => 'AKUN';

  @override
  String get settingsSecurityTitle => 'Keamanan Akun';

  @override
  String get settingsAnalyticsTitle => 'Analytics (tanpa data pribadi)';

  @override
  String get settingsAnalyticsSubtitle => 'Membantu peningkatan aplikasi';

  @override
  String get settingsLanguageTitle => 'Bahasa';

  @override
  String get settingsLanguageSubtitle => 'Pilih bahasa aplikasi';

  @override
  String get settingsGeneralSection => 'UMUM';

  @override
  String get settingsSecuritySection => 'KEAMANAN';

  @override
  String get settingsVerifyAccount => 'Verifikasi Akun';

  @override
  String settingsVerificationStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get settingsVerificationPendingShort => 'Menunggu';

  @override
  String get settingsLogout => 'Keluar';

  @override
  String settingsVersion(Object version) {
    return 'Versi $version';
  }

  @override
  String get settingsAbout => 'Tentang Aplikasi';

  @override
  String get settingsHelp => 'Bantuan & Dukungan';

  @override
  String get settingsChangePassword => 'Ubah Kata Sandi';

  @override
  String get settingsBlockedUsers => 'Pengguna yang Diblokir';

  @override
  String get settingsAccountSecuritySubtitle =>
      'Kelola email, nomor HP, password, dan sesi';

  @override
  String get settingsEmailResend => 'Kirim ulang verifikasi email';

  @override
  String get settingsChangeEmail => 'Ganti email';

  @override
  String get settingsEmailNotAvailable => 'Email tidak tersedia';

  @override
  String get settingsEmailSent => 'Email verifikasi dikirim';

  @override
  String get settingsInvalidEmail => 'Format email tidak valid';

  @override
  String get settingsChangeEmailTitle => 'Ganti Email';

  @override
  String get settingsEmailHint => 'nama@email.com';

  @override
  String get settingsLogoutConfirmTitle => 'Keluar Akun';

  @override
  String get settingsLogoutConfirmMessage =>
      'Apakah Anda yakin ingin keluar dari aplikasi?';

  @override
  String get settingsLogoutButton => 'Keluar';

  @override
  String settingsLogoutFailed(Object error) {
    return 'Gagal keluar: $error';
  }

  @override
  String get settingsUserNotFound => 'User tidak ditemukan';

  @override
  String get settingsLanguageSystem => 'Ikuti perangkat';

  @override
  String get settingsLanguageIndonesian => 'Bahasa Indonesia';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get commonInfo => 'Info';

  @override
  String get chatEmptyCta => 'Mulai Chat';

  @override
  String get chatActionNewChat => 'Chat baru';

  @override
  String get chatActionNewChatSubtitle => 'Cari teman dan mulai percakapan';

  @override
  String get chatActionCreateGroup => 'Buat Grup';

  @override
  String get chatActionCreateGroupSubtitle => 'Mulai grup dengan teman mutual';

  @override
  String get chatActionJoinLink => 'Gabung via tautan';

  @override
  String get chatActionJoinLinkSubtitle => 'Tempel tautan atau kode undangan';

  @override
  String get chatJoinLinkTitle => 'Gabung grup';

  @override
  String get chatJoinLinkHint => 'Tempel tautan/kode grup';

  @override
  String get chatJoinLinkAction => 'Gabung';

  @override
  String get chatJoinLinkSuccess => 'Berhasil bergabung ke grup';

  @override
  String get chatJoinLinkAlreadyMember => 'Kamu sudah ada di grup ini';

  @override
  String get chatJoinLinkPending =>
      'Permintaan terkirim. Menunggu persetujuan.';

  @override
  String get chatJoinLinkInvalid => 'Tautan atau kode tidak valid';

  @override
  String get chatJoinLinkFailed => 'Gagal bergabung ke grup';

  @override
  String get chatMutualRequiredTitle => 'Butuh saling follow';

  @override
  String get chatMutualRequiredMessage =>
      'Untuk membuat grup, kamu dan teman harus saling follow.';

  @override
  String get chatLeaveGroupTitle => 'Keluar dari grup?';

  @override
  String get chatLeaveGroupMessage => 'Kamu akan keluar dari grup ini.';

  @override
  String get chatLeaveGroupConfirm => 'Keluar';

  @override
  String get chatLeaveGroup => 'Keluar';

  @override
  String get chatLeaveUnavailable => 'Keluar grup belum tersedia.';

  @override
  String get chatSearchTileTitle => 'Cari Teman';

  @override
  String get chatSearchTileSubtitle => 'Temukan teman berdasarkan gereja';

  @override
  String get chatPreviewEmpty => 'Memulai percakapan';

  @override
  String get chatYesterday => 'Kemarin';

  @override
  String get friendSearchTitle => 'Cari Teman';

  @override
  String get friendSearchSelectTitle => 'Pilih Teman';

  @override
  String get friendSearchHint => 'Cari nama teman...';

  @override
  String get friendSearchFilterTitle => 'Filter Lokasi';

  @override
  String get friendSearchCountryHint => 'Pilih Negara';

  @override
  String get friendSearchDioceseHint => 'Pilih Keuskupan';

  @override
  String get friendSearchChurchHint => 'Pilih Paroki';

  @override
  String get friendSearchReset => 'Reset Filter';

  @override
  String get friendSearchEmptyTitle => 'Tidak ada hasil';

  @override
  String get friendSearchEmptySubtitle => 'Coba kata kunci lain';
}
