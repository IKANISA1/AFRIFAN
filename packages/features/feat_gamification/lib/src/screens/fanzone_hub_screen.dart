import 'package:flutter/material.dart';
import '../predict/predict_screen.dart';

/// Compatibility widget for callers that used the old Fan Zone hub.
/// Both names use the same controller, data and three-section Predict UI.
class FanzoneHubScreen extends StatelessWidget {
  const FanzoneHubScreen({super.key});

  @override
  Widget build(BuildContext context) => const PredictScreen(embedded: true);
}
