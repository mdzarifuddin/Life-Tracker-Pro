import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models.dart';

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// Stable color for a category (shared by donut + icons).
Color catColor(String name) =>
    AppColors.forIndex(name.isEmpty ? 0 : name.codeUnitAt(0) + name.length);

/// Built-in Monefy-style line icons a category can use (key → icon).
const kCategoryIcons = <String, IconData>{
  'restaurant': Icons.restaurant_outlined,
  'fastfood': Icons.fastfood_outlined,
  'coffee': Icons.local_cafe_outlined,
  'basket': Icons.shopping_basket_outlined,
  'cart': Icons.shopping_cart_outlined,
  'bus': Icons.directions_bus_outlined,
  'rickshaw': Icons.pedal_bike_outlined,
  'train': Icons.train_outlined,
  'car': Icons.directions_car_outlined,
  'taxi': Icons.local_taxi_outlined,
  'bike': Icons.two_wheeler_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'flight': Icons.flight_outlined,
  'house': Icons.house_outlined,
  'electricity': Icons.bolt_outlined,
  'gas': Icons.local_fire_department_outlined,
  'water': Icons.water_drop_outlined,
  'wifi': Icons.wifi_outlined,
  'phone': Icons.phone_outlined,
  'bill': Icons.receipt_long_outlined,
  'book': Icons.menu_book_outlined,
  'pen': Icons.edit_outlined,
  'school': Icons.school_outlined,
  'thesis': Icons.science_outlined,
  'teach': Icons.cast_for_education_outlined,
  'family': Icons.family_restroom_outlined,
  'child': Icons.child_care_outlined,
  'medical': Icons.medical_services_outlined,
  'medicine': Icons.medication_outlined,
  'soap': Icons.soap_outlined,
  'salon': Icons.content_cut_outlined,
  'clothes': Icons.checkroom_outlined,
  'bag': Icons.shopping_bag_outlined,
  'movie': Icons.movie_outlined,
  'music': Icons.music_note_outlined,
  'game': Icons.sports_esports_outlined,
  'sports': Icons.sports_soccer_outlined,
  'gym': Icons.fitness_center_outlined,
  'drink': Icons.local_bar_outlined,
  'gift': Icons.card_giftcard_outlined,
  'charity': Icons.volunteer_activism_outlined,
  'pets': Icons.pets_outlined,
  'devices': Icons.devices_outlined,
  'laptop': Icons.laptop_mac_outlined,
  'repair': Icons.build_outlined,
  'loan': Icons.credit_card_outlined,
  'govt': Icons.account_balance_outlined,
  'code': Icons.code_outlined,
  'subscription': Icons.subscriptions_outlined,
  'invest': Icons.trending_up_outlined,
  'savings': Icons.savings_outlined,
  'salary': Icons.payments_outlined,
  'bonus': Icons.redeem_outlined,
  'award': Icons.workspace_premium_outlined,
  'store': Icons.storefront_outlined,
  'sell': Icons.sell_outlined,
  'refund': Icons.currency_exchange_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'mosque': Icons.mosque_outlined,
  'celebration': Icons.celebration_outlined,
  'baby': Icons.baby_changing_station_outlined,
  'garden': Icons.local_florist_outlined,
  'tools': Icons.handyman_outlined,
  'other': Icons.category_outlined,
};

/// Fallback icon keys for categories saved before icons existed.
const _nameToIcon = <String, String>{
  'food': 'restaurant', 'transport': 'bus', 'tuition travel': 'train',
  'internet': 'wifi', 'mobile recharge': 'phone', 'mobile': 'phone',
  'books': 'book', 'family': 'family', 'medical': 'medical', 'shopping': 'bag',
  'entertainment': 'movie', 'govt job': 'govt', 'thesis': 'thesis',
  'software': 'code', 'subscriptions': 'subscription', 'investment': 'invest',
  'grocery': 'basket', 'tuition': 'teach', 'freelancing': 'laptop',
  'scholarship': 'award', 'gift': 'gift', 'salary': 'salary', 'business': 'store',
};

/// Category name (lower-case) → chosen icon key; refreshed from the repo.
final _iconByName = <String, String>{};

void _syncCategoryIcons(Repo repo) {
  _iconByName.clear();
  for (final c in [...repo.categoriesOf('expense'), ...repo.categoriesOf('income')]) {
    if (c.icon.isNotEmpty) _iconByName[c.name.toLowerCase()] = c.icon;
  }
}

