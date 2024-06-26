import pickle
from flask import Flask, request, jsonify
import pandas as pd

port_no = 49574
app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    json_ = request.json
    print(json_)
    data = pd.DataFrame(json_, index=[0])

    # Load your pre-trained model
    model = pickle.load(open("model2.pkl", "rb"))

    # Make predictions
    predictions = model.predict(data)
    normal_alert = 'Normal'
    aggressive_alert = 'Please Drive slow!'

    if predictions[0] == 1:
        return jsonify({'Alert': aggressive_alert})
    else:
        return jsonify({'Alert': normal_alert})

@app.route('/HealthCheck', methods=['GET'])
def HealthCheck():
    return "<p> Running Fine... </p>"

# Change the host to '0.0.0.0' to make it accessible externally
app.run(host='0.0.0.0', port=port_no)

