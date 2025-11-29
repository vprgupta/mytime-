import 'package:flutter/material.dart';
import '../models/bypass_attempt.dart';
import '../services/bypass_prevention_service.dart';
import '../../../core/widgets/app_card.dart';


class BypassAttemptsScreen extends StatefulWidget {
  const BypassAttemptsScreen({super.key});

  @override
  State<BypassAttemptsScreen> createState() => _BypassAttemptsScreenState();
}

class _BypassAttemptsScreenState extends State<BypassAttemptsScreen> {
  final BypassPreventionService _bypassService = BypassPreventionService();
  List<BypassAttempt> _allAttempts = [];
  List<BypassAttempt> _todayAttempts = [];
  Map<String, int> _attemptsByType = {};

  @override
  void initState() {
    super.initState();
    _loadBypassAttempts();
  }

  void _loadBypassAttempts() {
    setState(() {
      _allAttempts = _bypassService.getAllBypassAttempts();
      _todayAttempts = _bypassService.getTodayBypassAttempts();
      _attemptsByType = _bypassService.getBypassAttemptsByType();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bypass Attempts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBypassAttempts,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsSection(),
          Expanded(child: _buildAttemptsList()),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Today', _todayAttempts.length, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Total', _allAttempts.length, Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTypeBreakdown(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return AppCard(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBreakdown() {
    if (_attemptsByType.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attempt Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._attemptsByType.entries.map((entry) => _buildTypeRow(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildTypeRow(String type, int count) {
    final icon = _getTypeIcon(type);
    final color = _getTypeColor(type);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatAttemptType(type),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsList() {
    if (_allAttempts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No bypass attempts detected',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your app blocking is secure!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Sort attempts by timestamp (newest first)
    final sortedAttempts = List<BypassAttempt>.from(_allAttempts)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedAttempts.length,
      itemBuilder: (context, index) {
        final attempt = sortedAttempts[index];
        return _buildAttemptCard(attempt);
      },
    );
  }

  Widget _buildAttemptCard(BypassAttempt attempt) {
    final icon = _getTypeIcon(attempt.attemptType);
    final color = _getTypeColor(attempt.attemptType);
    final isToday = _isToday(attempt.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          _formatAttemptType(attempt.attemptType),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
  '${attempt.timestamp.day}/${attempt.timestamp.month}/${attempt.timestamp.year} ${attempt.timestamp.hour}:${attempt.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
            if (attempt.additionalInfo != null) ...[
              const SizedBox(height: 2),
              Text(
                attempt.additionalInfo!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getSeverityColor(attempt.severityLevel).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                attempt.severityLevel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getSeverityColor(attempt.severityLevel),
                ),
              ),
            ),
            if (isToday) ...[
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'uninstall':
        return Icons.delete_forever;
      case 'force_stop':
        return Icons.stop_circle;
      case 'settings_access':
        return Icons.settings;
      case 'time_change':
        return Icons.access_time;
      case 'safe_mode':
        return Icons.security;
      case 'root_access':
        return Icons.admin_panel_settings;
      case 'developer_options':
        return Icons.developer_mode;
      case 'emergency_bypass':
        return Icons.emergency;
      default:
        return Icons.warning;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'uninstall':
      case 'root_access':
        return Colors.red;
      case 'force_stop':
      case 'safe_mode':
        return Colors.orange;
      case 'settings_access':
      case 'time_change':
      case 'developer_options':
        return Colors.amber;
      case 'emergency_bypass':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'major':
        return Colors.orange;
      case 'minor':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatAttemptType(String type) {
    switch (type) {
      case 'uninstall':
        return 'Uninstall Attempt';
      case 'force_stop':
        return 'Force Stop Attempt';
      case 'settings_access':
        return 'Settings Access';
      case 'time_change':
        return 'System Time Change';
      case 'safe_mode':
        return 'Safe Mode Detection';
      case 'root_access':
        return 'Root Access Detected';
      case 'developer_options':
        return 'Developer Options Enabled';
      case 'emergency_bypass':
        return 'Emergency Bypass';
      default:
        return type.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
           dateTime.month == now.month &&
           dateTime.day == now.day;
  }
}