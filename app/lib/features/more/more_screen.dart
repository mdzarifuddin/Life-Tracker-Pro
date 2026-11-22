import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(Icons.checklist, 'My Tasks', 'Personal scheduled to-dos', AppColors.primaryGrad, '/more/tasks'),
      _MoreItem(Icons.account_balance, 'Govt Job Prep', 'Daily MCQ targets', AppColors.savingsGrad, '/more/jobprep'),
      _MoreItem(Icons.school, 'MSc Thesis', 'Stage-wise progress', AppColors.primaryGrad, '/more/thesis'),
      _MoreItem(Icons.shopping_cart, 'Family Lists', 'Bazar & future needs', AppColors.accentGrad, '/more/lists'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
