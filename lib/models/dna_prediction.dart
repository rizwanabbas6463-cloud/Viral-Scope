/// Model class representing a DNA prediction result
class DnaPrediction {
  final String sequence;
  final int prediction; // 0 = Non-Coding, 1 = Coding
  final String predictionLabel;
  final double confidence;
  final double nonCodingProbability;
  final double codingProbability;

  DnaPrediction({
    required this.sequence,
    required this.prediction,
    required this.predictionLabel,
    required this.confidence,
    required this.nonCodingProbability,
    required this.codingProbability,
  });

  factory DnaPrediction.fromJson(Map<String, dynamic> json) {
    return DnaPrediction(
      sequence: json['sequence'] ?? '',
      prediction: json['prediction'] ?? 0,
      predictionLabel: json['prediction_label'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      nonCodingProbability: (json['probabilities']?['non_coding'] ?? 0.0).toDouble(),
      codingProbability: (json['probabilities']?['coding'] ?? 0.0).toDouble(),
    );
  }

  bool get isCoding => prediction == 1;
  bool get isNonCoding => prediction == 0;
}

/// Model class for training status
class TrainingStatus {
  final bool isTrained;
  final double? accuracy;
  final int? datasetSize;
  final int? trainingSamples;
  final int? testSamples;

  TrainingStatus({
    required this.isTrained,
    this.accuracy,
    this.datasetSize,
    this.trainingSamples,
    this.testSamples,
  });

  factory TrainingStatus.fromJson(Map<String, dynamic> json) {
    return TrainingStatus(
      isTrained: json['model_trained'] ?? false,
    );
  }
}

