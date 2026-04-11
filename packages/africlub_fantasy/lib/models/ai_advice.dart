import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_advice.freezed.dart';
part 'ai_advice.g.dart';

@freezed
class AIAdvice with _$AIAdvice {
  const factory AIAdvice({
    required String advice,
    required String question,
    @JsonKey(name: 'generated_at') DateTime? generatedAt,
  }) = _AIAdvice;

  factory AIAdvice.fromJson(Map<String, dynamic> json) =>
      _$AIAdviceFromJson(json);
}
