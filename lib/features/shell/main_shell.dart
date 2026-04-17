import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Главный шелл с нижней навигацией. AI — центральный, выделенный.
class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  static final List<_NavItem> _items = <_NavItem>[
    _NavItem(icon: Icons.calendar_today_rounded, label: 'Календарь', route: AppRoutes.calendar),
    _NavItem(icon: Icons.checklist_rounded, label: 'Задачи', route: AppRoutes.tasks),
    _NavItem(
      icon: Icons.auto_awesome_rounded,
      label: 'AI',
      route: AppRoutes.aiAssistant,
      isAccent: true,
    ),
    _NavItem(icon: Icons.timer_rounded, label: 'Pomodoro', route: AppRoutes.pomodoro),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Статистика', route: AppRoutes.statistics),
  ];

  int _currentIndex(String location) {
    for (int i = 0; i < _items.length; i++) {
      if (location.startsWith(_items[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final int currentIndex = _currentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List<Widget>.generate(_items.length, (int i) {
                final _NavItem item = _items[i];
                final bool selected = i == currentIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.go(item.route);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: item.isAccent ? 20 : 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: item.isAccent
                                  ? AppColors.accentGlow
                                  : null,
                              color: !item.isAccent && selected
                                  ? AppColors.primaryDark
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: item.isAccent
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              item.icon,
                              size: item.isAccent ? 28 : 26,
                              color: item.isAccent
                                  ? Colors.black
                                  : (selected ? AppColors.accent : AppColors.textDisabled),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? AppColors.accent : AppColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isAccent = false,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool isAccent;
}
