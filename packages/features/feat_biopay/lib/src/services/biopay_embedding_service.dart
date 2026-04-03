import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/biopay_model_contract.dart';

/// Service for generating face embeddings using a TFLite MobileFaceNet model.
///
/// Handles model loading, platform-aware hardware acceleration
/// (CoreML on iOS, CPU elsewhere), and L2-normalized embedding output.
class BiopayEmbeddingService {
  BiopayEmbeddingService({String? modelAssetPath, String? contractAssetPath})
    : _modelAssetPath = modelAssetPath ?? BiopayModelContract.modelAssetPath,
      _contractAssetPath =
          contractAssetPath ?? BiopayModelContract.contractAssetPath;

  final String _modelAssetPath;
  final String _contractAssetPath;

  Interpreter? _interpreter;
  BiopayModelContract? _contract;
  String? _modelIssue;

  bool get isLoaded => _interpreter != null;
  String? get modelIssue => _modelIssue;
  int get embeddingSize => BiopayModelContract.expectedEmbeddingSize;

  // ─── Lifecycle ──────────────────────────────────────────────

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    try {
      // Load and validate the contract
      final contractJson = await rootBundle.loadString(_contractAssetPath);
      _contract = BiopayModelContract.fromJsonString(contractJson);

      final contractIssue = _contract!.validateStaticExpectations();
      if (contractIssue != null) {
        _modelIssue = contractIssue;
        debugPrint('[BiopayEmbeddingService] Contract issue: $contractIssue');
        return;
      }

      // Load and validate the model bytes
      final modelByteData = await rootBundle.load(_modelAssetPath);
      final bytesData = modelByteData.buffer.asUint8List(
        modelByteData.offsetInBytes,
        modelByteData.lengthInBytes,
      );

      final bytesIssue = _contract!.validateModelBytes(bytesData);
      if (bytesIssue != null) {
        _modelIssue = bytesIssue;
        debugPrint('[BiopayEmbeddingService] Model issue: $bytesIssue');
        return;
      }

      // Create the interpreter with best-effort acceleration
      final options = InterpreterOptions()..threads = 2;
      _tryAddDelegate(options);

      _interpreter = Interpreter.fromBuffer(bytesData, options: options);

      // Validate runtime tensor metadata
      final input = _interpreter!.getInputTensor(0);
      final output = _interpreter!.getOutputTensor(0);
      final tensorIssue = _contract!.validateTensorMetadata(
        runtimeInputShape: input.shape,
        runtimeInputType: _tensorTypeName(input.type),
        runtimeOutputShape: output.shape,
        runtimeOutputType: _tensorTypeName(output.type),
      );
      if (tensorIssue != null) {
        _modelIssue = tensorIssue;
        debugPrint('[BiopayEmbeddingService] Tensor issue: $tensorIssue');
        _interpreter?.close();
        _interpreter = null;
        return;
      }

      _modelIssue = null;
      debugPrint('[BiopayEmbeddingService] Model loaded successfully.');
    } catch (error, stack) {
      _modelIssue = 'Failed to load BioPay model: $error';
      debugPrint('[BiopayEmbeddingService] Load error: $error\n$stack');
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  // ─── Embedding ──────────────────────────────────────────────

  /// Generate an L2-normalized face embedding from a preprocessed tensor.
  List<double> generateEmbedding(Float32List inputTensor) {
    if (_interpreter == null) {
      throw StateError('BioPay model is not loaded. Call loadModel() first.');
    }

    const outputShape = BiopayModelContract.expectedOutputShape;
    final outputBuffer = List.generate(
      outputShape[0],
      (_) => List<double>.filled(outputShape[1], 0),
    );

    _interpreter!.run(
      inputTensor.buffer.asFloat32List().reshape(
        BiopayModelContract.expectedInputShape,
      ),
      outputBuffer,
    );

    final rawEmbedding = outputBuffer[0];
    return _l2Normalize(rawEmbedding);
  }

  /// Generate averaged embedding from multiple frames for enrollment.
  List<double> generateAveragedEmbedding(List<Float32List> tensors) {
    if (tensors.isEmpty) {
      throw ArgumentError('At least one tensor is required.');
    }
    if (tensors.length == 1) return generateEmbedding(tensors.first);

    final embeddings = tensors.map(generateEmbedding).toList();
    final size = embeddings.first.length;
    final averaged = List<double>.filled(size, 0);

    for (final embedding in embeddings) {
      for (var i = 0; i < size; i++) {
        averaged[i] += embedding[i];
      }
    }

    final count = embeddings.length.toDouble();
    for (var i = 0; i < size; i++) {
      averaged[i] /= count;
    }

    return _l2Normalize(averaged);
  }

  // ─── Helpers ────────────────────────────────────────────────

  List<double> _l2Normalize(List<double> embedding) {
    var sumSquared = 0.0;
    for (final value in embedding) {
      sumSquared += value * value;
    }
    if (sumSquared == 0) return embedding;

    final norm = math.sqrt(sumSquared);
    return embedding.map((v) => v / norm).toList(growable: false);
  }

  void _tryAddDelegate(InterpreterOptions options) {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          options.addDelegate(CoreMlDelegate());
          debugPrint('[BiopayEmbeddingService] Using CoreML delegate (iOS).');
          return;
        } catch (_) {
          debugPrint('[BiopayEmbeddingService] CoreML unavailable, using CPU.');
        }
      }
    } catch (_) {
      debugPrint('[BiopayEmbeddingService] Delegate setup failed, using CPU.');
    }
  }

  String _tensorTypeName(TensorType type) {
    return switch (type) {
      TensorType.float32 => 'float32',
      TensorType.float16 => 'float16',
      TensorType.int32 => 'int32',
      TensorType.uint8 => 'uint8',
      TensorType.int8 => 'int8',
      TensorType.int64 => 'int64',
      TensorType.boolean => 'bool',
      _ => 'unknown',
    };
  }
}
