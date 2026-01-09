"""
Vercel Serverless Function for DNA Classification API
"""
from http.server import BaseHTTPRequestHandler
import json
import os
import pickle
from urllib.parse import urlparse, parse_qs

# API Key for authentication
API_KEY = os.environ.get('API_KEY', 'your-secret-api-key-here')

# Global variables for model and vectorizer
model = None
vectorizer = None
is_trained = False

# Model file paths
MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'models')
MODEL_FILE = os.path.join(MODEL_DIR, 'dna_classifier_model.pkl')
VECTORIZER_FILE = os.path.join(MODEL_DIR, 'vectorizer.pkl')

def get_kmers(sequence, k=3):
    """Extract k-mers from DNA sequence"""
    sequence = str(sequence)
    return " ".join([sequence[i:i+k] for i in range(len(sequence)-k+1)])

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
            return True
        return False
    except Exception as e:
        print(f"Error loading model: {e}")
        return False

def check_api_key(headers):
    """Check if API key is valid"""
    api_key = headers.get('X-Api-Key') or headers.get('x-api-key') or \
              headers.get('Authorization', '').replace('Bearer ', '')
    if not api_key or api_key != API_KEY:
        return {
            'statusCode': 401,
            'body': json.dumps({
                'success': False,
                'error': 'Invalid or missing API key. Please provide X-API-Key header or Bearer token.'
            })
        }
    return None

# Load model on module import
if not load_model():
    print("Warning: Model not loaded. Please ensure model files are deployed.")

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/api/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            response = {
                'status': 'healthy',
                'model_trained': is_trained,
                'message': 'API is running. Use X-API-Key header for authenticated endpoints.'
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(json.dumps({'error': 'Not found'}).encode())
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        try:
            data = json.loads(body.decode('utf-8'))
        except:
            data = {}
        
        # Health check doesn't need auth
        if path == '/api/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            response = {
                'status': 'healthy',
                'model_trained': is_trained
            }
            self.wfile.write(json.dumps(response).encode())
            return
        
        # Check API key for other endpoints
        headers_dict = dict(self.headers)
        auth_error = check_api_key(headers_dict)
        if auth_error:
            self.send_response(401)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(auth_error['body'].encode())
            return
        
        # Route to appropriate handler
        if path == '/api/predict':
            response = self.handle_predict(data)
        elif path == '/api/batch_predict':
            response = self.handle_batch_predict(data)
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'error': 'Not found'}).encode())
            return
        
        # Send response
        self.send_response(response['statusCode'])
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(response['body'].encode())
    
    def handle_predict(self, data):
        """Handle prediction request"""
        global model, vectorizer, is_trained
        
        if not is_trained or model is None or vectorizer is None:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': 'Model not loaded. Please contact administrator.'
                })
            }
        
        try:
            sequence = data.get('sequence', '').strip().upper()
            
            if not sequence:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'success': False,
                        'error': 'Sequence is required'
                    })
                }
            
            # Validate sequence
            valid_bases = set('ATGC')
            if not all(base in valid_bases for base in sequence):
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'success': False,
                        'error': 'Invalid DNA sequence. Only A, T, G, C are allowed.'
                    })
                }
            
            # Predict
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
            
            return {
                'statusCode': 200,
                'body': json.dumps(result)
            }
        
        except Exception as e:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': str(e)
                })
            }
    
    def handle_batch_predict(self, data):
        """Handle batch prediction request"""
        global model, vectorizer, is_trained
        
        if not is_trained or model is None or vectorizer is None:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': 'Model not loaded. Please contact administrator.'
                })
            }
        
        try:
            sequences = data.get('sequences', [])
            
            if not sequences:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'success': False,
                        'error': 'Sequences array is required'
                    })
                }
            
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
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'results': results,
                    'count': len(results)
                })
            }
        
        except Exception as e:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'success': False,
                    'error': str(e)
                })
            }
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, X-API-Key, Authorization')
        self.end_headers()
