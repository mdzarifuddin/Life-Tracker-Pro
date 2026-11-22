import 'package:flutter/widgets.dart';

/// Lightweight localization: English is the key, Bangla comes from [_bn].
///
/// Usage: `Text(tr('Save'))`, with placeholders `tr('{n} classes', {'n': 5})`.
/// Strings without a Bangla entry fall back to English, so new screens can be
/// translated later just by wrapping their strings in [tr] and adding entries
/// to [_bn].
enum AppLang {
  en('English', 'ইংরেজি'),
  bn('বাংলা', 'Bangla');

  const AppLang(this.nativeName, this.otherName);

  /// Name in the language itself, and in the other language.
  final String nativeName, otherName;

  static AppLang parse(Object? v) =>
      AppLang.values.firstWhere((l) => l.name == v, orElse: () => AppLang.en);
}

AppLang _lang = AppLang.en;

/// The language currently used by [tr].
AppLang get currentLang => _lang;

/// Switches the language and rebuilds every mounted widget so all [tr] calls
/// (including routes deeper in the navigation stack) pick up the change.
void applyLang(AppLang l, {bool force = false}) {
  if (_lang == l && !force) return;
  _lang = l;
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) _rebuildAll(root);
}

/// Sets the language without touching the widget tree (startup / tests).
void setLangSilently(AppLang l) => _lang = l;

void _rebuildAll(Element e) {
  e.markNeedsBuild();
  e.visitChildren(_rebuildAll);
}

/// Translates [english] into the current language, then fills `{name}`
/// placeholders from [args].
String tr(String english, [Map<String, Object?>? args]) =>
    trIn(_lang, english, args);

/// Same as [tr] for an explicit language.
String trIn(AppLang lang, String english, [Map<String, Object?>? args]) {
  var s = lang == AppLang.bn ? (_bn[english] ?? english) : english;
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  }
  return s;
}

/// Whether [english] has a Bangla entry (for tests / tooling).
bool hasBangla(String english) => _bn.containsKey(english);

