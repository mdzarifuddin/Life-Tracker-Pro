import 'package:flutter/material.dart';
import 'theme.dart';

/// Section header with optional colored icon badge + trailing action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.icon, this.color});
  final String text;
  final Widget? trailing;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              IconBadge(icon: icon!, color: color ?? AppColors.primary, size: 30),
              const SizedBox(width: 10),
            ],
            Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            ?trailing,
          ],
        ),
      );
}

/// Rounded square icon with a tinted background.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(icon, color: color, size: size * 0.55),
      );
}

/// Gradient hero header with rounded corners (greeting / title block).
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.child, this.gradient = AppColors.hero});
  final Widget child;
  final Gradient gradient;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D5DF6).withValues(alpha: 0.35),
              blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: child,
      );
}

/// Vibrant gradient stat tile with white text.
class GradientStatCard extends StatelessWidget {
  const GradientStatCard({
    super.key, required this.label, required this.value,
    required this.gradient, required this.icon, this.onTap});
  final String label, value;
  final Gradient gradient;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (gradient is LinearGradient
                    ? (gradient as LinearGradient).colors.first
                    : Colors.black)
                .withValues(alpha: 0.30),
            blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
            const Spacer(),
            if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.8), size: 16),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5)),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card);
  }
}

/// Rounded card with default padding.
class PadCard extends StatelessWidget {
  const PadCard({super.key, required this.child, this.onTap, this.padding, this.tint});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Card(
        color: tint == null
            ? null
            : Color.alphaBlend(tint!.withValues(alpha: 0.20), Theme.of(context).colorScheme.surface),
        shape: tint == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: tint!.withValues(alpha: 0.55))),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
        ),
      );
}

/// Small stat card: label + big value.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.color, this.icon});
  final String label, value;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => PadCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
              Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
            ]),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}

/// Friendly empty state with a CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.cta, this.onCta});
  final IconData icon;
  final String message;
  final String? cta;
  final VoidCallback? onCta;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).hintColor),
              Gap.l,
              Text(message, textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15)),
              if (cta != null) ...[
                Gap.l,
                FilledButton.tonal(onPressed: onCta, child: Text(cta!)),
              ],
            ],
          ),
        ),
      );
}

/// Title + progress bar + percent label.
class ProgressRow extends StatelessWidget {
  const ProgressRow({super.key, required this.label, required this.percent, required this.color});
  final String label;
  final int percent;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      );
}

/// Avatar with a person's initial.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.seed = 0});
  final String name;
  final int seed;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.forIndex(name.isEmpty ? seed : name.codeUnitAt(0));
    return CircleAvatar(
      backgroundColor: c.withValues(alpha: 0.18),
      foregroundColor: c,
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

/// Small pill with an icon + label, used for compact card info.
class InfoChip extends StatelessWidget {
  const InfoChip(this.icon, this.text, {super.key, this.color});
  final IconData icon;
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

String minutesToTime(int m) {
  final h = (m ~/ 60) % 24;
  final mm = m % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${mm.toString().padLeft(2, '0')} $period';
}
