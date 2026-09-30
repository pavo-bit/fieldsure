import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/test_kit_model.dart';
import '../../data/tests_repository.dart';
import '../../../../core/models/auth_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/test_model.dart';

class NewTestState {
  final String caseId;
  final String sampleId;
  final String notes;
  final TestKitModel? selectedKit;
  final bool isLoading;
  final String? error;

  const NewTestState({
    this.caseId = '',
    this.sampleId = '',
    this.notes = '',
    this.selectedKit,
    this.isLoading = false,
    this.error,
  });

  NewTestState copyWith({
    String? caseId,
    String? sampleId,
    String? notes,
    TestKitModel? selectedKit,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NewTestState(
      caseId: caseId ?? this.caseId,
      sampleId: sampleId ?? this.sampleId,
      notes: notes ?? this.notes,
      selectedKit: selectedKit ?? this.selectedKit,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isValid => caseId.trim().isNotEmpty && sampleId.trim().isNotEmpty;
}

class NewTestNotifier extends StateNotifier<NewTestState> {
  final TestsRepository _testsRepository;
  final AuthState _authState;

  NewTestNotifier(this._testsRepository, this._authState) : super(const NewTestState());

  void updateCaseId(String id) => state = state.copyWith(caseId: id);
  void updateSampleId(String id) => state = state.copyWith(sampleId: id);
  void updateNotes(String notes) => state = state.copyWith(notes: notes);
  void selectKit(TestKitModel kit) => state = state.copyWith(selectedKit: kit);

  void clear() => state = const NewTestState();

  Future<TestModel?> submitTest() async {
    if (!state.isValid || state.selectedKit == null) return null;
    if (_authState.user == null) {
      state = state.copyWith(error: 'User not authenticated');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final draft = await _testsRepository.createDraft(
        operatorId: _authState.user!.id, // Using user ID for now
        kitId: state.selectedKit!.id,
        caseId: state.caseId.trim(),
        sampleId: state.sampleId.trim(),
      );
      
      state = state.copyWith(isLoading: false);
      return draft;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to create test: $e');
      return null;
    }
  }
}

final newTestControllerProvider = StateNotifierProvider<NewTestNotifier, NewTestState>((ref) {
  return NewTestNotifier(
    ref.watch(testsRepositoryProvider),
    ref.watch(authControllerProvider),
  );
});
