import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dna_prediction.dart';

/// API Service - Data Layer (Model in MVVM)
class ApiService {
  // ============================================
  // BACKEND URL CONFIGURATION
  // ============================================
  // Choose one of the following options:
  
  // OPTION 1: Local Development (Physical Device)
  // static const String baseUrl = 'http://192.168.100.12:5000';
  // static const String? apiKey = null;
  
  // OPTION 2: Android Emulator
  // static const String baseUrl = 'http://10.0.2.2:5000';
  // static const String? apiKey = null;
  
  // OPTION 3: iOS Simulator
  // static const String baseUrl = 'http://localhost:5000';
  // static const String? apiKey = null;
  
  // OPTION 4: Cloud Deployment (Vercel/Railway/Render)
  // Replace with your deployed URL after deployment
  static const String baseUrl = 'https://awake-comfort-production-9ce7.up.railway.app'; // Railway deployment
  static const String? apiKey = null; // No API key needed for Railway
  
  // For local development, use:
  // static const String baseUrl = 'http://192.168.100.12:5000';
  // static const String? apiKey = null;
  
  // Example for Vercel (if you use it later):
  // static const String baseUrl = 'https://dna-classifier-api.vercel.app';
  // static const String? apiKey = 'your-api-key-here';
  
  /// Get headers with API key if configured
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['X-API-Key'] = apiKey!;
    }
    return headers;
  }

  /// Check if the model is trained
  Future<TrainingStatus> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TrainingStatus.fromJson(data);
      } else {
        throw Exception('Failed to check health: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error checking health: $e');
    }
  }

  /// Train the model
  Future<Map<String, dynamic>> trainModel({String? filePath}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/train'),
        headers: _headers,
        body: json.encode({
          if (filePath != null) 'file_path': filePath,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Training failed');
      }
    } catch (e) {
      throw Exception('Error training model: $e');
    }
  }

  /// Predict a single DNA sequence
  Future<DnaPrediction> predictSequence(String sequence) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/predict'),
        headers: _headers,
        body: json.encode({'sequence': sequence}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return DnaPrediction.fromJson(data);
      } else {
        throw Exception(data['error'] ?? 'Prediction failed');
      }
    } catch (e) {
      throw Exception('Error predicting sequence: $e');
    }
  }

  /// Predict multiple sequences
  Future<List<DnaPrediction>> batchPredict(List<String> sequences) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/batch_predict'),
        headers: _headers,
        body: json.encode({'sequences': sequences}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return (data['results'] as List)
            .map((item) => DnaPrediction(
                  sequence: item['sequence'],
                  prediction: item['prediction'],
                  predictionLabel: item['prediction_label'],
                  confidence: (item['confidence'] ?? 0.0).toDouble(),
                  nonCodingProbability: (1.0 - (item['confidence'] ?? 0.0).toDouble()),
                  codingProbability: (item['confidence'] ?? 0.0).toDouble(),
                ))
            .toList();
      } else {
        throw Exception(data['error'] ?? 'Batch prediction failed');
      }
    } catch (e) {
      throw Exception('Error in batch prediction: $e');
    }
  }
}

