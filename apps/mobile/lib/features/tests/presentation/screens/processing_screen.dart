import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tests_repository.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final String testId;

  const ProcessingScreen({super.key, required this.testId});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final repo = ref.read(testsRepositoryProvider);
      
      // Enqueue the processing request and update local status
      await repo.processTest(widget.testId);

      if (mounted) {
        context.pushReplacementNamed('test_detail', pathParameters: {'id': widget.testId});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to queue processing.\n$e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Processing Evidence'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Analyzing test image...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Applying computer vision pipeline and color calibration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: AppColors.error, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Processing Failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _startProcessing,
                  child: const Text('Retry Processing'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    context.pushReplacementNamed('test_detail', pathParameters: {'id': widget.testId});
                  },
                  child: const Text('Skip to Result (Offline)'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
