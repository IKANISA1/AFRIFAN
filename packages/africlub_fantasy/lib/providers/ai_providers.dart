import 'package:africlub_fantasy/models/ai_advice.dart';
import 'package:africlub_fantasy/repositories/ai_advisor_repository.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiAdvisorRepositoryProvider = Provider<AIAdvisorRepository>((ref) {
  return AIAdvisorRepository(ref.watch(supabaseClientProvider));
});

class AIAdviceController extends StateNotifier<AsyncValue<AIAdvice?>> {
  AIAdviceController(this._repository) : super(const AsyncValue.data(null));

  final AIAdvisorRepository _repository;

  Future<void> ask({required String entryId, String? question}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.getAdvice(entryId: entryId, question: question),
    );
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final aiAdviceControllerProvider =
    StateNotifierProvider<AIAdviceController, AsyncValue<AIAdvice?>>((ref) {
      return AIAdviceController(ref.watch(aiAdvisorRepositoryProvider));
    });