const _bn = <String, String>{
  // ---- common buttons ----
  'Save': 'সেভ',
  'Cancel': 'বাতিল',
  'Add': 'যোগ করুন',
  'Delete': 'মুছুন',
  'Edit': 'এডিট',
  'Done': 'সম্পন্ন',
  'OK': 'ঠিক আছে',
  'Close': 'বন্ধ',
  'Set': 'সেট করুন',
  'Reset': 'রিসেট',
  'Apply': 'প্রয়োগ করুন',
  'Search': 'খুঁজুন',
  'Export': 'এক্সপোর্ট',
  'Import': 'ইমপোর্ট',
  'UNDO': 'আগের মতো',

  // ---- bottom navigation ----
  'Home': 'হোম',
  'Tuition': 'টিউশন',
  'Schedule': 'সময়সূচি',
  'Finance': 'হিসাব',
  'More': 'আরও',

  // ---- settings ----
  'Settings': 'সেটিংস',
  'Appearance': 'চেহারা',
  'Theme': 'থিম',
  'Dark': 'ডার্ক',
  'Light': 'লাইট',
  'System': 'সিস্টেম',
  'Dark (default)': 'ডার্ক (ডিফল্ট)',
  'Follow system': 'সিস্টেম অনুযায়ী',
  'Background': 'ব্যাকগ্রাউন্ড',
  'Dark mode backgrounds': 'ডার্ক মোডের ব্যাকগ্রাউন্ড',
  'Light mode backgrounds': 'লাইট মোডের ব্যাকগ্রাউন্ড',
  'Custom': 'নিজের মতো',
  'Create': 'তৈরি করুন',
  'Custom background': 'নিজের ব্যাকগ্রাউন্ড',
  'Edit custom background': 'নিজের ব্যাকগ্রাউন্ড এডিট',
  'Colours': 'রং',
  'Colour {n}': 'রং {n}',
  'Add colour': 'রং যোগ করুন',
  'Remove colour': 'রং সরান',
  'Direction': 'দিক',
  'Diagonal': 'কোনাকুনি',
  'Diagonal (reverse)': 'উল্টো কোনাকুনি',
  'Top to bottom': 'উপর থেকে নিচে',
  'Left to right': 'বাম থেকে ডানে',
  'Radial': 'বৃত্তাকার',
  'Hue': 'রঙের ধরন',
  'Saturation': 'গাঢ়তা',
  'Brightness': 'উজ্জ্বলতা',
  'Use this background': 'এই ব্যাকগ্রাউন্ড ব্যবহার করুন',
  'Preview': 'প্রিভিউ',
  'This is how text will look.': 'লেখা দেখতে এমন হবে।',
  'Text may be hard to read on this background.':
      'এই ব্যাকগ্রাউন্ডে লেখা পড়তে কষ্ট হতে পারে।',
  'Text size': 'লেখার আকার',
  'Small': 'ছোট',
  'Normal': 'স্বাভাবিক',
  'Large': 'বড়',
  'Extra large': 'অনেক বড়',
  'Today: 5 classes · ৳ 27,000 collected': 'আজ: ৫টি ক্লাস · ৳ ২৭,০০০ আদায়',
  'Applies to the whole app, on top of the phone\'s font size.':
      'পুরো অ্যাপে প্রযোজ্য, ফোনের ফন্ট সাইজের সাথে মিলিয়ে।',
  'Language': 'ভাষা',
  'App language': 'অ্যাপের ভাষা',
  'Some screens are still in English.': 'কিছু স্ক্রিন এখনো ইংরেজিতে।',
  'Security': 'নিরাপত্তা',
  'Change Vault PIN': 'ভল্ট পিন বদলান',
  'Set Vault PIN': 'ভল্ট পিন সেট করুন',
  'Locks the Finance tab': 'হিসাব ট্যাব লক করে',
  'Remove PIN': 'পিন সরান',
  'Vault PIN removed': 'ভল্ট পিন সরানো হয়েছে',
  'Vault PIN': 'ভল্ট পিন',
  'Enter 4–6 digit PIN': '৪–৬ সংখ্যার পিন দিন',
  'Vault PIN set': 'ভল্ট পিন সেট হয়েছে',
  'Backup': 'ব্যাকআপ',
  'Tuition history (JSON)': 'টিউশনের ইতিহাস (JSON)',
  'All classes and payments per student: view, export, import':
      'প্রতি ছাত্রের সব ক্লাস ও পেমেন্ট: দেখুন, এক্সপোর্ট, ইমপোর্ট',
  'Save backup to device': 'ডিভাইসে ব্যাকআপ সেভ করুন',
  'All data as one JSON file, saved where you choose':
      'সব ডেটা একটি JSON ফাইলে, আপনার পছন্দের জায়গায়',
  'Save cancelled': 'সেভ বাতিল হয়েছে',
  'Backup saved': 'ব্যাকআপ সেভ হয়েছে',
  "Couldn't save backup: {e}": 'ব্যাকআপ সেভ করা যায়নি: {e}',
  'Share backup': 'ব্যাকআপ শেয়ার করুন',
  'Send the JSON file via WhatsApp, Google Drive, email…':
      'WhatsApp, Google Drive, ইমেইলে JSON ফাইল পাঠান…',
  "Couldn't share backup: {e}": 'ব্যাকআপ শেয়ার করা যায়নি: {e}',
  'Import backup': 'ব্যাকআপ ইমপোর্ট করুন',
  'Restore all data from a backup file (replaces current data)':
      'ব্যাকআপ ফাইল থেকে সব ডেটা ফেরত আনুন (বর্তমান ডেটা বদলে যাবে)',
  'Restore a backup?': 'ব্যাকআপ রিস্টোর করবেন?',
  'This replaces everything in the app with the backup. A safety copy of your current data is kept automatically.':
      'এতে অ্যাপের সবকিছু ব্যাকআপ দিয়ে বদলে যাবে। বর্তমান ডেটার একটি নিরাপত্তা কপি নিজে থেকেই রাখা হবে।',
  'Choose file': 'ফাইল বাছুন',
  'Data imported. Restart the app to apply everything.':
      'ডেটা ইমপোর্ট হয়েছে। সব ঠিকমতো দেখতে অ্যাপটি আবার চালু করুন।',
  'Import cancelled': 'ইমপোর্ট বাতিল হয়েছে',
  "Couldn't import: {e}": 'ইমপোর্ট করা যায়নি: {e}',
  'General': 'সাধারণ',
  'Update available': 'আপডেট আছে',
  'Check for updates': 'আপডেট দেখুন',
  'Download the latest version from GitHub': 'GitHub থেকে সর্বশেষ ভার্সন নামান',
  'Version —': 'ভার্সন —',
  'Version {v}': 'ভার্সন {v}',

  // background preset names
  'Aurora': 'অরোরা',
  'Midnight': 'মাঝরাত',
  'Sunset': 'সূর্যাস্ত',
  'Ocean': 'সমুদ্র',
  'Forest': 'বন',
  'Rose': 'গোলাপ',
  'Graphite': 'গ্রাফাইট',
  'Pastel': 'প্যাস্টেল',
  'Mint': 'পুদিনা',
  'Sky': 'আকাশ',
  'Peach': 'পীচ',
  'Lavender': 'ল্যাভেন্ডার',
  'Cloud': 'মেঘ',

  // ---- more ----
  'My Tasks': 'আমার কাজ',
  'Personal scheduled to-dos': 'নিজের নির্ধারিত কাজের তালিকা',
  'Govt Job Prep': 'সরকারি চাকরির প্রস্তুতি',
  'Daily MCQ targets': 'প্রতিদিনের MCQ লক্ষ্য',
  'MSc Thesis': 'MSc থিসিস',
  'Stage-wise progress': 'ধাপে ধাপে অগ্রগতি',
  'Family Lists': 'পরিবারের তালিকা',
  'Bazar & future needs': 'বাজার ও ভবিষ্যৎ প্রয়োজন',
  'App look, language, backup, PIN': 'চেহারা, ভাষা, ব্যাকআপ, পিন',

  // ---- tuition list ----
  'Pay': 'পেমেন্ট',
  'History': 'ইতিহাস',
  'Exams': 'পরীক্ষা',
  'Search students…': 'ছাত্র খুঁজুন…',
  'Current ({n})': 'বর্তমান ({n})',
  'All students ({n})': 'সব ছাত্র ({n})',
  'All batches': 'সব ব্যাচ',
  'Open batch · attendance, payments, members':
      'ব্যাচ খুলুন · উপস্থিতি, পেমেন্ট, সদস্য',
  'No match.': 'কিছু মেলেনি।',
  'No students yet.\nTap Add to create a student or a batch.':
      'এখনো কোনো ছাত্র নেই।\nছাত্র বা ব্যাচ তৈরি করতে "যোগ করুন" চাপুন।',
  'No current students.\nOpen "All students" to see previous ones.':
      'বর্তমানে কোনো ছাত্র নেই।\nআগের ছাত্রদের দেখতে "সব ছাত্র" খুলুন।',
  'Previous': 'আগের',
  'Previous · left {d}': 'আগের · ছেড়েছে {d}',
  '{n} class': '{n}টি ক্লাস',
  '{n} classes': '{n}টি ক্লাস',
  'Next: {t}': 'পরের ক্লাস: {t}',
  'No class set': 'ক্লাস ঠিক করা নেই',
  'Last: {t}': 'শেষ: {t}',
  'Add Student': 'ছাত্র যোগ করুন',
  'One student': 'একজন ছাত্র',
  'Add Batch': 'ব্যাচ যোগ করুন',
  'A group: shared fee, days & time, many students':
      'একটি গ্রুপ: একই ফি, দিন ও সময়, অনেক ছাত্র',

  // ---- payments ----
  'Payments': 'পেমেন্ট',
  'Paid': 'পরিশোধিত',
  'Partial': 'আংশিক',
  'Due': 'বাকি',
  'Fee for {m}': '{m} মাসের ফি',
  'Custom due for this month only': 'শুধু এই মাসের জন্য আলাদা বাকি',
  'Use automatic': 'স্বয়ংক্রিয় ব্যবহার করুন',
  'Enter an amount': 'টাকার পরিমাণ দিন',
  '{a} marked paid': '{a} পরিশোধিত হিসেবে চিহ্নিত',
  'Due (custom)': 'বাকি (আলাদা)',
  'Remaining': 'অবশিষ্ট',
  'Previous due {c} carried forward + this month {d}':
      'আগের বাকি {c} যোগ হয়েছে + এই মাস {d}',
  'Advance {c} from earlier months − adjusted against {d}':
      'আগের মাসের অগ্রিম {c} − {d} থেকে বাদ দেওয়া হয়েছে',
  'No payment yet.': 'এখনো কোনো পেমেন্ট নেই।',
  'Pay for some classes': 'কিছু ক্লাসের টাকা দিন',
  '{r} per class · {n} taught this month': 'প্রতি ক্লাস {r} · এই মাসে {n}টি পড়ানো',
  'Amount (৳)': 'পরিমাণ (৳)',
  'Pay {n} classes': '{n}টি ক্লাসের টাকা',
  'Pay some': 'কিছু টাকা',
  'Pay all ({a})': 'সব পরিশোধ ({a})',
  'Fully paid': 'সম্পূর্ণ পরিশোধিত',
  'Collected': 'আদায় হয়েছে',
  'No students for this month.': 'এই মাসে কোনো ছাত্র নেই।',
  '{n} · custom fee {d}': '{n} · আলাদা ফি {d}',
  'Includes previous due {c}': 'আগের বাকি {c} সহ',
  'Paid {a}': 'পরিশোধিত {a}',
  'Due {a}': 'বাকি {a}',

  // ---- history ----
  'Tuition history': 'টিউশনের ইতিহাস',
  'Could not read that file': 'ফাইলটি পড়া যায়নি',
  'History saved': 'ইতিহাস সেভ হয়েছে',
  'Share as JSON': 'JSON হিসেবে শেয়ার করুন',
  'Save JSON to device': 'ডিভাইসে JSON সেভ করুন',
  'Import JSON': 'JSON ইমপোর্ট করুন',
  'Students': 'ছাত্র',
  'Classes': 'ক্লাস',
  'Paid classes': 'পরিশোধিত ক্লাস',
  'Received': 'পাওয়া গেছে',
  'By student': 'ছাত্র অনুযায়ী',
  'Timeline': 'সময়রেখা',
  'Search student': 'ছাত্র খুঁজুন',
  'No students yet.': 'এখনো কোনো ছাত্র নেই।',
  '{n} classes · {p} paid · {a} received': '{n}টি ক্লাস · {p}টি পরিশোধিত · {a} পাওয়া গেছে',
  'No classes yet.': 'এখনো কোনো ক্লাস নেই।',
  '{m} · {n} classes': '{m} · {n}টি ক্লাস',
  'Taught': 'পড়ানো হয়েছে',
  '{d} · for {m}': '{d} · {m} মাসের জন্য',
  'Nothing here yet.': 'এখানে এখনো কিছু নেই।',
  '{s} · class': '{s} · ক্লাস',
  '{s} · payment {a}': '{s} · পেমেন্ট {a}',
  'Showing the latest 400 of {n}. Use "By student" or export the JSON for everything.':
      '{n}টির মধ্যে সর্বশেষ ৪০০টি দেখানো হচ্ছে। সব দেখতে "ছাত্র অনুযায়ী" বা JSON এক্সপোর্ট করুন।',
};
