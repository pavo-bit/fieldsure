import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldsure_mobile/core/localization/app_localizations.dart';

/// Screen for selecting or creating a case to associate with drug tests
class CaseSelectionScreen extends ConsumerStatefulWidget {
  const CaseSelectionScreen({super.key});

  @override
  ConsumerState<CaseSelectionScreen> createState() => _CaseSelectionScreenState();
}

class _CaseSelectionScreenState extends ConsumerState<CaseSelectionScreen> {
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectCase),
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, l10n),
          Expanded(
            child: _buildCaseList(theme, l10n),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewCase(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newCase),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: l10n.searchCases,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildCaseList(ThemeData theme, AppLocalizations l10n) {
    // Mock data - replace with actual database query
    final cases = [
      _MockCase(
        id: 'CASE-2026-001',
        description: 'Traffic Stop - Route 66',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        testCount: 3,
        status: 'ACTIVE',
      ),
      _MockCase(
        id: 'CASE-2026-002',
        description: 'Search Warrant Execution',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        testCount: 7,
        status: 'ACTIVE',
      ),
      _MockCase(
        id: 'CASE-2025-459',
        description: 'Field Interview',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        testCount: 1,
        status: 'CLOSED',
      ),
    ];

    final filtered = cases.where((c) =>
        c.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        c.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noCasesFound,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final caseItem = filtered[index];
        return _buildCaseCard(caseItem, theme, l10n);
      },
    );
  }

  Widget _buildCaseCard(_MockCase caseItem, ThemeData theme, AppLocalizations l10n) {
    final isActive = caseItem.status == 'ACTIVE';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectCase(caseItem.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caseItem.id,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      caseItem.status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                caseItem.description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.science,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${caseItem.testCount} ${l10n.tests}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatRelativeTime(caseItem.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _selectCase(String caseId) {
    Navigator.of(context).pop(caseId);
  }

  void _createNewCase(BuildContext context) {
    // TODO: Navigate to case creation screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.newCase),
        content: Text(AppLocalizations.of(context)!.featureComingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
        ],
      ),
    );
  }
}

// Mock data class - replace with actual Case model
class _MockCase {
  final String id;
  final String description;
  final DateTime createdAt;
  final int testCount;
  final String status;

  _MockCase({
    required this.id,
    required this.description,
    required this.createdAt,
    required this.testCount,
    required this.status,
  });
}
