class AnalyticsEvents {
  static const String screenView = 'screen_view';

  static const String authLoginSuccess = 'auth_login_success';
  static const String authLoginFailed = 'auth_login_failed';
  static const String authRegisterSuccess = 'auth_register_success';
  static const String authRegisterFailed = 'auth_register_failed';

  static const String profileView = 'profile_view';
  static const String profileEditSaved = 'profile_edit_saved';
  static const String follow = 'follow';

  static const String chatOpen = 'chat_open';
  static const String chatMessageSent = 'chat_message_sent';

  static const String scheduleDayChange = 'schedule_day_change';
  static const String scheduleRefresh = 'schedule_refresh';

  static const String postCreate = 'post_create';
  static const String postLikeToggle = 'post_like_toggle';

  static const String settingsSecurityOpen = 'settings_security_open';
  static const String settingsChangeEmailAttempt = 'settings_change_email_attempt';
  static const String settingsChangeEmailSuccess = 'settings_change_email_success';
  static const String settingsChangeEmailFail = 'settings_change_email_fail';
  static const String settingsChangePasswordAttempt = 'settings_change_password_attempt';
  static const String settingsChangePasswordSuccess = 'settings_change_password_success';
  static const String settingsChangePasswordFail = 'settings_change_password_fail';
  static const String settingsChangePhoneAttempt = 'settings_change_phone_attempt';
  static const String settingsChangePhoneSuccess = 'settings_change_phone_success';
  static const String settingsChangePhoneFail = 'settings_change_phone_fail';

  static const String analyticsOptOut = 'analytics_opt_out';
}