/// Monefy-style line icon for a category name.
IconData catIcon(String name) {
  final n = name.toLowerCase();
  final key = _iconByName[n] ?? _nameToIcon[n];
  return kCategoryIcons[key] ?? Icons.sell_outlined;
}

/// Monefy palette (mint light / charcoal dark).
class _Mf {
  _Mf(BuildContext context) : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  static const green = Color(0xFF6CC28A);
  static const red = Color(0xFFEF7F7F);
  Color get bg => dark ? const Color(0xFF3B3B3B) : const Color(0xFFF1FAF3);
  Color get bar => dark ? const Color(0xFF5B5B5B) : const Color(0xFF7CC896);
  Color get text => dark ? Colors.white : const Color(0xFF4A6655);
  Color get muted => dark ? Colors.white60 : const Color(0xFF6FAE85);
  Color get line => dark ? Colors.white24 : const Color(0xFFA9D9B9);
  Color get keyFill => dark ? const Color(0xFF454545) : const Color(0xFFF8FDF9);
  Color get selFill => dark ? const Color(0xFF4F6B58) : const Color(0xFFD7F0DF);
}

const kAccounts = <String, String>{
  'cash': 'Cash', 'bkash': 'bKash', 'nagad': 'Nagad', 'bank': 'Bank',
};

IconData accountIcon(String a) {
  switch (a) {
    case 'bkash': case 'nagad': return Icons.phone_android_outlined;
    case 'bank': return Icons.account_balance_outlined;
    default: return Icons.payments_outlined;
  }
}

/// "৳ 3,982" with small ".00" like Monefy.
Widget moneyText(double v, {required Color color, double size = 16, FontWeight weight = FontWeight.w500}) {
  final f = NumberFormat('#,##0.00', 'en_US').format(v.abs());
  final dot = f.lastIndexOf('.');
  return Text.rich(
    TextSpan(children: [
      TextSpan(text: '${v < 0 ? '-' : ''}৳${f.substring(0, dot)}'),
      TextSpan(text: f.substring(dot), style: TextStyle(fontSize: size * 0.62)),
    ]),
    maxLines: 1,
    style: TextStyle(color: color, fontSize: size, fontWeight: weight),
  );
}

enum FinPeriod { day, week, month, year, all, interval }

class _Range {
  final DateTime start, end;
  const _Range(this.start, this.end);
  bool has(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
}

_Range _rangeFor(FinPeriod p, DateTime a, DateTimeRange? interval) {
  switch (p) {
    case FinPeriod.day:
      return _Range(DateTime(a.year, a.month, a.day), DateTime(a.year, a.month, a.day, 23, 59, 59));
    case FinPeriod.week:
      final mon = a.subtract(Duration(days: a.weekday - 1));
      final s = DateTime(mon.year, mon.month, mon.day);
      return _Range(s, s.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)));
    case FinPeriod.month:
      return _Range(DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 0, 23, 59, 59));
    case FinPeriod.year:
      return _Range(DateTime(a.year, 1, 1), DateTime(a.year, 12, 31, 23, 59, 59));
    case FinPeriod.all:
      return _Range(DateTime(2000), DateTime(2200));
    case FinPeriod.interval:
      if (interval == null) return _Range(DateTime(2000), DateTime(2200));
      final s = interval.start, e = interval.end;
      return _Range(DateTime(s.year, s.month, s.day), DateTime(e.year, e.month, e.day, 23, 59, 59));
  }
}

String _periodLabel(FinPeriod p, DateTime a, DateTimeRange? interval) {
  switch (p) {
    case FinPeriod.day: return DateFormat('EEEE, d MMMM').format(a);
    case FinPeriod.week:
      final r = _rangeFor(p, a, null);
      return '${shortDate(r.start)} – ${shortDate(r.end)}';
    case FinPeriod.month:
      return a.year == DateTime.now().year ? DateFormat('MMMM').format(a) : monthLabel(a);
    case FinPeriod.year: return '${a.year}';
    case FinPeriod.all: return 'All time';
    case FinPeriod.interval:
      return interval == null ? 'Interval' : '${fullDate(interval.start)} – ${fullDate(interval.end)}';
  }
}

