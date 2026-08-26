import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ShadApp'**
  String get appTitle;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @contracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get contracts;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvals;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @meetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meetings;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @contractClauses.
  ///
  /// In en, this message translates to:
  /// **'Contract Clauses'**
  String get contractClauses;

  /// No description provided for @noClauses.
  ///
  /// In en, this message translates to:
  /// **'No clauses'**
  String get noClauses;

  /// No description provided for @viewClauses.
  ///
  /// In en, this message translates to:
  /// **'View Clauses'**
  String get viewClauses;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @pendingYourApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending your approval'**
  String get pendingYourApproval;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @editRequested.
  ///
  /// In en, this message translates to:
  /// **'Edit requested'**
  String get editRequested;

  /// No description provided for @attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachment;

  /// No description provided for @waitingClientApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for client approval'**
  String get waitingClientApproval;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @accountManager.
  ///
  /// In en, this message translates to:
  /// **'Account Manager'**
  String get accountManager;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @createClient.
  ///
  /// In en, this message translates to:
  /// **'Create Client'**
  String get createClient;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

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

  /// No description provided for @unauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized'**
  String get unauthorized;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmation;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @totalClients.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get totalClients;

  /// No description provided for @pendingContracts.
  ///
  /// In en, this message translates to:
  /// **'Pending Contracts'**
  String get pendingContracts;

  /// No description provided for @createNewClient.
  ///
  /// In en, this message translates to:
  /// **'Create New Client'**
  String get createNewClient;

  /// No description provided for @pendingApprovalContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts Pending Approval'**
  String get pendingApprovalContracts;

  /// No description provided for @pendingApprovalRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval Requests'**
  String get pendingApprovalRequests;

  /// No description provided for @createMeeting.
  ///
  /// In en, this message translates to:
  /// **'Create Meeting'**
  String get createMeeting;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @noClients.
  ///
  /// In en, this message translates to:
  /// **'No Clients'**
  String get noClients;

  /// No description provided for @noClientsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No clients have been created yet'**
  String get noClientsSubtitle;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get noResults;

  /// No description provided for @noClientWithName.
  ///
  /// In en, this message translates to:
  /// **'No client with this name'**
  String get noClientWithName;

  /// No description provided for @searchClients.
  ///
  /// In en, this message translates to:
  /// **'Search clients...'**
  String get searchClients;

  /// No description provided for @contractsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load contracts'**
  String get contractsLoadFailed;

  /// No description provided for @contractUpdated.
  ///
  /// In en, this message translates to:
  /// **'Contract updated'**
  String get contractUpdated;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @noContracts.
  ///
  /// In en, this message translates to:
  /// **'No Contracts'**
  String get noContracts;

  /// No description provided for @noContractsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No contracts have been created yet'**
  String get noContractsSubtitle;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @completeComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeComplete;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @companyApprove.
  ///
  /// In en, this message translates to:
  /// **'Company Approve'**
  String get companyApprove;

  /// No description provided for @createNewContract.
  ///
  /// In en, this message translates to:
  /// **'Create New Contract'**
  String get createNewContract;

  /// No description provided for @reportsStatistics.
  ///
  /// In en, this message translates to:
  /// **'Reports & Statistics'**
  String get reportsStatistics;

  /// No description provided for @totalContracts.
  ///
  /// In en, this message translates to:
  /// **'Total Contracts'**
  String get totalContracts;

  /// No description provided for @totalPayments.
  ///
  /// In en, this message translates to:
  /// **'Total Payments'**
  String get totalPayments;

  /// No description provided for @createClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Client'**
  String get createClientTitle;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name *'**
  String get companyName;

  /// No description provided for @companyNameHint.
  ///
  /// In en, this message translates to:
  /// **'Official company name'**
  String get companyNameHint;

  /// No description provided for @companyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Company name is required'**
  String get companyNameRequired;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person *'**
  String get contactPerson;

  /// No description provided for @contactPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Contact person name'**
  String get contactPersonHint;

  /// No description provided for @contactPersonRequired.
  ///
  /// In en, this message translates to:
  /// **'Contact person is required'**
  String get contactPersonRequired;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email *'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get emailInvalid;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number *'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'05xxxxxxxx'**
  String get phoneHint;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone is required'**
  String get phoneRequired;

  /// No description provided for @phoneMinLength.
  ///
  /// In en, this message translates to:
  /// **'Phone must be at least 10 digits'**
  String get phoneMinLength;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Saudi Arabia'**
  String get countryHint;

  /// No description provided for @industry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get industry;

  /// No description provided for @industryHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Information Technology'**
  String get industryHint;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'Street, city, area...'**
  String get addressHint;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset link.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgotPasswordSubmit;

  /// No description provided for @forgotPasswordSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get forgotPasswordSending;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'If your email is registered, a reset link is on its way. Open it on this device or any browser, set a new password, then come back and sign in.'**
  String get forgotPasswordSent;

  /// No description provided for @forgotPasswordBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotPasswordBackToLogin;

  /// No description provided for @forgotPasswordEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get forgotPasswordEnterEmail;

  /// No description provided for @contractValue.
  ///
  /// In en, this message translates to:
  /// **'Contract Value *'**
  String get contractValue;

  /// No description provided for @contractValuePositive.
  ///
  /// In en, this message translates to:
  /// **'Contract value must be greater than 0'**
  String get contractValuePositive;

  /// No description provided for @clientType.
  ///
  /// In en, this message translates to:
  /// **'Client Type *'**
  String get clientType;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Additional notes...'**
  String get notesHint;

  /// No description provided for @clientCreated.
  ///
  /// In en, this message translates to:
  /// **'✅ Client created'**
  String get clientCreated;

  /// No description provided for @clientCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create client'**
  String get clientCreateFailed;

  /// No description provided for @contractsByStatus.
  ///
  /// In en, this message translates to:
  /// **'Contracts by Status'**
  String get contractsByStatus;

  /// No description provided for @paymentsByMonth.
  ///
  /// In en, this message translates to:
  /// **'Payments by Month'**
  String get paymentsByMonth;

  /// No description provided for @approvalStats.
  ///
  /// In en, this message translates to:
  /// **'Approval Statistics'**
  String get approvalStats;

  /// No description provided for @auditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get auditLogs;

  /// No description provided for @noAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'No audit logs found'**
  String get noAuditLogs;

  /// No description provided for @totalClients_.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get totalClients_;

  /// No description provided for @activeWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Active Workspaces'**
  String get activeWorkspaces;

  /// No description provided for @pendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get pendingPayments;

  /// No description provided for @signed.
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get signed;

  /// No description provided for @recentLogins.
  ///
  /// In en, this message translates to:
  /// **'Recent Logins'**
  String get recentLogins;

  /// No description provided for @sendAfterEdit.
  ///
  /// In en, this message translates to:
  /// **'Send After Edit'**
  String get sendAfterEdit;

  /// No description provided for @companySignature.
  ///
  /// In en, this message translates to:
  /// **'Company Signature'**
  String get companySignature;

  /// No description provided for @signatureHint.
  ///
  /// In en, this message translates to:
  /// **'Type your name as signature...'**
  String get signatureHint;

  /// No description provided for @enterSignature.
  ///
  /// In en, this message translates to:
  /// **'Please enter your signature'**
  String get enterSignature;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @clientApproved.
  ///
  /// In en, this message translates to:
  /// **'Client Approved'**
  String get clientApproved;

  /// No description provided for @clientRejected.
  ///
  /// In en, this message translates to:
  /// **'Client Rejected'**
  String get clientRejected;

  /// No description provided for @companyApproved.
  ///
  /// In en, this message translates to:
  /// **'Company Approved'**
  String get companyApproved;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @editRequestedStatus.
  ///
  /// In en, this message translates to:
  /// **'Edit Requested'**
  String get editRequestedStatus;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get sessionExpired;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid Credentials'**
  String get invalidCredentials;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server Error'**
  String get serverError;

  /// No description provided for @dataLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get dataLoadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No Items'**
  String get noItems;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm Action'**
  String get confirmAction;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get deleteConfirmation;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @enterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password'**
  String get enterEmailAndPassword;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please login again.'**
  String get sessionExpiredMessage;

  /// No description provided for @serverErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'A server error occurred. Please try again later.'**
  String get serverErrorMessage;

  /// No description provided for @invalidCredentialsMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please try again.'**
  String get invalidCredentialsMessage;

  /// No description provided for @connectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and make sure the server is running.'**
  String get connectionFailedMessage;

  /// No description provided for @tooManyAttemptsMessage.
  ///
  /// In en, this message translates to:
  /// **'Too many login attempts. Please wait a minute and try again.'**
  String get tooManyAttemptsMessage;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccess;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReview;

  /// No description provided for @approved_status.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved_status;

  /// No description provided for @rejected_status.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected_status;

  /// No description provided for @chatContractCard_fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get chatContractCard_fileOpenFailed;

  /// No description provided for @contractValueExclVat.
  ///
  /// In en, this message translates to:
  /// **'Contract Value (Excl. VAT)'**
  String get contractValueExclVat;

  /// No description provided for @contractApprovedUploadPayment.
  ///
  /// In en, this message translates to:
  /// **'Contract approved! Please upload payment proof.'**
  String get contractApprovedUploadPayment;

  /// No description provided for @viewSignedContract.
  ///
  /// In en, this message translates to:
  /// **'View Signed Contract'**
  String get viewSignedContract;

  /// No description provided for @downloadFinalContract.
  ///
  /// In en, this message translates to:
  /// **'Download Final Contract'**
  String get downloadFinalContract;

  /// No description provided for @uploadPayment.
  ///
  /// In en, this message translates to:
  /// **'Upload Payment'**
  String get uploadPayment;

  /// No description provided for @clientTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get clientTypeCompany;

  /// No description provided for @clientTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get clientTypeIndividual;

  /// No description provided for @errorStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorStateTitle;

  /// No description provided for @meetingChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingChipLabel;

  /// No description provided for @passwordFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordFieldLabel;

  /// No description provided for @passwordFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordFieldHint;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordRequireLetter.
  ///
  /// In en, this message translates to:
  /// **'Password must contain a letter'**
  String get passwordRequireLetter;

  /// No description provided for @passwordRequireNumber.
  ///
  /// In en, this message translates to:
  /// **'Password must contain a number'**
  String get passwordRequireNumber;

  /// No description provided for @paymentBanner_request.
  ///
  /// In en, this message translates to:
  /// **'Payment Requested'**
  String get paymentBanner_request;

  /// No description provided for @paymentBanner_overdue.
  ///
  /// In en, this message translates to:
  /// **'Payment Overdue'**
  String get paymentBanner_overdue;

  /// No description provided for @paymentBanner_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Payment'**
  String get paymentBanner_upcoming;

  /// No description provided for @paymentBanner_underReview.
  ///
  /// In en, this message translates to:
  /// **'Payment Under Review'**
  String get paymentBanner_underReview;

  /// No description provided for @paymentBanner_paid.
  ///
  /// In en, this message translates to:
  /// **'Payment Paid'**
  String get paymentBanner_paid;

  /// No description provided for @paymentDetail_title.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetail_title;

  /// No description provided for @paymentDetail_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paymentDetail_amount;

  /// No description provided for @paymentDetail_dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get paymentDetail_dueDate;

  /// No description provided for @paymentDetail_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get paymentDetail_notes;

  /// No description provided for @paymentDetail_payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get paymentDetail_payNow;

  /// No description provided for @paymentDetail_statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentDetail_statusPending;

  /// No description provided for @paymentDetail_statusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get paymentDetail_statusUnderReview;

  /// No description provided for @paymentDetail_statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentDetail_statusPaid;

  /// No description provided for @paymentDetail_statusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get paymentDetail_statusOverdue;

  /// No description provided for @paymentBanner_today.
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get paymentBanner_today;

  /// No description provided for @paymentBanner_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due Tomorrow'**
  String get paymentBanner_tomorrow;

  /// No description provided for @paymentBanner_daysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days} days overdue'**
  String paymentBanner_daysOverdue(Object days);

  /// No description provided for @paymentBanner_daysAhead.
  ///
  /// In en, this message translates to:
  /// **'{days} days ahead'**
  String paymentBanner_daysAhead(Object days);

  /// No description provided for @chat_editFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit message'**
  String get chat_editFailed;

  /// No description provided for @chat_attachFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to attach file'**
  String get chat_attachFailed;

  /// No description provided for @chat_editRequested.
  ///
  /// In en, this message translates to:
  /// **'Edit Requested'**
  String get chat_editRequested;

  /// No description provided for @chat_actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get chat_actionFailed;

  /// No description provided for @chat_requestEdit.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get chat_requestEdit;

  /// No description provided for @chat_mentionChanges.
  ///
  /// In en, this message translates to:
  /// **'Mention the changes you want'**
  String get chat_mentionChanges;

  /// No description provided for @chat_exampleChanges.
  ///
  /// In en, this message translates to:
  /// **'e.g. Please update the payment terms'**
  String get chat_exampleChanges;

  /// No description provided for @chat_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chat_cancel;

  /// No description provided for @chat_send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chat_send;

  /// No description provided for @chat_noActiveMeeting.
  ///
  /// In en, this message translates to:
  /// **'No active meeting'**
  String get chat_noActiveMeeting;

  /// No description provided for @chat_unavailableSpace.
  ///
  /// In en, this message translates to:
  /// **'Space unavailable'**
  String get chat_unavailableSpace;

  /// No description provided for @chat_accountManager.
  ///
  /// In en, this message translates to:
  /// **'Account Manager'**
  String get chat_accountManager;

  /// No description provided for @chat_online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chat_online;

  /// No description provided for @chat_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chat_offline;

  /// No description provided for @chat_editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get chat_editMessage;

  /// No description provided for @chat_editYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit your message'**
  String get chat_editYourMessage;

  /// No description provided for @chat_upcomingMeeting.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Meeting'**
  String get chat_upcomingMeeting;

  /// No description provided for @chat_join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chat_join;

  /// No description provided for @chat_edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chat_edited;

  /// No description provided for @chat_newApproval.
  ///
  /// In en, this message translates to:
  /// **'New Approval Request'**
  String get chat_newApproval;

  /// No description provided for @chat_needsYourApproval.
  ///
  /// In en, this message translates to:
  /// **'Needs your approval'**
  String get chat_needsYourApproval;

  /// No description provided for @chat_approvalRequestEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit has been requested'**
  String get chat_approvalRequestEdit;

  /// No description provided for @chat_approveAction.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get chat_approveAction;

  /// No description provided for @chat_approvedStatus.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get chat_approvedStatus;

  /// No description provided for @chat_rejectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get chat_rejectedStatus;

  /// No description provided for @chat_requestedEditStatus.
  ///
  /// In en, this message translates to:
  /// **'Edit Requested'**
  String get chat_requestedEditStatus;

  /// No description provided for @chat_fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get chat_fileOpenFailed;

  /// No description provided for @chat_downloadCertificate.
  ///
  /// In en, this message translates to:
  /// **'Download Certificate'**
  String get chat_downloadCertificate;

  /// No description provided for @chat_editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chat_editAction;

  /// No description provided for @chat_replyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chat_replyAction;

  /// No description provided for @chat_contracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get chat_contracts;

  /// No description provided for @chat_noContracts.
  ///
  /// In en, this message translates to:
  /// **'No contracts available'**
  String get chat_noContracts;

  /// No description provided for @contract_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get contract_all;

  /// No description provided for @contract_uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get contract_uploaded;

  /// No description provided for @contract_uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get contract_uploadFailed;

  /// No description provided for @contract_extraService.
  ///
  /// In en, this message translates to:
  /// **'Extra Service'**
  String get contract_extraService;

  /// No description provided for @contract_primary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get contract_primary;

  /// No description provided for @contract_info.
  ///
  /// In en, this message translates to:
  /// **'Contract Information'**
  String get contract_info;

  /// No description provided for @contract_startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get contract_startDate;

  /// No description provided for @contract_endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get contract_endDate;

  /// No description provided for @contract_value.
  ///
  /// In en, this message translates to:
  /// **'Contract Value'**
  String get contract_value;

  /// No description provided for @contract_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get contract_paid;

  /// No description provided for @contract_remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get contract_remaining;

  /// No description provided for @contract_clauses.
  ///
  /// In en, this message translates to:
  /// **'Contract Clauses'**
  String get contract_clauses;

  /// No description provided for @contract_requiredDocs.
  ///
  /// In en, this message translates to:
  /// **'Required Documents'**
  String get contract_requiredDocs;

  /// No description provided for @contract_rejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get contract_rejectionReason;

  /// No description provided for @contract_uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get contract_uploading;

  /// No description provided for @contract_uploadDoc.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get contract_uploadDoc;

  /// No description provided for @contract_uploadedFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Files'**
  String get contract_uploadedFiles;

  /// No description provided for @contract_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get contract_actions;

  /// No description provided for @contract_approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get contract_approve;

  /// No description provided for @contract_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get contract_edit;

  /// No description provided for @contract_downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get contract_downloadPdf;

  /// No description provided for @contract_companyApproved.
  ///
  /// In en, this message translates to:
  /// **'Company Approved'**
  String get contract_companyApproved;

  /// No description provided for @contract_goToPayment.
  ///
  /// In en, this message translates to:
  /// **'Go to Payment'**
  String get contract_goToPayment;

  /// No description provided for @contract_youApproved.
  ///
  /// In en, this message translates to:
  /// **'You approved this contract'**
  String get contract_youApproved;

  /// No description provided for @contract_youRequestedEdit.
  ///
  /// In en, this message translates to:
  /// **'You requested an edit'**
  String get contract_youRequestedEdit;

  /// No description provided for @contract_youRejected.
  ///
  /// In en, this message translates to:
  /// **'You rejected this contract'**
  String get contract_youRejected;

  /// No description provided for @contract_completedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get contract_completedLabel;

  /// No description provided for @contract_fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get contract_fileOpenFailed;

  /// No description provided for @contract_invalidFileUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid file URL'**
  String get contract_invalidFileUrl;

  /// No description provided for @contract_deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get contract_deleteFile;

  /// No description provided for @contract_deleteFileConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this file?'**
  String get contract_deleteFileConfirmation;

  /// No description provided for @contract_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get contract_cancel;

  /// No description provided for @contract_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get contract_delete;

  /// No description provided for @contract_fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted successfully'**
  String get contract_fileDeleted;

  /// No description provided for @contract_fileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file'**
  String get contract_fileDeleteFailed;

  /// No description provided for @contract_approveLabel.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get contract_approveLabel;

  /// No description provided for @contract_requestEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get contract_requestEditLabel;

  /// No description provided for @contract_confirmApprove.
  ///
  /// In en, this message translates to:
  /// **'Confirm Approval'**
  String get contract_confirmApprove;

  /// No description provided for @contract_confirmApproveMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this contract?'**
  String get contract_confirmApproveMsg;

  /// No description provided for @contract_confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get contract_confirmAction;

  /// No description provided for @contract_areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get contract_areYouSure;

  /// No description provided for @contract_actionComplete.
  ///
  /// In en, this message translates to:
  /// **'Action completed successfully'**
  String get contract_actionComplete;

  /// No description provided for @contract_actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get contract_actionFailed;

  /// No description provided for @contract_editReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for Edit Request'**
  String get contract_editReason;

  /// No description provided for @contract_mentionChanges.
  ///
  /// In en, this message translates to:
  /// **'Mention the changes you need'**
  String get contract_mentionChanges;

  /// No description provided for @contract_cancel_action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get contract_cancel_action;

  /// No description provided for @contract_confirm_action.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get contract_confirm_action;

  /// No description provided for @contract_waitingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment receipt'**
  String get contract_waitingReceipt;

  /// No description provided for @contract_extraLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra Service'**
  String get contract_extraLabel;

  /// No description provided for @contract_primaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get contract_primaryLabel;

  /// No description provided for @contract_valueExclVat.
  ///
  /// In en, this message translates to:
  /// **'Value (Excl. VAT)'**
  String get contract_valueExclVat;

  /// No description provided for @contract_editReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Reason'**
  String get contract_editReasonLabel;

  /// No description provided for @contract_signNow.
  ///
  /// In en, this message translates to:
  /// **'Sign Now'**
  String get contract_signNow;

  /// No description provided for @contract_companyApprovedMsg.
  ///
  /// In en, this message translates to:
  /// **'Contract has been approved by the company'**
  String get contract_companyApprovedMsg;

  /// No description provided for @contract_goToPaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get contract_goToPaymentAction;

  /// No description provided for @contract_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading contract...'**
  String get contract_loading;

  /// No description provided for @contract_createNew.
  ///
  /// In en, this message translates to:
  /// **'Create New Contract'**
  String get contract_createNew;

  /// No description provided for @contract_title.
  ///
  /// In en, this message translates to:
  /// **'Contract Title'**
  String get contract_title;

  /// No description provided for @contract_valueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get contract_valueLabel;

  /// No description provided for @contract_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get contract_currency;

  /// No description provided for @contract_startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get contract_startDateLabel;

  /// No description provided for @contract_endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get contract_endDateLabel;

  /// No description provided for @contract_clausesLabel.
  ///
  /// In en, this message translates to:
  /// **'Clauses'**
  String get contract_clausesLabel;

  /// No description provided for @contract_requiredDocsLabel.
  ///
  /// In en, this message translates to:
  /// **'Required Documents'**
  String get contract_requiredDocsLabel;

  /// No description provided for @contract_docInputHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to select files'**
  String get contract_docInputHint;

  /// No description provided for @contract_noContracts.
  ///
  /// In en, this message translates to:
  /// **'No contracts available'**
  String get contract_noContracts;

  /// No description provided for @dashboard_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dashboard'**
  String get dashboard_failedToLoad;

  /// No description provided for @dashboard_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dashboard_retry;

  /// No description provided for @dashboard_newNotification.
  ///
  /// In en, this message translates to:
  /// **'New Notification'**
  String get dashboard_newNotification;

  /// No description provided for @dashboard_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get dashboard_logout;

  /// No description provided for @dashboard_logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get dashboard_logoutConfirmation;

  /// No description provided for @dashboard_logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get dashboard_logoutAction;

  /// No description provided for @dashboard_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dashboard_cancel;

  /// No description provided for @dashboard_changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get dashboard_changeLanguage;

  /// No description provided for @dashboard_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get dashboard_settings;

  /// No description provided for @dashboard_more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get dashboard_more;

  /// No description provided for @dashboard_meetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get dashboard_meetings;

  /// No description provided for @dashboard_signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get dashboard_signature;

  /// No description provided for @dashboard_team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get dashboard_team;

  /// No description provided for @dashboard_stage_signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get dashboard_stage_signature;

  /// No description provided for @dashboard_stage_receiveContract.
  ///
  /// In en, this message translates to:
  /// **'Receive Contract'**
  String get dashboard_stage_receiveContract;

  /// No description provided for @dashboard_stage_yourApproval.
  ///
  /// In en, this message translates to:
  /// **'Your Approval'**
  String get dashboard_stage_yourApproval;

  /// No description provided for @dashboard_stage_companyApproval.
  ///
  /// In en, this message translates to:
  /// **'Company Approval'**
  String get dashboard_stage_companyApproval;

  /// No description provided for @dashboard_stage_paymentProof.
  ///
  /// In en, this message translates to:
  /// **'Payment Proof'**
  String get dashboard_stage_paymentProof;

  /// No description provided for @dashboard_stage_activateSpace.
  ///
  /// In en, this message translates to:
  /// **'Activate Space'**
  String get dashboard_stage_activateSpace;

  /// No description provided for @dashboard_stage_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get dashboard_stage_locked;

  /// No description provided for @dashboard_tab_contracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get dashboard_tab_contracts;

  /// No description provided for @dashboard_tab_payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get dashboard_tab_payments;

  /// No description provided for @dashboard_tab_chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get dashboard_tab_chat;

  /// No description provided for @dashboard_tab_approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get dashboard_tab_approvals;

  /// No description provided for @dashboard_tab_files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get dashboard_tab_files;

  /// No description provided for @dashboard_notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get dashboard_notifications_title;

  /// No description provided for @dashboard_notifications_markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All Read'**
  String get dashboard_notifications_markAllRead;

  /// No description provided for @dashboard_notifications_empty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get dashboard_notifications_empty;

  /// No description provided for @dashboard_notifications_minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String dashboard_notifications_minutesAgo(Object minutes);

  /// No description provided for @dashboard_notifications_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String dashboard_notifications_hoursAgo(Object hours);

  /// No description provided for @dashboard_notifications_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String dashboard_notifications_daysAgo(Object days);

  /// No description provided for @files_chooseDocType.
  ///
  /// In en, this message translates to:
  /// **'Choose Document Type'**
  String get files_chooseDocType;

  /// No description provided for @files_chooseAndUpload.
  ///
  /// In en, this message translates to:
  /// **'Choose and Upload'**
  String get files_chooseAndUpload;

  /// No description provided for @files_uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload file'**
  String get files_uploadFailed;

  /// No description provided for @files_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get files_deleteTitle;

  /// No description provided for @files_deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this file?'**
  String get files_deleteConfirmation;

  /// No description provided for @files_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get files_cancel;

  /// No description provided for @files_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get files_delete;

  /// No description provided for @files_deleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted successfully'**
  String get files_deleted;

  /// No description provided for @files_deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file'**
  String get files_deleteFailed;

  /// No description provided for @files_docDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Document Definitions'**
  String get files_docDefinitions;

  /// No description provided for @meetings_noMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings'**
  String get meetings_noMeetings;

  /// No description provided for @meetings_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get meetings_upcoming;

  /// No description provided for @meetings_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get meetings_previous;

  /// No description provided for @meetings_joinNow.
  ///
  /// In en, this message translates to:
  /// **'Join Now'**
  String get meetings_joinNow;

  /// No description provided for @meetings_ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get meetings_ended;

  /// No description provided for @meetings_minutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String meetings_minutesLeft(Object minutes);

  /// No description provided for @meetings_hoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours}h left'**
  String meetings_hoursLeft(Object hours);

  /// No description provided for @meetings_daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String meetings_daysLeft(Object days);

  /// No description provided for @notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications_title;

  /// No description provided for @notifications_markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All Read'**
  String get notifications_markAllRead;

  /// No description provided for @notifications_empty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifications_empty;

  /// No description provided for @notifications_minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String notifications_minutesAgo(Object minutes);

  /// No description provided for @notifications_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String notifications_hoursAgo(Object hours);

  /// No description provided for @notifications_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String notifications_daysAgo(Object days);

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @settings_profilePicture.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture'**
  String get settings_profilePicture;

  /// No description provided for @settings_changePicture.
  ///
  /// In en, this message translates to:
  /// **'Change Profile Picture'**
  String get settings_changePicture;

  /// No description provided for @settings_displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get settings_displayName;

  /// No description provided for @settings_displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get settings_displayNameHint;

  /// No description provided for @settings_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settings_email;

  /// No description provided for @settings_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settings_phone;

  /// No description provided for @settings_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get settings_dateOfBirth;

  /// No description provided for @settings_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settings_notSet;

  /// No description provided for @settings_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settings_save;

  /// No description provided for @settings_passwordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Password Confirmation'**
  String get settings_passwordConfirm;

  /// No description provided for @settings_enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get settings_enterCurrentPassword;

  /// No description provided for @settings_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settings_cancel;

  /// No description provided for @settings_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settings_confirm;

  /// No description provided for @settings_imageChanged.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get settings_imageChanged;

  /// No description provided for @settings_imageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get settings_imageChangeFailed;

  /// No description provided for @settings_saved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settings_saved;

  /// No description provided for @settings_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get settings_saveFailed;

  /// No description provided for @signature_deleted.
  ///
  /// In en, this message translates to:
  /// **'Signature deleted'**
  String get signature_deleted;

  /// No description provided for @signature_deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete signature'**
  String get signature_deleteFailed;

  /// No description provided for @signature_saved.
  ///
  /// In en, this message translates to:
  /// **'Signature saved'**
  String get signature_saved;

  /// No description provided for @signature_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save signature'**
  String get signature_saveFailed;

  /// No description provided for @signature_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load signature: {error}'**
  String signature_loadFailed(Object error);

  /// No description provided for @signature_userIdNotFound.
  ///
  /// In en, this message translates to:
  /// **'User ID not found'**
  String get signature_userIdNotFound;

  /// No description provided for @signature_title.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature_title;

  /// No description provided for @signature_currentSignature.
  ///
  /// In en, this message translates to:
  /// **'Current Signature'**
  String get signature_currentSignature;

  /// No description provided for @signature_deleteSignature.
  ///
  /// In en, this message translates to:
  /// **'Delete Signature'**
  String get signature_deleteSignature;

  /// No description provided for @signature_drawMode.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get signature_drawMode;

  /// No description provided for @signature_textMode.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get signature_textMode;

  /// No description provided for @signature_typeYourName.
  ///
  /// In en, this message translates to:
  /// **'Type your name'**
  String get signature_typeYourName;

  /// No description provided for @signature_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signature_clear;

  /// No description provided for @signature_saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get signature_saving;

  /// No description provided for @signature_saveSignature.
  ///
  /// In en, this message translates to:
  /// **'Save Signature'**
  String get signature_saveSignature;

  /// No description provided for @signature_orUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Or upload an image'**
  String get signature_orUploadImage;

  /// No description provided for @signature_saved_willReturn.
  ///
  /// In en, this message translates to:
  /// **'Signature saved. You will be returned.'**
  String get signature_saved_willReturn;

  /// No description provided for @signature_fileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read signature file'**
  String get signature_fileReadFailed;

  /// No description provided for @signature_renderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to render signature'**
  String get signature_renderFailed;

  /// No description provided for @subusers_permission_chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get subusers_permission_chat;

  /// No description provided for @subusers_permission_viewContracts.
  ///
  /// In en, this message translates to:
  /// **'View Contracts'**
  String get subusers_permission_viewContracts;

  /// No description provided for @subusers_permission_approveContracts.
  ///
  /// In en, this message translates to:
  /// **'Approve Contracts'**
  String get subusers_permission_approveContracts;

  /// No description provided for @subusers_permission_viewPayments.
  ///
  /// In en, this message translates to:
  /// **'View Payments'**
  String get subusers_permission_viewPayments;

  /// No description provided for @subusers_permission_uploadProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Payment Proof'**
  String get subusers_permission_uploadProof;

  /// No description provided for @subusers_permission_viewApprovals.
  ///
  /// In en, this message translates to:
  /// **'View Approvals'**
  String get subusers_permission_viewApprovals;

  /// No description provided for @subusers_permission_replyApprovals.
  ///
  /// In en, this message translates to:
  /// **'Reply to Approvals'**
  String get subusers_permission_replyApprovals;

  /// No description provided for @subusers_permission_viewFiles.
  ///
  /// In en, this message translates to:
  /// **'View Files'**
  String get subusers_permission_viewFiles;

  /// No description provided for @subusers_permission_uploadFiles.
  ///
  /// In en, this message translates to:
  /// **'Upload Files'**
  String get subusers_permission_uploadFiles;

  /// No description provided for @subusers_permission_viewMeetings.
  ///
  /// In en, this message translates to:
  /// **'View Meetings'**
  String get subusers_permission_viewMeetings;

  /// No description provided for @subusers_permission_joinMeetings.
  ///
  /// In en, this message translates to:
  /// **'Join Meetings'**
  String get subusers_permission_joinMeetings;

  /// No description provided for @subusers_createFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create sub-user'**
  String get subusers_createFailed;

  /// No description provided for @subusers_deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete sub-user'**
  String get subusers_deleteFailed;

  /// No description provided for @subusers_updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update sub-user'**
  String get subusers_updateFailed;

  /// No description provided for @subusers_title.
  ///
  /// In en, this message translates to:
  /// **'Sub-Users'**
  String get subusers_title;

  /// No description provided for @subusers_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get subusers_cancel;

  /// No description provided for @subusers_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get subusers_add;

  /// No description provided for @subusers_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get subusers_name;

  /// No description provided for @subusers_username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get subusers_username;

  /// No description provided for @subusers_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get subusers_email;

  /// No description provided for @subusers_emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get subusers_emailHint;

  /// No description provided for @subusers_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get subusers_dateOfBirth;

  /// No description provided for @subusers_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get subusers_notSet;

  /// No description provided for @subusers_addUser.
  ///
  /// In en, this message translates to:
  /// **'Add Sub-User'**
  String get subusers_addUser;

  /// No description provided for @subusers_noUsers.
  ///
  /// In en, this message translates to:
  /// **'No sub-users'**
  String get subusers_noUsers;

  /// No description provided for @subusers_permissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} permission(s)'**
  String subusers_permissionsCount(Object count);

  /// No description provided for @approvals_noWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace selected'**
  String get approvals_noWorkspace;

  /// No description provided for @approvals_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load approvals'**
  String get approvals_failedToLoad;

  /// No description provided for @approvals_editRequested.
  ///
  /// In en, this message translates to:
  /// **'Edit Requested'**
  String get approvals_editRequested;

  /// No description provided for @approvals_actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get approvals_actionFailed;

  /// No description provided for @approvals_confirmApproval.
  ///
  /// In en, this message translates to:
  /// **'Confirm Approval'**
  String get approvals_confirmApproval;

  /// No description provided for @approvals_confirmApprovalMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this?'**
  String get approvals_confirmApprovalMsg;

  /// No description provided for @approvals_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get approvals_cancel;

  /// No description provided for @approvals_approveAction.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approvals_approveAction;

  /// No description provided for @approvals_approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvals_approved;

  /// No description provided for @approvals_actionError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get approvals_actionError;

  /// No description provided for @approvals_requestEdit.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get approvals_requestEdit;

  /// No description provided for @approvals_mentionChanges.
  ///
  /// In en, this message translates to:
  /// **'Mention the changes you need'**
  String get approvals_mentionChanges;

  /// No description provided for @approvals_exampleChanges.
  ///
  /// In en, this message translates to:
  /// **'e.g. Please update the terms'**
  String get approvals_exampleChanges;

  /// No description provided for @approvals_cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get approvals_cancelAction;

  /// No description provided for @approvals_sendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get approvals_sendAction;

  /// No description provided for @approvals_empty.
  ///
  /// In en, this message translates to:
  /// **'No approvals'**
  String get approvals_empty;

  /// No description provided for @approvals_referenceNo.
  ///
  /// In en, this message translates to:
  /// **'Ref. No.'**
  String get approvals_referenceNo;

  /// No description provided for @approvals_fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get approvals_fileOpenFailed;

  /// No description provided for @approvals_certificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get approvals_certificate;

  /// No description provided for @approvals_approvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvals_approvedLabel;

  /// No description provided for @approvals_requestedEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Requested'**
  String get approvals_requestedEditLabel;

  /// No description provided for @approvals_editReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Reason'**
  String get approvals_editReasonLabel;

  /// No description provided for @approvals_approveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approvals_approveButton;

  /// No description provided for @approvals_requestEditButton.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get approvals_requestEditButton;

  /// No description provided for @payments_installmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Installment'**
  String get payments_installmentLabel;

  /// No description provided for @payments_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load payments'**
  String get payments_failedToLoad;

  /// No description provided for @payments_paidInFull.
  ///
  /// In en, this message translates to:
  /// **'Paid in Full'**
  String get payments_paidInFull;

  /// No description provided for @payments_totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get payments_totalPaid;

  /// No description provided for @payments_totalRemaining.
  ///
  /// In en, this message translates to:
  /// **'Total Remaining'**
  String get payments_totalRemaining;

  /// No description provided for @payments_valueBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Value Breakdown'**
  String get payments_valueBreakdown;

  /// No description provided for @payments_filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get payments_filterAll;

  /// No description provided for @payments_filterAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get payments_filterAccepted;

  /// No description provided for @payments_filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payments_filterPending;

  /// No description provided for @payments_filterRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get payments_filterRejected;

  /// No description provided for @payments_filterScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get payments_filterScheduled;

  /// No description provided for @payments_upcomingPayments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Payments'**
  String get payments_upcomingPayments;

  /// No description provided for @payments_empty.
  ///
  /// In en, this message translates to:
  /// **'No payments'**
  String get payments_empty;

  /// No description provided for @payments_requestPayment.
  ///
  /// In en, this message translates to:
  /// **'Request Payment'**
  String get payments_requestPayment;

  /// No description provided for @payments_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get payments_amount;

  /// No description provided for @payments_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get payments_currency;

  /// No description provided for @payments_paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payments_paymentMethod;

  /// No description provided for @payments_attachProof.
  ///
  /// In en, this message translates to:
  /// **'Attach Payment Proof'**
  String get payments_attachProof;

  /// No description provided for @payments_sendPayment.
  ///
  /// In en, this message translates to:
  /// **'Send Payment'**
  String get payments_sendPayment;

  /// No description provided for @payments_enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get payments_enterValidAmount;

  /// No description provided for @payments_workspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Workspace unavailable'**
  String get payments_workspaceUnavailable;

  /// No description provided for @payments_requestSent.
  ///
  /// In en, this message translates to:
  /// **'Payment request sent'**
  String get payments_requestSent;

  /// No description provided for @payments_sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send payment'**
  String get payments_sendFailed;

  /// No description provided for @payments_statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get payments_statusApproved;

  /// No description provided for @payments_statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payments_statusPending;

  /// No description provided for @payments_statusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get payments_statusRequested;

  /// No description provided for @payments_statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get payments_statusScheduled;

  /// No description provided for @payments_statusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get payments_statusOverdue;

  /// No description provided for @payments_statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get payments_statusRejected;

  /// No description provided for @payments_dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get payments_dueDate;

  /// No description provided for @payments_fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get payments_fileOpenFailed;

  /// No description provided for @payments_viewProof.
  ///
  /// In en, this message translates to:
  /// **'View Payment Proof'**
  String get payments_viewProof;

  /// No description provided for @payments_scheduledPayment.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Payment'**
  String get payments_scheduledPayment;

  /// No description provided for @payments_payLabel.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get payments_payLabel;

  /// No description provided for @payments_paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payments_paymentMethodLabel;

  /// No description provided for @payments_attachProofLabel.
  ///
  /// In en, this message translates to:
  /// **'Attach Proof'**
  String get payments_attachProofLabel;

  /// No description provided for @payments_sendProof.
  ///
  /// In en, this message translates to:
  /// **'Send Proof'**
  String get payments_sendProof;

  /// No description provided for @payments_requireProof.
  ///
  /// In en, this message translates to:
  /// **'Payment proof is required'**
  String get payments_requireProof;

  /// No description provided for @payments_workspaceUnavailableMsg.
  ///
  /// In en, this message translates to:
  /// **'Workspace is not available'**
  String get payments_workspaceUnavailableMsg;

  /// No description provided for @payments_proofSent.
  ///
  /// In en, this message translates to:
  /// **'Payment proof sent successfully'**
  String get payments_proofSent;

  /// No description provided for @payments_proofSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send payment proof'**
  String get payments_proofSendFailed;

  /// No description provided for @payments_scheduledLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get payments_scheduledLabel;

  /// No description provided for @payments_overdueLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get payments_overdueLabel;

  /// No description provided for @profile_imageChanged.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get profile_imageChanged;

  /// No description provided for @profile_imageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get profile_imageChangeFailed;

  /// No description provided for @profile_saved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profile_saved;

  /// No description provided for @profile_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile'**
  String get profile_saveFailed;

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile_title;

  /// No description provided for @profile_changePicture.
  ///
  /// In en, this message translates to:
  /// **'Change Picture'**
  String get profile_changePicture;

  /// No description provided for @profile_displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get profile_displayName;

  /// No description provided for @profile_displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get profile_displayNameHint;

  /// No description provided for @profile_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profile_save;

  /// No description provided for @am_newNotification.
  ///
  /// In en, this message translates to:
  /// **'New Notification'**
  String get am_newNotification;

  /// No description provided for @am_workspaceCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create workspace'**
  String get am_workspaceCreateFailed;

  /// No description provided for @am_noClientsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No clients available'**
  String get am_noClientsAvailable;

  /// No description provided for @am_meetingCreated.
  ///
  /// In en, this message translates to:
  /// **'Meeting created successfully'**
  String get am_meetingCreated;

  /// No description provided for @am_changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get am_changeLanguage;

  /// No description provided for @am_nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get am_nav_home;

  /// No description provided for @am_nav_approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get am_nav_approvals;

  /// No description provided for @am_nav_clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get am_nav_clients;

  /// No description provided for @am_nav_team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get am_nav_team;

  /// No description provided for @am_nav_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get am_nav_settings;

  /// No description provided for @am_stat_totalClients.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get am_stat_totalClients;

  /// No description provided for @am_stat_activeContracts.
  ///
  /// In en, this message translates to:
  /// **'Active Contracts'**
  String get am_stat_activeContracts;

  /// No description provided for @am_stat_pendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get am_stat_pendingPayments;

  /// No description provided for @am_stat_pendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get am_stat_pendingApprovals;

  /// No description provided for @am_stat_reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get am_stat_reports;

  /// No description provided for @am_stat_meetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get am_stat_meetings;

  /// No description provided for @am_recentApprovals.
  ///
  /// In en, this message translates to:
  /// **'Recent Approvals'**
  String get am_recentApprovals;

  /// No description provided for @am_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get am_viewAll;

  /// No description provided for @am_noPendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'No pending approvals'**
  String get am_noPendingApprovals;

  /// No description provided for @am_contractApproval.
  ///
  /// In en, this message translates to:
  /// **'Contract Approval'**
  String get am_contractApproval;

  /// No description provided for @am_paymentApproval.
  ///
  /// In en, this message translates to:
  /// **'Payment Approval'**
  String get am_paymentApproval;

  /// No description provided for @am_clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get am_clients;

  /// No description provided for @am_totalManagers.
  ///
  /// In en, this message translates to:
  /// **'Total Managers'**
  String get am_totalManagers;

  /// No description provided for @am_totalClientsStat.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get am_totalClientsStat;

  /// No description provided for @am_contractsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load contracts'**
  String get am_contractsLoadFailed;

  /// No description provided for @am_meetingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load meetings'**
  String get am_meetingsLoadFailed;

  /// No description provided for @am_pendingPaymentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get am_pendingPaymentsLabel;

  /// No description provided for @am_allContracts.
  ///
  /// In en, this message translates to:
  /// **'All Contracts'**
  String get am_allContracts;

  /// No description provided for @am_allMeetings.
  ///
  /// In en, this message translates to:
  /// **'All Meetings'**
  String get am_allMeetings;

  /// No description provided for @am_manageManagers.
  ///
  /// In en, this message translates to:
  /// **'Manage Managers'**
  String get am_manageManagers;

  /// No description provided for @am_activityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get am_activityLog;

  /// No description provided for @am_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get am_settings;

  /// No description provided for @am_clientsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load clients'**
  String get am_clientsLoadFailed;

  /// No description provided for @am_status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get am_status_active;

  /// No description provided for @am_status_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get am_status_inactive;

  /// No description provided for @am_status_contracted.
  ///
  /// In en, this message translates to:
  /// **'Contracted'**
  String get am_status_contracted;

  /// No description provided for @am_status_notContracted.
  ///
  /// In en, this message translates to:
  /// **'Not Contracted'**
  String get am_status_notContracted;

  /// No description provided for @am_status_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get am_status_paid;

  /// No description provided for @am_status_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get am_status_pending;

  /// No description provided for @am_noItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get am_noItems;

  /// No description provided for @am_clientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get am_clientsTitle;

  /// No description provided for @am_noClients.
  ///
  /// In en, this message translates to:
  /// **'No clients'**
  String get am_noClients;

  /// No description provided for @am_notActive.
  ///
  /// In en, this message translates to:
  /// **'Not Active'**
  String get am_notActive;

  /// No description provided for @am_pendingPaymentsSection.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get am_pendingPaymentsSection;

  /// No description provided for @am_noPendingPayments.
  ///
  /// In en, this message translates to:
  /// **'No pending payments'**
  String get am_noPendingPayments;

  /// No description provided for @am_clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get am_clientLabel;

  /// No description provided for @am_contractStatuses.
  ///
  /// In en, this message translates to:
  /// **'Contract Statuses'**
  String get am_contractStatuses;

  /// No description provided for @am_meetingsSection.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get am_meetingsSection;

  /// No description provided for @am_noMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings'**
  String get am_noMeetings;

  /// No description provided for @am_createMeeting.
  ///
  /// In en, this message translates to:
  /// **'Create Meeting'**
  String get am_createMeeting;

  /// No description provided for @am_meetingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get am_meetingScheduled;

  /// No description provided for @am_meetingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get am_meetingCompleted;

  /// No description provided for @am_meetingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get am_meetingCancelled;

  /// No description provided for @am_meeting_createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Meeting'**
  String get am_meeting_createTitle;

  /// No description provided for @am_meeting_enterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter meeting title'**
  String get am_meeting_enterTitle;

  /// No description provided for @am_meeting_titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Meeting title is required'**
  String get am_meeting_titleRequired;

  /// No description provided for @am_meeting_createFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create meeting'**
  String get am_meeting_createFailed;

  /// No description provided for @am_meeting_title.
  ///
  /// In en, this message translates to:
  /// **'Meeting Title'**
  String get am_meeting_title;

  /// No description provided for @am_meeting_client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get am_meeting_client;

  /// No description provided for @am_meeting_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get am_meeting_date;

  /// No description provided for @am_meeting_time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get am_meeting_time;

  /// No description provided for @am_meeting_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get am_meeting_duration;

  /// No description provided for @am_meeting_minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get am_meeting_minutes;

  /// No description provided for @am_meeting_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get am_meeting_notes;

  /// No description provided for @am_meeting_create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get am_meeting_create;

  /// No description provided for @sa_team_title.
  ///
  /// In en, this message translates to:
  /// **'Team Management'**
  String get sa_team_title;

  /// No description provided for @sa_team_manage.
  ///
  /// In en, this message translates to:
  /// **'Manage Account Managers'**
  String get sa_team_manage;

  /// No description provided for @sa_team_noManagers.
  ///
  /// In en, this message translates to:
  /// **'No account managers'**
  String get sa_team_noManagers;

  /// No description provided for @sa_team_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search managers...'**
  String get sa_team_searchHint;

  /// No description provided for @sa_approvals_title.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get sa_approvals_title;

  /// No description provided for @sa_approvals_noApprovals.
  ///
  /// In en, this message translates to:
  /// **'No approvals'**
  String get sa_approvals_noApprovals;

  /// No description provided for @sa_approvals_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sa_approvals_all;

  /// No description provided for @sa_approvals_contracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get sa_approvals_contracts;

  /// No description provided for @sa_approvals_payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get sa_approvals_payments;

  /// No description provided for @sa_approvals_contractApproval.
  ///
  /// In en, this message translates to:
  /// **'Contract Approval'**
  String get sa_approvals_contractApproval;

  /// No description provided for @sa_approvals_paymentApproval.
  ///
  /// In en, this message translates to:
  /// **'Payment Approval'**
  String get sa_approvals_paymentApproval;

  /// No description provided for @sa_approvals_contractLabel.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get sa_approvals_contractLabel;

  /// No description provided for @sa_approvals_paymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get sa_approvals_paymentLabel;

  /// No description provided for @sa_clients_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search clients...'**
  String get sa_clients_searchHint;

  /// No description provided for @sa_clients_title.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get sa_clients_title;

  /// No description provided for @sa_clients_noClients.
  ///
  /// In en, this message translates to:
  /// **'No clients'**
  String get sa_clients_noClients;

  /// No description provided for @sa_clients_selectManager.
  ///
  /// In en, this message translates to:
  /// **'Select Manager'**
  String get sa_clients_selectManager;

  /// No description provided for @sa_clients_allManagers.
  ///
  /// In en, this message translates to:
  /// **'All Managers'**
  String get sa_clients_allManagers;

  /// No description provided for @sa_clients_managerLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get sa_clients_managerLabel;

  /// No description provided for @clientDetail_imageChanged.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get clientDetail_imageChanged;

  /// No description provided for @clientDetail_imageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get clientDetail_imageChangeFailed;

  /// No description provided for @clientDetail_saved.
  ///
  /// In en, this message translates to:
  /// **'Client data saved'**
  String get clientDetail_saved;

  /// No description provided for @clientDetail_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save client data'**
  String get clientDetail_saveFailed;

  /// No description provided for @clientDetail_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get clientDetail_editTitle;

  /// No description provided for @clientDetail_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get clientDetail_save;

  /// No description provided for @clientDetail_initials.
  ///
  /// In en, this message translates to:
  /// **'Initials'**
  String get clientDetail_initials;

  /// No description provided for @clientDetail_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get clientDetail_active;

  /// No description provided for @clientDetail_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get clientDetail_inactive;

  /// No description provided for @clientDetail_fixedInfo.
  ///
  /// In en, this message translates to:
  /// **'Fixed Information'**
  String get clientDetail_fixedInfo;

  /// No description provided for @clientDetail_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get clientDetail_email;

  /// No description provided for @clientDetail_registeredDate.
  ///
  /// In en, this message translates to:
  /// **'Registered Date'**
  String get clientDetail_registeredDate;

  /// No description provided for @clientDetail_spaceStatus.
  ///
  /// In en, this message translates to:
  /// **'Space Status'**
  String get clientDetail_spaceStatus;

  /// No description provided for @clientDetail_company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get clientDetail_company;

  /// No description provided for @clientDetail_individual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get clientDetail_individual;

  /// No description provided for @clientDetail_editableData.
  ///
  /// In en, this message translates to:
  /// **'Editable Data'**
  String get clientDetail_editableData;

  /// No description provided for @clientDetail_companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get clientDetail_companyName;

  /// No description provided for @clientDetail_contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get clientDetail_contactPerson;

  /// No description provided for @clientDetail_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get clientDetail_phone;

  /// No description provided for @clientDetail_country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get clientDetail_country;

  /// No description provided for @clientDetail_industry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get clientDetail_industry;

  /// No description provided for @clientDetail_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get clientDetail_dateOfBirth;

  /// No description provided for @clientDetail_selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get clientDetail_selectDate;

  /// No description provided for @clientDetail_resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get clientDetail_resetPassword;

  /// No description provided for @clientDetail_newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get clientDetail_newPassword;

  /// No description provided for @clientDetail_leaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep current password'**
  String get clientDetail_leaveBlank;

  /// No description provided for @clientDetail_subUsers.
  ///
  /// In en, this message translates to:
  /// **'Sub-Users'**
  String get clientDetail_subUsers;

  /// No description provided for @clientDetail_saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get clientDetail_saveChanges;

  /// No description provided for @clientDetail_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get clientDetail_cancel;

  /// No description provided for @createClient_success.
  ///
  /// In en, this message translates to:
  /// **'Client created successfully'**
  String get createClient_success;

  /// No description provided for @createClient_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get createClient_email;

  /// No description provided for @createClient_emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get createClient_emailCopied;

  /// No description provided for @createClient_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get createClient_copy;

  /// No description provided for @createClient_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get createClient_password;

  /// No description provided for @createClient_passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get createClient_passwordCopied;

  /// No description provided for @createClient_credentialsSent.
  ///
  /// In en, this message translates to:
  /// **'Credentials sent to client'**
  String get createClient_credentialsSent;

  /// No description provided for @createClient_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get createClient_ok;

  /// No description provided for @createClient_title.
  ///
  /// In en, this message translates to:
  /// **'Create New Client'**
  String get createClient_title;

  /// No description provided for @clientCreated_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get clientCreated_ok;

  /// No description provided for @createClient_addImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get createClient_addImage;

  /// No description provided for @createClient_type.
  ///
  /// In en, this message translates to:
  /// **'Client Type'**
  String get createClient_type;

  /// No description provided for @createClient_company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get createClient_company;

  /// No description provided for @createClient_individual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get createClient_individual;

  /// No description provided for @createClient_companyData.
  ///
  /// In en, this message translates to:
  /// **'Company Data'**
  String get createClient_companyData;

  /// No description provided for @clientCreated_heading.
  ///
  /// In en, this message translates to:
  /// **'Client Created Successfully'**
  String get clientCreated_heading;

  /// No description provided for @createClient_additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get createClient_additionalDetails;

  /// No description provided for @createClient_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get createClient_dateOfBirth;

  /// No description provided for @createClient_selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get createClient_selectDate;

  /// No description provided for @createClient_autoPassword.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate Password'**
  String get createClient_autoPassword;

  /// No description provided for @createClient_autoPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'A strong password will be generated automatically'**
  String get createClient_autoPasswordHint;

  /// No description provided for @createClient_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get createClient_notes;

  /// No description provided for @createClient_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Additional notes...'**
  String get createClient_notesHint;

  /// No description provided for @createClient_createButton.
  ///
  /// In en, this message translates to:
  /// **'Create Client'**
  String get createClient_createButton;

  /// No description provided for @createClient_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createClient_cancel;

  /// No description provided for @managerDetail_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load manager details'**
  String get managerDetail_failedToLoad;

  /// No description provided for @managerDetail_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get managerDetail_retry;

  /// No description provided for @managerDetail_stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get managerDetail_stats;

  /// No description provided for @managerDetail_clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get managerDetail_clients;

  /// No description provided for @managerDetail_activeSpaces.
  ///
  /// In en, this message translates to:
  /// **'Active Spaces'**
  String get managerDetail_activeSpaces;

  /// No description provided for @managerDetail_totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get managerDetail_totalIncome;

  /// No description provided for @managerDetail_pendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get managerDetail_pendingPayments;

  /// No description provided for @managerDetail_contractsByStatus.
  ///
  /// In en, this message translates to:
  /// **'Contracts by Status'**
  String get managerDetail_contractsByStatus;

  /// No description provided for @managerDetail_monthlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Monthly Income'**
  String get managerDetail_monthlyIncome;

  /// No description provided for @managerDetail_clientsList.
  ///
  /// In en, this message translates to:
  /// **'Clients List'**
  String get managerDetail_clientsList;

  /// No description provided for @managerDetail_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get managerDetail_active;

  /// No description provided for @managerDetail_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get managerDetail_inactive;

  /// No description provided for @managerDetail_noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get managerDetail_noData;

  /// No description provided for @managerDetail_contractStatuses.
  ///
  /// In en, this message translates to:
  /// **'Contract Statuses'**
  String get managerDetail_contractStatuses;

  /// No description provided for @createManager_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get createManager_failedToLoad;

  /// No description provided for @createManager_updated.
  ///
  /// In en, this message translates to:
  /// **'Manager updated successfully'**
  String get createManager_updated;

  /// No description provided for @createManager_created.
  ///
  /// In en, this message translates to:
  /// **'Manager created successfully'**
  String get createManager_created;

  /// No description provided for @createManager_createdEmail.
  ///
  /// In en, this message translates to:
  /// **'Manager Email'**
  String get createManager_createdEmail;

  /// No description provided for @createManager_emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get createManager_emailCopied;

  /// No description provided for @createManager_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get createManager_copy;

  /// No description provided for @createManager_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get createManager_password;

  /// No description provided for @createManager_passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get createManager_passwordCopied;

  /// No description provided for @createManager_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get createManager_ok;

  /// No description provided for @createManager_updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update manager'**
  String get createManager_updateFailed;

  /// No description provided for @createManager_createFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create manager'**
  String get createManager_createFailed;

  /// No description provided for @createManager_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Manager'**
  String get createManager_editTitle;

  /// No description provided for @createManager_createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Manager'**
  String get createManager_createTitle;

  /// No description provided for @createManager_basicData.
  ///
  /// In en, this message translates to:
  /// **'Basic Data'**
  String get createManager_basicData;

  /// No description provided for @createManager_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get createManager_name;

  /// No description provided for @createManager_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get createManager_nameHint;

  /// No description provided for @createManager_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get createManager_nameRequired;

  /// No description provided for @createManager_emailField.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get createManager_emailField;

  /// No description provided for @createManager_emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get createManager_emailHint;

  /// No description provided for @createManager_emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get createManager_emailRequired;

  /// No description provided for @createManager_emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get createManager_emailInvalid;

  /// No description provided for @createManager_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get createManager_phone;

  /// No description provided for @createManager_phoneHint.
  ///
  /// In en, this message translates to:
  /// **'05xxxxxxxx'**
  String get createManager_phoneHint;

  /// No description provided for @createManager_additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get createManager_additionalDetails;

  /// No description provided for @createManager_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get createManager_dateOfBirth;

  /// No description provided for @createManager_selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get createManager_selectDate;

  /// No description provided for @createManager_autoPassword.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate Password'**
  String get createManager_autoPassword;

  /// No description provided for @createManager_autoPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'A strong password will be generated automatically'**
  String get createManager_autoPasswordHint;

  /// No description provided for @createManager_resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get createManager_resetPassword;

  /// No description provided for @createManager_newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get createManager_newPassword;

  /// No description provided for @createManager_leaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep current password'**
  String get createManager_leaveBlank;

  /// No description provided for @createManager_saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get createManager_saveChanges;

  /// No description provided for @createManager_createButton.
  ///
  /// In en, this message translates to:
  /// **'Create Manager'**
  String get createManager_createButton;

  /// No description provided for @createManager_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createManager_cancel;

  /// No description provided for @accountManagers_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load account managers'**
  String get accountManagers_failedToLoad;

  /// No description provided for @accountManagers_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Manager'**
  String get accountManagers_deleteTitle;

  /// No description provided for @accountManagers_deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this manager?'**
  String get accountManagers_deleteConfirmation;

  /// No description provided for @accountManagers_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountManagers_cancel;

  /// No description provided for @accountManagers_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountManagers_delete;

  /// No description provided for @accountManagers_deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete manager'**
  String get accountManagers_deleteFailed;

  /// No description provided for @accountManagers_title.
  ///
  /// In en, this message translates to:
  /// **'Account Managers'**
  String get accountManagers_title;

  /// No description provided for @accountManagers_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get accountManagers_retry;

  /// No description provided for @accountManagers_empty.
  ///
  /// In en, this message translates to:
  /// **'No account managers'**
  String get accountManagers_empty;

  /// No description provided for @accountManagers_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Account managers will appear here'**
  String get accountManagers_emptyHint;

  /// No description provided for @accountManagers_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add Manager'**
  String get accountManagers_addButton;

  /// No description provided for @accountManagers_clientCount.
  ///
  /// In en, this message translates to:
  /// **'{count} client(s)'**
  String accountManagers_clientCount(Object count);

  /// No description provided for @adminSettings_saved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get adminSettings_saved;

  /// No description provided for @adminSettings_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get adminSettings_saveFailed;

  /// No description provided for @adminSettings_enterValidPercentage.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid percentage (0-100)'**
  String get adminSettings_enterValidPercentage;

  /// No description provided for @adminSettings_taxSaved.
  ///
  /// In en, this message translates to:
  /// **'Tax settings saved'**
  String get adminSettings_taxSaved;

  /// No description provided for @adminSettings_taxSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save tax settings'**
  String get adminSettings_taxSaveFailed;

  /// No description provided for @adminSettings_imageChanged.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get adminSettings_imageChanged;

  /// No description provided for @adminSettings_imageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get adminSettings_imageChangeFailed;

  /// No description provided for @adminSettings_signatureSaved.
  ///
  /// In en, this message translates to:
  /// **'Signature saved'**
  String get adminSettings_signatureSaved;

  /// No description provided for @adminSettings_signatureSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save signature'**
  String get adminSettings_signatureSaveFailed;

  /// No description provided for @adminSettings_signatureDeleted.
  ///
  /// In en, this message translates to:
  /// **'Signature deleted'**
  String get adminSettings_signatureDeleted;

  /// No description provided for @adminSettings_signatureDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete signature'**
  String get adminSettings_signatureDeleteFailed;

  /// No description provided for @adminSettings_title.
  ///
  /// In en, this message translates to:
  /// **'Admin Settings'**
  String get adminSettings_title;

  /// No description provided for @adminSettings_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get adminSettings_profile;

  /// No description provided for @adminSettings_changePicture.
  ///
  /// In en, this message translates to:
  /// **'Change Picture'**
  String get adminSettings_changePicture;

  /// No description provided for @adminSettings_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminSettings_name;

  /// No description provided for @adminSettings_officialEmail.
  ///
  /// In en, this message translates to:
  /// **'Official Email'**
  String get adminSettings_officialEmail;

  /// No description provided for @adminSettings_saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get adminSettings_saveChanges;

  /// No description provided for @adminSettings_signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get adminSettings_signature;

  /// No description provided for @adminSettings_currentSignature.
  ///
  /// In en, this message translates to:
  /// **'Current Signature'**
  String get adminSettings_currentSignature;

  /// No description provided for @adminSettings_newSignature.
  ///
  /// In en, this message translates to:
  /// **'New Signature'**
  String get adminSettings_newSignature;

  /// No description provided for @adminSettings_addSignature.
  ///
  /// In en, this message translates to:
  /// **'Add Signature'**
  String get adminSettings_addSignature;

  /// No description provided for @adminSettings_draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get adminSettings_draw;

  /// No description provided for @adminSettings_text.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminSettings_text;

  /// No description provided for @adminSettings_uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get adminSettings_uploadImage;

  /// No description provided for @adminSettings_signHere.
  ///
  /// In en, this message translates to:
  /// **'Sign here'**
  String get adminSettings_signHere;

  /// No description provided for @adminSettings_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminSettings_clear;

  /// No description provided for @adminSettings_saveSignature.
  ///
  /// In en, this message translates to:
  /// **'Save Signature'**
  String get adminSettings_saveSignature;

  /// No description provided for @adminSettings_typeYourName.
  ///
  /// In en, this message translates to:
  /// **'Type your name'**
  String get adminSettings_typeYourName;

  /// No description provided for @adminSettings_typeSignature.
  ///
  /// In en, this message translates to:
  /// **'Type your signature'**
  String get adminSettings_typeSignature;

  /// No description provided for @adminSettings_systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get adminSettings_systemSettings;

  /// No description provided for @adminSettings_companyTax.
  ///
  /// In en, this message translates to:
  /// **'Company Tax'**
  String get adminSettings_companyTax;

  /// No description provided for @adminSettings_taxDescription.
  ///
  /// In en, this message translates to:
  /// **'Tax percentage applied to all contracts'**
  String get adminSettings_taxDescription;

  /// No description provided for @adminSettings_taxPercentage.
  ///
  /// In en, this message translates to:
  /// **'Tax Percentage (%)'**
  String get adminSettings_taxPercentage;

  /// No description provided for @adminSettings_saveTax.
  ///
  /// In en, this message translates to:
  /// **'Save Tax Settings'**
  String get adminSettings_saveTax;

  /// No description provided for @adminSettings_clauses.
  ///
  /// In en, this message translates to:
  /// **'Contract Clauses'**
  String get adminSettings_clauses;

  /// No description provided for @adminSettings_clausesDescription.
  ///
  /// In en, this message translates to:
  /// **'Fixed clauses are automatically added to every new contract.'**
  String get adminSettings_clausesDescription;

  /// No description provided for @adminSettings_addClause.
  ///
  /// In en, this message translates to:
  /// **'Add Clause'**
  String get adminSettings_addClause;

  /// No description provided for @adminSettings_editClause.
  ///
  /// In en, this message translates to:
  /// **'Edit Clause'**
  String get adminSettings_editClause;

  /// No description provided for @adminSettings_clauseName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminSettings_clauseName;

  /// No description provided for @adminSettings_clauseNamePh.
  ///
  /// In en, this message translates to:
  /// **'Clause name'**
  String get adminSettings_clauseNamePh;

  /// No description provided for @adminSettings_clauseOrderSaved.
  ///
  /// In en, this message translates to:
  /// **'Order saved'**
  String get adminSettings_clauseOrderSaved;

  /// No description provided for @adminSettings_clauseType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminSettings_clauseType;

  /// No description provided for @adminSettings_clauseCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get adminSettings_clauseCategory;

  /// No description provided for @adminSettings_clauseContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get adminSettings_clauseContent;

  /// No description provided for @adminSettings_clauseContentPh.
  ///
  /// In en, this message translates to:
  /// **'Clause text'**
  String get adminSettings_clauseContentPh;

  /// No description provided for @adminSettings_clauseFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get adminSettings_clauseFixed;

  /// No description provided for @adminSettings_clauseOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get adminSettings_clauseOptional;

  /// No description provided for @adminSettings_clauseAdded.
  ///
  /// In en, this message translates to:
  /// **'Clause added'**
  String get adminSettings_clauseAdded;

  /// No description provided for @adminSettings_clauseUpdated.
  ///
  /// In en, this message translates to:
  /// **'Clause updated'**
  String get adminSettings_clauseUpdated;

  /// No description provided for @adminSettings_clauseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Clause deleted'**
  String get adminSettings_clauseDeleted;

  /// No description provided for @adminSettings_clauseDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this clause? Existing contracts are not affected.'**
  String get adminSettings_clauseDeleteConfirm;

  /// No description provided for @adminSettings_clauseActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminSettings_clauseActive;

  /// No description provided for @adminSettings_clauseInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminSettings_clauseInactive;

  /// No description provided for @adminSettings_clauseToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get adminSettings_clauseToggleOff;

  /// No description provided for @adminSettings_clauseToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get adminSettings_clauseToggleOn;

  /// No description provided for @adminSettings_clauseMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get adminSettings_clauseMoveUp;

  /// No description provided for @adminSettings_clauseMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get adminSettings_clauseMoveDown;

  /// No description provided for @adminSettings_clauseSaveOrder.
  ///
  /// In en, this message translates to:
  /// **'Save order'**
  String get adminSettings_clauseSaveOrder;

  /// No description provided for @adminSettings_clausesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No clauses yet — add your first template.'**
  String get adminSettings_clausesEmpty;

  /// No description provided for @adminSettings_clausesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load clauses'**
  String get adminSettings_clausesLoadFailed;

  /// No description provided for @auditLog_noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get auditLog_noEvents;

  /// No description provided for @auditLog_noActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities found'**
  String get auditLog_noActivities;

  /// No description provided for @auditLog_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get auditLog_retry;

  /// No description provided for @auditLog_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get auditLog_today;

  /// No description provided for @auditLog_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get auditLog_yesterday;

  /// No description provided for @auditLog_months.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get auditLog_months;

  /// No description provided for @auditLog_title.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLog_title;

  /// No description provided for @auditLog_eventCount.
  ///
  /// In en, this message translates to:
  /// **'{count} event(s)'**
  String auditLog_eventCount(Object count);

  /// No description provided for @auditLog_search.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get auditLog_search;

  /// No description provided for @auditLog_filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get auditLog_filterAll;

  /// No description provided for @auditLog_filterContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get auditLog_filterContracts;

  /// No description provided for @auditLog_filterPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get auditLog_filterPayments;

  /// No description provided for @auditLog_filterApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get auditLog_filterApprovals;

  /// No description provided for @auditLog_filterMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get auditLog_filterMeetings;

  /// No description provided for @auditLog_filterLogins.
  ///
  /// In en, this message translates to:
  /// **'Logins'**
  String get auditLog_filterLogins;

  /// No description provided for @auditLog_filterClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get auditLog_filterClients;

  /// No description provided for @auditLog_from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get auditLog_from;

  /// No description provided for @auditLog_to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get auditLog_to;

  /// No description provided for @auditLog_typeContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get auditLog_typeContract;

  /// No description provided for @auditLog_typePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get auditLog_typePayment;

  /// No description provided for @auditLog_typeClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get auditLog_typeClient;

  /// No description provided for @auditLog_typeApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get auditLog_typeApproval;

  /// No description provided for @auditLog_typeMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get auditLog_typeMeeting;

  /// No description provided for @auditLog_typeLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auditLog_typeLogin;

  /// No description provided for @auditLog_typeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get auditLog_typeFile;

  /// No description provided for @auditLog_typeSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get auditLog_typeSpace;

  /// No description provided for @auditLog_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get auditLog_previous;

  /// No description provided for @auditLog_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get auditLog_next;

  /// No description provided for @auditLog_action_createContract.
  ///
  /// In en, this message translates to:
  /// **'Contract created'**
  String get auditLog_action_createContract;

  /// No description provided for @auditLog_action_sendContract.
  ///
  /// In en, this message translates to:
  /// **'Contract sent'**
  String get auditLog_action_sendContract;

  /// No description provided for @auditLog_action_clientApprove.
  ///
  /// In en, this message translates to:
  /// **'Client approved'**
  String get auditLog_action_clientApprove;

  /// No description provided for @auditLog_action_clientReject.
  ///
  /// In en, this message translates to:
  /// **'Client rejected'**
  String get auditLog_action_clientReject;

  /// No description provided for @auditLog_action_requestEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit requested'**
  String get auditLog_action_requestEdit;

  /// No description provided for @auditLog_action_companyApprove.
  ///
  /// In en, this message translates to:
  /// **'Company approved'**
  String get auditLog_action_companyApprove;

  /// No description provided for @auditLog_action_completeContract.
  ///
  /// In en, this message translates to:
  /// **'Contract completed'**
  String get auditLog_action_completeContract;

  /// No description provided for @auditLog_action_archiveContract.
  ///
  /// In en, this message translates to:
  /// **'Contract archived'**
  String get auditLog_action_archiveContract;

  /// No description provided for @auditLog_action_createSpace.
  ///
  /// In en, this message translates to:
  /// **'Space created'**
  String get auditLog_action_createSpace;

  /// No description provided for @auditLog_action_activateSpace.
  ///
  /// In en, this message translates to:
  /// **'Space activated'**
  String get auditLog_action_activateSpace;

  /// No description provided for @auditLog_action_createApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval created'**
  String get auditLog_action_createApproval;

  /// No description provided for @auditLog_action_approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get auditLog_action_approved;

  /// No description provided for @auditLog_action_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get auditLog_action_rejected;

  /// No description provided for @auditLog_action_requestEditApproval.
  ///
  /// In en, this message translates to:
  /// **'Edit requested on approval'**
  String get auditLog_action_requestEditApproval;

  /// No description provided for @auditLog_action_submitPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment submitted'**
  String get auditLog_action_submitPayment;

  /// No description provided for @auditLog_action_approvePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment approved'**
  String get auditLog_action_approvePayment;

  /// No description provided for @auditLog_action_rejectPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment rejected'**
  String get auditLog_action_rejectPayment;

  /// No description provided for @auditLog_action_uploadFile.
  ///
  /// In en, this message translates to:
  /// **'File uploaded'**
  String get auditLog_action_uploadFile;

  /// No description provided for @auditLog_action_approveFile.
  ///
  /// In en, this message translates to:
  /// **'File approved'**
  String get auditLog_action_approveFile;

  /// No description provided for @auditLog_action_rejectFile.
  ///
  /// In en, this message translates to:
  /// **'File rejected'**
  String get auditLog_action_rejectFile;

  /// No description provided for @auditLog_action_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auditLog_action_login;

  /// No description provided for @auditLog_action_createMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting created'**
  String get auditLog_action_createMeeting;

  /// No description provided for @auditLog_action_updateMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting updated'**
  String get auditLog_action_updateMeeting;

  /// No description provided for @auditLog_action_createClient.
  ///
  /// In en, this message translates to:
  /// **'Client created'**
  String get auditLog_action_createClient;

  /// No description provided for @auditLog_action_deleteClient.
  ///
  /// In en, this message translates to:
  /// **'Client deleted'**
  String get auditLog_action_deleteClient;

  /// No description provided for @contractBuilder_currencySAR.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get contractBuilder_currencySAR;

  /// No description provided for @contractBuilder_currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'USD'**
  String get contractBuilder_currencyUSD;

  /// No description provided for @contractBuilder_currencyEUR.
  ///
  /// In en, this message translates to:
  /// **'EUR'**
  String get contractBuilder_currencyEUR;

  /// No description provided for @contractBuilder_currencyAED.
  ///
  /// In en, this message translates to:
  /// **'AED'**
  String get contractBuilder_currencyAED;

  /// No description provided for @contractBuilder_clauseTemplate1.
  ///
  /// In en, this message translates to:
  /// **'The first party agrees to provide the services specified in the attached scope of work.'**
  String get contractBuilder_clauseTemplate1;

  /// No description provided for @contractBuilder_clauseTemplate2.
  ///
  /// In en, this message translates to:
  /// **'The second party agrees to pay the agreed-upon amount in accordance with the payment schedule.'**
  String get contractBuilder_clauseTemplate2;

  /// No description provided for @contractBuilder_clauseTemplate3.
  ///
  /// In en, this message translates to:
  /// **'The contract duration shall be as specified in the agreement, commencing from the start date.'**
  String get contractBuilder_clauseTemplate3;

  /// No description provided for @contractBuilder_clauseTemplate4.
  ///
  /// In en, this message translates to:
  /// **'Either party may terminate this agreement with a written notice of {days} days.'**
  String contractBuilder_clauseTemplate4(Object days);

  /// No description provided for @contractBuilder_clauseTemplate5.
  ///
  /// In en, this message translates to:
  /// **'All confidential information shared between parties shall remain protected.'**
  String get contractBuilder_clauseTemplate5;

  /// No description provided for @contractBuilder_clauseTemplate6.
  ///
  /// In en, this message translates to:
  /// **'Any modifications to this contract must be made in writing and signed by both parties.'**
  String get contractBuilder_clauseTemplate6;

  /// No description provided for @contractBuilder_clauseTemplate7.
  ///
  /// In en, this message translates to:
  /// **'Disputes shall be resolved through amicable negotiation before any legal action.'**
  String get contractBuilder_clauseTemplate7;

  /// No description provided for @contractBuilder_clauseTemplate8.
  ///
  /// In en, this message translates to:
  /// **'This agreement is governed by the laws of the Kingdom of Saudi Arabia.'**
  String get contractBuilder_clauseTemplate8;

  /// No description provided for @contractBuilder_titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get contractBuilder_titleRequired;

  /// No description provided for @contractBuilder_valueRequired.
  ///
  /// In en, this message translates to:
  /// **'Value is required'**
  String get contractBuilder_valueRequired;

  /// No description provided for @contractBuilder_updated.
  ///
  /// In en, this message translates to:
  /// **'Contract updated successfully'**
  String get contractBuilder_updated;

  /// No description provided for @contractBuilder_createdAndSent.
  ///
  /// In en, this message translates to:
  /// **'Contract created and sent successfully'**
  String get contractBuilder_createdAndSent;

  /// No description provided for @contractBuilder_createdSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Contract created but failed to send'**
  String get contractBuilder_createdSendFailed;

  /// No description provided for @contractBuilder_updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update contract'**
  String get contractBuilder_updateFailed;

  /// No description provided for @contractBuilder_createFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create contract'**
  String get contractBuilder_createFailed;

  /// No description provided for @contractBuilder_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Contract'**
  String get contractBuilder_editTitle;

  /// No description provided for @contractBuilder_createExtraTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Extra Service'**
  String get contractBuilder_createExtraTitle;

  /// No description provided for @contractBuilder_createNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Contract'**
  String get contractBuilder_createNewTitle;

  /// No description provided for @onboarding_newNotification.
  ///
  /// In en, this message translates to:
  /// **'New Notification'**
  String get onboarding_newNotification;

  /// No description provided for @onboarding_spaceActivated.
  ///
  /// In en, this message translates to:
  /// **'Your workspace is now active!'**
  String get onboarding_spaceActivated;

  /// No description provided for @onboarding_failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load onboarding data'**
  String get onboarding_failedToLoad;

  /// No description provided for @onboarding_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get onboarding_logout;

  /// No description provided for @onboarding_logoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get onboarding_logoutQuestion;

  /// No description provided for @onboarding_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get onboarding_cancel;

  /// No description provided for @onboarding_logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get onboarding_logoutAction;

  /// No description provided for @onboarding_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get onboarding_retry;

  /// No description provided for @onboarding_changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get onboarding_changeLanguage;

  /// No description provided for @onboarding_signStage.
  ///
  /// In en, this message translates to:
  /// **'Sign Contract'**
  String get onboarding_signStage;

  /// No description provided for @onboarding_receiveContractStage.
  ///
  /// In en, this message translates to:
  /// **'Receive Contract'**
  String get onboarding_receiveContractStage;

  /// No description provided for @onboarding_approvalStage.
  ///
  /// In en, this message translates to:
  /// **'Review & Approve'**
  String get onboarding_approvalStage;

  /// No description provided for @onboarding_companyApprovalStage.
  ///
  /// In en, this message translates to:
  /// **'Company Approval'**
  String get onboarding_companyApprovalStage;

  /// No description provided for @onboarding_paymentStage.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get onboarding_paymentStage;

  /// No description provided for @onboarding_activateStage.
  ///
  /// In en, this message translates to:
  /// **'Activate Space'**
  String get onboarding_activateStage;

  /// No description provided for @onboarding_waitingContract.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Contract'**
  String get onboarding_waitingContract;

  /// No description provided for @onboarding_waitingContractMsg.
  ///
  /// In en, this message translates to:
  /// **'Your contract is being prepared. You will be notified once it is ready.'**
  String get onboarding_waitingContractMsg;

  /// No description provided for @onboarding_waitingCompanyApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Company Approval'**
  String get onboarding_waitingCompanyApproval;

  /// No description provided for @onboarding_waitingCompanyApprovalMsg.
  ///
  /// In en, this message translates to:
  /// **'The company is reviewing your contract. Please wait for their response.'**
  String get onboarding_waitingCompanyApprovalMsg;

  /// No description provided for @onboarding_reviewingPayment.
  ///
  /// In en, this message translates to:
  /// **'Reviewing Payment'**
  String get onboarding_reviewingPayment;

  /// No description provided for @onboarding_waitingActivation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Activation'**
  String get onboarding_waitingActivation;

  /// No description provided for @onboarding_welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get onboarding_welcome;

  /// No description provided for @onboarding_addSignature.
  ///
  /// In en, this message translates to:
  /// **'Add Your Signature'**
  String get onboarding_addSignature;

  /// No description provided for @onboarding_signNow.
  ///
  /// In en, this message translates to:
  /// **'Sign Now'**
  String get onboarding_signNow;

  /// No description provided for @onboarding_contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get onboarding_contactSupport;

  /// No description provided for @onboarding_contractReceived.
  ///
  /// In en, this message translates to:
  /// **'Contract Received'**
  String get onboarding_contractReceived;

  /// No description provided for @onboarding_reviewContract.
  ///
  /// In en, this message translates to:
  /// **'Review Contract'**
  String get onboarding_reviewContract;

  /// No description provided for @onboarding_previewContract.
  ///
  /// In en, this message translates to:
  /// **'Preview Contract'**
  String get onboarding_previewContract;

  /// No description provided for @onboarding_approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get onboarding_approve;

  /// No description provided for @onboarding_requestEdit.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get onboarding_requestEdit;

  /// No description provided for @onboarding_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboarding_back;

  /// No description provided for @onboarding_editRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Requested'**
  String get onboarding_editRequestedTitle;

  /// No description provided for @onboarding_mentionChanges.
  ///
  /// In en, this message translates to:
  /// **'Mention the changes you need'**
  String get onboarding_mentionChanges;

  /// No description provided for @onboarding_exampleChanges.
  ///
  /// In en, this message translates to:
  /// **'e.g. Please update the payment terms'**
  String get onboarding_exampleChanges;

  /// No description provided for @onboarding_cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get onboarding_cancelAction;

  /// No description provided for @onboarding_confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get onboarding_confirmAction;

  /// No description provided for @onboarding_approvedMessage.
  ///
  /// In en, this message translates to:
  /// **'Contract approved successfully!'**
  String get onboarding_approvedMessage;

  /// No description provided for @onboarding_editSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit request sent successfully!'**
  String get onboarding_editSentMessage;

  /// No description provided for @onboarding_errorMessage.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get onboarding_errorMessage;

  /// No description provided for @onboarding_completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get onboarding_completePayment;

  /// No description provided for @onboarding_confirmPaymentMsg.
  ///
  /// In en, this message translates to:
  /// **'Please upload your payment proof to continue.'**
  String get onboarding_confirmPaymentMsg;

  /// No description provided for @onboarding_remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'Remaining Amount'**
  String get onboarding_remainingAmount;

  /// No description provided for @onboarding_valueBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Value Breakdown'**
  String get onboarding_valueBreakdown;

  /// No description provided for @onboarding_contractDetails.
  ///
  /// In en, this message translates to:
  /// **'Contract Details'**
  String get onboarding_contractDetails;

  /// No description provided for @onboarding_startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get onboarding_startDate;

  /// No description provided for @onboarding_endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get onboarding_endDate;

  /// No description provided for @onboarding_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get onboarding_amount;

  /// No description provided for @onboarding_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get onboarding_currency;

  /// No description provided for @onboarding_tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get onboarding_tax;

  /// No description provided for @onboarding_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get onboarding_total;

  /// No description provided for @onboarding_paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid Amount'**
  String get onboarding_paidAmount;

  /// No description provided for @onboarding_remainingAmount2.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get onboarding_remainingAmount2;

  /// No description provided for @onboarding_uploadPayment.
  ///
  /// In en, this message translates to:
  /// **'Upload Payment Proof'**
  String get onboarding_uploadPayment;

  /// No description provided for @onboarding_paymentMethodMap.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get onboarding_paymentMethodMap;

  /// No description provided for @onboarding_requestPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Request'**
  String get onboarding_requestPaymentTitle;

  /// No description provided for @onboarding_amountField.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get onboarding_amountField;

  /// No description provided for @onboarding_currencyField.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get onboarding_currencyField;

  /// No description provided for @onboarding_paymentMethodField.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get onboarding_paymentMethodField;

  /// No description provided for @onboarding_proofField.
  ///
  /// In en, this message translates to:
  /// **'Payment Proof'**
  String get onboarding_proofField;

  /// No description provided for @onboarding_attachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach File'**
  String get onboarding_attachFile;

  /// No description provided for @onboarding_camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get onboarding_camera;

  /// No description provided for @onboarding_filesAttached.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) attached'**
  String onboarding_filesAttached(Object count);

  /// No description provided for @onboarding_sendPayment.
  ///
  /// In en, this message translates to:
  /// **'Send Payment'**
  String get onboarding_sendPayment;

  /// No description provided for @onboarding_enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get onboarding_enterValidAmount;

  /// No description provided for @onboarding_workspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Workspace unavailable'**
  String get onboarding_workspaceUnavailable;

  /// No description provided for @onboarding_paymentSent.
  ///
  /// In en, this message translates to:
  /// **'Payment sent successfully!'**
  String get onboarding_paymentSent;

  /// No description provided for @onboarding_paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send payment'**
  String get onboarding_paymentFailed;

  /// No description provided for @onboarding_welcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome {name}'**
  String onboarding_welcomeName(Object name);

  /// No description provided for @onboarding_addSignaturePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please add your electronic signature'**
  String get onboarding_addSignaturePrompt;

  /// No description provided for @onboarding_yourApprovalStage.
  ///
  /// In en, this message translates to:
  /// **'Your Approval'**
  String get onboarding_yourApprovalStage;

  /// No description provided for @onboarding_paymentProofStage.
  ///
  /// In en, this message translates to:
  /// **'Payment Proof'**
  String get onboarding_paymentProofStage;

  /// No description provided for @onboarding_waitingContractSendMsg.
  ///
  /// In en, this message translates to:
  /// **'The contract will be sent to you for signing soon'**
  String get onboarding_waitingContractSendMsg;

  /// No description provided for @onboarding_waitingCompanyReviewMsg.
  ///
  /// In en, this message translates to:
  /// **'The company team is reviewing your request'**
  String get onboarding_waitingCompanyReviewMsg;

  /// No description provided for @onboarding_reviewContractPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please review the contract and provide your approval'**
  String get onboarding_reviewContractPrompt;

  /// No description provided for @onboarding_confirmPaymentToActivate.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your payment to activate the workspace'**
  String get onboarding_confirmPaymentToActivate;

  /// No description provided for @onboarding_failedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String onboarding_failedWithError(Object error);

  /// No description provided for @onboarding_takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get onboarding_takePhoto;

  /// No description provided for @currency_sar.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal'**
  String get currency_sar;

  /// No description provided for @currency_usd.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get currency_usd;

  /// No description provided for @currency_eur.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get currency_eur;

  /// No description provided for @currency_aed.
  ///
  /// In en, this message translates to:
  /// **'UAE Dirham'**
  String get currency_aed;

  /// No description provided for @currency_egp.
  ///
  /// In en, this message translates to:
  /// **'Egyptian Pound'**
  String get currency_egp;

  /// No description provided for @currency_kwd.
  ///
  /// In en, this message translates to:
  /// **'Kuwaiti Dinar'**
  String get currency_kwd;

  /// No description provided for @currency_qar.
  ///
  /// In en, this message translates to:
  /// **'Qatari Riyal'**
  String get currency_qar;

  /// No description provided for @currency_bhd.
  ///
  /// In en, this message translates to:
  /// **'Bahraini Dinar'**
  String get currency_bhd;

  /// No description provided for @currency_omr.
  ///
  /// In en, this message translates to:
  /// **'Omani Riyal'**
  String get currency_omr;

  /// No description provided for @preview_vibeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Preview'**
  String get preview_vibeTitle;

  /// No description provided for @preview_bestFor.
  ///
  /// In en, this message translates to:
  /// **'Best for'**
  String get preview_bestFor;

  /// No description provided for @preview_colors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get preview_colors;

  /// No description provided for @preview_sampleCard.
  ///
  /// In en, this message translates to:
  /// **'Sample Card'**
  String get preview_sampleCard;

  /// No description provided for @preview_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get preview_active;

  /// No description provided for @preview_buttons.
  ///
  /// In en, this message translates to:
  /// **'Buttons'**
  String get preview_buttons;

  /// No description provided for @preview_primaryAction.
  ///
  /// In en, this message translates to:
  /// **'Primary Action'**
  String get preview_primaryAction;

  /// No description provided for @preview_secondaryAction.
  ///
  /// In en, this message translates to:
  /// **'Secondary Action'**
  String get preview_secondaryAction;

  /// No description provided for @preview_chat.
  ///
  /// In en, this message translates to:
  /// **'Chat Preview'**
  String get preview_chat;

  /// No description provided for @preview_clientMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, I have reviewed the contract.'**
  String get preview_clientMessage;

  /// No description provided for @preview_amMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you! We will process it shortly.'**
  String get preview_amMessage;

  /// No description provided for @preview_loginScreen.
  ///
  /// In en, this message translates to:
  /// **'Login Screen'**
  String get preview_loginScreen;

  /// No description provided for @preview_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get preview_email;

  /// No description provided for @preview_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get preview_password;

  /// No description provided for @preview_loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get preview_loginButton;

  /// No description provided for @preview_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get preview_dashboard;

  /// No description provided for @preview_typography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get preview_typography;

  /// No description provided for @preview_headings.
  ///
  /// In en, this message translates to:
  /// **'Headings'**
  String get preview_headings;

  /// No description provided for @preview_headingSample.
  ///
  /// In en, this message translates to:
  /// **'Headings in {font} regular text'**
  String preview_headingSample(Object font);

  /// No description provided for @preview_chooseDirection.
  ///
  /// In en, this message translates to:
  /// **'Choose Direction'**
  String get preview_chooseDirection;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @upcomingMeeting.
  ///
  /// In en, this message translates to:
  /// **'Upcoming meeting'**
  String get upcomingMeeting;

  /// No description provided for @inMinutes.
  ///
  /// In en, this message translates to:
  /// **'In {count} minutes'**
  String inMinutes(Object count);

  /// No description provided for @inHours.
  ///
  /// In en, this message translates to:
  /// **'In {count} hours'**
  String inHours(Object count);

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'In {count} days'**
  String inDays(Object count);

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @noActiveMeeting.
  ///
  /// In en, this message translates to:
  /// **'No active meeting'**
  String get noActiveMeeting;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat is unavailable — waiting for workspace activation after payment'**
  String get chatUnavailable;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @editYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit your message...'**
  String get editYourMessage;

  /// No description provided for @editFailed.
  ///
  /// In en, this message translates to:
  /// **'Edit failed: {error}'**
  String editFailed(Object error);

  /// No description provided for @attachmentSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send attachment'**
  String get attachmentSendFailed;

  /// No description provided for @editRequestedToast.
  ///
  /// In en, this message translates to:
  /// **'Edit requested'**
  String get editRequestedToast;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to execute action'**
  String get actionFailed;

  /// No description provided for @editRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Request'**
  String get editRequestTitle;

  /// No description provided for @editRequestPrompt.
  ///
  /// In en, this message translates to:
  /// **'Mention the required edits:'**
  String get editRequestPrompt;

  /// No description provided for @editRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Edit the design colors...'**
  String get editRequestHint;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get edited;

  /// No description provided for @newApproval.
  ///
  /// In en, this message translates to:
  /// **'NEW APPROVAL'**
  String get newApproval;

  /// No description provided for @needsYourApproval.
  ///
  /// In en, this message translates to:
  /// **'Needs your approval'**
  String get needsYourApproval;

  /// No description provided for @requestEdit.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get requestEdit;

  /// No description provided for @approvedLabel.
  ///
  /// In en, this message translates to:
  /// **'✓ Approved'**
  String get approvedLabel;

  /// No description provided for @rejectedLabel.
  ///
  /// In en, this message translates to:
  /// **'✗ Rejected'**
  String get rejectedLabel;

  /// No description provided for @editRequestedLabel.
  ///
  /// In en, this message translates to:
  /// **'✎ Edit requested'**
  String get editRequestedLabel;

  /// No description provided for @downloadApprovalCert.
  ///
  /// In en, this message translates to:
  /// **'Download Approval Certificate'**
  String get downloadApprovalCert;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get fileOpenFailed;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @documentUploaded.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded'**
  String get documentUploaded;

  /// No description provided for @documentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload document: {error}'**
  String documentUploadFailed(Object error);

  /// No description provided for @additionalServiceContract.
  ///
  /// In en, this message translates to:
  /// **'Additional Service Contract'**
  String get additionalServiceContract;

  /// No description provided for @mainContract.
  ///
  /// In en, this message translates to:
  /// **'Main Contract'**
  String get mainContract;

  /// No description provided for @contractInfo.
  ///
  /// In en, this message translates to:
  /// **'Contract Info'**
  String get contractInfo;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @requiredDocuments.
  ///
  /// In en, this message translates to:
  /// **'Required Documents'**
  String get requiredDocuments;

  /// No description provided for @uploadedFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Files'**
  String get uploadedFiles;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @rejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason: {reason}'**
  String rejectionReason(Object reason);

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @uploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument;

  /// No description provided for @downloadContractPdf.
  ///
  /// In en, this message translates to:
  /// **'Download Contract (PDF)'**
  String get downloadContractPdf;

  /// No description provided for @contractApprovedByCompany.
  ///
  /// In en, this message translates to:
  /// **'Contract approved by company'**
  String get contractApprovedByCompany;

  /// No description provided for @goToPaymentPage.
  ///
  /// In en, this message translates to:
  /// **'You can proceed to payment page to complete payment'**
  String get goToPaymentPage;

  /// No description provided for @proceedToPayment.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get proceedToPayment;

  /// No description provided for @youApprovedThisContract.
  ///
  /// In en, this message translates to:
  /// **'You approved this contract'**
  String get youApprovedThisContract;

  /// No description provided for @youRequestedEdit.
  ///
  /// In en, this message translates to:
  /// **'You requested an edit'**
  String get youRequestedEdit;

  /// No description provided for @youRejectedThisContract.
  ///
  /// In en, this message translates to:
  /// **'You rejected this contract'**
  String get youRejectedThisContract;

  /// No description provided for @contractCompleted.
  ///
  /// In en, this message translates to:
  /// **'Contract completed'**
  String get contractCompleted;

  /// No description provided for @invalidFileUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid file URL'**
  String get invalidFileUrl;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// No description provided for @deleteFileConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteFileConfirmation(Object name);

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get fileDeleted;

  /// No description provided for @fileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file: {error}'**
  String fileDeleteFailed(Object error);

  /// No description provided for @allContracts.
  ///
  /// In en, this message translates to:
  /// **'All Contracts'**
  String get allContracts;

  /// No description provided for @waitingForContracts.
  ///
  /// In en, this message translates to:
  /// **'Waiting for contracts'**
  String get waitingForContracts;

  /// No description provided for @contractValueExcludesVat.
  ///
  /// In en, this message translates to:
  /// **'Contract value excludes VAT'**
  String get contractValueExcludesVat;

  /// No description provided for @additionalContract.
  ///
  /// In en, this message translates to:
  /// **'Additional Contract'**
  String get additionalContract;

  /// No description provided for @editReason.
  ///
  /// In en, this message translates to:
  /// **'Edit reason: {reason}'**
  String editReason(Object reason);

  /// No description provided for @approveContract.
  ///
  /// In en, this message translates to:
  /// **'Approve Contract'**
  String get approveContract;

  /// No description provided for @confirmApproveContract.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this contract?'**
  String get confirmApproveContract;

  /// No description provided for @requiredEdits.
  ///
  /// In en, this message translates to:
  /// **'Required edits'**
  String get requiredEdits;

  /// No description provided for @editRequestHint2.
  ///
  /// In en, this message translates to:
  /// **'Mention the required edits...'**
  String get editRequestHint2;

  /// No description provided for @contractActionDone.
  ///
  /// In en, this message translates to:
  /// **'Contract {action}'**
  String contractActionDone(Object action);

  /// No description provided for @contractActionDialog.
  ///
  /// In en, this message translates to:
  /// **'{action} Contract'**
  String contractActionDialog(Object action);

  /// No description provided for @dashboard_notifications_appBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get dashboard_notifications_appBarTitle;

  /// No description provided for @dashboard_tabLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'This tab is locked — you must complete the stage \"{stage}\" first'**
  String dashboard_tabLockedMessage(Object stage);

  /// No description provided for @payments_methodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get payments_methodBankTransfer;

  /// No description provided for @payments_methodSwift.
  ///
  /// In en, this message translates to:
  /// **'SWIFT transfer'**
  String get payments_methodSwift;

  /// No description provided for @payments_methodCorporateAccount.
  ///
  /// In en, this message translates to:
  /// **'Corporate account'**
  String get payments_methodCorporateAccount;

  /// No description provided for @payments_methodInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get payments_methodInstapay;

  /// No description provided for @payments_methodVodafoneCash.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash'**
  String get payments_methodVodafoneCash;

  /// No description provided for @payments_methodMobileWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get payments_methodMobileWallet;

  /// No description provided for @payments_remainingSummary.
  ///
  /// In en, this message translates to:
  /// **'of {total} {currency} — {remaining} remaining'**
  String payments_remainingSummary(
      Object currency, Object remaining, Object total);

  /// No description provided for @payments_taxSummary.
  ///
  /// In en, this message translates to:
  /// **'Value: {value} {currency} + tax {percentage}% = {amount} {currency}'**
  String payments_taxSummary(
      Object amount, Object currency, Object percentage, Object value);

  /// No description provided for @payments_dueDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String payments_dueDateFormat(Object date);

  /// No description provided for @payments_ordinalFirst.
  ///
  /// In en, this message translates to:
  /// **'first'**
  String get payments_ordinalFirst;

  /// No description provided for @payments_ordinalSecond.
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get payments_ordinalSecond;

  /// No description provided for @payments_ordinalThird.
  ///
  /// In en, this message translates to:
  /// **'third'**
  String get payments_ordinalThird;

  /// No description provided for @payments_ordinalFourth.
  ///
  /// In en, this message translates to:
  /// **'fourth'**
  String get payments_ordinalFourth;

  /// No description provided for @payments_ordinalFifth.
  ///
  /// In en, this message translates to:
  /// **'fifth'**
  String get payments_ordinalFifth;

  /// No description provided for @payments_ordinalSixth.
  ///
  /// In en, this message translates to:
  /// **'sixth'**
  String get payments_ordinalSixth;

  /// No description provided for @payments_ordinalSeventh.
  ///
  /// In en, this message translates to:
  /// **'seventh'**
  String get payments_ordinalSeventh;

  /// No description provided for @payments_ordinalEighth.
  ///
  /// In en, this message translates to:
  /// **'eighth'**
  String get payments_ordinalEighth;

  /// No description provided for @payments_ordinalNinth.
  ///
  /// In en, this message translates to:
  /// **'ninth'**
  String get payments_ordinalNinth;

  /// No description provided for @payments_ordinalTenth.
  ///
  /// In en, this message translates to:
  /// **'tenth'**
  String get payments_ordinalTenth;

  /// No description provided for @payments_installmentFormat.
  ///
  /// In en, this message translates to:
  /// **'Installment {ordinal}'**
  String payments_installmentFormat(Object ordinal);

  /// No description provided for @payments_installmentFormatNumbered.
  ///
  /// In en, this message translates to:
  /// **'Installment {number}'**
  String payments_installmentFormatNumbered(Object number);

  /// No description provided for @payments_payScheduled.
  ///
  /// In en, this message translates to:
  /// **'Pay {label}'**
  String payments_payScheduled(Object label);

  /// No description provided for @files_uploadedFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploaded files'**
  String get files_uploadedFiles;

  /// No description provided for @files_uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get files_uploading;

  /// No description provided for @files_uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get files_uploadFile;

  /// No description provided for @files_noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get files_noFiles;

  /// No description provided for @files_paymentProofs.
  ///
  /// In en, this message translates to:
  /// **'Payment proofs'**
  String get files_paymentProofs;

  /// No description provided for @files_paymentProof.
  ///
  /// In en, this message translates to:
  /// **'Payment proof'**
  String get files_paymentProof;

  /// No description provided for @subusers_noSubUsers.
  ///
  /// In en, this message translates to:
  /// **'No sub-users'**
  String get subusers_noSubUsers;

  /// No description provided for @invalidData.
  ///
  /// In en, this message translates to:
  /// **'Invalid data'**
  String get invalidData;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'ShadApp Notifications'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'App notifications'**
  String get notificationChannelDescription;

  /// No description provided for @couldNotLoadData.
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get couldNotLoadData;

  /// No description provided for @paymentRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment request — {amount} {currency}'**
  String paymentRequestTitle(Object amount, Object currency);

  /// No description provided for @overduePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Overdue payment — {amount} {currency}'**
  String overduePaymentTitle(Object amount, Object currency);

  /// No description provided for @scheduledPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming payment — {amount} {currency}'**
  String scheduledPaymentTitle(Object amount, Object currency);

  /// No description provided for @pendingPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending review — {amount} {currency}'**
  String pendingPaymentTitle(Object amount, Object currency);

  /// No description provided for @paidPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Paid — {amount} {currency}'**
  String paidPaymentTitle(Object amount, Object currency);

  /// No description provided for @sarClauses.
  ///
  /// In en, this message translates to:
  /// **'{value} SAR • {count} clauses'**
  String sarClauses(Object value, Object count);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @daysLate.
  ///
  /// In en, this message translates to:
  /// **'{count} day(s) late'**
  String daysLate(Object count);

  /// No description provided for @atLeast8Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8Chars;

  /// No description provided for @oneEnglishLetter.
  ///
  /// In en, this message translates to:
  /// **'One English letter'**
  String get oneEnglishLetter;

  /// No description provided for @oneNumber.
  ///
  /// In en, this message translates to:
  /// **'One number'**
  String get oneNumber;

  /// No description provided for @mustContainEnglishLetter.
  ///
  /// In en, this message translates to:
  /// **'Must contain an English letter'**
  String get mustContainEnglishLetter;

  /// No description provided for @mustContainNumber.
  ///
  /// In en, this message translates to:
  /// **'Must contain a number'**
  String get mustContainNumber;

  /// No description provided for @awaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get awaitingPayment;

  /// No description provided for @approveContractTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Contract'**
  String get approveContractTitle;

  /// No description provided for @approveContractConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this contract?'**
  String get approveContractConfirm;

  /// No description provided for @editReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the reason for editing...'**
  String get editReasonHint;

  /// No description provided for @awaitingContracts.
  ///
  /// In en, this message translates to:
  /// **'Awaiting contracts...'**
  String get awaitingContracts;

  /// No description provided for @goToPayment.
  ///
  /// In en, this message translates to:
  /// **'Go to payment'**
  String get goToPayment;

  /// No description provided for @goToPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'You can now proceed to payment'**
  String get goToPaymentHint;

  /// No description provided for @clientApprovedStatus.
  ///
  /// In en, this message translates to:
  /// **'You have approved this contract'**
  String get clientApprovedStatus;

  /// No description provided for @rejectedStatus.
  ///
  /// In en, this message translates to:
  /// **'You have rejected this contract'**
  String get rejectedStatus;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'Contract completed'**
  String get completedStatus;

  /// No description provided for @editReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit reason'**
  String get editReasonTitle;

  /// No description provided for @deleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get deleteFileTitle;

  /// No description provided for @editReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit reason: {reason}'**
  String editReasonLabel(Object reason);

  /// No description provided for @accountManagersAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Manager'**
  String get accountManagersAddButton;

  /// No description provided for @accountManagersAddHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a new manager'**
  String get accountManagersAddHint;

  /// No description provided for @accountManagersClientCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clients'**
  String accountManagersClientCount(Object count);

  /// No description provided for @accountManagersDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete manager'**
  String get accountManagersDeleteFailed;

  /// No description provided for @accountManagersDeleteNameConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String accountManagersDeleteNameConfirmation(Object name);

  /// No description provided for @accountManagersDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Manager'**
  String get accountManagersDeleteTitle;

  /// No description provided for @accountManagersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No managers yet'**
  String get accountManagersEmpty;

  /// No description provided for @accountManagersFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load managers'**
  String get accountManagersFailedToLoad;

  /// No description provided for @amAllContracts.
  ///
  /// In en, this message translates to:
  /// **'All Contracts'**
  String get amAllContracts;

  /// No description provided for @amClientRequired.
  ///
  /// In en, this message translates to:
  /// **'Client *'**
  String get amClientRequired;

  /// No description provided for @amClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get amClients;

  /// No description provided for @amClientsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load clients'**
  String get amClientsLoadFailed;

  /// No description provided for @amContractApproval.
  ///
  /// In en, this message translates to:
  /// **'Approve Contract'**
  String get amContractApproval;

  /// No description provided for @amContractsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load contracts'**
  String get amContractsLoadFailed;

  /// No description provided for @amDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get amDate;

  /// No description provided for @amDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get amDurationMinutes;

  /// No description provided for @amManageManagers.
  ///
  /// In en, this message translates to:
  /// **'Manage Managers'**
  String get amManageManagers;

  /// No description provided for @amMeetingCreated.
  ///
  /// In en, this message translates to:
  /// **'Meeting created successfully'**
  String get amMeetingCreated;

  /// No description provided for @amMeetingCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create meeting'**
  String get amMeetingCreateFailed;

  /// No description provided for @amMeetingCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Meeting'**
  String get amMeetingCreateTitle;

  /// No description provided for @amMeetingDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get amMeetingDate;

  /// No description provided for @amMeetingDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get amMeetingDuration;

  /// No description provided for @amMeetingMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get amMeetingMinutes;

  /// No description provided for @amMeetingNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get amMeetingNotes;

  /// No description provided for @amMeetingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load meetings'**
  String get amMeetingsLoadFailed;

  /// No description provided for @amMeetingTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get amMeetingTime;

  /// No description provided for @amMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting Title *'**
  String get amMeetingTitle;

  /// No description provided for @amMeetingTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: weekly follow-up meeting'**
  String get amMeetingTitleHint;

  /// No description provided for @amMeetingValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a meeting title and select a client'**
  String get amMeetingValidation;

  /// No description provided for @amMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get amMinutes;

  /// No description provided for @amNavTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get amNavTeam;

  /// No description provided for @amNewNotification.
  ///
  /// In en, this message translates to:
  /// **'New notification'**
  String get amNewNotification;

  /// No description provided for @amNoClientsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No available clients'**
  String get amNoClientsAvailable;

  /// No description provided for @amNoContracts.
  ///
  /// In en, this message translates to:
  /// **'No contracts'**
  String get amNoContracts;

  /// No description provided for @amNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get amNoItems;

  /// No description provided for @amNoMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings'**
  String get amNoMeetings;

  /// No description provided for @amNoPendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'No pending approvals'**
  String get amNoPendingApprovals;

  /// No description provided for @amNoPendingPayments.
  ///
  /// In en, this message translates to:
  /// **'No pending payments'**
  String get amNoPendingPayments;

  /// No description provided for @amNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get amNotes;

  /// No description provided for @amPaymentApproval.
  ///
  /// In en, this message translates to:
  /// **'Approve Payment'**
  String get amPaymentApproval;

  /// No description provided for @amPendingPaymentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get amPendingPaymentsLabel;

  /// No description provided for @amRecentApprovals.
  ///
  /// In en, this message translates to:
  /// **'Recent Pending Approvals'**
  String get amRecentApprovals;

  /// No description provided for @amStatActiveContracts.
  ///
  /// In en, this message translates to:
  /// **'Active Contracts'**
  String get amStatActiveContracts;

  /// No description provided for @amStatMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get amStatMeetings;

  /// No description provided for @amStatPendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get amStatPendingApprovals;

  /// No description provided for @amStatPendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get amStatPendingPayments;

  /// No description provided for @amStatReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get amStatReports;

  /// No description provided for @amStatTotalClients.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get amStatTotalClients;

  /// No description provided for @amStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get amStatusActive;

  /// No description provided for @amStatusContracted.
  ///
  /// In en, this message translates to:
  /// **'Contracted'**
  String get amStatusContracted;

  /// No description provided for @amStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get amStatusInactive;

  /// No description provided for @amStatusNotContracted.
  ///
  /// In en, this message translates to:
  /// **'Not Contracted'**
  String get amStatusNotContracted;

  /// No description provided for @amStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get amStatusPaid;

  /// No description provided for @amStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get amStatusPending;

  /// No description provided for @amTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get amTime;

  /// No description provided for @amViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get amViewAll;

  /// No description provided for @amWorkspaceCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create workspace'**
  String get amWorkspaceCreateFailed;

  /// No description provided for @approvalActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get approvalActionFailed;

  /// No description provided for @approvalApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvalApproved;

  /// No description provided for @approvalAttachFiles.
  ///
  /// In en, this message translates to:
  /// **'Attach Files'**
  String get approvalAttachFiles;

  /// No description provided for @approvalCertificate.
  ///
  /// In en, this message translates to:
  /// **'Approval Certificate'**
  String get approvalCertificate;

  /// No description provided for @approvalCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Approval Request'**
  String get approvalCreateTitle;

  /// No description provided for @approvalDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get approvalDescription;

  /// No description provided for @approvalDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Additional details...'**
  String get approvalDescriptionHint;

  /// No description provided for @approvalEditReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Mention the required edits...'**
  String get approvalEditReasonHint;

  /// No description provided for @approvalEditReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit reason:'**
  String get approvalEditReasonLabel;

  /// No description provided for @approvalEditRequested.
  ///
  /// In en, this message translates to:
  /// **'Edit requested'**
  String get approvalEditRequested;

  /// No description provided for @approvalEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get approvalEditTitle;

  /// No description provided for @approvalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No approval requests'**
  String get approvalEmpty;

  /// No description provided for @approvalFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String approvalFileCount(Object count);

  /// No description provided for @approvalFileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get approvalFileOpenFailed;

  /// No description provided for @approvalPreviousRequests.
  ///
  /// In en, this message translates to:
  /// **'Previous Requests'**
  String get approvalPreviousRequests;

  /// No description provided for @approvalReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get approvalReference;

  /// No description provided for @approvalRequestEdit.
  ///
  /// In en, this message translates to:
  /// **'Request Edit'**
  String get approvalRequestEdit;

  /// No description provided for @approvalRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Approval request sent'**
  String get approvalRequestSent;

  /// No description provided for @approvalSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send Approval Request'**
  String get approvalSendButton;

  /// No description provided for @approvalSendDialogButton.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get approvalSendDialogButton;

  /// No description provided for @approvalSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request'**
  String get approvalSendFailed;

  /// No description provided for @approvalTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: approve the final design'**
  String get approvalTitleHint;

  /// No description provided for @approvalTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Request Title *'**
  String get approvalTitleLabel;

  /// No description provided for @auditLogActionActivateSpace.
  ///
  /// In en, this message translates to:
  /// **'Activate workspace'**
  String get auditLogActionActivateSpace;

  /// No description provided for @auditLogActionApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get auditLogActionApproved;

  /// No description provided for @auditLogActionApproveFile.
  ///
  /// In en, this message translates to:
  /// **'Approve file'**
  String get auditLogActionApproveFile;

  /// No description provided for @auditLogActionApprovePayment.
  ///
  /// In en, this message translates to:
  /// **'Approve payment'**
  String get auditLogActionApprovePayment;

  /// No description provided for @auditLogActionArchiveContract.
  ///
  /// In en, this message translates to:
  /// **'Archive contract'**
  String get auditLogActionArchiveContract;

  /// No description provided for @auditLogActionClientApprove.
  ///
  /// In en, this message translates to:
  /// **'Client approved contract'**
  String get auditLogActionClientApprove;

  /// No description provided for @auditLogActionClientReject.
  ///
  /// In en, this message translates to:
  /// **'Client rejected contract'**
  String get auditLogActionClientReject;

  /// No description provided for @auditLogActionCompanyApprove.
  ///
  /// In en, this message translates to:
  /// **'Company approved contract'**
  String get auditLogActionCompanyApprove;

  /// No description provided for @auditLogActionCompleteContract.
  ///
  /// In en, this message translates to:
  /// **'Complete contract'**
  String get auditLogActionCompleteContract;

  /// No description provided for @auditLogActionCreateApproval.
  ///
  /// In en, this message translates to:
  /// **'Create approval request'**
  String get auditLogActionCreateApproval;

  /// No description provided for @auditLogActionCreateClient.
  ///
  /// In en, this message translates to:
  /// **'Create client'**
  String get auditLogActionCreateClient;

  /// No description provided for @auditLogActionCreateContract.
  ///
  /// In en, this message translates to:
  /// **'Create contract'**
  String get auditLogActionCreateContract;

  /// No description provided for @auditLogActionCreateMeeting.
  ///
  /// In en, this message translates to:
  /// **'Create meeting'**
  String get auditLogActionCreateMeeting;

  /// No description provided for @auditLogActionCreateSpace.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get auditLogActionCreateSpace;

  /// No description provided for @auditLogActionDeleteClient.
  ///
  /// In en, this message translates to:
  /// **'Delete client'**
  String get auditLogActionDeleteClient;

  /// No description provided for @auditLogActionLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auditLogActionLogin;

  /// No description provided for @auditLogActionRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get auditLogActionRejected;

  /// No description provided for @auditLogActionRejectFile.
  ///
  /// In en, this message translates to:
  /// **'Reject file'**
  String get auditLogActionRejectFile;

  /// No description provided for @auditLogActionRejectPayment.
  ///
  /// In en, this message translates to:
  /// **'Reject payment'**
  String get auditLogActionRejectPayment;

  /// No description provided for @auditLogActionRequestEdit.
  ///
  /// In en, this message translates to:
  /// **'Request contract edit'**
  String get auditLogActionRequestEdit;

  /// No description provided for @auditLogActionRequestEditApproval.
  ///
  /// In en, this message translates to:
  /// **'Request approval edit'**
  String get auditLogActionRequestEditApproval;

  /// No description provided for @auditLogActionSendContract.
  ///
  /// In en, this message translates to:
  /// **'Send contract'**
  String get auditLogActionSendContract;

  /// No description provided for @auditLogActionSubmitPayment.
  ///
  /// In en, this message translates to:
  /// **'Submit payment'**
  String get auditLogActionSubmitPayment;

  /// No description provided for @auditLogActionUpdateMeeting.
  ///
  /// In en, this message translates to:
  /// **'Update meeting'**
  String get auditLogActionUpdateMeeting;

  /// No description provided for @auditLogActionUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get auditLogActionUploadFile;

  /// No description provided for @auditLogEventCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events logged'**
  String auditLogEventCount(Object count);

  /// No description provided for @auditLogFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get auditLogFilterAll;

  /// No description provided for @auditLogFilterApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get auditLogFilterApprovals;

  /// No description provided for @auditLogFilterClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get auditLogFilterClients;

  /// No description provided for @auditLogFilterContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get auditLogFilterContracts;

  /// No description provided for @auditLogFilterLogins.
  ///
  /// In en, this message translates to:
  /// **'Logins'**
  String get auditLogFilterLogins;

  /// No description provided for @auditLogFilterMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get auditLogFilterMeetings;

  /// No description provided for @auditLogFilterPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get auditLogFilterPayments;

  /// No description provided for @auditLogFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get auditLogFrom;

  /// No description provided for @auditLogMonthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get auditLogMonthApril;

  /// No description provided for @auditLogMonthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get auditLogMonthAugust;

  /// No description provided for @auditLogMonthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get auditLogMonthDecember;

  /// No description provided for @auditLogMonthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get auditLogMonthFebruary;

  /// No description provided for @auditLogMonthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get auditLogMonthJanuary;

  /// No description provided for @auditLogMonthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get auditLogMonthJuly;

  /// No description provided for @auditLogMonthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get auditLogMonthJune;

  /// No description provided for @auditLogMonthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get auditLogMonthMarch;

  /// No description provided for @auditLogMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get auditLogMonthMay;

  /// No description provided for @auditLogMonthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get auditLogMonthNovember;

  /// No description provided for @auditLogMonthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get auditLogMonthOctober;

  /// No description provided for @auditLogMonthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get auditLogMonthSeptember;

  /// No description provided for @auditLogNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get auditLogNext;

  /// No description provided for @auditLogNoActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get auditLogNoActivities;

  /// No description provided for @auditLogNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get auditLogNoEvents;

  /// No description provided for @auditLogPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get auditLogPrevious;

  /// No description provided for @auditLogRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get auditLogRetry;

  /// No description provided for @auditLogSearch.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get auditLogSearch;

  /// No description provided for @auditLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLogTitle;

  /// No description provided for @auditLogTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get auditLogTo;

  /// No description provided for @auditLogToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get auditLogToday;

  /// No description provided for @auditLogTypeApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get auditLogTypeApproval;

  /// No description provided for @auditLogTypeClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get auditLogTypeClient;

  /// No description provided for @auditLogTypeContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get auditLogTypeContract;

  /// No description provided for @auditLogTypeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get auditLogTypeFile;

  /// No description provided for @auditLogTypeLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auditLogTypeLogin;

  /// No description provided for @auditLogTypeMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get auditLogTypeMeeting;

  /// No description provided for @auditLogTypePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get auditLogTypePayment;

  /// No description provided for @auditLogTypeSpace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get auditLogTypeSpace;

  /// No description provided for @auditLogYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get auditLogYesterday;

  /// No description provided for @calendarAllEvents.
  ///
  /// In en, this message translates to:
  /// **'All Events'**
  String get calendarAllEvents;

  /// No description provided for @calendarApproval.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get calendarApproval;

  /// No description provided for @calendarApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get calendarApprovals;

  /// No description provided for @calendarContractEndLegend.
  ///
  /// In en, this message translates to:
  /// **'Contract End'**
  String get calendarContractEndLegend;

  /// No description provided for @calendarContractStartLegend.
  ///
  /// In en, this message translates to:
  /// **'Contract Start'**
  String get calendarContractStartLegend;

  /// No description provided for @calendarDateFormat.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {year}/{month}/{day}'**
  String calendarDateFormat(
      Object day, Object month, Object weekday, Object year);

  /// No description provided for @calendarEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get calendarEmpty;

  /// No description provided for @calendarEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get calendarEnd;

  /// No description provided for @calendarMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get calendarMeeting;

  /// No description provided for @calendarMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get calendarMeetings;

  /// No description provided for @calendarPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get calendarPayment;

  /// No description provided for @calendarPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get calendarPayments;

  /// No description provided for @calendarStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get calendarStart;

  /// No description provided for @chatApprovalAlreadyRequested.
  ///
  /// In en, this message translates to:
  /// **'Approval already requested'**
  String get chatApprovalAlreadyRequested;

  /// No description provided for @chatApprovalRequestedHint.
  ///
  /// In en, this message translates to:
  /// **'The client will be asked to approve this message'**
  String get chatApprovalRequestedHint;

  /// No description provided for @chatApprovalRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Approval request failed'**
  String get chatApprovalRequestFailed;

  /// No description provided for @chatApprovedStatus.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get chatApprovedStatus;

  /// No description provided for @chatAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send attachment'**
  String get chatAttachFailed;

  /// No description provided for @chatAwaitingClientApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting client approval'**
  String get chatAwaitingClientApproval;

  /// No description provided for @chatClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get chatClient;

  /// No description provided for @chatContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get chatContracts;

  /// No description provided for @chatDownloadCertificate.
  ///
  /// In en, this message translates to:
  /// **'Download Approval Certificate'**
  String get chatDownloadCertificate;

  /// No description provided for @chatEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEditAction;

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get chatEdited;

  /// No description provided for @chatEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit'**
  String get chatEditFailed;

  /// No description provided for @chatEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get chatEditMessage;

  /// No description provided for @chatEditYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit your message...'**
  String get chatEditYourMessage;

  /// No description provided for @chatFileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get chatFileOpenFailed;

  /// No description provided for @chatInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days} days'**
  String chatInDays(Object days);

  /// No description provided for @chatInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} hours'**
  String chatInHours(Object hours);

  /// No description provided for @chatInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} minutes'**
  String chatInMinutes(Object minutes);

  /// No description provided for @chatJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chatJoin;

  /// No description provided for @chatMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatMessage;

  /// No description provided for @chatMessageDetails.
  ///
  /// In en, this message translates to:
  /// **'Request client approval'**
  String get chatMessageDetails;

  /// No description provided for @chatNewApproval.
  ///
  /// In en, this message translates to:
  /// **'New Approval'**
  String get chatNewApproval;

  /// No description provided for @chatNoActiveMeeting.
  ///
  /// In en, this message translates to:
  /// **'No active meeting'**
  String get chatNoActiveMeeting;

  /// No description provided for @chatNoContracts.
  ///
  /// In en, this message translates to:
  /// **'No contracts'**
  String get chatNoContracts;

  /// No description provided for @chatNoText.
  ///
  /// In en, this message translates to:
  /// **'The client will be asked to approve this message'**
  String get chatNoText;

  /// No description provided for @chatOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatOffline;

  /// No description provided for @chatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get chatOnline;

  /// No description provided for @chatReadOnly.
  ///
  /// In en, this message translates to:
  /// **'View chat only'**
  String get chatReadOnly;

  /// No description provided for @chatRejectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get chatRejectedStatus;

  /// No description provided for @chatReplyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReplyAction;

  /// No description provided for @chatRequestClientApproval.
  ///
  /// In en, this message translates to:
  /// **'Request Client Approval'**
  String get chatRequestClientApproval;

  /// No description provided for @chatRequestedEditStatus.
  ///
  /// In en, this message translates to:
  /// **'Edit requested'**
  String get chatRequestedEditStatus;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatUpcomingMeeting.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Meeting'**
  String get chatUpcomingMeeting;

  /// No description provided for @chatWorkspaceLocked.
  ///
  /// In en, this message translates to:
  /// **'Chat unavailable — waiting for workspace activation'**
  String get chatWorkspaceLocked;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @clientDetailActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get clientDetailActive;

  /// No description provided for @clientDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get clientDetailCancel;

  /// No description provided for @clientDetailCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get clientDetailCompany;

  /// No description provided for @clientDetailCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get clientDetailCompanyName;

  /// No description provided for @clientDetailContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get clientDetailContactPerson;

  /// No description provided for @clientDetailCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get clientDetailCountry;

  /// No description provided for @clientDetailAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get clientDetailAddress;

  /// No description provided for @clientDetailDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get clientDetailDateOfBirth;

  /// No description provided for @clientDetailEditableData.
  ///
  /// In en, this message translates to:
  /// **'Editable Data'**
  String get clientDetailEditableData;

  /// No description provided for @clientDetailEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get clientDetailEditTitle;

  /// No description provided for @clientDetailEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get clientDetailEmail;

  /// No description provided for @clientDetailFixedInfo.
  ///
  /// In en, this message translates to:
  /// **'Fixed Information'**
  String get clientDetailFixedInfo;

  /// No description provided for @clientDetailImageChanged.
  ///
  /// In en, this message translates to:
  /// **'Image changed successfully'**
  String get clientDetailImageChanged;

  /// No description provided for @clientDetailImageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change image'**
  String get clientDetailImageChangeFailed;

  /// No description provided for @clientDetailInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get clientDetailInactive;

  /// No description provided for @clientDetailIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get clientDetailIndividual;

  /// No description provided for @clientDetailIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get clientDetailIndustry;

  /// No description provided for @clientDetailInitials.
  ///
  /// In en, this message translates to:
  /// **'MU'**
  String get clientDetailInitials;

  /// No description provided for @clientDetailLeaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if you don\'t want to change it'**
  String get clientDetailLeaveBlank;

  /// No description provided for @clientDetailNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get clientDetailNewPassword;

  /// No description provided for @clientDetailPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get clientDetailPhone;

  /// No description provided for @clientDetailRegisteredDate.
  ///
  /// In en, this message translates to:
  /// **'Registration Date'**
  String get clientDetailRegisteredDate;

  /// No description provided for @clientDetailResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get clientDetailResetPassword;

  /// No description provided for @clientDetailSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get clientDetailSave;

  /// No description provided for @clientDetailSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get clientDetailSaveChanges;

  /// No description provided for @clientDetailSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved successfully'**
  String get clientDetailSaved;

  /// No description provided for @clientDetailSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get clientDetailSaveFailed;

  /// No description provided for @clientDetailSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get clientDetailSelectDate;

  /// No description provided for @clientDetailSpaceStatus.
  ///
  /// In en, this message translates to:
  /// **'Workspace Status'**
  String get clientDetailSpaceStatus;

  /// No description provided for @clientDetailSubUsersCount.
  ///
  /// In en, this message translates to:
  /// **'Sub Users ({count})'**
  String clientDetailSubUsersCount(Object count);

  /// No description provided for @companyApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Contract: {title}'**
  String companyApproveTitle(Object title);

  /// No description provided for @companyApproveUseSavedSignature.
  ///
  /// In en, this message translates to:
  /// **'Your saved signature will be used:'**
  String get companyApproveUseSavedSignature;

  /// No description provided for @contractAreYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get contractAreYouSure;

  /// No description provided for @contractBuilderClauseFallback1.
  ///
  /// In en, this message translates to:
  /// **'Both parties acknowledge their legal capacity to contract'**
  String get contractBuilderClauseFallback1;

  /// No description provided for @contractBuilderClauseFallback2.
  ///
  /// In en, this message translates to:
  /// **'The first party shall provide the agreed services'**
  String get contractBuilderClauseFallback2;

  /// No description provided for @contractBuilderClauseFallback3.
  ///
  /// In en, this message translates to:
  /// **'The second party shall pay the agreed amount'**
  String get contractBuilderClauseFallback3;

  /// No description provided for @contractBuilderClauseFallback4.
  ///
  /// In en, this message translates to:
  /// **'Both parties shall maintain full confidentiality'**
  String get contractBuilderClauseFallback4;

  /// No description provided for @contractBuilderClauseOptional1.
  ///
  /// In en, this message translates to:
  /// **'Either party may terminate the contract with 30 days written notice'**
  String get contractBuilderClauseOptional1;

  /// No description provided for @contractBuilderClauseOptional2.
  ///
  /// In en, this message translates to:
  /// **'The company is not liable for any delay caused by force majeure'**
  String get contractBuilderClauseOptional2;

  /// No description provided for @contractBuilderClauseOptional3.
  ///
  /// In en, this message translates to:
  /// **'Intellectual property rights belong to the first party'**
  String get contractBuilderClauseOptional3;

  /// No description provided for @contractBuilderClauseOptional4.
  ///
  /// In en, this message translates to:
  /// **'The first party may adjust prices after 12 months'**
  String get contractBuilderClauseOptional4;

  /// No description provided for @contractBuilderClauseOptional5.
  ///
  /// In en, this message translates to:
  /// **'This contract is subject to local laws and regulations'**
  String get contractBuilderClauseOptional5;

  /// No description provided for @contractBuilderClauseOptional6.
  ///
  /// In en, this message translates to:
  /// **'Disputes shall be resolved through arbitration'**
  String get contractBuilderClauseOptional6;

  /// No description provided for @contractBuilderCreateAndSend.
  ///
  /// In en, this message translates to:
  /// **'Create and Send'**
  String get contractBuilderCreateAndSend;

  /// No description provided for @contractBuilderCreatedAndSent.
  ///
  /// In en, this message translates to:
  /// **'Contract created and sent successfully'**
  String get contractBuilderCreatedAndSent;

  /// No description provided for @contractBuilderCreatedSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Contract created but sending failed'**
  String get contractBuilderCreatedSendFailed;

  /// No description provided for @contractBuilderCreateExtraTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Additional Service Contract'**
  String get contractBuilderCreateExtraTitle;

  /// No description provided for @contractBuilderCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create contract'**
  String get contractBuilderCreateFailed;

  /// No description provided for @contractBuilderCreateNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Contract'**
  String get contractBuilderCreateNewTitle;

  /// No description provided for @contractBuilderCurrencyNameAED.
  ///
  /// In en, this message translates to:
  /// **'UAE Dirham'**
  String get contractBuilderCurrencyNameAED;

  /// No description provided for @contractBuilderCurrencyNameBHD.
  ///
  /// In en, this message translates to:
  /// **'Bahraini Dinar'**
  String get contractBuilderCurrencyNameBHD;

  /// No description provided for @contractBuilderCurrencyNameEGP.
  ///
  /// In en, this message translates to:
  /// **'Egyptian Pound'**
  String get contractBuilderCurrencyNameEGP;

  /// No description provided for @contractBuilderCurrencyNameEUR.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get contractBuilderCurrencyNameEUR;

  /// No description provided for @contractBuilderCurrencyNameKWD.
  ///
  /// In en, this message translates to:
  /// **'Kuwaiti Dinar'**
  String get contractBuilderCurrencyNameKWD;

  /// No description provided for @contractBuilderCurrencyNameOMR.
  ///
  /// In en, this message translates to:
  /// **'Omani Rial'**
  String get contractBuilderCurrencyNameOMR;

  /// No description provided for @contractBuilderCurrencyNameQAR.
  ///
  /// In en, this message translates to:
  /// **'Qatari Rial'**
  String get contractBuilderCurrencyNameQAR;

  /// No description provided for @contractBuilderCurrencyNameSAR.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal'**
  String get contractBuilderCurrencyNameSAR;

  /// No description provided for @contractBuilderCurrencyNameUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get contractBuilderCurrencyNameUSD;

  /// No description provided for @contractBuilderCustomClauseHint.
  ///
  /// In en, this message translates to:
  /// **'Write a new clause...'**
  String get contractBuilderCustomClauseHint;

  /// No description provided for @contractBuilderCustomClauses.
  ///
  /// In en, this message translates to:
  /// **'Custom Clauses'**
  String get contractBuilderCustomClauses;

  /// No description provided for @contractBuilderDocNameHint.
  ///
  /// In en, this message translates to:
  /// **'Document name...'**
  String get contractBuilderDocNameHint;

  /// No description provided for @contractBuilderEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Contract'**
  String get contractBuilderEditTitle;

  /// No description provided for @contractBuilderFixedClauses.
  ///
  /// In en, this message translates to:
  /// **'Fixed Clauses'**
  String get contractBuilderFixedClauses;

  /// No description provided for @contractBuilderOptionalClauses.
  ///
  /// In en, this message translates to:
  /// **'Optional Clauses'**
  String get contractBuilderOptionalClauses;

  /// No description provided for @contractBuilderSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get contractBuilderSaveChanges;

  /// No description provided for @contractBuilderSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get contractBuilderSelectDate;

  /// No description provided for @contractBuilderTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: additional maintenance contract'**
  String get contractBuilderTitleHint;

  /// No description provided for @contractBuilderTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the contract title'**
  String get contractBuilderTitleRequired;

  /// No description provided for @contractBuilderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Contract updated'**
  String get contractBuilderUpdated;

  /// No description provided for @contractBuilderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update contract'**
  String get contractBuilderUpdateFailed;

  /// No description provided for @contractBuilderValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the contract value'**
  String get contractBuilderValueRequired;

  /// No description provided for @contractClausesLabel.
  ///
  /// In en, this message translates to:
  /// **'Clauses'**
  String get contractClausesLabel;

  /// No description provided for @contractCreateMain.
  ///
  /// In en, this message translates to:
  /// **'Create Main Contract'**
  String get contractCreateMain;

  /// No description provided for @contractCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get contractCurrency;

  /// No description provided for @contractDateFrom.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String contractDateFrom(Object date);

  /// No description provided for @contractDateRange.
  ///
  /// In en, this message translates to:
  /// **'From {from} to {to}'**
  String contractDateRange(Object from, Object to);

  /// No description provided for @contractDeleteConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this contract? This action cannot be undone.'**
  String get contractDeleteConfirmMsg;

  /// No description provided for @contractDeleted.
  ///
  /// In en, this message translates to:
  /// **'Contract deleted'**
  String get contractDeleted;

  /// No description provided for @contractDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete contract'**
  String get contractDeleteFailed;

  /// No description provided for @contractDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Contract'**
  String get contractDeleteTitle;

  /// No description provided for @contractDownloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download Final Contract'**
  String get contractDownloadPdf;

  /// No description provided for @contractEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get contractEndDateLabel;

  /// No description provided for @contractExtraService.
  ///
  /// In en, this message translates to:
  /// **'Additional Contract'**
  String get contractExtraService;

  /// No description provided for @contractRequiredDocs.
  ///
  /// In en, this message translates to:
  /// **'Documents Required from the Client'**
  String get contractRequiredDocs;

  /// No description provided for @contractRequiredDocsLabel.
  ///
  /// In en, this message translates to:
  /// **'Required Documents'**
  String get contractRequiredDocsLabel;

  /// No description provided for @contractStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get contractStartDateLabel;

  /// No description provided for @contractTitle.
  ///
  /// In en, this message translates to:
  /// **'Contract Title *'**
  String get contractTitle;

  /// No description provided for @contractViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get contractViewDetails;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get copyLink;

  /// No description provided for @createClientAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get createClientAddImage;

  /// No description provided for @createClientAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get createClientAdditionalDetails;

  /// No description provided for @createClientAutoPassword.
  ///
  /// In en, this message translates to:
  /// **'Auto Password'**
  String get createClientAutoPassword;

  /// No description provided for @createClientAutoPasswordEmailHint.
  ///
  /// In en, this message translates to:
  /// **'It will be sent to the client via email'**
  String get createClientAutoPasswordEmailHint;

  /// No description provided for @createClientCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createClientCancel;

  /// No description provided for @createClientCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get createClientCompany;

  /// No description provided for @createClientCompanyData.
  ///
  /// In en, this message translates to:
  /// **'Company Data'**
  String get createClientCompanyData;

  /// No description provided for @createClientCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get createClientCopy;

  /// No description provided for @createClientCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Client'**
  String get createClientCreateButton;

  /// No description provided for @createClientCredentialsSent.
  ///
  /// In en, this message translates to:
  /// **'Login credentials sent to the client via email'**
  String get createClientCredentialsSent;

  /// No description provided for @createClientDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get createClientDateOfBirth;

  /// No description provided for @createClientEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get createClientEmail;

  /// No description provided for @createClientEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied successfully'**
  String get createClientEmailCopied;

  /// No description provided for @createClientIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get createClientIndividual;

  /// No description provided for @createClientNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get createClientNotes;

  /// No description provided for @createClientNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Any additional information about the client...'**
  String get createClientNotesHint;

  /// No description provided for @createClientOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get createClientOk;

  /// No description provided for @createClientPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get createClientPassword;

  /// No description provided for @createClientPasswordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied successfully'**
  String get createClientPasswordCopied;

  /// No description provided for @createClientSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get createClientSelectDate;

  /// No description provided for @createClientSuccess.
  ///
  /// In en, this message translates to:
  /// **'Client created successfully'**
  String get createClientSuccess;

  /// No description provided for @createClientType.
  ///
  /// In en, this message translates to:
  /// **'Client Type'**
  String get createClientType;

  /// No description provided for @createManagerAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get createManagerAdditionalDetails;

  /// No description provided for @createManagerAutoPassword.
  ///
  /// In en, this message translates to:
  /// **'Auto Password'**
  String get createManagerAutoPassword;

  /// No description provided for @createManagerAutoPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'It will be generated automatically'**
  String get createManagerAutoPasswordHint;

  /// No description provided for @createManagerBasicData.
  ///
  /// In en, this message translates to:
  /// **'Basic Data'**
  String get createManagerBasicData;

  /// No description provided for @createManagerCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get createManagerCopy;

  /// No description provided for @createManagerCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Manager'**
  String get createManagerCreateButton;

  /// No description provided for @createManagerCreated.
  ///
  /// In en, this message translates to:
  /// **'Manager created successfully'**
  String get createManagerCreated;

  /// No description provided for @createManagerCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create manager'**
  String get createManagerCreateFailed;

  /// No description provided for @createManagerCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Manager'**
  String get createManagerCreateTitle;

  /// No description provided for @createManagerDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get createManagerDateOfBirth;

  /// No description provided for @createManagerEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Manager'**
  String get createManagerEditTitle;

  /// No description provided for @createManagerEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get createManagerEmailCopied;

  /// No description provided for @createManagerEmailField.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get createManagerEmailField;

  /// No description provided for @createManagerEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get createManagerEmailInvalid;

  /// No description provided for @createManagerEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get createManagerEmailRequired;

  /// No description provided for @createManagerFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load manager data'**
  String get createManagerFailedToLoad;

  /// No description provided for @createManagerLeaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if you don\'t want to change it'**
  String get createManagerLeaveBlank;

  /// No description provided for @createManagerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get createManagerName;

  /// No description provided for @createManagerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get createManagerNameRequired;

  /// No description provided for @createManagerNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get createManagerNewPassword;

  /// No description provided for @createManagerOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get createManagerOk;

  /// No description provided for @createManagerPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get createManagerPassword;

  /// No description provided for @createManagerPasswordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get createManagerPasswordCopied;

  /// No description provided for @createManagerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get createManagerPhone;

  /// No description provided for @createManagerResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get createManagerResetPassword;

  /// No description provided for @createManagerSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get createManagerSelectDate;

  /// No description provided for @createManagerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Manager updated successfully'**
  String get createManagerUpdated;

  /// No description provided for @createManagerUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update manager'**
  String get createManagerUpdateFailed;

  /// No description provided for @currencyAed.
  ///
  /// In en, this message translates to:
  /// **'UAE Dirham'**
  String get currencyAed;

  /// No description provided for @currencyBhd.
  ///
  /// In en, this message translates to:
  /// **'Bahraini Dinar'**
  String get currencyBhd;

  /// No description provided for @currencyEgp.
  ///
  /// In en, this message translates to:
  /// **'Egyptian Pound'**
  String get currencyEgp;

  /// No description provided for @currencyEur.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get currencyEur;

  /// No description provided for @currencyKwd.
  ///
  /// In en, this message translates to:
  /// **'Kuwaiti Dinar'**
  String get currencyKwd;

  /// No description provided for @currencyOmr.
  ///
  /// In en, this message translates to:
  /// **'Omani Rial'**
  String get currencyOmr;

  /// No description provided for @currencyQar.
  ///
  /// In en, this message translates to:
  /// **'Qatari Rial'**
  String get currencyQar;

  /// No description provided for @currencySar.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal'**
  String get currencySar;

  /// No description provided for @currencyUsd.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get currencyUsd;

  /// No description provided for @filesActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get filesActionFailed;

  /// No description provided for @filesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get filesAdd;

  /// No description provided for @filesAddDefinitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Document Definition'**
  String get filesAddDefinitionTitle;

  /// No description provided for @filesConfirmRejection.
  ///
  /// In en, this message translates to:
  /// **'Confirm Rejection'**
  String get filesConfirmRejection;

  /// No description provided for @filesDefinitionAdded.
  ///
  /// In en, this message translates to:
  /// **'Definition added successfully'**
  String get filesDefinitionAdded;

  /// No description provided for @filesDefinitionAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add definition'**
  String get filesDefinitionAddFailed;

  /// No description provided for @filesDefinitionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Definition deleted successfully'**
  String get filesDefinitionDeleted;

  /// No description provided for @filesDefinitionDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete definition'**
  String get filesDefinitionDeleteFailed;

  /// No description provided for @filesDeleteDefinitionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this definition?'**
  String get filesDeleteDefinitionConfirm;

  /// No description provided for @filesDeleteDefinitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Document Definition'**
  String get filesDeleteDefinitionTitle;

  /// No description provided for @filesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get filesDescription;

  /// No description provided for @filesDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Document description...'**
  String get filesDescriptionHint;

  /// No description provided for @filesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get filesEmpty;

  /// No description provided for @filesFileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get filesFileOpenFailed;

  /// No description provided for @filesNameHint.
  ///
  /// In en, this message translates to:
  /// **'Example: founding contract'**
  String get filesNameHint;

  /// No description provided for @filesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Document Name *'**
  String get filesNameLabel;

  /// No description provided for @filesRejectionReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Mention the reason for rejection...'**
  String get filesRejectionReasonHint;

  /// No description provided for @filesRejectionReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get filesRejectionReasonTitle;

  /// No description provided for @filesRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get filesRequired;

  /// No description provided for @filesRequiredDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Required Document Definitions'**
  String get filesRequiredDefinitions;

  /// No description provided for @filesUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Files'**
  String get filesUploaded;

  /// No description provided for @filesUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload file'**
  String get filesUploadFailed;

  /// No description provided for @filesUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'File uploaded successfully'**
  String get filesUploadSuccess;

  /// No description provided for @managerDetailActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get managerDetailActive;

  /// No description provided for @managerDetailActiveSpaces.
  ///
  /// In en, this message translates to:
  /// **'Active Spaces'**
  String get managerDetailActiveSpaces;

  /// No description provided for @managerDetailClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get managerDetailClients;

  /// No description provided for @managerDetailClientsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Clients ({count})'**
  String managerDetailClientsWithCount(Object count);

  /// No description provided for @managerDetailContractsByStatus.
  ///
  /// In en, this message translates to:
  /// **'Contracts by Status'**
  String get managerDetailContractsByStatus;

  /// No description provided for @managerDetailInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get managerDetailInactive;

  /// No description provided for @managerDetailMonthlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Monthly Income'**
  String get managerDetailMonthlyIncome;

  /// No description provided for @managerDetailNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get managerDetailNoData;

  /// No description provided for @managerDetailPendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get managerDetailPendingPayments;

  /// No description provided for @managerDetailStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get managerDetailStats;

  /// No description provided for @managerDetailTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get managerDetailTotalIncome;

  /// No description provided for @meetingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get meetingBack;

  /// No description provided for @meetingCancelConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel \"{title}\"?'**
  String meetingCancelConfirmation(Object title);

  /// No description provided for @meetingCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel meeting'**
  String get meetingCancelFailed;

  /// No description provided for @meetingCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Meeting cancelled successfully'**
  String get meetingCancelSuccess;

  /// No description provided for @meetingCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Meeting'**
  String get meetingCancelTitle;

  /// No description provided for @meetingCompleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Completion'**
  String get meetingCompleteConfirm;

  /// No description provided for @meetingCompleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark \"{title}\" as completed?'**
  String meetingCompleteConfirmation(Object title);

  /// No description provided for @meetingCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete meeting'**
  String get meetingCompleteFailed;

  /// No description provided for @meetingCompleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Meeting completed successfully'**
  String get meetingCompleteSuccess;

  /// No description provided for @meetingCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Meeting'**
  String get meetingCompleteTitle;

  /// No description provided for @meetingContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get meetingContract;

  /// No description provided for @meetingDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get meetingDone;

  /// No description provided for @meetingEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Meeting'**
  String get meetingEditTitle;

  /// No description provided for @meetingKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get meetingKeep;

  /// No description provided for @meetingLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied successfully'**
  String get meetingLinkCopied;

  /// No description provided for @meetingNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Meeting link or additional notes...'**
  String get meetingNotesHint;

  /// No description provided for @meetingPasscode.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get meetingPasscode;

  /// No description provided for @meetingPasscodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Passcode copied successfully'**
  String get meetingPasscodeCopied;

  /// No description provided for @meetingRelatedContract.
  ///
  /// In en, this message translates to:
  /// **'Related Contract'**
  String get meetingRelatedContract;

  /// No description provided for @meetingsPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous Meetings'**
  String get meetingsPrevious;

  /// No description provided for @meetingsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Meetings'**
  String get meetingsUpcoming;

  /// No description provided for @meetingTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: contract discussion'**
  String get meetingTitleHint;

  /// No description provided for @meetingUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update meeting'**
  String get meetingUpdateFailed;

  /// No description provided for @meetingUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Meeting updated successfully'**
  String get meetingUpdateSuccess;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// No description provided for @paymentsAddInstallment.
  ///
  /// In en, this message translates to:
  /// **'Add Installment'**
  String get paymentsAddInstallment;

  /// No description provided for @paymentsAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount *'**
  String get paymentsAmount;

  /// No description provided for @paymentsApproveConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this payment?'**
  String get paymentsApproveConfirmMsg;

  /// No description provided for @paymentsApprovedWorkspaceActive.
  ///
  /// In en, this message translates to:
  /// **'Payment approved — workspace is now active'**
  String get paymentsApprovedWorkspaceActive;

  /// No description provided for @paymentsApprovedWorkspacePending.
  ///
  /// In en, this message translates to:
  /// **'Payment approved — workspace will be activated once procedures are complete'**
  String get paymentsApprovedWorkspacePending;

  /// No description provided for @paymentsApprovePayment.
  ///
  /// In en, this message translates to:
  /// **'Approve Payment'**
  String get paymentsApprovePayment;

  /// No description provided for @paymentsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get paymentsClear;

  /// No description provided for @paymentsClearInstallmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear this installment?'**
  String get paymentsClearInstallmentConfirm;

  /// No description provided for @paymentsClearInstallmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Installment'**
  String get paymentsClearInstallmentTitle;

  /// No description provided for @paymentsContractsValue.
  ///
  /// In en, this message translates to:
  /// **'Contracts Value'**
  String get paymentsContractsValue;

  /// No description provided for @paymentsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get paymentsCurrency;

  /// No description provided for @paymentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get paymentsDescription;

  /// No description provided for @paymentsDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Example: first installment'**
  String get paymentsDescriptionHint;

  /// No description provided for @paymentsDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get paymentsDescriptionOptional;

  /// No description provided for @paymentsDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get paymentsDueDate;

  /// No description provided for @paymentsDueDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String paymentsDueDateFormat(Object date);

  /// No description provided for @paymentsEditInstallmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Installment'**
  String get paymentsEditInstallmentTitle;

  /// No description provided for @paymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments'**
  String get paymentsEmpty;

  /// No description provided for @paymentsFileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get paymentsFileOpenFailed;

  /// No description provided for @paymentsInstallmentCleared.
  ///
  /// In en, this message translates to:
  /// **'Installment cleared successfully'**
  String get paymentsInstallmentCleared;

  /// No description provided for @paymentsInstallmentClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear installment'**
  String get paymentsInstallmentClearFailed;

  /// No description provided for @paymentsInstallmentFormat.
  ///
  /// In en, this message translates to:
  /// **'Installment {ordinal}'**
  String paymentsInstallmentFormat(Object ordinal);

  /// No description provided for @paymentsInstallmentFormatNumbered.
  ///
  /// In en, this message translates to:
  /// **'Installment {number}'**
  String paymentsInstallmentFormatNumbered(Object number);

  /// No description provided for @paymentsInstallmentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Installment updated successfully'**
  String get paymentsInstallmentUpdated;

  /// No description provided for @paymentsInstallmentUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update installment'**
  String get paymentsInstallmentUpdateFailed;

  /// No description provided for @paymentsInvalidData.
  ///
  /// In en, this message translates to:
  /// **'Invalid data'**
  String get paymentsInvalidData;

  /// No description provided for @paymentsMethodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentsMethodBankTransfer;

  /// No description provided for @paymentsMethodCorporateAccount.
  ///
  /// In en, this message translates to:
  /// **'Corporate Account'**
  String get paymentsMethodCorporateAccount;

  /// No description provided for @paymentsMethodInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get paymentsMethodInstapay;

  /// No description provided for @paymentsMethodMobileWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile Wallet'**
  String get paymentsMethodMobileWallet;

  /// No description provided for @paymentsMethodSwift.
  ///
  /// In en, this message translates to:
  /// **'SWIFT Transfer'**
  String get paymentsMethodSwift;

  /// No description provided for @paymentsMethodVodafoneCash.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash'**
  String get paymentsMethodVodafoneCash;

  /// No description provided for @paymentsNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Example: first contract payment'**
  String get paymentsNoteHint;

  /// No description provided for @paymentsNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get paymentsNoteOptional;

  /// No description provided for @paymentsOrdinalEighth.
  ///
  /// In en, this message translates to:
  /// **'Eighth'**
  String get paymentsOrdinalEighth;

  /// No description provided for @paymentsOrdinalFifth.
  ///
  /// In en, this message translates to:
  /// **'Fifth'**
  String get paymentsOrdinalFifth;

  /// No description provided for @paymentsOrdinalFirst.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get paymentsOrdinalFirst;

  /// No description provided for @paymentsOrdinalFourth.
  ///
  /// In en, this message translates to:
  /// **'Fourth'**
  String get paymentsOrdinalFourth;

  /// No description provided for @paymentsOrdinalNinth.
  ///
  /// In en, this message translates to:
  /// **'Ninth'**
  String get paymentsOrdinalNinth;

  /// No description provided for @paymentsOrdinalSecond.
  ///
  /// In en, this message translates to:
  /// **'Second'**
  String get paymentsOrdinalSecond;

  /// No description provided for @paymentsOrdinalSeventh.
  ///
  /// In en, this message translates to:
  /// **'Seventh'**
  String get paymentsOrdinalSeventh;

  /// No description provided for @paymentsOrdinalSixth.
  ///
  /// In en, this message translates to:
  /// **'Sixth'**
  String get paymentsOrdinalSixth;

  /// No description provided for @paymentsOrdinalTenth.
  ///
  /// In en, this message translates to:
  /// **'Tenth'**
  String get paymentsOrdinalTenth;

  /// No description provided for @paymentsOrdinalThird.
  ///
  /// In en, this message translates to:
  /// **'Third'**
  String get paymentsOrdinalThird;

  /// No description provided for @paymentsPaidInFull.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get paymentsPaidInFull;

  /// No description provided for @paymentsRejectConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this payment?'**
  String get paymentsRejectConfirmMsg;

  /// No description provided for @paymentsRejectedMsg.
  ///
  /// In en, this message translates to:
  /// **'Payment rejected'**
  String get paymentsRejectedMsg;

  /// No description provided for @paymentsRejectPayment.
  ///
  /// In en, this message translates to:
  /// **'Reject Payment'**
  String get paymentsRejectPayment;

  /// No description provided for @paymentsRemainingSummary.
  ///
  /// In en, this message translates to:
  /// **'of {total} {currency} — {remaining} remaining'**
  String paymentsRemainingSummary(
      Object currency, Object remaining, Object total);

  /// No description provided for @paymentsRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Send a payment request to the client'**
  String get paymentsRequestHint;

  /// No description provided for @paymentsRequestPayment.
  ///
  /// In en, this message translates to:
  /// **'Request Payment'**
  String get paymentsRequestPayment;

  /// No description provided for @paymentsRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Payment request sent successfully'**
  String get paymentsRequestSent;

  /// No description provided for @paymentsScheduleCount.
  ///
  /// In en, this message translates to:
  /// **'Schedule ({count} installments)'**
  String paymentsScheduleCount(Object count);

  /// No description provided for @paymentsScheduledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payments scheduled successfully'**
  String get paymentsScheduledSuccess;

  /// No description provided for @paymentsScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to schedule payments'**
  String get paymentsScheduleFailed;

  /// No description provided for @paymentsScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule Payments'**
  String get paymentsScheduleTitle;

  /// No description provided for @paymentsSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request'**
  String get paymentsSendFailed;

  /// No description provided for @paymentsSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get paymentsSendRequest;

  /// No description provided for @paymentsStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get paymentsStatusApproved;

  /// No description provided for @paymentsStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get paymentsStatusOverdue;

  /// No description provided for @paymentsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentsStatusPending;

  /// No description provided for @paymentsStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get paymentsStatusScheduled;

  /// No description provided for @paymentsTaxDetails.
  ///
  /// In en, this message translates to:
  /// **'Tax Details'**
  String get paymentsTaxDetails;

  /// No description provided for @paymentsTaxRow.
  ///
  /// In en, this message translates to:
  /// **'Tax {percent}%'**
  String paymentsTaxRow(Object percent);

  /// No description provided for @paymentsTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get paymentsTotalPaid;

  /// No description provided for @paymentsTotalRow.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get paymentsTotalRow;

  /// No description provided for @paymentsViewProof.
  ///
  /// In en, this message translates to:
  /// **'View Payment Proof'**
  String get paymentsViewProof;

  /// No description provided for @profileChangePicture.
  ///
  /// In en, this message translates to:
  /// **'Change Picture'**
  String get profileChangePicture;

  /// No description provided for @reportsAcceptedPaymentsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Accepted Payments'**
  String get reportsAcceptedPaymentsTotal;

  /// No description provided for @reportsAllClients.
  ///
  /// In en, this message translates to:
  /// **'All Clients'**
  String get reportsAllClients;

  /// No description provided for @reportsAllManagers.
  ///
  /// In en, this message translates to:
  /// **'All Managers'**
  String get reportsAllManagers;

  /// No description provided for @reportsAmPerformance.
  ///
  /// In en, this message translates to:
  /// **'Account Managers Performance'**
  String get reportsAmPerformance;

  /// No description provided for @reportsClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get reportsClient;

  /// No description provided for @reportsClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get reportsClients;

  /// No description provided for @reportsContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get reportsContracts;

  /// No description provided for @reportsContractsByStatus.
  ///
  /// In en, this message translates to:
  /// **'Contracts by Status'**
  String get reportsContractsByStatus;

  /// No description provided for @reportsCurrentDistribution.
  ///
  /// In en, this message translates to:
  /// **'Current Distribution'**
  String get reportsCurrentDistribution;

  /// No description provided for @reportsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get reportsCustom;

  /// No description provided for @reportsDeltaActivated.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get reportsDeltaActivated;

  /// No description provided for @reportsDeltaActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get reportsDeltaActive;

  /// No description provided for @reportsDeltaMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportsDeltaMonth;

  /// No description provided for @reportsDeltaNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get reportsDeltaNew;

  /// No description provided for @reportsLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get reportsLast30Days;

  /// No description provided for @reportsLast3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 Months'**
  String get reportsLast3Months;

  /// No description provided for @reportsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load reports'**
  String get reportsLoadFailed;

  /// No description provided for @reportsManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get reportsManager;

  /// No description provided for @reportsManagerFallback.
  ///
  /// In en, this message translates to:
  /// **'Manager {index}'**
  String reportsManagerFallback(Object index);

  /// No description provided for @reportsMonthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get reportsMonthlyRevenue;

  /// No description provided for @reportsNeedsAction.
  ///
  /// In en, this message translates to:
  /// **'Needs Action'**
  String get reportsNeedsAction;

  /// No description provided for @reportsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get reportsPending;

  /// No description provided for @reportsPeriod6m.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get reportsPeriod6m;

  /// No description provided for @reportsPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get reportsPeriodYear;

  /// No description provided for @reportsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reportsReset;

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get reportsThisMonth;

  /// No description provided for @reportsThisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get reportsThisYear;

  /// No description provided for @reportsWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get reportsWorkspaces;

  /// No description provided for @saApprovalsContractApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Contract — {title}'**
  String saApprovalsContractApprovalTitle(Object title);

  /// No description provided for @saApprovalsContractLabel.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get saApprovalsContractLabel;

  /// No description provided for @saApprovalsContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get saApprovalsContracts;

  /// No description provided for @saApprovalsPaymentApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Payment — {title}'**
  String saApprovalsPaymentApprovalTitle(Object title);

  /// No description provided for @saApprovalsPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get saApprovalsPaymentLabel;

  /// No description provided for @saApprovalsPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get saApprovalsPayments;

  /// No description provided for @saClientsAllManagers.
  ///
  /// In en, this message translates to:
  /// **'All Managers'**
  String get saClientsAllManagers;

  /// No description provided for @saClientsDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" permanently? This action cannot be undone.'**
  String saClientsDeleteConfirmation(Object name);

  /// No description provided for @saClientsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete client'**
  String get saClientsDeleteFailed;

  /// No description provided for @saClientsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Client'**
  String get saClientsDeleteTitle;

  /// No description provided for @saClientsManagerLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get saClientsManagerLabel;

  /// No description provided for @saClientsNoClients.
  ///
  /// In en, this message translates to:
  /// **'No clients'**
  String get saClientsNoClients;

  /// No description provided for @saClientsSearchHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, or email...'**
  String get saClientsSearchHintPhone;

  /// No description provided for @saClientsSelectManager.
  ///
  /// In en, this message translates to:
  /// **'Select Manager'**
  String get saClientsSelectManager;

  /// No description provided for @saClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get saClientsTitle;

  /// No description provided for @saTeamManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get saTeamManage;

  /// No description provided for @saTeamNoManagers.
  ///
  /// In en, this message translates to:
  /// **'No managers'**
  String get saTeamNoManagers;

  /// No description provided for @saTeamSearchHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get saTeamSearchHintPhone;

  /// No description provided for @settingsAddYourSignature.
  ///
  /// In en, this message translates to:
  /// **'Add your signature'**
  String get settingsAddYourSignature;

  /// No description provided for @settingsCorporateTax.
  ///
  /// In en, this message translates to:
  /// **'Corporate Tax'**
  String get settingsCorporateTax;

  /// No description provided for @settingsCorporateTaxDesc.
  ///
  /// In en, this message translates to:
  /// **'The tax percentage added to contract values for company clients'**
  String get settingsCorporateTaxDesc;

  /// No description provided for @settingsImageChanged.
  ///
  /// In en, this message translates to:
  /// **'Image changed successfully'**
  String get settingsImageChanged;

  /// No description provided for @settingsImageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change image'**
  String get settingsImageChangeFailed;

  /// No description provided for @settingsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsName;

  /// No description provided for @settingsNewSignature.
  ///
  /// In en, this message translates to:
  /// **'New Signature'**
  String get settingsNewSignature;

  /// No description provided for @settingsOfficialEmail.
  ///
  /// In en, this message translates to:
  /// **'Official Email'**
  String get settingsOfficialEmail;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get settingsSaveChanges;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get settingsSaveFailed;

  /// No description provided for @settingsSaveTax.
  ///
  /// In en, this message translates to:
  /// **'Save Tax Rate'**
  String get settingsSaveTax;

  /// No description provided for @settingsSignatureHint.
  ///
  /// In en, this message translates to:
  /// **'Type your signature'**
  String get settingsSignatureHint;

  /// No description provided for @settingsSignHere.
  ///
  /// In en, this message translates to:
  /// **'Sign here'**
  String get settingsSignHere;

  /// No description provided for @settingsSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get settingsSystemSettings;

  /// No description provided for @settingsTaxInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid percentage (0-100)'**
  String get settingsTaxInvalid;

  /// No description provided for @settingsTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax Rate (%)'**
  String get settingsTaxRate;

  /// No description provided for @settingsTaxSaved.
  ///
  /// In en, this message translates to:
  /// **'Tax rate saved successfully'**
  String get settingsTaxSaved;

  /// No description provided for @settingsTaxSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save tax rate'**
  String get settingsTaxSaveFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsUploadSignatureImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Signature Image'**
  String get settingsUploadSignatureImage;

  /// No description provided for @signatureClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signatureClear;

  /// No description provided for @signatureCurrentSignature.
  ///
  /// In en, this message translates to:
  /// **'Current Signature'**
  String get signatureCurrentSignature;

  /// No description provided for @signatureDeleted.
  ///
  /// In en, this message translates to:
  /// **'Signature deleted successfully'**
  String get signatureDeleted;

  /// No description provided for @signatureDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete signature'**
  String get signatureDeleteFailed;

  /// No description provided for @signatureDrawMode.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get signatureDrawMode;

  /// No description provided for @signatureSaved.
  ///
  /// In en, this message translates to:
  /// **'Signature saved successfully'**
  String get signatureSaved;

  /// No description provided for @signatureSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save signature'**
  String get signatureSaveFailed;

  /// No description provided for @signatureSaveSignature.
  ///
  /// In en, this message translates to:
  /// **'Save Signature'**
  String get signatureSaveSignature;

  /// No description provided for @signatureTextMode.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get signatureTextMode;

  /// No description provided for @signatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signatureTitle;

  /// No description provided for @signatureTypeYourName.
  ///
  /// In en, this message translates to:
  /// **'Type your name'**
  String get signatureTypeYourName;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @workspaceTabApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get workspaceTabApprovals;

  /// No description provided for @workspaceTabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get workspaceTabChat;

  /// No description provided for @workspaceTabContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get workspaceTabContracts;

  /// No description provided for @workspaceTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get workspaceTabFiles;

  /// No description provided for @workspaceTabLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get workspaceTabLog;

  /// No description provided for @workspaceTabMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get workspaceTabMeetings;

  /// No description provided for @workspaceTabPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get workspaceTabPayments;

  /// No description provided for @workspaceTabClientProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get workspaceTabClientProfile;

  /// No description provided for @clientProfileContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get clientProfileContactInfo;

  /// No description provided for @clientProfileCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get clientProfileCompany;

  /// No description provided for @clientProfileContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get clientProfileContactPerson;

  /// No description provided for @clientProfileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get clientProfileEmail;

  /// No description provided for @clientProfilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get clientProfilePhone;

  /// No description provided for @clientProfileCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get clientProfileCountry;

  /// No description provided for @clientProfileIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get clientProfileIndustry;

  /// No description provided for @clientProfileClientType.
  ///
  /// In en, this message translates to:
  /// **'Client Type'**
  String get clientProfileClientType;

  /// No description provided for @clientProfileContracts.
  ///
  /// In en, this message translates to:
  /// **'Contracts'**
  String get clientProfileContracts;

  /// No description provided for @clientProfileDraft.
  ///
  /// In en, this message translates to:
  /// **'draft'**
  String get clientProfileDraft;

  /// No description provided for @clientProfileInProgress.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get clientProfileInProgress;

  /// No description provided for @clientProfileCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get clientProfileCompleted;

  /// No description provided for @clientProfileTotalValue.
  ///
  /// In en, this message translates to:
  /// **'Total Value'**
  String get clientProfileTotalValue;

  /// No description provided for @clientProfileTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get clientProfileTotalPaid;

  /// No description provided for @clientProfilePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get clientProfilePending;

  /// No description provided for @clientProfileMeetings.
  ///
  /// In en, this message translates to:
  /// **'meetings'**
  String get clientProfileMeetings;

  /// No description provided for @clientProfileApprovals.
  ///
  /// In en, this message translates to:
  /// **'approvals'**
  String get clientProfileApprovals;

  /// No description provided for @clientProfileLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get clientProfileLocation;

  /// No description provided for @clientProfileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Location not recorded yet'**
  String get clientProfileNotSet;

  /// No description provided for @clientProfileCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in Location'**
  String get clientProfileCheckIn;

  /// No description provided for @clientProfileCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Location updated successfully'**
  String get clientProfileCheckInSuccess;

  /// No description provided for @clientProfileCheckInFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location. Check permissions.'**
  String get clientProfileCheckInFailed;

  /// No description provided for @clientProfileOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get clientProfileOpenMaps;

  /// No description provided for @clientProfileLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get clientProfileLastUpdated;

  /// No description provided for @clientProfilePickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on Map'**
  String get clientProfilePickOnMap;

  /// No description provided for @locationPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Client Location'**
  String get locationPickerTitle;

  /// No description provided for @locationPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Search for the address or tap the map to place the pin. Tap again to adjust it.'**
  String get locationPickerHint;

  /// No description provided for @locationPickerSearchPh.
  ///
  /// In en, this message translates to:
  /// **'Search for an address...'**
  String get locationPickerSearchPh;

  /// No description provided for @locationPickerSearchBtn.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get locationPickerSearchBtn;

  /// No description provided for @locationPickerSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get locationPickerSearchNoResults;

  /// No description provided for @locationPickerSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed, try again'**
  String get locationPickerSearchFailed;

  /// No description provided for @locationPickerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get locationPickerAddressLabel;

  /// No description provided for @locationPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save Location'**
  String get locationPickerConfirm;

  /// No description provided for @clientProfileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get clientProfileEdit;

  /// No description provided for @clientProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get clientProfileLoadFailed;

  /// No description provided for @amActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get amActivityLog;

  /// No description provided for @amAllMeetings.
  ///
  /// In en, this message translates to:
  /// **'All Meetings'**
  String get amAllMeetings;

  /// No description provided for @amChangeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get amChangeLanguage;

  /// No description provided for @amNavApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get amNavApprovals;

  /// No description provided for @amNavClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get amNavClients;

  /// No description provided for @amNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get amNavHome;

  /// No description provided for @amNavSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get amNavSettings;

  /// No description provided for @amSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get amSettings;

  /// No description provided for @amTotalClientsStat.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get amTotalClientsStat;

  /// No description provided for @amTotalManagers.
  ///
  /// In en, this message translates to:
  /// **'Total Managers'**
  String get amTotalManagers;

  /// No description provided for @approvalLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load approvals'**
  String get approvalLoadFailed;

  /// No description provided for @filesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load files'**
  String get filesLoadFailed;

  /// No description provided for @paymentsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load payments'**
  String get paymentsFailedToLoad;
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
      <String>['ar', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
