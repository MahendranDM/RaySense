import joblib
import pandas as pd


# --------------------------------
# LOAD TRAINED XGBOOST MODEL
# --------------------------------

MODEL_PATH = "data/xgboost_model.pkl"

model = joblib.load(MODEL_PATH)


# --------------------------------
# FEATURES USED DURING TRAINING
# --------------------------------

FEATURES = [
    "T2M",
    "RH2M",
    "WS10M",
    "WD10M",
    "PS",
    "ALLSKY_SFC_SW_DWN",
    "latitude_pv",
    "longitude_pv",
    "elevation_pv",
    "hour",
    "month",
    "day_of_year",
    "day_of_week",
    "system_capacity_kw",
]


# --------------------------------
# PREDICTION FUNCTION
# --------------------------------

def predict_generation(
    temperature,
    humidity,
    wind_speed,
    wind_direction,
    pressure,
    solar_radiation,
    latitude,
    longitude,
    elevation,
    hour,
    month,
    day_of_year,
    day_of_week,
    system_capacity_kw,
):

  

    input_data = pd.DataFrame(
        [[
            temperature,
            humidity,
            wind_speed,
            wind_direction,
            pressure,
            solar_radiation,
            latitude,
            longitude,
            elevation,
            hour,
            month,
            day_of_year,
            day_of_week,
            system_capacity_kw,
        ]],
        columns=FEATURES
    )

    # Predict
    prediction = model.predict(input_data)[0]

    # Physical constraint:
    # solar generation cannot be negative.
    prediction = max(0.0, float(prediction))

    # Prevent generation from exceeding
    # the theoretical hourly system capacity.
    prediction = min(
        prediction,
        float(system_capacity_kw)
    )

    return round(prediction, 4)