DateTime _shift(FinPeriod p, DateTime a, int dir) {
  switch (p) {
    case FinPeriod.day: return a.add(Duration(days: dir));
    case FinPeriod.week: return a.add(Duration(days: 7 * dir));
    case FinPeriod.month: return DateTime(a.year, a.month + dir, 1);
    case FinPeriod.year: return DateTime(a.year + dir, 1, 1);
    case FinPeriod.all: case FinPeriod.interval: return a;
  }
}

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final unlocked = ref.watch(vaultProvider);
    if (repo.pinHash != null && !unlocked) return const _VaultGate();
    return const _FinanceHome();
  }
}

class _VaultGate extends ConsumerStatefulWidget {
  const _VaultGate();
  @override
  ConsumerState<_VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends ConsumerState<_VaultGate> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  void _try() {
    if (hashPin(_pin.text) == ref.read(repoProvider).pinHash) {
      ref.read(vaultProvider.notifier).unlock();
    } else {
      setState(() => _error = 'Wrong PIN');
    }
  }

  Future<void> _bio() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      if (!supported) return;
      final ok = await auth.authenticate(localizedReason: 'Unlock Finance Vault');
      if (ok && mounted) ref.read(vaultProvider.notifier).unlock();
    } catch (_) {/* fall back to PIN */}
  }

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    return Scaffold(
      backgroundColor: mf.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 64, color: _Mf.green),
              Gap.l,
              Text('Finance Vault', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: mf.text)),
              Text('Enter your PIN to continue', style: TextStyle(color: mf.muted)),
              Gap.xl,
              TextField(
                controller: _pin, obscureText: true, obscuringCharacter: '*',
                keyboardType: TextInputType.number, autocorrect: false, enableSuggestions: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 10),
                decoration: InputDecoration(errorText: _error, hintText: '* * * *'),
                onSubmitted: (_) => _try(),
              ),
              Gap.l,
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _Mf.green),
                  onPressed: _try, child: const Text('Unlock')),
              Gap.m,
              TextButton.icon(
                onPressed: _bio,
                style: TextButton.styleFrom(foregroundColor: mf.muted),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use fingerprint'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FinanceHome extends ConsumerStatefulWidget {
  const _FinanceHome();
  @override
  ConsumerState<_FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends ConsumerState<_FinanceHome> {
  final _scaffold = GlobalKey<ScaffoldState>();
  FinPeriod _period = FinPeriod.month;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _interval;
  String? _account; // null = all accounts
  bool _listMode = false;

  Future<void> _add(String type, {String? category}) async {
    final res = await context.push<Txn>('/txn-form',
        extra: {'type': type, 'category': ?category});
    if (res == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${res.category}: ${taka(res.amount)} added'),
        persist: false,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'CANCEL', textColor: _Mf.green,
          onPressed: () => ref.read(repoProvider).deleteTxn(res.id)),
      ));
  }

  Future<void> _pickInterval() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime(2100),
      initialDateRange: _interval ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (r != null) setState(() { _interval = r; _period = FinPeriod.interval; });
  }

  Future<void> _chooseDate() async {
    final d = await showDatePicker(context: context, initialDate: _anchor,
        firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() { _anchor = d; _period = FinPeriod.day; });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final mf = _Mf(context);
    return Scaffold(
      key: _scaffold,
      backgroundColor: mf.bg,
      drawer: _drawer(mf),
      appBar: AppBar(
        backgroundColor: mf.bar,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () => _scaffold.currentState?.openDrawer()),
        titleSpacing: 4,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Finance', style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
          Text(_account == null ? 'All accounts' : kAccounts[_account]!,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: _listMode ? 'Chart' : 'Records',
            icon: Icon(_listMode ? Icons.donut_large : Icons.swap_vert),
            onPressed: () => setState(() => _listMode = !_listMode)),
          if (repo.pinHash != null)
            IconButton(
              tooltip: 'Lock',
              icon: const Icon(Icons.lock_outline),
              onPressed: () => ref.read(vaultProvider.notifier).lock()),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([repo.txnsL, repo.categoriesL]),
        builder: (context, _) {
          _syncCategoryIcons(repo);
          final range = _rangeFor(_period, _anchor, _interval);
          final txns = repo.txnList
              .where((t) => range.has(t.date) && (_account == null || t.account == _account))
              .toList();
          final income = txns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
          final expense = txns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
          final balance = income - expense;
          final canShift = _period != FinPeriod.all && _period != FinPeriod.interval;

          return Column(children: [
            // period
            SizedBox(
              height: 36,
              child: Row(children: [
                if (canShift)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: mf.muted, icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _anchor = _shift(_period, _anchor, -1))),
                Expanded(child: GestureDetector(
                  onTap: () => _scaffold.currentState?.openDrawer(),
                  child: Text(_periodLabel(_period, _anchor, _interval),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: mf.muted, fontSize: 16)),
                )),
                if (canShift)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: mf.muted, icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _anchor = _shift(_period, _anchor, 1))),
              ]),
            ),
            if (_listMode) ...[
              _BalanceBar(balance: balance, onTap: () => setState(() => _listMode = false)),
              Expanded(child: _GroupedList(txns: txns)),
            ] else ...[
              Expanded(child: _ChartView(
                txns: txns,
                categories: repo.categoriesOf('expense'),
                income: income,
                expense: expense,
                onCategory: (c) => _add('expense', category: c),
                onCenter: () => setState(() => _listMode = true),
              )),
              _BalanceBar(balance: balance, onTap: () => setState(() => _listMode = true)),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 10, 40, 14),
              child: Row(children: [
                _CircleButton(icon: Icons.remove, color: _Mf.red, onTap: () => _add('expense')),
                const Spacer(),
                _CircleButton(icon: Icons.add, color: _Mf.green, onTap: () => _add('income')),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _drawer(_Mf mf) {
    Widget box({required Widget child, bool selected = false, required VoidCallback onTap}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: selected ? mf.selFill : Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6), side: BorderSide(color: mf.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: SizedBox(height: 50, child: Center(child: child)),
            ),
          ),
        );

    Widget periodBtn(FinPeriod p, String label, {VoidCallback? onTap}) => box(
          selected: _period == p,
          onTap: onTap ?? () { setState(() => _period = p); Navigator.pop(context); },
          child: Text(label, style: TextStyle(color: mf.muted, fontSize: 16)),
        );

    return Drawer(
      backgroundColor: mf.bg,
      width: 240,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          // account selector
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6), border: Border.all(color: mf.line)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _account,
                isExpanded: true,
                dropdownColor: mf.bg,
                iconEnabledColor: mf.muted,
                itemHeight: 56,
                items: [
                  DropdownMenuItem<String?>(value: null, child: _accountTile(mf, null)),
                  ...kAccounts.keys.map((a) =>
                      DropdownMenuItem<String?>(value: a, child: _accountTile(mf, a))),
                ],
                onChanged: (v) { setState(() => _account = v); Navigator.pop(context); },
              ),
            ),
          ),
          periodBtn(FinPeriod.day, 'Day'),
          periodBtn(FinPeriod.week, 'Week'),
          periodBtn(FinPeriod.month, 'Month'),
          periodBtn(FinPeriod.year, 'Year'),
          periodBtn(FinPeriod.all, 'All'),
          periodBtn(FinPeriod.interval, 'Interval',
              onTap: () { Navigator.pop(context); _pickInterval(); }),
          box(
            onTap: () { Navigator.pop(context); _chooseDate(); },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_available_outlined, color: mf.muted, size: 20),
              const SizedBox(width: 8),
              Text('Choose date', style: TextStyle(color: mf.muted, fontSize: 16)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _accountTile(_Mf mf, String? a) => Row(children: [
        Icon(a == null ? Icons.sell_outlined : accountIcon(a), color: const Color(0xFFE0B03C), size: 30),
        const SizedBox(width: 10),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a == null ? 'All accounts' : kAccounts[a]!, style: TextStyle(color: mf.muted, fontSize: 16)),
          Text('BDT', style: TextStyle(color: mf.text, fontSize: 11)),
        ]),
      ]);
}

