import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viral_scope/viewmodels/prediction_viewmodel.dart';

/// View - UI Layer (MVVM Pattern)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _sequenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PredictionViewModel>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('DNA Classifier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<PredictionViewModel>(context, listen: false)
                  .initialize();
            },
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<PredictionViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Model Status Card (Small)
                  _buildStatusCard(viewModel),
                  const SizedBox(height: 16),

                  // Input Section
                  _buildInputSection(viewModel),
                  const SizedBox(height: 16),

                  // Prediction Result
                  if (viewModel.lastPrediction != null)
                    _buildResultCard(viewModel.lastPrediction!),

                  // Error Message
                  if (viewModel.errorMessage != null)
                    _buildErrorCard(viewModel.errorMessage!),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(PredictionViewModel viewModel) {
    final isReady = viewModel.isModelTrained;
    final hasConnectionError = viewModel.errorMessage != null && 
        (viewModel.errorMessage!.contains('Cannot connect') ||
         viewModel.errorMessage!.contains('Failed to connect'));
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isReady) {
      statusColor = const Color(0xFF059669); // Green
      statusIcon = Icons.check_circle;
      statusText = 'Model Ready';
    } else if (hasConnectionError) {
      statusColor = const Color(0xFFDC2626); // Red
      statusIcon = Icons.cloud_off;
      statusText = 'Connection Error';
    } else {
      statusColor = const Color(0xFFF59E0B); // Orange
      statusIcon = Icons.warning;
      statusText = 'Model Not Ready';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (viewModel.isLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection(PredictionViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter DNA Sequence',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sequenceController,
              maxLines: 6,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Paste your DNA sequence here...\n\nExample:\nATGCCCCAACTAAATACTACCGT...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                suffixIcon: _sequenceController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _sequenceController.clear();
                          viewModel.clearPrediction();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              enabled: !viewModel.isLoading && viewModel.isModelTrained,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (viewModel.isLoading || !viewModel.isModelTrained)
                  ? null
                  : () {
                      viewModel.predictSequence(_sequenceController.text);
                    },
              icon: viewModel.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.analytics_outlined, size: 24),
              label: const Text(
                'Classify Sequence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Only show train button if model is not trained AND no connection error
            if (!viewModel.isModelTrained && 
                viewModel.errorMessage != null && 
                !viewModel.errorMessage!.contains('Cannot connect') &&
                !viewModel.errorMessage!.contains('Failed to connect')) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: viewModel.isLoading
                    ? null
                    : () {
                        _showTrainDialog(viewModel);
                      },
                icon: const Icon(Icons.train),
                label: const Text('Train Model'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  foregroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(prediction) {
    final isCoding = prediction.isCoding;
    final primaryColor = isCoding ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final secondaryColor = isCoding ? const Color(0xFF059669) : const Color(0xFF2563EB);
    final icon = isCoding ? Icons.biotech : Icons.science;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.1),
            secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.predictionLabel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${(prediction.confidence * 100).toStringAsFixed(1)}% confidence',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProgressBar(
              'Confidence Score',
              prediction.confidence,
              primaryColor,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildProbabilityCard(
                    'Non-Coding',
                    prediction.nonCodingProbability,
                    const Color(0xFF3B82F6),
                    Icons.block,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProbabilityCard(
                    'Coding',
                    prediction.codingProbability,
                    const Color(0xFF10B981),
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sequence: ${prediction.sequence.substring(0, prediction.sequence.length > 40 ? 40 : prediction.sequence.length)}${prediction.sequence.length > 40 ? "..." : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildProbabilityCard(
    String label,
    double probability,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(probability * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrainDialog(PredictionViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.train, color: Color(0xFF2563EB)),
            SizedBox(width: 12),
            Text('Train Model'),
          ],
        ),
        content: const Text(
          'This will train the model using the dataset. This may take a few moments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.trainModel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Train'),
          ),
        ],
      ),
    );
  }
}
