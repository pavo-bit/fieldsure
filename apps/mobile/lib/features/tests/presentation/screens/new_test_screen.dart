import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/new_test_controller.dart';

class NewTestScreen extends ConsumerStatefulWidget {
  const NewTestScreen({super.key});

  @override
  ConsumerState<NewTestScreen> createState() => _NewTestScreenState();
}

class _NewTestScreenState extends ConsumerState<NewTestScreen> {
  final _caseIdController = TextEditingController();
  final _sampleIdController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(newTestControllerProvider);
    _caseIdController.text = state.caseId;
    _sampleIdController.text = state.sampleId;
    _notesController.text = state.notes;
  }

  @override
  void dispose() {
    _caseIdController.dispose();
    _sampleIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onContinue() {
    ref.read(newTestControllerProvider.notifier).updateCaseId(_caseIdController.text);
    ref.read(newTestControllerProvider.notifier).updateSampleId(_sampleIdController.text);
    ref.read(newTestControllerProvider.notifier).updateNotes(_notesController.text);
    context.push('/tests/new/kit');
  }

  @override
  Widget build(BuildContext context) {
    // Watch to rebuild when state changes (e.g., error or loading)
    ref.watch(newTestControllerProvider);
    // Local validation check for enabling the button real-time
    final isValid = _caseIdController.text.trim().isNotEmpty && _sampleIdController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('New Field Test'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(newTestControllerProvider.notifier).clear();
            context.go('/dashboard');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter Sample Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Provide the required identifiers for this field test.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _caseIdController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Case ID *',
                  hintText: 'e.g., 2026-INC-0123',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _sampleIdController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Sample ID *',
                  hintText: 'e.g., ITEM-A',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any additional field observations',
                ),
                maxLines: 3,
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: isValid ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