/// Donut in the middle, category icons with % arranged around it.
class _ChartView extends StatelessWidget {
  const _ChartView({
    required this.txns, required this.categories, required this.income,
    required this.expense, required this.onCategory, required this.onCenter});
  final List<Txn> txns;
  final List<Category> categories;
  final double income, expense;
  final ValueChanged<String> onCategory;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    final byCat = <String, double>{};
    for (final t in txns.where((t) => t.type == 'expense')) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    // spent categories first (largest first), then the rest in stored order
    final spent = byCat.keys.toList()..sort((a, b) => byCat[b]!.compareTo(byCat[a]!));
    final names = <String>[...spent, ...categories.map((c) => c.name).where((n) => !byCat.containsKey(n))];

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final sw = w / 4;
      final sh = (h / 5).clamp(56.0, 96.0);
      final midH = h - 2 * sh;

      // 14 slots clockwise: top 4, right 3, bottom 4, left 3
      final slots = <Offset>[
        for (var i = 0; i < 4; i++) Offset(sw * i + sw / 2, sh / 2),
        for (var i = 0; i < 3; i++) Offset(w - sw / 2, sh + midH * (i + 0.5) / 3),
        for (var i = 3; i >= 0; i--) Offset(sw * i + sw / 2, h - sh / 2),
        for (var i = 2; i >= 0; i--) Offset(sw / 2, sh + midH * (i + 0.5) / 3),
      ];
      final shown = names.take(slots.length).toList();

