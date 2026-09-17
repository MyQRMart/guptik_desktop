import 'package:flutter/material.dart';
import 'package:guptik_desktop/screens/home_control/nodedashboardscreen.dart';
import '../../screens/dashboard/all_insights_widget.dart';
import '../../screens/dashboard/dashboard_overview.dart';
import '../../theme/app_chrome.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          backgroundColor: Chrome.sidebar,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          labelType: NavigationRailLabelType.selected,
          minWidth: 48,
          selectedIconTheme: const IconThemeData(color: Chrome.accent, size: 18),
          unselectedIconTheme: const IconThemeData(color: Chrome.fgDim, size: 18),
          selectedLabelTextStyle: const TextStyle(color: Chrome.accent, fontSize: 10),
          unselectedLabelTextStyle: const TextStyle(color: Chrome.fgDim, fontSize: 10),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
            NavigationRailDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: Text('Node')),
          ],
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Chrome.border),
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_selectedIndex == 1) {
      return const NodeDashboardScreen(nodeUrl: 'http://localhost:55000');
    }
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardOverview(),
          SizedBox(height: 16),
          AllInsightsWidget(),
        ],
      ),
    );
  }
}
