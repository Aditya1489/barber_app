import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('hi'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Barber Sync'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get myAccount;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @shopSettings.
  ///
  /// In en, this message translates to:
  /// **'Shop Settings'**
  String get shopSettings;

  /// No description provided for @staffManagement.
  ///
  /// In en, this message translates to:
  /// **'Staff Management'**
  String get staffManagement;

  /// No description provided for @businessAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Business Analytics'**
  String get businessAnalytics;

  /// No description provided for @staffPerformance.
  ///
  /// In en, this message translates to:
  /// **'Staff Performance'**
  String get staffPerformance;

  /// No description provided for @auditTrail.
  ///
  /// In en, this message translates to:
  /// **'Audit Trail'**
  String get auditTrail;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @todayFocus.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Focus'**
  String get todayFocus;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language / भाा'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @todayEarnings.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Earnings'**
  String get todayEarnings;

  /// No description provided for @weeklyEarnings.
  ///
  /// In en, this message translates to:
  /// **'Weekly Earnings'**
  String get weeklyEarnings;

  /// No description provided for @monthlyEarnings.
  ///
  /// In en, this message translates to:
  /// **'Monthly Earnings'**
  String get monthlyEarnings;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments'**
  String get noAppointments;

  /// No description provided for @allSystemsRunning.
  ///
  /// In en, this message translates to:
  /// **'All Systems Running Smoothly'**
  String get allSystemsRunning;

  /// No description provided for @noActionRequired.
  ///
  /// In en, this message translates to:
  /// **'No action required today'**
  String get noActionRequired;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @joinApp.
  ///
  /// In en, this message translates to:
  /// **'Join BarberSync'**
  String get joinApp;

  /// No description provided for @customerAccount.
  ///
  /// In en, this message translates to:
  /// **'Customer Account'**
  String get customerAccount;

  /// No description provided for @barberAdmin.
  ///
  /// In en, this message translates to:
  /// **'Barber & Shop Management'**
  String get barberAdmin;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log In'**
  String get haveAccount;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields'**
  String get fillAllFields;

  /// No description provided for @continueAsBarberOwner.
  ///
  /// In en, this message translates to:
  /// **'Continue as Barber / Owner'**
  String get continueAsBarberOwner;

  /// No description provided for @manageShopClients.
  ///
  /// In en, this message translates to:
  /// **'Manage your shop & clients'**
  String get manageShopClients;

  /// No description provided for @professionalGrooming.
  ///
  /// In en, this message translates to:
  /// **'Professional Grooming Marketplace'**
  String get professionalGrooming;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Your Role'**
  String get selectRole;

  /// No description provided for @shopOwnerOrBarber.
  ///
  /// In en, this message translates to:
  /// **'Are you a shop owner or a barber working in a shop?'**
  String get shopOwnerOrBarber;

  /// No description provided for @shopOwner.
  ///
  /// In en, this message translates to:
  /// **'Shop Owner'**
  String get shopOwner;

  /// No description provided for @createManageShop.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your own shop'**
  String get createManageShop;

  /// No description provided for @staffBarber.
  ///
  /// In en, this message translates to:
  /// **'Staff / Barber'**
  String get staffBarber;

  /// No description provided for @joinExistingShop.
  ///
  /// In en, this message translates to:
  /// **'Join an existing shop as a barber'**
  String get joinExistingShop;

  /// No description provided for @setupShop.
  ///
  /// In en, this message translates to:
  /// **'Setup Your Shop'**
  String get setupShop;

  /// No description provided for @tellUsAboutBusiness.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your business'**
  String get tellUsAboutBusiness;

  /// No description provided for @enterBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Enter business name'**
  String get enterBusinessName;

  /// No description provided for @detectLocation.
  ///
  /// In en, this message translates to:
  /// **'Detect Location'**
  String get detectLocation;

  /// No description provided for @locationReady.
  ///
  /// In en, this message translates to:
  /// **'Location Ready'**
  String get locationReady;

  /// No description provided for @pinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN Code'**
  String get pinCode;

  /// No description provided for @shopPhotos.
  ///
  /// In en, this message translates to:
  /// **'Shop Photos'**
  String get shopPhotos;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'UPLOAD'**
  String get upload;

  /// No description provided for @servicesOffered.
  ///
  /// In en, this message translates to:
  /// **'Services Offered'**
  String get servicesOffered;

  /// No description provided for @noServicesAdded.
  ///
  /// In en, this message translates to:
  /// **'No services added yet'**
  String get noServicesAdded;

  /// No description provided for @staffMembers.
  ///
  /// In en, this message translates to:
  /// **'Staff Members'**
  String get staffMembers;

  /// No description provided for @noStaffAdded.
  ///
  /// In en, this message translates to:
  /// **'No staff added yet'**
  String get noStaffAdded;

  /// No description provided for @addStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Add Staff Member'**
  String get addStaffMember;

  /// No description provided for @staffName.
  ///
  /// In en, this message translates to:
  /// **'Staff Name'**
  String get staffName;

  /// No description provided for @createShopStart.
  ///
  /// In en, this message translates to:
  /// **'CREATE SHOP & START'**
  String get createShopStart;

  /// No description provided for @buildProfile.
  ///
  /// In en, this message translates to:
  /// **'Build Your Profile'**
  String get buildProfile;

  /// No description provided for @linkToShop.
  ///
  /// In en, this message translates to:
  /// **'Link yourself to a nearby shop to start.'**
  String get linkToShop;

  /// No description provided for @uploadProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Profile Photo'**
  String get uploadProfilePhoto;

  /// No description provided for @yearsExperience.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get yearsExperience;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About You'**
  String get aboutYou;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio (Previous Work)'**
  String get portfolio;

  /// No description provided for @joinShopStart.
  ///
  /// In en, this message translates to:
  /// **'JOIN SHOP & START'**
  String get joinShopStart;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @createAccountContinue.
  ///
  /// In en, this message translates to:
  /// **'Create your account to continue'**
  String get createAccountContinue;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'NEXT STEP'**
  String get nextStep;

  /// No description provided for @onFire.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE ON FIRE!'**
  String get onFire;

  /// No description provided for @performanceStreak.
  ///
  /// In en, this message translates to:
  /// **'Performance Streak'**
  String get performanceStreak;

  /// No description provided for @nextClient.
  ///
  /// In en, this message translates to:
  /// **'Next Client'**
  String get nextClient;

  /// No description provided for @pendingRequest.
  ///
  /// In en, this message translates to:
  /// **'Pending Request'**
  String get pendingRequest;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get pendingRequests;

  /// No description provided for @returning.
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get returning;

  /// No description provided for @firstTime.
  ///
  /// In en, this message translates to:
  /// **'First-time'**
  String get firstTime;

  /// No description provided for @addSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Add Session Note'**
  String get addSessionNote;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Likes skin fade, has sensitive skin...'**
  String get noteHint;

  /// No description provided for @personalProfile.
  ///
  /// In en, this message translates to:
  /// **'Personal Profile'**
  String get personalProfile;

  /// No description provided for @myServices.
  ///
  /// In en, this message translates to:
  /// **'My Services'**
  String get myServices;

  /// No description provided for @previewShopProfile.
  ///
  /// In en, this message translates to:
  /// **'Preview Shop Profile'**
  String get previewShopProfile;

  /// No description provided for @manageServices.
  ///
  /// In en, this message translates to:
  /// **'Manage Services'**
  String get manageServices;

  /// No description provided for @profileLoading.
  ///
  /// In en, this message translates to:
  /// **'Profile loading...'**
  String get profileLoading;

  /// No description provided for @shopDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shop data not available.'**
  String get shopDataUnavailable;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @keepUpWork.
  ///
  /// In en, this message translates to:
  /// **'Keep up the great work!'**
  String get keepUpWork;

  /// No description provided for @startStreak.
  ///
  /// In en, this message translates to:
  /// **'Start your streak today!'**
  String get startStreak;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @oneDayStreak.
  ///
  /// In en, this message translates to:
  /// **'1 day streak! Keep it going! ⚡️'**
  String get oneDayStreak;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak! 🔥'**
  String dayStreak(int streak);

  /// No description provided for @dayStreakAmazing.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak! Amazing! 🔥🔥'**
  String dayStreakAmazing(int streak);

  /// No description provided for @dayStreakUnstoppable.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak! You\'re unstoppable! 🔥🔥🔥'**
  String dayStreakUnstoppable(int streak);

  /// No description provided for @loyal.
  ///
  /// In en, this message translates to:
  /// **'Loyal'**
  String get loyal;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'REPORT ISSUE'**
  String get reportIssue;

  /// No description provided for @addNoteBtn.
  ///
  /// In en, this message translates to:
  /// **'ADD NOTE'**
  String get addNoteBtn;

  /// No description provided for @lostPotential.
  ///
  /// In en, this message translates to:
  /// **'Lost Potential: \${amount} · Affects your visibility rating'**
  String lostPotential(String amount);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// No description provided for @avgPerSession.
  ///
  /// In en, this message translates to:
  /// **'Avg / Session'**
  String get avgPerSession;

  /// No description provided for @performanceAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Performance Analytics'**
  String get performanceAnalytics;

  /// No description provided for @uniqueClients.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get uniqueClients;

  /// No description provided for @repeatClients.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatClients;

  /// No description provided for @newClients.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newClients;

  /// No description provided for @vsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'vs Last Week'**
  String get vsLastWeek;

  /// No description provided for @goalProgress.
  ///
  /// In en, this message translates to:
  /// **'Goal Progress'**
  String get goalProgress;

  /// No description provided for @earningsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Earnings Breakdown'**
  String get earningsBreakdown;

  /// No description provided for @serviceRevenue.
  ///
  /// In en, this message translates to:
  /// **'Service Revenue'**
  String get serviceRevenue;

  /// No description provided for @deductions.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get deductions;

  /// No description provided for @netPayout.
  ///
  /// In en, this message translates to:
  /// **'Net Payout'**
  String get netPayout;

  /// No description provided for @earningsTrend.
  ///
  /// In en, this message translates to:
  /// **'Earnings Trend'**
  String get earningsTrend;

  /// No description provided for @serviceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Service Breakdown'**
  String get serviceBreakdown;

  /// No description provided for @completionRate.
  ///
  /// In en, this message translates to:
  /// **'Completion'**
  String get completionRate;

  /// No description provided for @noShowRate.
  ///
  /// In en, this message translates to:
  /// **'No-Show'**
  String get noShowRate;

  /// No description provided for @productivityHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Productivity Heatmap'**
  String get productivityHeatmap;

  /// No description provided for @fullHistory.
  ///
  /// In en, this message translates to:
  /// **'Full Earning History'**
  String get fullHistory;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export Statement (PDF)'**
  String get exportPdf;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and will remove all your data.'**
  String get deleteAccountWarning;

  /// No description provided for @logoutSession.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT SESSION'**
  String get logoutSession;

  /// No description provided for @createUser.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUser;

  /// No description provided for @removeStaffConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove Staff?'**
  String get removeStaffConfirm;

  /// No description provided for @removeStaffWarning.
  ///
  /// In en, this message translates to:
  /// **'They will be unlinked from your shop.'**
  String get removeStaffWarning;

  /// No description provided for @noStaffFound.
  ///
  /// In en, this message translates to:
  /// **'No staff added yet.'**
  String get noStaffFound;

  /// No description provided for @addStaff.
  ///
  /// In en, this message translates to:
  /// **'Add Staff'**
  String get addStaff;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (Optional)'**
  String get emailOptional;

  /// No description provided for @allActions.
  ///
  /// In en, this message translates to:
  /// **'All Actions'**
  String get allActions;

  /// No description provided for @noAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'No audit logs found'**
  String get noAuditLogs;

  /// No description provided for @auditLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Actions will appear here as they occur'**
  String get auditLogsSubtitle;

  /// No description provided for @auditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immutable history of all actions'**
  String get auditSubtitle;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @mAgo.
  ///
  /// In en, this message translates to:
  /// **'m ago'**
  String get mAgo;

  /// No description provided for @hAgo.
  ///
  /// In en, this message translates to:
  /// **'h ago'**
  String get hAgo;

  /// No description provided for @dAgo.
  ///
  /// In en, this message translates to:
  /// **'d ago'**
  String get dAgo;

  /// No description provided for @shopSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shop settings updated successfully'**
  String get shopSettingsUpdated;

  /// No description provided for @shopUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update shop'**
  String get shopUpdateFailed;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get choosePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get removePhoto;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @profileStrength.
  ///
  /// In en, this message translates to:
  /// **'Profile Strength'**
  String get profileStrength;

  /// No description provided for @qualityBio.
  ///
  /// In en, this message translates to:
  /// **'Quality Bio / About'**
  String get qualityBio;

  /// No description provided for @experienceLevel.
  ///
  /// In en, this message translates to:
  /// **'Experience Level'**
  String get experienceLevel;

  /// No description provided for @professionalPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Professional Portfolio'**
  String get professionalPortfolio;

  /// No description provided for @skillsExpertise.
  ///
  /// In en, this message translates to:
  /// **'Skills & Expertise'**
  String get skillsExpertise;

  /// No description provided for @fullNamePublic.
  ///
  /// In en, this message translates to:
  /// **'Full Name (Public)'**
  String get fullNamePublic;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name as customers will see it'**
  String get nameHint;

  /// No description provided for @aboutMe.
  ///
  /// In en, this message translates to:
  /// **'About Me'**
  String get aboutMe;

  /// No description provided for @aboutMeHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. 10+ years experience in modern fades & beard styling. I specialize in precision scissor cuts.'**
  String get aboutMeHint;

  /// No description provided for @yearsActive.
  ///
  /// In en, this message translates to:
  /// **'YEARS ACTIVE'**
  String get yearsActive;

  /// No description provided for @workPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Work Portfolio'**
  String get workPortfolio;

  /// No description provided for @portfolioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your strongest weapon to win clients'**
  String get portfolioSubtitle;

  /// No description provided for @noPhotosAdded.
  ///
  /// In en, this message translates to:
  /// **'No photos added yet'**
  String get noPhotosAdded;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag...'**
  String get addTag;

  /// No description provided for @tagThisWork.
  ///
  /// In en, this message translates to:
  /// **'Tag this work'**
  String get tagThisWork;

  /// No description provided for @tagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Skin Fade, Beard Trim'**
  String get tagHint;

  /// No description provided for @maxPortfolioLimit.
  ///
  /// In en, this message translates to:
  /// **'Maximum 10 portfolio images allowed'**
  String get maxPortfolioLimit;

  /// No description provided for @skillFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get skillFade;

  /// No description provided for @skillBeard.
  ///
  /// In en, this message translates to:
  /// **'Beard Styling'**
  String get skillBeard;

  /// No description provided for @skillKids.
  ///
  /// In en, this message translates to:
  /// **'Kids Haircut'**
  String get skillKids;

  /// No description provided for @skillRazor.
  ///
  /// In en, this message translates to:
  /// **'Straight Razor'**
  String get skillRazor;

  /// No description provided for @skillScissor.
  ///
  /// In en, this message translates to:
  /// **'Scissor Cut'**
  String get skillScissor;

  /// No description provided for @skillColor.
  ///
  /// In en, this message translates to:
  /// **'Hair Coloring'**
  String get skillColor;

  /// No description provided for @skillShave.
  ///
  /// In en, this message translates to:
  /// **'Shave'**
  String get skillShave;

  /// No description provided for @skillBuzz.
  ///
  /// In en, this message translates to:
  /// **'Buzz Cut'**
  String get skillBuzz;

  /// No description provided for @selectSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Select your specialties'**
  String get selectSpecialties;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'OPEN NOW'**
  String get openNow;

  /// No description provided for @waitTime.
  ///
  /// In en, this message translates to:
  /// **'~15 MIN WAIT'**
  String get waitTime;

  /// No description provided for @shopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Modern Cuts · Clean Fades · Men\'s Grooming'**
  String get shopSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @theExperience.
  ///
  /// In en, this message translates to:
  /// **'The Experience'**
  String get theExperience;

  /// No description provided for @meetTheTeam.
  ///
  /// In en, this message translates to:
  /// **'Meet the Team'**
  String get meetTheTeam;

  /// No description provided for @masters.
  ///
  /// In en, this message translates to:
  /// **'Masters'**
  String get masters;

  /// No description provided for @lovedByClients.
  ///
  /// In en, this message translates to:
  /// **'Loved by 200+ clients'**
  String get lovedByClients;

  /// No description provided for @cleanHygienic.
  ///
  /// In en, this message translates to:
  /// **'Clean & Hygienic'**
  String get cleanHygienic;

  /// No description provided for @certifiedMasters.
  ///
  /// In en, this message translates to:
  /// **'Certified Masters'**
  String get certifiedMasters;

  /// No description provided for @ourServices.
  ///
  /// In en, this message translates to:
  /// **'Our Services'**
  String get ourServices;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @popularPicks.
  ///
  /// In en, this message translates to:
  /// **'Popular Picks'**
  String get popularPicks;

  /// No description provided for @mainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenu;

  /// No description provided for @top.
  ///
  /// In en, this message translates to:
  /// **'TOP'**
  String get top;

  /// No description provided for @professionalService.
  ///
  /// In en, this message translates to:
  /// **'Professional {serviceName} with custom styling.'**
  String professionalService(String serviceName);

  /// No description provided for @mins.
  ///
  /// In en, this message translates to:
  /// **'mins'**
  String get mins;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'BOOK APPOINTMENT'**
  String get bookAppointment;

  /// No description provided for @noServices.
  ///
  /// In en, this message translates to:
  /// **'No services available.'**
  String get noServices;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @profileCompletion.
  ///
  /// In en, this message translates to:
  /// **'Profile Completion'**
  String get profileCompletion;

  /// No description provided for @profileCompleteSug.
  ///
  /// In en, this message translates to:
  /// **'Great job! Your profile is complete!'**
  String get profileCompleteSug;

  /// No description provided for @profileIncompleteSug.
  ///
  /// In en, this message translates to:
  /// **'Add {items} to increase your bookings!'**
  String profileIncompleteSug(String items);

  /// No description provided for @avgRating.
  ///
  /// In en, this message translates to:
  /// **'Avg Rating'**
  String get avgRating;

  /// No description provided for @noSkillsAdded.
  ///
  /// In en, this message translates to:
  /// **'No skills added yet. Add skills in your profile to showcase your expertise!'**
  String get noSkillsAdded;

  /// No description provided for @availableToday.
  ///
  /// In en, this message translates to:
  /// **'Available for Today'**
  String get availableToday;

  /// No description provided for @instantlyAcceptBookings.
  ///
  /// In en, this message translates to:
  /// **'Instantly accept new bookings'**
  String get instantlyAcceptBookings;

  /// No description provided for @shopGallery.
  ///
  /// In en, this message translates to:
  /// **'Shop Gallery'**
  String get shopGallery;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add Service'**
  String get addService;

  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit Service'**
  String get editService;

  /// No description provided for @saveService.
  ///
  /// In en, this message translates to:
  /// **'Save Service'**
  String get saveService;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service Name'**
  String get serviceName;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @durationMin.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get durationMin;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get available;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'DISABLED'**
  String get disabled;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @noServicesFound.
  ///
  /// In en, this message translates to:
  /// **'No services found'**
  String get noServicesFound;

  /// No description provided for @nothingToSave.
  ///
  /// In en, this message translates to:
  /// **'NOTHING TO SAVE'**
  String get nothingToSave;

  /// No description provided for @deleteServiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Service?'**
  String get deleteServiceConfirm;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @servicesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Services updated successfully!'**
  String get servicesUpdated;

  /// No description provided for @serviceDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete service. Please try again.'**
  String get serviceDeleteFailed;

  /// No description provided for @staffNoServicesSug.
  ///
  /// In en, this message translates to:
  /// **'Contact your shop owner to add master services to the list.'**
  String get staffNoServicesSug;

  /// No description provided for @myShop.
  ///
  /// In en, this message translates to:
  /// **'My Shop'**
  String get myShop;

  /// No description provided for @noAddressSaved.
  ///
  /// In en, this message translates to:
  /// **'No Address Saved'**
  String get noAddressSaved;

  /// No description provided for @noShopAssigned.
  ///
  /// In en, this message translates to:
  /// **'No Shop Assigned'**
  String get noShopAssigned;

  /// No description provided for @failedToUpdateAvailability.
  ///
  /// In en, this message translates to:
  /// **'Failed to update availability'**
  String get failedToUpdateAvailability;

  /// No description provided for @recentlyBooked.
  ///
  /// In en, this message translates to:
  /// **'Recently Booked'**
  String get recentlyBooked;

  /// No description provided for @appointmentDate.
  ///
  /// In en, this message translates to:
  /// **'Appointment Date'**
  String get appointmentDate;

  /// No description provided for @highestAmount.
  ///
  /// In en, this message translates to:
  /// **'Highest Amount'**
  String get highestAmount;

  /// No description provided for @longestDuration.
  ///
  /// In en, this message translates to:
  /// **'Longest Duration'**
  String get longestDuration;

  /// No description provided for @timeStatus.
  ///
  /// In en, this message translates to:
  /// **'Time Status'**
  String get timeStatus;

  /// No description provided for @topRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get topRated;

  /// No description provided for @readAll.
  ///
  /// In en, this message translates to:
  /// **'Read All'**
  String get readAll;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @sortRequests.
  ///
  /// In en, this message translates to:
  /// **'Sort Requests'**
  String get sortRequests;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedStatus;

  /// No description provided for @noShowStatus.
  ///
  /// In en, this message translates to:
  /// **'NO SHOW'**
  String get noShowStatus;

  /// No description provided for @pendingPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'PENDING PAYMENT'**
  String get pendingPaymentStatus;

  /// No description provided for @currentStatus.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get currentStatus;

  /// No description provided for @upcomingStatus.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get upcomingStatus;

  /// No description provided for @privateNote.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE NOTE'**
  String get privateNote;

  /// No description provided for @verifiedByShop.
  ///
  /// In en, this message translates to:
  /// **'Verified by Shop'**
  String get verifiedByShop;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated!'**
  String get profilePhotoUpdated;

  /// No description provided for @setAsProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Set as Profile Photo'**
  String get setAsProfilePhoto;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @portfolioPhotos.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Photos'**
  String get portfolioPhotos;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @experience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experience;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @servicesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} services selected'**
  String servicesSelected(int count);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @defaultShopDescription.
  ///
  /// In en, this message translates to:
  /// **'A modern neighborhood barber shop offering precision haircuts and grooming services by experienced professionals.'**
  String get defaultShopDescription;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guestUser;

  /// No description provided for @busyDay.
  ///
  /// In en, this message translates to:
  /// **'Busy day 🔥'**
  String get busyDay;

  /// No description provided for @productiveDay.
  ///
  /// In en, this message translates to:
  /// **'Productive day ✅'**
  String get productiveDay;

  /// No description provided for @lightDay.
  ///
  /// In en, this message translates to:
  /// **'Light day ☁️'**
  String get lightDay;

  /// No description provided for @manageYourDay.
  ///
  /// In en, this message translates to:
  /// **'Manage your day'**
  String get manageYourDay;

  /// No description provided for @barber.
  ///
  /// In en, this message translates to:
  /// **'Barber'**
  String get barber;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @stylist.
  ///
  /// In en, this message translates to:
  /// **'Stylist'**
  String get stylist;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get allCaughtUp;

  /// No description provided for @noNewRequests.
  ///
  /// In en, this message translates to:
  /// **'No new requests at the moment.'**
  String get noNewRequests;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;
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
      <String>['ar', 'en', 'es', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