      final d = ((w - 2 * sw) < midH ? (w - 2 * sw) : midH) + 16;
      final r = d / 2;
      final ring = r * 0.30;

      return Stack(children: [
        Positioned(
          left: (w - d) / 2, top: (h - d) / 2, width: d, height: d,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: r - ring,
              pieTouchData: PieTouchData(touchCallback: (e, res) {
                if (e is FlTapUpEvent) onCenter();
              }),
              sections: spent.isEmpty
                  ? [PieChartSectionData(value: 1, color: mf.line, radius: ring, showTitle: false)]
                  : spent.map((n) => PieChartSectionData(
                        value: byCat[n]!, color: catColor(n), radius: ring, showTitle: false)).toList(),
            )),
            GestureDetector(
              onTap: onCenter,
              child: SizedBox(
                width: (r - ring) * 1.5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    moneyText(income, color: _Mf.green, size: 18),
                    moneyText(expense, color: _Mf.red, size: 18),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: slots[i].dx - sw / 2, top: slots[i].dy - sh / 2, width: sw, height: sh,
            child: _CatSlot(
              name: shown[i],
              percent: expense > 0 && byCat[shown[i]] != null ? byCat[shown[i]]! / expense * 100 : null,
              textColor: mf.text,
              onTap: () => onCategory(shown[i]),
            ),
          ),
      ]);
    });
  }
}

