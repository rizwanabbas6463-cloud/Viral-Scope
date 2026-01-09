"""
Deploy Model Script
Trains the model and saves it for production use.
Run this script once to train and save the model.
"""
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
import os
import pickle

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

def main():
    print("=" * 60)
    print("DNA Classifier Model Deployment")
    print("=" * 60)
    
    # Check if data file exists
    data_file = 'Human Data Sequnence.txt'
    if not os.path.exists(data_file):
        print(f"❌ Error: Data file '{data_file}' not found!")
        print(f"   Please ensure the file is in the current directory.")
        return
    
    try:
        # Load and prepare data
        print(f"\n📊 Loading dataset from '{data_file}'...")
        df, seq_col, label_col = load_and_prepare_data(data_file)
        print(f"✅ Dataset loaded: {len(df)} samples")
        
        # Create features
        print("\n🔧 Creating features (k-mer extraction)...")
        vectorizer = CountVectorizer()
        X = vectorizer.fit_transform(df['kmer_seq'])
        y = df['binary_class']
        print(f"✅ Features created: {X.shape[1]} features")
        
        # Train-test split
        print("\n📈 Splitting data into train/test sets...")
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        print(f"✅ Training samples: {X_train.shape[0]}")
        print(f"✅ Test samples: {X_test.shape[0]}")
        
        # Train model
        print("\n🤖 Training Logistic Regression model...")
        model = LogisticRegression(max_iter=1000, class_weight='balanced')
        model.fit(X_train, y_train)
        print("✅ Model training completed")
        
        # Evaluate
        print("\n📊 Evaluating model...")
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        print(f"✅ Test Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")
        
        # Print classification report
        print("\n📋 Classification Report:")
        print(classification_report(y_test, y_pred))
        
        # Save model
        print("\n💾 Saving model to disk...")
        os.makedirs(MODEL_DIR, exist_ok=True)
        with open(MODEL_FILE, 'wb') as f:
            pickle.dump(model, f)
        with open(VECTORIZER_FILE, 'wb') as f:
            pickle.dump(vectorizer, f)
        print(f"✅ Model saved to: {MODEL_FILE}")
        print(f"✅ Vectorizer saved to: {VECTORIZER_FILE}")
        
        print("\n" + "=" * 60)
        print("✅ Model deployment completed successfully!")
        print("=" * 60)
        print("\n🚀 You can now start the Flask server:")
        print("   python app.py")
        print("\n   The model will be automatically loaded on startup.")
        
    except Exception as e:
        print(f"\n❌ Error during deployment: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

