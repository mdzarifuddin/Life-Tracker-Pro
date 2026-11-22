import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(Icons.checklist, tr('My Tasks'), tr('Personal scheduled to-dos'), AppColors.primaryGrad, '/more/tasks'),
      _MoreItem(Icons.account_balance, tr('Govt Job Prep'), tr('Daily MCQ targets'), AppColors.savingsGrad, '/more/jobprep'),
      _MoreItem(Icons.school, tr('MSc Thesis'), tr('Stage-wise progress'), AppColors.primaryGrad, '/more/thesis'),
      _MoreItem(Icons.shopping_cart, tr('Family Lists'), tr('Bazar & future needs'), AppColors.accentGrad, '/more/lists'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('More'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.02,
          children: items.map((it) => Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.go(it.route),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            gradient: it.gradient,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(it.icon, color: Colors.white, size: 26),
                        ),
                        const Spacer(),
                        Text(it.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(it.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.hero, borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.settings, color: Colors.white),
                ),
                title: Text(tr('Settings'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                subtitle: Text(tr('App look, language, backup, PIN')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/more/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String title, subtitle, route;
  final Gradient gradient;
  _MoreItem(this.icon, this.title, this.subtitle, this.gradient, this.route);
}
