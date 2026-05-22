import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int m) => setState(() => _month = DateTime(_month.year, _month.month + m));

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final monthK = monthKey(_month);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.studentsL, repo.paymentsL]),
          builder: (context, _) {
            final students = repo.studentsForMonth(_month);
            var collected = 0.0, pending = 0.0;
            for (final s in students) {
              final p = repo.paymentFor(s.id, monthK);
              if (p?.status == 'paid') {
                collected += p!.amount;
              } else {
                pending += repo.dueForMonth(s, _month);
              }
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  Text(monthLabel(_month), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ]),
                Gap.m,
                Row(children: [
                  Expanded(child: GradientStatCard(label: 'Collected', value: taka(collected), gradient: AppColors.incomeGrad, icon: Icons.check_circle)),
                  Gap.m,
                  Expanded(child: GradientStatCard(label: 'Pending', value: taka(pending), gradient: AppColors.warningGrad, icon: Icons.schedule)),
                ]),
                Gap.l,
                if (students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(icon: Icons.attach_money, message: 'No students for this month.'),
                  )
                else
                  ...students.map((s) {
                    final p = repo.paymentFor(s.id, monthK);
                    final paid = p?.status == 'paid';
                    final classes = repo.classesInMonth(s.id, _month);
                    final due = paid ? p!.amount : repo.dueForMonth(s, _month);
                    final perClass = s.classesPerMonth > 0 ? (s.monthlyFee / s.classesPerMonth) : s.monthlyFee;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PadCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          InitialAvatar(s.name),
                          Gap.m,
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('$classes ${classes == 1 ? 'class' : 'classes'} × ${taka(perClass)} = ${taka(due)}',
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                          ])),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: paid ? AppColors.income : null,
                              minimumSize: const Size(92, 40),
                            ),
                            onPressed: () async {
                              if (paid) {
                                await repo.markFeeUnpaid(p!);
                              } else {
                                await repo.markFeePaid(s, _month);
                              }
                            },
                            child: Text(paid ? 'Paid' : 'Mark Paid'),
                          ),
                        ]),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
