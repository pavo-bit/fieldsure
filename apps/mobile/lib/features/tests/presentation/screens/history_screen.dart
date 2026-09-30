import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/history_controller.dart';
import '../../domain/test_model.dart';
import 'dart:async';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(historyControllerProvider.notifier).fetchTests();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(historyControllerProvider.notifier).updateSearch(query);
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT': return AppColors.secondaryText;
      case 'CAPTURED':
      case 'UPLOADING':
      case 'PROCESSING': return AppColors.primaryOrange;
      case 'COMPLETED': return AppColors.success;
      case 'FAILED': return AppColors.error;
      default: return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Test History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search ID, Case, Sample...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterDropdown(
                        value: state.filterResult,
                        items: const ['All', 'POSITIVE', 'NEGATIVE', 'INCONCLUSIVE', 'PENDING', 'FAILED'],
                        onChanged: (v) => controller.updateFilterResult(v!),
                      ),
                      const SizedBox(width: 8),
                      _FilterDropdown(
                        value: state.filterVerification,
                        items: const ['All', 'Verified', 'Integrity failed', 'Not yet verified'],
                        onChanged: (v) => controller.updateFilterVerification(v!),
                      ),
                      const SizedBox(width: 8),
                      _FilterDropdown(
                        value: state.sort,
                        items: const ['desc', 'asc'],
                        labels: const ['Newest First', 'Oldest First'],
                        onChanged: (v) => controller.updateSort(v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: state.tests.isEmpty && state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.tests.isEmpty && !state.isLoading
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => controller.fetchTests(refresh: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.tests.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.tests.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        final test = state.tests[index];
                        return _buildTestCard(context, test);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, TestModel test) {
    final statusColor = _getStatusColor(test.status);
    final isSynced = test.testNumber != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      color: AppColors.white,
      child: InkWell(
        onTap: () => context.push('/tests/${test.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      test.testNumber ?? 'Local Draft',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      test.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (test.caseId != null)
                Text('Case: ${test.caseId}', style: const TextStyle(fontSize: 13)),
              if (test.result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Result: ${test.result}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: test.result == 'POSITIVE' ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateTime.parse(test.clientCreatedAt).toLocal().toString().split('.')[0],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        size: 14,
                        color: isSynced ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSynced ? 'Synced' : 'Local',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSynced ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'No field tests found.',
            style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final List<String>? labels;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: items.asMap().entries.map((entry) {
            final idx = entry.key;
            final val = entry.value;
            final label = labels != null ? labels![idx] : val;
            return DropdownMenuItem(
              value: val,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