class _CatSlot extends StatelessWidget {
  const _CatSlot({required this.name, required this.percent, required this.textColor, required this.onTap});
  final String name;
  final double? percent;
  final Color textColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: name,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(catIcon(name), color: catColor(name), size: 38),
            SizedBox(
              height: 18,
              child: percent == null
                  ? null
                  : Text('${percent!.round()}%', style: TextStyle(color: textColor, fontSize: 13)),
            ),
          ]),
        ),
      );
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.balance, required this.onTap});
  final double balance;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    Widget lines() => Column(mainAxisSize: MainAxisSize.min, children: List.generate(3, (_) =>
        Container(width: 36, height: 1.4, margin: const EdgeInsets.symmetric(vertical: 3.5), color: mf.muted)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(children: [
        lines(),
        const SizedBox(width: 20),
        Expanded(
          child: Material(
            color: balance >= 0 ? _Mf.green : _Mf.red,
            elevation: 2,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 50,
                child: Center(child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Balance ', style: TextStyle(color: Colors.white, fontSize: 19)),
                    moneyText(balance, color: Colors.white, size: 19, weight: FontWeight.w400),
                  ]),
                )),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        lines(),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: _Mf(context).bg,
        shape: CircleBorder(side: BorderSide(color: color, width: 5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 92, height: 92, child: Icon(icon, color: color, size: 40)),
        ),
      );
}

/// Records grouped by category; tap a group to expand its entries.
class _GroupedList extends ConsumerStatefulWidget {
  const _GroupedList({required this.txns});
  final List<Txn> txns;
  @override
  ConsumerState<_GroupedList> createState() => _GroupedListState();
}

class _GroupedListState extends ConsumerState<_GroupedList> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    final groups = <String, List<Txn>>{};
    for (final t in widget.txns) {
      groups.putIfAbsent('${t.type}|${t.category}', () => []).add(t);
    }
    double total(List<Txn> l) => l.fold(0.0, (s, t) => s + t.amount);
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final ia = a.startsWith('income'), ib = b.startsWith('income');
        if (ia != ib) return ia ? -1 : 1;
        return total(groups[b]!).compareTo(total(groups[a]!));
      });

    if (keys.isEmpty) {
      return Center(child: Text('No records in this period', style: TextStyle(color: mf.muted)));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(8, 4, 16, 8), children: [
      for (final k in keys) ...[
        _groupRow(mf, k, groups[k]!, total(groups[k]!)),
        if (_open.contains(k))
          for (final t in groups[k]!) _entryRow(mf, t),
      ],
    ]);
  }

  Widget _groupRow(_Mf mf, String key, List<Txn> list, double sum) {
    final t = list.first;
    final income = t.type == 'income';
    final open = _open.contains(key);
    final c = catColor(t.category);
    return InkWell(
      onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
      child: SizedBox(
        height: 64,
        child: Row(children: [
          SizedBox(width: 40, child: Icon(open ? Icons.expand_less : Icons.expand_more, color: mf.muted)),
          Icon(catIcon(t.category), color: c, size: 36),
          const SizedBox(width: 14),
          Flexible(child: Text(t.category, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: income ? mf.text : c, fontSize: 17))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: _Mf.green, borderRadius: BorderRadius.circular(8)),
            child: Text('${list.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const Spacer(),
          moneyText(sum, color: income ? _Mf.green : _Mf.red, size: 17),
        ]),
      ),
    );
  }

  Widget _entryRow(_Mf mf, Txn t) => Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: _Mf.red,
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) => ref.read(repoProvider).deleteTxn(t.id),
        child: InkWell(
          onTap: () => context.push('/txn-form', extra: t),
          child: SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(width: 90),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: t.type == 'income' ? _Mf.green : _Mf.red, shape: BoxShape.circle)),
              const SizedBox(width: 26),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                moneyText(t.amount, color: mf.text, size: 16, weight: FontWeight.w400),
                if (t.note.isNotEmpty)
                  Text(t.note, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mf.muted, fontSize: 12)),
              ])),
              Text(DateFormat('d MMM').format(t.date), style: TextStyle(color: mf.text, fontSize: 16)),
            ]),
          ),
        ),
      );
}

