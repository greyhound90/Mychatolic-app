// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MyChatolic';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonErrorGeneric => 'Something went wrong.';

  @override
  String get commonNoData => 'No data.';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to continue your faith journey';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get emailInvalidFormat => 'Invalid email format';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Repeat your password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginProcessing => 'Processing...';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginGoToRegister => 'SIGN UP';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginPasswordRequired => 'Please enter your password';

  @override
  String get loginEmailUnverified => 'Email is not verified. Check your inbox.';

  @override
  String get loginProfileCorrupt =>
      'Profile data is corrupted. Please register again.';

  @override
  String get loginBannedTitle => 'Access denied';

  @override
  String get loginBannedMessage =>
      'Your account has been disabled/suspended. Please contact your parish admin for more info.';

  @override
  String get loginInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get loginNetworkError => 'Check your internet connection.';

  @override
  String loginUnknownError(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get registerTitleStep1 => 'Create account';

  @override
  String get registerSubtitleStep1 => 'Start your faith journey today.';

  @override
  String get registerTitleStep2 => 'Personal info';

  @override
  String get registerSubtitleStep2 => 'Tell us a bit about you.';

  @override
  String get registerTitleStep3 => 'Location';

  @override
  String get registerSubtitleStep3 => 'Where do you attend church?';

  @override
  String get registerTitleStep4 => 'Role & status';

  @override
  String get registerSubtitleStep4 => 'How do you serve in church?';

  @override
  String get registerEmailPasswordRequired => 'Email and password are required';

  @override
  String get registerPasswordsNotMatch => 'Passwords do not match';

  @override
  String get registerPasswordMin => 'Password must be at least 6 characters';

  @override
  String get registerNameRequired => 'Full name is required';

  @override
  String get registerDobRequired => 'Date of birth is required';

  @override
  String get registerMaritalRequired => 'Marital status is required';

  @override
  String get registerCountryRequired => 'Country is required';

  @override
  String get registerRoleRequired => 'Please choose your service role';

  @override
  String get registerAgreeTermsRequired =>
      'You must agree to the Terms & Conditions';

  @override
  String get registerFullNameLabel => 'Full name';

  @override
  String get registerFullNameHint => 'As shown on your ID';

  @override
  String get registerBaptismNameLabel => 'Baptism name (optional)';

  @override
  String get registerBaptismNameHint => 'Enter baptism name if any';

  @override
  String get registerDobLabel => 'Date of birth';

  @override
  String get registerDobHint => 'DD/MM/YYYY';

  @override
  String get registerMaritalStatusLabel => 'MARITAL STATUS';

  @override
  String get registerSelectMaritalStatus => 'Select marital status';

  @override
  String get registerEthnicityLabel => 'Ethnicity';

  @override
  String get registerEthnicityHint => 'Example: Batak, Javanese, Chinese';

  @override
  String get registerCountryLabel => 'Country';

  @override
  String get registerCountryHint => 'Select country';

  @override
  String get registerDioceseLabel => 'Diocese';

  @override
  String get registerDioceseHint => 'Select diocese';

  @override
  String get registerParishLabel => 'Parish church';

  @override
  String get registerParishHint => 'Select parish church';

  @override
  String get registerRoleLabel => 'CHOOSE ROLE';

  @override
  String get registerRoleUmat => 'Layperson';

  @override
  String get registerRolePriest => 'Priest';

  @override
  String get registerRoleReligious => 'Religious (brother/sister)';

  @override
  String get registerRoleCatechist => 'Catechist';

  @override
  String get registerCatechumenLabel =>
      'I am a catechumen / learning about the Catholic faith';

  @override
  String get registerTermsText =>
      'I agree to the Terms & Conditions and allow verification of my faith data.';

  @override
  String registerPickLabel(Object label) {
    return 'Select $label';
  }

  @override
  String get registerCancel => 'Cancel';

  @override
  String get registerNext => 'NEXT';

  @override
  String get registerBack => 'BACK';

  @override
  String get registerSubmit => 'SIGN UP';

  @override
  String get registerProcessing => 'Processing...';

  @override
  String get registerStepLabelAccount => 'Account';

  @override
  String get registerStepLabelData => 'Data';

  @override
  String get registerStepLabelLocation => 'Location';

  @override
  String get registerStepLabelRole => 'Role';

  @override
  String get registerMaritalSingle => 'Never married';

  @override
  String get registerMaritalWidowed => 'Widowed';

  @override
  String get registerSuccessTitle => 'Registration successful';

  @override
  String get registerSuccessMessage =>
      'Your account has been created. Please verify your email first, then sign in.';

  @override
  String get registerSuccessAction => 'Go to sign in';

  @override
  String registerSearchHint(Object label) {
    return 'Search $label...';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileShare => 'Share profile';

  @override
  String get profileFollow => 'Follow';

  @override
  String get profileUnfollow => 'Following';

  @override
  String get profileChat => 'Chat';

  @override
  String get profileInviteMass => 'Invite to Mass';

  @override
  String get profileGalleryTab => 'GALLERY';

  @override
  String get profileStatusTab => 'STATUS';

  @override
  String get profileSavedTab => 'SAVED';

  @override
  String get profileEmptyPosts => 'No posts yet';

  @override
  String get profileEmptySaved => 'No saved posts';

  @override
  String get profileNoProfile => 'Profile not available';

  @override
  String get profileRetry => 'Try again';

  @override
  String profileShareMessage(Object name, Object id) {
    return 'Check my profile on MyChatolic!\nName: $name\nID: $id';
  }

  @override
  String profileBaptismName(Object name) {
    return 'Baptism name: $name';
  }

  @override
  String profileAge(Object age) {
    return '$age years';
  }

  @override
  String get profileStatsPosts => 'Posts';

  @override
  String get profileStatsFollowers => 'Followers';

  @override
  String get profileStatsFollowing => 'Following';

  @override
  String get profileVerified => 'Verified';

  @override
  String get profileNotVerified => 'Not verified';

  @override
  String get profileVerificationPending =>
      'Your documents are being reviewed by admin.';

  @override
  String get profileVerificationNeeded =>
      'Your account is not verified. Upload documents to unlock full access.';

  @override
  String get profileVerifyAction => 'VERIFY';

  @override
  String get profileTrustCatholic => '100% Catholic';

  @override
  String profileTrustVerifiedClergy(Object role) {
    return '$role verified';
  }

  @override
  String get profileTrustPending => 'Verification pending';

  @override
  String get profileTrustCatechumen => 'Catechumen';

  @override
  String get profileTrustUnverified => 'Not verified';

  @override
  String get profileViewBanner => 'View banner';

  @override
  String get profileChangeBanner => 'Change banner';

  @override
  String get profileBannerUnavailable => 'Banner not available';

  @override
  String get profileViewPhoto => 'View photo';

  @override
  String get profileChangePhoto => 'Change profile photo';

  @override
  String get a11yChangeBanner => 'Change banner';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yProfileBanner => 'Profile banner';

  @override
  String get a11yProfileAvatar => 'Profile photo';

  @override
  String get a11yChatSearch => 'Search chats';

  @override
  String get a11yChatCreate => 'Create chat';

  @override
  String get scheduleTitle => 'Calendar & Mass';

  @override
  String get scheduleCalendarLabel => 'Calendar';

  @override
  String get scheduleSearchTitle => 'Find Mass schedule';

  @override
  String get scheduleSearchButton => 'See schedule';

  @override
  String get scheduleResetDaily => 'Reset to daily view';

  @override
  String get scheduleResultsChurch => 'Full church schedule';

  @override
  String get scheduleResultsToday => 'Today\'s Mass schedule';

  @override
  String get scheduleLoading => 'Loading schedule...';

  @override
  String get scheduleEmptyTitleDaily => 'No schedule yet';

  @override
  String get scheduleEmptyTitleChurch => 'Schedule not found';

  @override
  String get scheduleEmptyMessageDaily =>
      'No schedule for this date. Use church search below.';

  @override
  String get scheduleEmptyMessageChurch =>
      'Try another parish or reset to daily view.';

  @override
  String get scheduleRetry => 'Retry';

  @override
  String get schedulePickChurchFirst => 'Please select a church first';

  @override
  String get scheduleLiturgyLoading => 'Loading liturgy info…';

  @override
  String get scheduleLiturgyMissing => 'Liturgy info not available';

  @override
  String scheduleLiturgyColor(Object color) {
    return 'Liturgy color: $color';
  }

  @override
  String get scheduleReadingUnavailable => 'Reading data not available.';

  @override
  String get scheduleReadingLoading => 'Loading verses.';

  @override
  String get scheduleReadingError => 'Failed to load verses.';

  @override
  String get scheduleLegendWhite => 'White';

  @override
  String get scheduleLegendRed => 'Red';

  @override
  String get scheduleLegendGreen => 'Green';

  @override
  String get scheduleLegendPurple => 'Purple';

  @override
  String get scheduleLegendRose => 'Rose';

  @override
  String get scheduleLegendBlack => 'Black';

  @override
  String get scheduleCachedLiturgyShown => 'Showing saved liturgy.';

  @override
  String get scheduleCachedScheduleShown =>
      'Connection issue, showing saved schedule.';

  @override
  String get scheduleCheckInSuccess =>
      'Check-in successful! See status in Mass Radar.';

  @override
  String get scheduleLoadErrorTitle => 'Failed to load schedule';

  @override
  String get scheduleLoadErrorMessage => 'There was an error loading the data.';

  @override
  String get scheduleSearchChurchButton => 'Find church';

  @override
  String get scheduleFeastFallback => 'Ordinary Time';

  @override
  String get scheduleReadingLabel1 => 'First Reading';

  @override
  String get scheduleReadingLabelPsalm => 'Psalm';

  @override
  String get scheduleReadingLabelGospel => 'Gospel';

  @override
  String get scheduleBibleDisabled => 'Bible feature is disabled.';

  @override
  String get scheduleActiveLabel => 'ACTIVE';

  @override
  String get scheduleLanguageGeneral => 'General';

  @override
  String get scheduleCheckInButton => 'Check-in';

  @override
  String get scheduleParishLoading => 'Loading parish...';

  @override
  String get scheduleParishLoadError => 'Failed to load parish data.';

  @override
  String get scheduleParishEmpty => 'Parish data not available.';

  @override
  String get scheduleParishScheduleLoading => 'Loading parish schedule...';

  @override
  String get scheduleParishScheduleError => 'Failed to load parish schedule.';

  @override
  String get scheduleParishHeader => 'Your parish schedule';

  @override
  String get scheduleParishEmptySchedule => 'No schedule yet.';

  @override
  String get scheduleParishSetupTitleUpdate => 'Parish schedule not available';

  @override
  String get scheduleParishSetupTitle => 'Set your parish';

  @override
  String get scheduleParishSetupMessageUpdate =>
      'Update your profile to see the correct parish schedule.';

  @override
  String get scheduleParishSetupMessage =>
      'Select your parish in profile to see automatic schedule.';

  @override
  String get scheduleParishSetupAction => 'Set up';

  @override
  String get chatTitle => 'Messages';

  @override
  String get chatEmptyTitle => 'No messages yet';

  @override
  String get chatEmptyMessage => 'Start a new conversation from the + button';

  @override
  String get chatLoadErrorTitle => 'Failed to load chats';

  @override
  String get chatLoadErrorMessage => 'Connection issue. Try again.';

  @override
  String get chatSessionExpiredTitle => 'Session expired';

  @override
  String get chatSessionExpiredMessage => 'Please log in again.';

  @override
  String get chatDeleteTitle => 'Delete chat?';

  @override
  String get chatDeleteMessage =>
      'This conversation will be permanently deleted.';

  @override
  String get chatDeleteCancel => 'Cancel';

  @override
  String get chatDeleteConfirm => 'Delete';

  @override
  String get chatDeleteSuccess => 'Chat deleted successfully';

  @override
  String get chatDeleteFailed => 'Failed to delete chat.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'ACCOUNT';

  @override
  String get settingsSecurityTitle => 'Account security';

  @override
  String get settingsAnalyticsTitle => 'Analytics (no personal data)';

  @override
  String get settingsAnalyticsSubtitle => 'Helps improve the app';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Choose app language';

  @override
  String get settingsGeneralSection => 'GENERAL';

  @override
  String get settingsSecuritySection => 'SECURITY';

  @override
  String get settingsVerifyAccount => 'Verify account';

  @override
  String settingsVerificationStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get settingsVerificationPendingShort => 'Pending';

  @override
  String get settingsLogout => 'Log out';

  @override
  String settingsVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get settingsAbout => 'About app';

  @override
  String get settingsHelp => 'Help & support';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsBlockedUsers => 'Blocked users';

  @override
  String get settingsAccountSecuritySubtitle =>
      'Manage email, phone, password, and sessions';

  @override
  String get settingsEmailResend => 'Resend verification email';

  @override
  String get settingsChangeEmail => 'Change email';

  @override
  String get settingsEmailNotAvailable => 'Email not available';

  @override
  String get settingsEmailSent => 'Verification email sent';

  @override
  String get settingsInvalidEmail => 'Invalid email format';

  @override
  String get settingsChangeEmailTitle => 'Change email';

  @override
  String get settingsEmailHint => 'name@email.com';

  @override
  String get settingsLogoutConfirmTitle => 'Sign out';

  @override
  String get settingsLogoutConfirmMessage =>
      'Are you sure you want to sign out?';

  @override
  String get settingsLogoutButton => 'Sign out';

  @override
  String settingsLogoutFailed(Object error) {
    return 'Failed to sign out: $error';
  }

  @override
  String get settingsUserNotFound => 'User not found';

  @override
  String get settingsLanguageSystem => 'Follow device';

  @override
  String get settingsLanguageIndonesian => 'Bahasa Indonesia';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get commonInfo => 'Info';

  @override
  String get chatEmptyCta => 'Start a chat';

  @override
  String get chatActionNewChat => 'New chat';

  @override
  String get chatActionNewChatSubtitle =>
      'Find friends and start a conversation';

  @override
  String get chatActionCreateGroup => 'Create group';

  @override
  String get chatActionCreateGroupSubtitle =>
      'Start a group with mutual friends';

  @override
  String get chatActionJoinLink => 'Join via link';

  @override
  String get chatActionJoinLinkSubtitle => 'Paste invite link or code';

  @override
  String get chatJoinLinkTitle => 'Join group';

  @override
  String get chatJoinLinkHint => 'Paste group link or code';

  @override
  String get chatJoinLinkAction => 'Join';

  @override
  String get chatJoinLinkSuccess => 'You\'re in the group';

  @override
  String get chatJoinLinkAlreadyMember => 'You\'re already in this group';

  @override
  String get chatJoinLinkPending => 'Request sent. Waiting for approval.';

  @override
  String get chatJoinLinkInvalid => 'Invalid link or code';

  @override
  String get chatJoinLinkFailed => 'Failed to join group';

  @override
  String get chatMutualRequiredTitle => 'Mutual follow required';

  @override
  String get chatMutualRequiredMessage =>
      'To create a group, you and your friends must follow each other.';

  @override
  String get chatLeaveGroupTitle => 'Leave group?';

  @override
  String get chatLeaveGroupMessage => 'You will leave this group chat.';

  @override
  String get chatLeaveGroupConfirm => 'Leave';

  @override
  String get chatLeaveGroup => 'Leave';

  @override
  String get chatLeaveUnavailable => 'Leave group is not available yet.';

  @override
  String get chatSearchTileTitle => 'Search friends';

  @override
  String get chatSearchTileSubtitle => 'Find people from your parish';

  @override
  String get chatPreviewEmpty => 'Start a conversation';

  @override
  String get chatYesterday => 'Yesterday';
}
