import 'package:flutter/foundation.dart';
import '../models/api_service.dart';
import '../models/dna_prediction.dart';

/// ViewModel - Business Logic Layer (MVVM Pattern)
class PredictionViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  DnaPrediction? _lastPrediction;
  TrainingStatus? _trainingStatus;
  bool _isModelTrained = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DnaPrediction? get lastPrediction => _lastPrediction;
  TrainingStatus? get trainingStatus => _trainingStatus;
  bool get isModelTrained => _isModelTrained;

  /// Initialize and check model status
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();
    try {
      _trainingStatus = await _apiService.checkHealth();
      _isModelTrained = _trainingStatus?.isTrained ?? false;
      if (!_isModelTrained) {
        _setError('Model is not trained. Please train the model first.');
      }
    } catch (e) {
      // Connection error - don't show train button, show connection error
      _isModelTrained = false;
      final errorMsg = e.toString();
      if (errorMsg.contains('Failed host lookup') || 
          errorMsg.contains('Connection refused') ||
          errorMsg.contains('Network is unreachable')) {
        _setError('Cannot connect to server.\n\nPlease check:\n• Internet connection\n• Server is running\n• Correct API URL in settings');
      } else {
        _setError('Failed to connect to server: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Train the model
  Future<void> trainModel({String? filePath}) async {
    _setLoading(true);
    _clearError();
    try {
      await _apiService.trainModel(filePath: filePath);
      _isModelTrained = true;
      await initialize(); // Refresh status
      notifyListeners();
    } catch (e) {
      _setError('Training failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Clean and extract DNA sequence from input
  /// Handles cases where users paste tab-separated data with class labels
  String _cleanSequence(String input) {
    // First, split by tabs or whitespace to separate sequence from class label
    final parts = input.split(RegExp(r'[\s\t]+'));
    
    // The first part should be the DNA sequence
    String sequence = parts.isNotEmpty ? parts[0] : input;
    
    // Remove any remaining non-DNA characters (keep only A, T, G, C, case-insensitive)
    sequence = sequence.replaceAll(RegExp(r'[^ATGCatgc]'), '');
    
    // Convert to uppercase
    sequence = sequence.toUpperCase();
    
    return sequence;
  }

  /// Predict a DNA sequence
  Future<void> predictSequence(String sequence) async {
    if (sequence.trim().isEmpty) {
      _setError('Please enter a DNA sequence');
      return;
    }

    // Clean the sequence (remove tabs, whitespace, class labels, etc.)
    final cleanedSequence = _cleanSequence(sequence);
    
    if (cleanedSequence.isEmpty) {
      _setError('No valid DNA sequence found. Please enter a sequence containing only A, T, G, C.');
      return;
    }

    // Validate sequence (only A, T, G, C)
    final validBases = RegExp(r'^[ATGCatgc]+$');
    if (!validBases.hasMatch(cleanedSequence)) {
      _setError('Invalid DNA sequence. Only A, T, G, C are allowed.\n\nFound: ${cleanedSequence.substring(0, cleanedSequence.length > 50 ? 50 : cleanedSequence.length)}...');
      return;
    }

    if (cleanedSequence.length < 3) {
      _setError('Sequence too short. Please enter at least 3 nucleotides.');
      return;
    }

    _setLoading(true);
    _clearError();
    try {
      _lastPrediction = await _apiService.predictSequence(cleanedSequence.toUpperCase());
      notifyListeners();
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Failed host lookup') || 
          errorMsg.contains('Connection refused') ||
          errorMsg.contains('Network is unreachable')) {
        _setError('Cannot connect to server.\n\nPlease check:\n• Internet connection\n• Server is running\n• Correct API URL');
      } else if (errorMsg.contains('Model not trained') || 
                 errorMsg.contains('Model not loaded')) {
        _setError('Model is not ready. Please train the model first.');
      } else {
        _setError('Prediction failed: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Clear the last prediction
  void clearPrediction() {
    _lastPrediction = null;
    _clearError();
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