/// Monefy-style entry: amount display + calculator keypad + category grid.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, required this.type, this.existing, this.category});
  final String type;
  final Txn? existing;
  final String? category;
  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  static const _ops = '+-×÷';
  late String _type = widget.type;
  String? _category;
  String _expr = '';
  final _note = TextEditingController();
  String _account = 'cash';
  DateTime _date = DateTime.now();

  bool get _editing => widget.existing != null;
  bool get _isIncome => _type == 'income';
  Color get _color => _isIncome ? _Mf.green : _Mf.red;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    final e = widget.existing;
    if (e != null) {
      _category = e.category;
      _expr = e.amount == 0 ? '' : _fmt(e.amount);
      _account = e.account;
      _note.text = e.note;
      _date = e.date;
    }
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  /// Evaluates "12+3×4" with × ÷ before + −.
  static double? _eval(String e) {
    while (e.isNotEmpty && _ops.contains(e[e.length - 1])) {
      e = e.substring(0, e.length - 1);
    }
    if (e.isEmpty) return null;
    final nums = <double>[];
    final ops = <String>[];
    var buf = '';
    for (final ch in e.split('')) {
      if (_ops.contains(ch)) {
        nums.add(double.tryParse(buf) ?? 0);
        ops.add(ch);
        buf = '';
      } else {
        buf += ch;
      }
    }
    nums.add(double.tryParse(buf) ?? 0);
    final n2 = [nums.first];
    final o2 = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final b = nums[i + 1];
      if (ops[i] == '×') {
        n2.last = n2.last * b;
      } else if (ops[i] == '÷') {
        n2.last = b == 0 ? n2.last : n2.last / b;
      } else {
        o2.add(ops[i]);
        n2.add(b);
      }
    }
    var r = n2.first;
    for (var i = 0; i < o2.length; i++) {
      r = o2[i] == '+' ? r + n2[i + 1] : r - n2[i + 1];
    }
    return r;
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '=') {
        final v = _eval(_expr);
        _expr = v == null ? '' : _fmt(v);
        return;
      }
      final last = _expr.isEmpty ? '' : _expr[_expr.length - 1];
      final cur = _expr.split(RegExp(r'[+\-×÷]')).last;
      if (_ops.contains(k)) {
        if (_expr.isEmpty) return;
        if (_ops.contains(last)) _expr = _expr.substring(0, _expr.length - 1);
        _expr += k;
        return;
      }
      if (_expr.length >= 18) return;
      if (k == '.') {
        if (cur.contains('.')) return;
        _expr += cur.isEmpty ? '0.' : '.';
        return;
      }
      if (cur.contains('.') && cur.split('.').last.length >= 2) return;
      if (cur == '0') _expr = _expr.substring(0, _expr.length - 1);
      _expr += k;
    });
  }

  void _backspace() {
    if (_expr.isEmpty) return;
    setState(() => _expr = _expr.substring(0, _expr.length - 1));
  }

  Future<String?> _addCategory() async {
    final repo = ref.read(repoProvider);
    final taken = repo.categoriesOf(_type).map((c) => c.name.toLowerCase()).toSet();
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NewCategoryDialog(taken: taken),
    );
    if (res == null) return null;
    final (name, icon) = res;
    await repo.saveCategory(Category(id: newId(), name: name, type: _type, icon: icon));
    _syncCategoryIcons(repo);
    return name;
  }

  Future<String?> _pickCategory() {
    final mf = _Mf(context);
    final cats = ref.read(repoProvider).categoriesOf(_type);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: mf.bg,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: cats.map((c) {
                  final col = catColor(c.name);
                  return Material(
                    color: _category == c.name ? mf.selFill : mf.keyFill,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6), side: BorderSide(color: mf.line)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => Navigator.pop(ctx, c.name),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(catIcon(c.name), color: col, size: 36),
                        const SizedBox(height: 6),
                        Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: col, fontSize: 12.5)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _wideKey(mf, 'Add category', color: _Mf.green, onTap: () async {
                final n = await _addCategory();
                if (n != null && ctx.mounted) Navigator.pop(ctx, n);
              }),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _chooseAndSave() async {
    final c = await _pickCategory();
    if (c == null) return;
    setState(() => _category = c);
    await _save();
  }

  Future<void> _save() async {
    final amt = _eval(_expr) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (_category == null) return _chooseAndSave();
    final txn = Txn(
      id: widget.existing?.id ?? newId(), type: _type, category: _category!,
      amount: amt, date: _date, account: _account, note: _note.text.trim(),
      sourceRef: widget.existing?.sourceRef ?? '',
    );
    await ref.read(repoProvider).saveTxn(txn);
    if (mounted) context.pop(_editing ? null : txn);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Mf.red),
              onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(repoProvider).deleteTxn(widget.existing!.id);
    if (mounted) context.pop();
  }

  void _switchType() {
    setState(() {
      _type = _isIncome ? 'expense' : 'income';
      final names = ref.read(repoProvider).categoriesOf(_type).map((c) => c.name);
      if (!names.contains(_category)) _category = null;
    });
  }

  Future<void> _pickAccount() async {
    final mf = _Mf(context);
    final a = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: mf.bg,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: kAccounts.entries.map((e) => ListTile(
          leading: Icon(accountIcon(e.key), color: _Mf.green),
          title: Text(e.value, style: TextStyle(color: mf.text)),
          trailing: e.key == _account ? const Icon(Icons.check, color: _Mf.green) : null,
          onTap: () => Navigator.pop(ctx, e.key),
        )).toList()),
      ),
    );
    if (a != null) setState(() => _account = a);
  }

  Widget _wideKey(_Mf mf, String label, {required VoidCallback onTap, Color? color}) => Material(
        color: mf.keyFill,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: mf.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: SizedBox(
            height: 58, width: double.infinity,
            child: Center(child: Text(label, style: TextStyle(
                color: color ?? mf.text, fontSize: 17, letterSpacing: 0.6))),
          ),
        ),
      );

  Widget _keypad(_Mf mf) {
    final keyH = MediaQuery.of(context).size.height < 720 ? 50.0 : 62.0;
    const rows = [
      ['1', '2', '3', '+'],
      ['4', '5', '6', '-'],
      ['7', '8', '9', '×'],
      ['.', '0', '=', '÷'],
    ];
    return Column(children: rows.map((r) => Row(children: r.map((k) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: mf.keyFill,
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: mf.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _key(k),
            child: SizedBox(height: keyH, child: Center(child: Text(k,
                style: TextStyle(color: mf.text, fontSize: 30, fontWeight: FontWeight.w300)))),
          ),
        ),
      ),
    )).toList())).toList());
  }

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    _syncCategoryIcons(ref.read(repoProvider));
    final title = _editing
        ? (_isIncome ? 'Edit income' : 'Edit expense')
        : (_isIncome ? 'New income' : 'New expense');
    return Scaffold(
      backgroundColor: mf.bg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: mf.bar,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(
            tooltip: _isIncome ? 'Switch to expense' : 'Switch to income',
            icon: const Icon(Icons.repeat),
            onPressed: _switchType),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 12),
          // date · time
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 18, color: mf.text),
                  const SizedBox(width: 4),
                  Text(DateFormat('EEEE, d MMMM').format(_date), style: TextStyle(color: mf.text, fontSize: 17)),
                ]),
              ),
            ),
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
                if (t != null) setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('· ${TimeOfDay.fromDateTime(_date).format(context)}',
                    style: TextStyle(color: mf.muted, fontSize: 15)),
              ),
            ),
          ]),
          const Spacer(),
          // amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: _color,
              elevation: 2,
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 84,
                child: Row(children: [
                  InkWell(
                    onTap: _pickAccount,
                    child: SizedBox(
                      width: 68,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(accountIcon(_account), color: Colors.white, size: 30),
                        Text(kAccounts[_account]!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ]),
                    ),
                  ),
                  Container(width: 1.5, height: 64, color: Colors.white70),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_expr.isEmpty ? '0' : _expr,
                          style: const TextStyle(color: Colors.white, fontSize: 46)),
                    ),
                  )),
                  GestureDetector(
                    onLongPress: () => setState(() => _expr = ''),
                    child: IconButton(
                      onPressed: _backspace,
                      icon: const Icon(Icons.backspace, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(width: 6),
                ]),
              ),
            ),
          ),
          // note
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _note,
              style: TextStyle(color: mf.text),
              decoration: InputDecoration(
                filled: false,
                hintText: 'Add note',
                hintStyle: TextStyle(color: mf.muted.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.edit_outlined, color: mf.muted),
                border: UnderlineInputBorder(borderSide: BorderSide(color: mf.line)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: mf.line)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: mf.muted)),
              ),
            ),
          ),
          const Spacer(flex: 2),
          if (_category != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionChip(
                backgroundColor: mf.keyFill,
                side: BorderSide(color: mf.line),
                avatar: Icon(catIcon(_category!), color: catColor(_category!), size: 20),
                label: Text(_category!, style: TextStyle(color: catColor(_category!))),
                onPressed: () async {
                  final c = await _pickCategory();
                  if (c != null) setState(() => _category = c);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(children: [
              _keypad(mf),
              Padding(
                padding: const EdgeInsets.all(2),
                child: _wideKey(mf,
                    _category == null ? 'CHOOSE CATEGORY' : (_editing ? 'UPDATE' : 'ADD'),
                    onTap: _save),
              ),
            ]),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}

/// "New category" dialog: name + icon from the built-in set.
/// Pops with (name, iconKey).
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({required this.taken});
  final Set<String> taken; // existing names (lower-case)
  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();
  String _icon = 'other';
  String? _error;

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) return setState(() => _error = 'Enter a name');
    if (widget.taken.contains(n.toLowerCase())) {
      return setState(() => _error = 'This category already exists');
    }
    Navigator.pop(context, (n, _icon));
  }

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    final color = catColor(_name.text.trim());
    return AlertDialog(
      backgroundColor: mf.bg,
      title: Text('New category', style: TextStyle(color: mf.text)),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(kCategoryIcons[_icon], color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: 'Category name', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            )),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Choose icon', style: TextStyle(color: mf.muted, fontSize: 13)),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: kCategoryIcons.entries.map((e) {
                final sel = e.key == _icon;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _icon = e.key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: sel ? mf.selFill : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? _Mf.green : Colors.transparent, width: 1.5),
                    ),
                    child: Icon(e.value, color: sel ? color : mf.text, size: 24),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _Mf.green, minimumSize: const Size(88, 44)),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
