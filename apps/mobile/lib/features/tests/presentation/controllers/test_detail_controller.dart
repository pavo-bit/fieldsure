import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/test_model.dart';
import '../../data/tests_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

final testDetailProvider = FutureProvider.family<TestModel?, String>((ref, id) async {
  final repo = ref.watch(testsRepositoryProvider);
  final user = ref.watch(authControllerProvider).user;
  
  if (user == null) return null;
  
  // Fetch from local repository first
  final localTests = await repo.getLocalTests(user.id);
  final draft = localTests.where((t) => t.id == id || t.testNumber == id).firstOrNull;
  
  if (draft != null) {
    return draft;
  }
  
  // Fallback to fetch from backend
  return await repo.getTestFromServer(id);
});
