import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldsure_mobile/core/localization/app_localizations.dart';

/// Screen for supervisors to review drug test results
/// Implements two-person integrity workflow
class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewQueue),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.pendingReview),
            Tab(text: l10n.reviewed),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(theme, l10n),
          _buildReviewedList(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildPendingList(ThemeData theme, AppLocalizations l10n) {
    // Mock data - replace with actual database query
    final pendingItems = [
      _MockReviewItem(
        testId: 'TEST-2026-001',
        caseId: 'CASE-2026-001',
        collectorName: 'Officer John Doe',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        result: 'POSITIVE',
        confidence: 0.92,
      ),
      _MockReviewItem(
        testId: 'TEST-2026-002',
        caseId: 'CASE-2026-001',
        collectorName: 'Officer John Doe',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        result: 'NEGATIVE',
        confidence: 0.94,
      ),
    ];

    if (pendingItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noItemsToReview,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: pendingItems.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = pendingItems[index];
        return _buildReviewCard(item, theme, l10n);
      },
    );
  }

  Widget _buildReviewedList(ThemeData theme, AppLocalizations l10n) {
    // Mock data
    final reviewedItems = <_MockReviewItem>[];

    if (reviewedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviewed items yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: reviewedItems.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = reviewedItems[index];
        return _buildReviewCard(item, theme, l10n, isReviewed: true);
      },
    );
  }

  Widget _buildReviewCard(
    _MockReviewItem item,
    ThemeData theme,
    AppLocalizations l10n, {
    bool isReviewed = false,
  }) {
    final isPositive = item.result == 'POSITIVE';
    final resultColor = isPositive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: resultColor.withValues(alpha: 0.1),
              child: Icon(
                isPositive ? Icons.warning : Icons.check_circle,
                color: resultColor,
              ),
            ),
            title: Text(
              item.testId,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('${l10n.caseLabel}: ${item.caseId}'),
            trailing: isReviewed
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.person,
                  item.collectorName,
                  theme,
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  Icons.access_time,
                  _formatDateTime(item.createdAt),
                  theme,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Result',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.result,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: resultColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.confidence,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(item.confidence * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isReviewed) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewTest(item, false),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reviewTest(item, true),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.approve),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _reviewTest(_MockReviewItem item, bool approved) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Show notes dialog
    final notes = await _showNotesDialog(approved);
    if (notes == null) return; // User cancelled

    // TODO: Submit review to backend
    // await ref.read(reviewServiceProvider).submitReview(
    //   testId: item.testId,
    //   approved: approved,
    //   notes: notes,
    // );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reviewSubmitted),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      
      // Refresh list
      setState(() {});
    }
  }

  Future<String?> _showNotesDialog(bool approved) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    String notes = '';

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? l10n.approve : l10n.reject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.reviewNotes,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: l10n.addNotes,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => notes = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(notes),
            child: Text(l10n.submitReview),
          ),
        ],
      ),
    );
  }
}

// Mock data class
class _MockReviewItem {
  final String testId;
  final String caseId;
  final String collectorName;
  final DateTime createdAt;
  final String result;
  final double confidence;

  _MockReviewItem({
    required this.testId,
    required this.caseId,
    required this.collectorName,
    required this.createdAt,
    required this.result,
    required this.confidence,
  });
}
