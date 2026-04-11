import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/ai_advice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AIAdvisorRepository {
  AIAdvisorRepository(this._client);

  final SupabaseClient _client;

  Future<AIAdvice> getAdvice({
    required String entryId,
    String? question,
    bool debrief = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'fantasy-ai-advisor',
        body: <String, dynamic>{
          'entry_id': entryId,
          'mode': debrief ? 'debrief' : 'advice',
          if (question != null && question.trim().isNotEmpty)
            'question': question.trim(),
        },
      );

      if (response.status != 200 || response.data == null) {
        throw FantasyException.data('AI advisor is unavailable right now.');
      }

      final json = Map<String, dynamic>.from(response.data as Map);
      return AIAdvice(
        advice: json['advice'] as String? ?? 'No advice available.',
        question: question?.trim().isNotEmpty == true
            ? question!.trim()
            : debrief
            ? 'Give me a post-gameweek debrief.'
            : 'What should I prioritize this week?',
        generatedAt: DateTime.now().toUtc(),
      );
    } on FunctionException catch (error) {
      throw FantasyException.data(
        error.details ?? 'AI advisor request failed.',
      );
    }
  }
}
