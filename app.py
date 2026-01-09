"""
Flask Backend API for DNA Classification
"""
from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
import os
import pickle
import numpy as np

app = Flask(__name__)
CORS(app)  # Enable CORS for mobile app

# Global variables for model and vectorizer
model = None
vectorizer = None
is_trained = False

# Model file paths
MODEL_DIR = 'models'
MODEL_FILE = os.path.join(MODEL_DIR, 'dna_classifier_model.pkl')
VECTORIZER_FILE = os.path.join(MODEL_DIR, 'vectorizer.pkl')

def get_kmers(sequence, k=3):
    """Extract k-mers from DNA sequence"""
    sequence = str(sequence)
    return " ".join([sequence[i:i+k] for i in range(len(sequence)-k+1)])

def load_and_prepare_data(file_path):
    """Load and prepare the dataset"""
    df = pd.read_csv(file_path, sep="\t")
    
    # Detect label column
    possible_label_cols = ['class', 'label', 'target', 'Category']
    label_col = None
    for col in possible_label_cols:
        if col in df.columns:
            label_col = col
            break
    
    if label_col is None:
        raise ValueError("No label column found")
    
    # Detect sequence column
    possible_seq_cols = ['sequence', 'Sequence', 'DNA', 'seq']
    seq_col = None
    for col in possible_seq_cols:
        if col in df.columns:
            seq_col = col
            break
    
    if seq_col is None:
        raise ValueError("No sequence column found")
    
    # Binary class conversion
    positive_class = df[label_col].unique()[0]
    df['binary_class'] = df[label_col].apply(lambda x: 1 if x == positive_class else 0)
    
    # Extract k-mers
    df['kmer_seq'] = df[seq_col].apply(lambda x: get_kmers(x, k=3))
    
    return df, seq_col, label_col

def save_model(model, vectorizer):
    """Save the trained model and vectorizer to disk"""
    os.makedirs(MODEL_DIR, exist_ok=True)
    with open(MODEL_FILE, 'wb') as f:
        pickle.dump(model, f)
    with open(VECTORIZER_FILE, 'wb') as f:
        pickle.dump(vectorizer, f)
    print(f"✅ Model saved to {MODEL_FILE}")
    print(f"✅ Vectorizer saved to {VECTORIZER_FILE}")

def load_model():
    """Load the trained model and vectorizer from disk"""
    global model, vectorizer, is_trained
    try:
        if os.path.exists(MODEL_FILE) and os.path.exists(VECTORIZER_FILE):
            with open(MODEL_FILE, 'rb') as f:
                model = pickle.load(f)
            with open(VECTORIZER_FILE, 'rb') as f:
                vectorizer = pickle.load(f)
            is_trained = True
            print(f"✅ Model loaded from {MODEL_FILE}")
            print(f"✅ Vectorizer loaded from {VECTORIZER_FILE}")
            return True
        return False
    except Exception as e:
        print(f"⚠️ Error loading model: {e}")
        return False

@app.route('/', methods=['GET'])
def root():
    """Root endpoint with API information"""
    return jsonify({
        'name': 'DNA Classifier API',
        'version': '1.0.0',
        'status': 'running',
        'model_trained': is_trained,
        'endpoints': {
            'health': '/api/health',
            'predict': '/api/predict (POST)',
            'batch_predict': '/api/batch_predict (POST)',
            'train': '/api/train (POST)'
        },
        'documentation': 'See README.md for API usage examples'
    })

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_trained': is_trained
    })

@app.route('/api/train', methods=['POST'])
def train_model():
    """Train the model with the dataset"""
    global model, vectorizer, is_trained
    
    try:
        # Get file path from request or use default
        data = request.get_json()
        file_path = data.get('file_path', 'Human Data Sequnence.txt')
        
        if not os.path.exists(file_path):
            return jsonify({
                'success': False,
                'error': f'File not found: {file_path}'
            }), 400
        
        # Load and prepare data
        df, seq_col, label_col = load_and_prepare_data(file_path)
        
        # Create features
        vectorizer = CountVectorizer()
        X = vectorizer.fit_transform(df['kmer_seq'])
        y = df['binary_class']
        
        # Train-test split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train model
        model = LogisticRegression(max_iter=1000, class_weight='balanced')
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        # Save the trained model
        save_model(model, vectorizer)
        is_trained = True
        
        return jsonify({
            'success': True,
            'accuracy': float(accuracy),
            'dataset_size': len(df),
            'training_samples': X_train.shape[0],
            'test_samples': X_test.shape[0],
            'model_saved': True
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/predict', methods=['POST'])
def predict():
    """Predict if a DNA sequence is coding or non-coding"""
    global model, vectorizer, is_trained
    
    if not is_trained or model is None or vectorizer is None:
        return jsonify({
            'success': False,
            'error': 'Model not trained. Please train the model first.'
        }), 400
    
    try:
        data = request.get_json()
        sequence = data.get('sequence', '').strip().upper()
        
        if not sequence:
            return jsonify({
                'success': False,
                'error': 'Sequence is required'
            }), 400
        
        # Validate sequence (only A, T, G, C)
        valid_bases = set('ATGC')
        if not all(base in valid_bases for base in sequence):
            return jsonify({
                'success': False,
                'error': 'Invalid DNA sequence. Only A, T, G, C are allowed.'
            }), 400
        
        # Extract k-mers and predict
        kmer_seq = get_kmers(sequence, k=3)
        X = vectorizer.transform([kmer_seq])
        prediction = model.predict(X)[0]
        probability = model.predict_proba(X)[0]
        
        result = {
            'success': True,
            'sequence': sequence,
            'prediction': int(prediction),
            'prediction_label': 'Coding' if prediction == 1 else 'Non-Coding',
            'confidence': float(max(probability)),
            'probabilities': {
                'non_coding': float(probability[0]),
                'coding': float(probability[1])
            }
        }
        
        return jsonify(result)
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/batch_predict', methods=['POST'])
def batch_predict():
    """Predict multiple sequences at once"""
    global model, vectorizer, is_trained
    
    if not is_trained or model is None or vectorizer is None:
        return jsonify({
            'success': False,
            'error': 'Model not trained. Please train the model first.'
        }), 400
    
    try:
        data = request.get_json()
        sequences = data.get('sequences', [])
        
        if not sequences:
            return jsonify({
                'success': False,
                'error': 'Sequences array is required'
            }), 400
        
        results = []
        for seq in sequences:
            seq = str(seq).strip().upper()
            kmer_seq = get_kmers(seq, k=3)
            X = vectorizer.transform([kmer_seq])
            prediction = model.predict(X)[0]
            probability = model.predict_proba(X)[0]
            
            results.append({
                'sequence': seq,
                'prediction': int(prediction),
                'prediction_label': 'Coding' if prediction == 1 else 'Non-Coding',
                'confidence': float(max(probability))
            })
        
        return jsonify({
            'success': True,
            'results': results,
            'count': len(results)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    # Try to load existing model first
    print("🔄 Attempting to load existing model...")
    if not load_model():
        print("⚠️ No saved model found. Model needs to be trained.")
        print("   Run 'python deploy_model.py' to train and save the model.")
        print("   Or use the /api/train endpoint to train via API.")
    else:
        print("✅ Model loaded successfully. Ready for predictions!")
    
    # Get port from environment variable (for Railway/Render) or use default 5000
    port = int(os.environ.get('PORT', 5000))
    print(f"\n🚀 Starting Flask server on http://0.0.0.0:{port}")
    app.run(host='0.0.0.0', port=port, debug=False)

