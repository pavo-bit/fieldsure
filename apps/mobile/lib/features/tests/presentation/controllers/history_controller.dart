import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/test_model.dart';

class HistoryState {
  final List<TestModel> tests;
  final bool isLoading;
  final String? error;
  final int page;
  final int totalPages;
  final String search;
  final String filterResult;
  final String filterStatus;
  final String filterVerification;
  final String sort;

  HistoryState({
    this.tests = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.search = '',
    this.filterResult = 'All',
    this.filterStatus = 'All',
    this.filterVerification = 'All',
    this.sort = 'desc',
  });

  HistoryState copyWith({
    List<TestModel>? tests,
    bool? isLoading,
    String? error,
    int? page,
    int? totalPages,
    String? search,
    String? filterResult,
    String? filterStatus,
    String? filterVerification,
    String? sort,
  }) {
    return HistoryState(
      tests: tests ?? this.tests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      search: search ?? this.search,
      filterResult: filterResult ?? this.filterResult,
      filterStatus: filterStatus ?? this.filterStatus,
      filterVerification: filterVerification ?? this.filterVerification,
      sort: sort ?? this.sort,
    );
  }
}

class HistoryController extends StateNotifier<HistoryState> {
  final ApiClient _api;

  HistoryController(this._api) : super(HistoryState()) {
    fetchTests(refresh: true);
  }

  Future<void> fetchTests({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && state.page > state.totalPages) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      page: refresh ? 1 : state.page,
      tests: refresh ? [] : state.tests,
    );

    try {
      final queryParams = {
        'page': state.page.toString(),
        'limit': '20',
        if (state.search.isNotEmpty) 'search': state.search,
        if (state.filterResult != 'All') 'result': state.filterResult,
        if (state.filterStatus != 'All') 'syncStatus': state.filterStatus,
        if (state.filterVerification != 'All') 'verificationStatus': state.filterVerification,
        'sort': state.sort,
      };

      final response = await _api.dio.get('/tests', queryParameters: queryParams);
      
      final data = response.data['data'];
      final List items = data['items'] ?? [];
      final List<TestModel> newTests = items.map((json) => TestModel.fromJson(json)).toList();

      state = state.copyWith(
        isLoading: false,
        tests: refresh ? newTests : [...state.tests, ...newTests],
        page: state.page + 1,
        totalPages: data['totalPages'] ?? 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(search: query);
    fetchTests(refresh: true);
  }

  void updateFilterResult(String result) {
    state = state.copyWith(filterResult: result);
    fetchTests(refresh: true);
  }

  void updateSort(String sort) {
    state = state.copyWith(sort: sort);
    fetchTests(refresh: true);
  }
  
  void updateFilterVerification(String verification) {
    state = state.copyWith(filterVerification: verification);
    fetchTests(refresh: true);
  }
}

final historyControllerProvider = StateNotifierProvider.autoDispose<HistoryController, HistoryState>((ref) {
  final api = ref.watch(apiClientProvider);
  return HistoryController(api);
});
