import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MyChatolic'**
  String get appName;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get commonErrorGeneric;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data.'**
  String get commonNoData;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your faith journey'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @emailInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get emailInvalidFormat;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat your password'**
  String get confirmPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @loginProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get loginProcessing;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginNoAccount;

  /// No description provided for @loginGoToRegister.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get loginGoToRegister;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get loginPasswordRequired;

  /// No description provided for @loginEmailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email is not verified. Check your inbox.'**
  String get loginEmailUnverified;

  /// No description provided for @loginProfileCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Profile data is corrupted. Please register again.'**
  String get loginProfileCorrupt;

  /// No description provided for @loginBannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get loginBannedTitle;

  /// No description provided for @loginBannedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been disabled/suspended. Please contact your parish admin for more info.'**
  String get loginBannedMessage;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection.'**
  String get loginNetworkError;

  /// No description provided for @loginUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String loginUnknownError(Object error);

  /// No description provided for @registerTitleStep1.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitleStep1;

  /// No description provided for @registerSubtitleStep1.
  ///
  /// In en, this message translates to:
  /// **'Start your faith journey today.'**
  String get registerSubtitleStep1;

  /// No description provided for @registerTitleStep2.
  ///
  /// In en, this message translates to:
  /// **'Personal info'**
  String get registerTitleStep2;

  /// No description provided for @registerSubtitleStep2.
  ///
  /// In en, this message translates to:
  /// **'Tell us a bit about you.'**
  String get registerSubtitleStep2;

  /// No description provided for @registerTitleStep3.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get registerTitleStep3;

  /// No description provided for @registerSubtitleStep3.
  ///
  /// In en, this message translates to:
  /// **'Where do you attend church?'**
  String get registerSubtitleStep3;

  /// No description provided for @registerTitleStep4.
  ///
  /// In en, this message translates to:
  /// **'Role & status'**
  String get registerTitleStep4;

  /// No description provided for @registerSubtitleStep4.
  ///
  /// In en, this message translates to:
  /// **'How do you serve in church?'**
  String get registerSubtitleStep4;

  /// No description provided for @registerEmailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required'**
  String get registerEmailPasswordRequired;

  /// No description provided for @registerPasswordsNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerPasswordsNotMatch;

  /// No description provided for @registerPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get registerPasswordMin;

  /// No description provided for @registerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get registerNameRequired;

  /// No description provided for @registerDobRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required'**
  String get registerDobRequired;

  /// No description provided for @registerMaritalRequired.
  ///
  /// In en, this message translates to:
  /// **'Marital status is required'**
  String get registerMaritalRequired;

  /// No description provided for @registerCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Country is required'**
  String get registerCountryRequired;

  /// No description provided for @registerRoleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose your service role'**
  String get registerRoleRequired;

  /// No description provided for @registerAgreeTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the Terms & Conditions'**
  String get registerAgreeTermsRequired;

  /// No description provided for @registerFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerFullNameLabel;

  /// No description provided for @registerFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'As shown on your ID'**
  String get registerFullNameHint;

  /// No description provided for @registerBaptismNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Baptism name (optional)'**
  String get registerBaptismNameLabel;

  /// No description provided for @registerBaptismNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter baptism name if any'**
  String get registerBaptismNameHint;

  /// No description provided for @registerDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get registerDobLabel;

  /// No description provided for @registerDobHint.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get registerDobHint;

  /// No description provided for @registerMaritalStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'MARITAL STATUS'**
  String get registerMaritalStatusLabel;

  /// No description provided for @registerSelectMaritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Select marital status'**
  String get registerSelectMaritalStatus;

  /// No description provided for @registerEthnicityLabel.
  ///
  /// In en, this message translates to:
  /// **'Ethnicity'**
  String get registerEthnicityLabel;

  /// No description provided for @registerEthnicityHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Batak, Javanese, Chinese'**
  String get registerEthnicityHint;

  /// No description provided for @registerCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get registerCountryLabel;

  /// No description provided for @registerCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get registerCountryHint;

  /// No description provided for @registerDioceseLabel.
  ///
  /// In en, this message translates to:
  /// **'Diocese'**
  String get registerDioceseLabel;

  /// No description provided for @registerDioceseHint.
  ///
  /// In en, this message translates to:
  /// **'Select diocese'**
  String get registerDioceseHint;

  /// No description provided for @registerParishLabel.
  ///
  /// In en, this message translates to:
  /// **'Parish church'**
  String get registerParishLabel;

  /// No description provided for @registerParishHint.
  ///
  /// In en, this message translates to:
  /// **'Select parish church'**
  String get registerParishHint;

  /// No description provided for @registerRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE ROLE'**
  String get registerRoleLabel;

  /// No description provided for @registerRoleUmat.
  ///
  /// In en, this message translates to:
  /// **'Layperson'**
  String get registerRoleUmat;

  /// No description provided for @registerRolePriest.
  ///
  /// In en, this message translates to:
  /// **'Priest'**
  String get registerRolePriest;

  /// No description provided for @registerRoleReligious.
  ///
  /// In en, this message translates to:
  /// **'Religious (brother/sister)'**
  String get registerRoleReligious;

  /// No description provided for @registerRoleCatechist.
  ///
  /// In en, this message translates to:
  /// **'Catechist'**
  String get registerRoleCatechist;

  /// No description provided for @registerCatechumenLabel.
  ///
  /// In en, this message translates to:
  /// **'I am a catechumen / learning about the Catholic faith'**
  String get registerCatechumenLabel;

  /// No description provided for @registerTermsText.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Conditions and allow verification of my faith data.'**
  String get registerTermsText;

  /// No description provided for @registerPickLabel.
  ///
  /// In en, this message translates to:
  /// **'Select {label}'**
  String registerPickLabel(Object label);

  /// No description provided for @registerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get registerCancel;

  /// No description provided for @registerNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get registerNext;

  /// No description provided for @registerBack.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get registerBack;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get registerSubmit;

  /// No description provided for @registerProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get registerProcessing;

  /// No description provided for @registerStepLabelAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get registerStepLabelAccount;

  /// No description provided for @registerStepLabelData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get registerStepLabelData;

  /// No description provided for @registerStepLabelLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get registerStepLabelLocation;

  /// No description provided for @registerStepLabelRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get registerStepLabelRole;

  /// No description provided for @registerMaritalSingle.
  ///
  /// In en, this message translates to:
  /// **'Never married'**
  String get registerMaritalSingle;

  /// No description provided for @registerMaritalWidowed.
  ///
  /// In en, this message translates to:
  /// **'Widowed'**
  String get registerMaritalWidowed;

  /// No description provided for @registerSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registerSuccessTitle;

  /// No description provided for @registerSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created. Please verify your email first, then sign in.'**
  String get registerSuccessMessage;

  /// No description provided for @registerSuccessAction.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get registerSuccessAction;

  /// No description provided for @registerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {label}...'**
  String registerSearchHint(Object label);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// No description provided for @profileShare.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get profileShare;

  /// No description provided for @profileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// No description provided for @profileUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileUnfollow;

  /// No description provided for @profileChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get profileChat;

  /// No description provided for @profileInviteMass.
  ///
  /// In en, this message translates to:
  /// **'Invite to Mass'**
  String get profileInviteMass;

  /// No description provided for @profileGalleryTab.
  ///
  /// In en, this message translates to:
  /// **'GALLERY'**
  String get profileGalleryTab;

  /// No description provided for @profileStatusTab.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get profileStatusTab;

  /// No description provided for @profileSavedTab.
  ///
  /// In en, this message translates to:
  /// **'SAVED'**
  String get profileSavedTab;

  /// No description provided for @profileEmptyPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get profileEmptyPosts;

  /// No description provided for @profileEmptySaved.
  ///
  /// In en, this message translates to:
  /// **'No saved posts'**
  String get profileEmptySaved;

  /// No description provided for @profileNoProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile not available'**
  String get profileNoProfile;

  /// No description provided for @profileRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get profileRetry;

  /// No description provided for @profileShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Check my profile on MyChatolic!\nName: {name}\nID: {id}'**
  String profileShareMessage(Object name, Object id);

  /// No description provided for @profileBaptismName.
  ///
  /// In en, this message translates to:
  /// **'Baptism name: {name}'**
  String profileBaptismName(Object name);

  /// No description provided for @profileAge.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String profileAge(Object age);

  /// No description provided for @profileStatsPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profileStatsPosts;

  /// No description provided for @profileStatsFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileStatsFollowers;

  /// No description provided for @profileStatsFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileStatsFollowing;

  /// No description provided for @profileVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileVerified;

  /// No description provided for @profileNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get profileNotVerified;

  /// No description provided for @profileVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Your documents are being reviewed by admin.'**
  String get profileVerificationPending;

  /// No description provided for @profileVerificationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Your account is not verified. Upload documents to unlock full access.'**
  String get profileVerificationNeeded;

  /// No description provided for @profileVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'VERIFY'**
  String get profileVerifyAction;

  /// No description provided for @profileTrustCatholic.
  ///
  /// In en, this message translates to:
  /// **'100% Catholic'**
  String get profileTrustCatholic;

  /// No description provided for @profileTrustVerifiedClergy.
  ///
  /// In en, this message translates to:
  /// **'{role} verified'**
  String profileTrustVerifiedClergy(Object role);

  /// No description provided for @profileTrustPending.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get profileTrustPending;

  /// No description provided for @profileTrustCatechumen.
  ///
  /// In en, this message translates to:
  /// **'Catechumen'**
  String get profileTrustCatechumen;

  /// No description provided for @profileTrustUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get profileTrustUnverified;

  /// No description provided for @profileViewBanner.
  ///
  /// In en, this message translates to:
  /// **'View banner'**
  String get profileViewBanner;

  /// No description provided for @profileChangeBanner.
  ///
  /// In en, this message translates to:
  /// **'Change banner'**
  String get profileChangeBanner;

  /// No description provided for @profileBannerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Banner not available'**
  String get profileBannerUnavailable;

  /// No description provided for @profileViewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View photo'**
  String get profileViewPhoto;

  /// No description provided for @profileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get profileChangePhoto;

  /// No description provided for @a11yChangeBanner.
  ///
  /// In en, this message translates to:
  /// **'Change banner'**
  String get a11yChangeBanner;

  /// No description provided for @a11yBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a11yBack;

  /// No description provided for @a11yProfileBanner.
  ///
  /// In en, this message translates to:
  /// **'Profile banner'**
  String get a11yProfileBanner;

  /// No description provided for @a11yProfileAvatar.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get a11yProfileAvatar;

  /// No description provided for @a11yChatSearch.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get a11yChatSearch;

  /// No description provided for @a11yChatCreate.
  ///
  /// In en, this message translates to:
  /// **'Create chat'**
  String get a11yChatCreate;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar & Mass'**
  String get scheduleTitle;

  /// No description provided for @scheduleCalendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get scheduleCalendarLabel;

  /// No description provided for @scheduleSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Mass schedule'**
  String get scheduleSearchTitle;

  /// No description provided for @scheduleSearchButton.
  ///
  /// In en, this message translates to:
  /// **'See schedule'**
  String get scheduleSearchButton;

  /// No description provided for @scheduleResetDaily.
  ///
  /// In en, this message translates to:
  /// **'Reset to daily view'**
  String get scheduleResetDaily;

  /// No description provided for @scheduleResultsChurch.
  ///
  /// In en, this message translates to:
  /// **'Full church schedule'**
  String get scheduleResultsChurch;

  /// No description provided for @scheduleResultsToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Mass schedule'**
  String get scheduleResultsToday;

  /// No description provided for @scheduleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading schedule...'**
  String get scheduleLoading;

  /// No description provided for @scheduleEmptyTitleDaily.
  ///
  /// In en, this message translates to:
  /// **'No schedule yet'**
  String get scheduleEmptyTitleDaily;

  /// No description provided for @scheduleEmptyTitleChurch.
  ///
  /// In en, this message translates to:
  /// **'Schedule not found'**
  String get scheduleEmptyTitleChurch;

  /// No description provided for @scheduleEmptyMessageDaily.
  ///
  /// In en, this message translates to:
  /// **'No schedule for this date. Use church search below.'**
  String get scheduleEmptyMessageDaily;

  /// No description provided for @scheduleEmptyMessageChurch.
  ///
  /// In en, this message translates to:
  /// **'Try another parish or reset to daily view.'**
  String get scheduleEmptyMessageChurch;

  /// No description provided for @scheduleRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get scheduleRetry;

  /// No description provided for @schedulePickChurchFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a church first'**
  String get schedulePickChurchFirst;

  /// No description provided for @scheduleLiturgyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading liturgy info…'**
  String get scheduleLiturgyLoading;

  /// No description provided for @scheduleLiturgyMissing.
  ///
  /// In en, this message translates to:
  /// **'Liturgy info not available'**
  String get scheduleLiturgyMissing;

  /// No description provided for @scheduleLiturgyColor.
  ///
  /// In en, this message translates to:
  /// **'Liturgy color: {color}'**
  String scheduleLiturgyColor(Object color);

  /// No description provided for @scheduleReadingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reading data not available.'**
  String get scheduleReadingUnavailable;

  /// No description provided for @scheduleReadingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading verses.'**
  String get scheduleReadingLoading;

  /// No description provided for @scheduleReadingError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load verses.'**
  String get scheduleReadingError;

  /// No description provided for @scheduleLegendWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get scheduleLegendWhite;

  /// No description provided for @scheduleLegendRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get scheduleLegendRed;

  /// No description provided for @scheduleLegendGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get scheduleLegendGreen;

  /// No description provided for @scheduleLegendPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get scheduleLegendPurple;

  /// No description provided for @scheduleLegendRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get scheduleLegendRose;

  /// No description provided for @scheduleLegendBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get scheduleLegendBlack;

  /// No description provided for @scheduleCachedLiturgyShown.
  ///
  /// In en, this message translates to:
  /// **'Showing saved liturgy.'**
  String get scheduleCachedLiturgyShown;

  /// No description provided for @scheduleCachedScheduleShown.
  ///
  /// In en, this message translates to:
  /// **'Connection issue, showing saved schedule.'**
  String get scheduleCachedScheduleShown;

  /// No description provided for @scheduleCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in successful! See status in Mass Radar.'**
  String get scheduleCheckInSuccess;

  /// No description provided for @scheduleLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load schedule'**
  String get scheduleLoadErrorTitle;

  /// No description provided for @scheduleLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'There was an error loading the data.'**
  String get scheduleLoadErrorMessage;

  /// No description provided for @scheduleSearchChurchButton.
  ///
  /// In en, this message translates to:
  /// **'Find church'**
  String get scheduleSearchChurchButton;

  /// No description provided for @scheduleFeastFallback.
  ///
  /// In en, this message translates to:
  /// **'Ordinary Time'**
  String get scheduleFeastFallback;

  /// No description provided for @scheduleReadingLabel1.
  ///
  /// In en, this message translates to:
  /// **'First Reading'**
  String get scheduleReadingLabel1;

  /// No description provided for @scheduleReadingLabelPsalm.
  ///
  /// In en, this message translates to:
  /// **'Psalm'**
  String get scheduleReadingLabelPsalm;

  /// No description provided for @scheduleReadingLabelGospel.
  ///
  /// In en, this message translates to:
  /// **'Gospel'**
  String get scheduleReadingLabelGospel;

  /// No description provided for @scheduleBibleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bible feature is disabled.'**
  String get scheduleBibleDisabled;

  /// No description provided for @scheduleActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get scheduleActiveLabel;

  /// No description provided for @scheduleLanguageGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get scheduleLanguageGeneral;

  /// No description provided for @scheduleCheckInButton.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get scheduleCheckInButton;

  /// No description provided for @scheduleParishLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading parish...'**
  String get scheduleParishLoading;

  /// No description provided for @scheduleParishLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load parish data.'**
  String get scheduleParishLoadError;

  /// No description provided for @scheduleParishEmpty.
  ///
  /// In en, this message translates to:
  /// **'Parish data not available.'**
  String get scheduleParishEmpty;

  /// No description provided for @scheduleParishScheduleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading parish schedule...'**
  String get scheduleParishScheduleLoading;

  /// No description provided for @scheduleParishScheduleError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load parish schedule.'**
  String get scheduleParishScheduleError;

  /// No description provided for @scheduleParishHeader.
  ///
  /// In en, this message translates to:
  /// **'Your parish schedule'**
  String get scheduleParishHeader;

  /// No description provided for @scheduleParishEmptySchedule.
  ///
  /// In en, this message translates to:
  /// **'No schedule yet.'**
  String get scheduleParishEmptySchedule;

  /// No description provided for @scheduleParishSetupTitleUpdate.
  ///
  /// In en, this message translates to:
  /// **'Parish schedule not available'**
  String get scheduleParishSetupTitleUpdate;

  /// No description provided for @scheduleParishSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your parish'**
  String get scheduleParishSetupTitle;

  /// No description provided for @scheduleParishSetupMessageUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update your profile to see the correct parish schedule.'**
  String get scheduleParishSetupMessageUpdate;

  /// No description provided for @scheduleParishSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'Select your parish in profile to see automatic schedule.'**
  String get scheduleParishSetupMessage;

  /// No description provided for @scheduleParishSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get scheduleParishSetupAction;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTitle;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation from the + button'**
  String get chatEmptyMessage;

  /// No description provided for @chatLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chats'**
  String get chatLoadErrorTitle;

  /// No description provided for @chatLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection issue. Try again.'**
  String get chatLoadErrorMessage;

  /// No description provided for @chatSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get chatSessionExpiredTitle;

  /// No description provided for @chatSessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please log in again.'**
  String get chatSessionExpiredMessage;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This conversation will be permanently deleted.'**
  String get chatDeleteMessage;

  /// No description provided for @chatDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatDeleteCancel;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteConfirm;

  /// No description provided for @chatDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted successfully'**
  String get chatDeleteSuccess;

  /// No description provided for @chatDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete chat.'**
  String get chatDeleteFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsAccountSection;

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics (no personal data)'**
  String get settingsAnalyticsTitle;

  /// No description provided for @settingsAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Helps improve the app'**
  String get settingsAnalyticsSubtitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get settingsGeneralSection;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get settingsSecuritySection;

  /// No description provided for @settingsVerifyAccount.
  ///
  /// In en, this message translates to:
  /// **'Verify account'**
  String get settingsVerifyAccount;

  /// No description provided for @settingsVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String settingsVerificationStatus(Object status);

  /// No description provided for @settingsVerificationPendingShort.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get settingsVerificationPendingShort;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(Object version);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get settingsAbout;

  /// No description provided for @settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get settingsHelp;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get settingsBlockedUsers;

  /// No description provided for @settingsAccountSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage email, phone, password, and sessions'**
  String get settingsAccountSecuritySubtitle;

  /// No description provided for @settingsEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get settingsEmailResend;

  /// No description provided for @settingsChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get settingsChangeEmail;

  /// No description provided for @settingsEmailNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Email not available'**
  String get settingsEmailNotAvailable;

  /// No description provided for @settingsEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent'**
  String get settingsEmailSent;

  /// No description provided for @settingsInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get settingsInvalidEmail;

  /// No description provided for @settingsChangeEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get settingsChangeEmailTitle;

  /// No description provided for @settingsEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@email.com'**
  String get settingsEmailHint;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsLogoutConfirmMessage;

  /// No description provided for @settingsLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsLogoutButton;

  /// No description provided for @settingsLogoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out: {error}'**
  String settingsLogoutFailed(Object error);

  /// No description provided for @settingsUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get settingsUserNotFound;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow device'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get settingsLanguageIndonesian;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @commonInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get commonInfo;

  /// No description provided for @chatEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Start a chat'**
  String get chatEmptyCta;

  /// No description provided for @chatActionNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatActionNewChat;

  /// No description provided for @chatActionNewChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find friends and start a conversation'**
  String get chatActionNewChatSubtitle;

  /// No description provided for @chatActionCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get chatActionCreateGroup;

  /// No description provided for @chatActionCreateGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a group with mutual friends'**
  String get chatActionCreateGroupSubtitle;

  /// No description provided for @chatActionJoinLink.
  ///
  /// In en, this message translates to:
  /// **'Join via link'**
  String get chatActionJoinLink;

  /// No description provided for @chatActionJoinLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste invite link or code'**
  String get chatActionJoinLinkSubtitle;

  /// No description provided for @chatJoinLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get chatJoinLinkTitle;

  /// No description provided for @chatJoinLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Paste group link or code'**
  String get chatJoinLinkHint;

  /// No description provided for @chatJoinLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chatJoinLinkAction;

  /// No description provided for @chatJoinLinkSuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re in the group'**
  String get chatJoinLinkSuccess;

  /// No description provided for @chatJoinLinkAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in this group'**
  String get chatJoinLinkAlreadyMember;

  /// No description provided for @chatJoinLinkPending.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Waiting for approval.'**
  String get chatJoinLinkPending;

  /// No description provided for @chatJoinLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid link or code'**
  String get chatJoinLinkInvalid;

  /// No description provided for @chatJoinLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join group'**
  String get chatJoinLinkFailed;

  /// No description provided for @chatMutualRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Mutual follow required'**
  String get chatMutualRequiredTitle;

  /// No description provided for @chatMutualRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'To create a group, you and your friends must follow each other.'**
  String get chatMutualRequiredMessage;

  /// No description provided for @chatLeaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave group?'**
  String get chatLeaveGroupTitle;

  /// No description provided for @chatLeaveGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'You will leave this group chat.'**
  String get chatLeaveGroupMessage;

  /// No description provided for @chatLeaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chatLeaveGroupConfirm;

  /// No description provided for @chatLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chatLeaveGroup;

  /// No description provided for @chatLeaveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Leave group is not available yet.'**
  String get chatLeaveUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
