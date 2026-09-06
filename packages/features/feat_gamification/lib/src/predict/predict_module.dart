import '../fanzone_module.dart';

/// Compatibility type. Register only one module: FanzoneModule now hosts
/// the canonical /predict shell and all former Predict/Challenge aliases.
@Deprecated('Use FanzoneModule; Predict is now the shared supporter shell.')
class PredictModule extends FanzoneModule {}
