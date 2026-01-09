# DNA Classifier Backend API

Flask REST API for DNA sequence classification (coding vs non-coding).

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Make sure `Human Data Sequnence.txt` is in the same directory

3. **Deploy the model** (train and save):
```bash
python deploy_model.py
```

This will:
- Train the model on your dataset
- Save the trained model to `models/dna_classifier_model.pkl`
- Save the vectorizer to `models/vectorizer.pkl`

4. Run the server:
```bash
python app.py
```

The API will be available at `http://localhost:5000`

The server will automatically load the saved model on startup.

## Deployment Workflow

### First Time Setup
```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Deploy (train and save) the model
python deploy_model.py

# 3. Start the server
python app.py
```

### Production Deployment
After running `deploy_model.py`, the model files are saved in the `models/` directory. 
You can:
- Copy the `models/` folder to your production server
- Start the server with `python app.py` - it will automatically load the saved model
- No need to retrain on every startup!

## API Endpoints

### Health Check
```
GET /api/health
```
Returns model training status.

### Train Model (Optional - for retraining)
```
POST /api/train
Content-Type: application/json

{
  "file_path": "Human Data Sequnence.txt"  // optional
}
```
Note: Training via API will also save the model automatically.

### Predict Sequence
```
POST /api/predict
Content-Type: application/json

{
  "sequence": "ATGCCCCAACTAAATACTACCGT..."
}
```

### Batch Predict
```
POST /api/batch_predict
Content-Type: application/json

{
  "sequences": ["ATGC...", "GCTA...", ...]
}
```

## Model Files

- `models/dna_classifier_model.pkl` - Trained Logistic Regression model
- `models/vectorizer.pkl` - Fitted CountVectorizer for k-mer features

These files are created by `deploy_model.py` and loaded automatically by `app.py`.

