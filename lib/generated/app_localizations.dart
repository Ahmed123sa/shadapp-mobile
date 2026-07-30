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
