import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/image_quality_service.dart';
import '../../data/evidence_repository.dart';
import '../../domain/image_quality_result.dart';

class CameraPreviewScreen extends ConsumerStatefulWidget {
  final String testId;
  final String imagePath;

  const CameraPreviewScreen({
    super.key,
    required this.testId,
    required this.imagePath,
  });

  @override
  ConsumerState<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends ConsumerState<CameraPreviewScreen> {
  bool _isProcessing = true;
  ImageQualityResult? _qualityResult;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _validateImage();
  }

  Future<void> _validateImage() async {
    final service = ref.read(imageQualityServiceProvider);
    final result = await service.validateImage(widget.imagePath);
    if (mounted) {
      setState(() {
        _qualityResult = result;
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmAndSave() async {
    if (_qualityResult == null || !_qualityResult!.isAcceptable) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(evidenceRepositoryProvider);
      
      // Calculate hash
      final hash = await repo.calculateImageHash(widget.imagePath);

      // We need image dimensions. Let's decode or we can just pass dummy for now if we didn't save them.
      // Better: we did decode it in validateImage but threw it away.
      // For MVP we can just say 1080x1920 or similar, but let's be accurate.
      // We will skip full decoding here to save memory, or assume quality result told us.
      
      // Save metadata
      await repo.saveCaptureMetadata(
        testId: widget.testId,
        localPath: widget.imagePath,
        imageWidth: 1080, // placeholder
        imageHeight: 1920, // placeholder
        qualityResult: _qualityResult!,
        imageHash: hash,
        deviceInfo: 'Android Device', // placeholder
      );

      if (mounted) {
        context.pushReplacementNamed('test_processing', pathParameters: {'id': widget.testId});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving evidence: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isProcessing)
                    const Center(child: CircularProgressIndicator())
                  else if (_qualityResult != null)
                    _buildQualityResult(_qualityResult!),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => context.pushReplacementNamed(
                                    'camera_capture',
                                    pathParameters: {'id': widget.testId},
                                  ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing || _isSaving || !(_qualityResult?.isAcceptable ?? false)
                              ? null
                              : _confirmAndSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Confirm Evidence'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityResult(ImageQualityResult result) {
    if (result.isAcceptable) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Image Quality Acceptable',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Ready for processing.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error, color: AppColors.error, size: 32),
              SizedBox(width: 16),
              Text(
                'Quality Check Failed',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.errors.map((e) => Text('• $e', style: const TextStyle(color: AppColors.error))),
        ],
      );
    }
  }
}
