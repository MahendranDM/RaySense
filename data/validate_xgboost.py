import pandas as pd
import numpy as np
import joblib

from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score
)

print("--------------------------------")
print("RaySense XGBoost Validation")
print("--------------------------------")

# --------------------------------
# LOAD DATA
# --------------------------------

df = pd.read_csv(
    "data/raysense_ml_dataset.csv"
)

# Recreate year
original = pd.read_csv(
    "data/combined_2015_2024_pv_weather.csv",
    usecols=["datetime"]
)

original["datetime"] = pd.to_datetime(
    original["datetime"]
)

df["year"] = original["datetime"].dt.year.values

# --------------------------------
# FEATURES
# --------------------------------

features = [
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
    "system_capacity_kw"
]

target = "generation_kwh"

# --------------------------------
# TEST DATA
# --------------------------------

test = df[
    df["year"] >= 2023
].copy()

X_test = test[features]

y_test = test[target]

print("Test rows:", len(test))

# --------------------------------
# LOAD XGBOOST MODEL
# --------------------------------

model = joblib.load(
    "data/xgboost_model.pkl"
)

print("XGBoost model loaded.")

# --------------------------------
# PREDICTIONS
# --------------------------------

predictions = model.predict(
    X_test
)

test["predicted_generation_kwh"] = predictions

# --------------------------------
# OVERALL METRICS
# --------------------------------

mae = mean_absolute_error(
    y_test,
    predictions
)

rmse = np.sqrt(
    mean_squared_error(
        y_test,
        predictions
    )
)

r2 = r2_score(
    y_test,
    predictions
)

# --------------------------------
# DAYTIME DATA
# --------------------------------
# Solar radiation > 0 means
# sunlight is present.

daytime = test[
    test["ALLSKY_SFC_SW_DWN"] > 0
].copy()

day_y = daytime["generation_kwh"]

day_pred = daytime[
    "predicted_generation_kwh"
]

day_mae = mean_absolute_error(
    day_y,
    day_pred
)

day_rmse = np.sqrt(
    mean_squared_error(
        day_y,
        day_pred
    )
)

day_r2 = r2_score(
    day_y,
    day_pred
)

# --------------------------------
# NIGHTTIME DATA
# --------------------------------

nighttime = test[
    test["ALLSKY_SFC_SW_DWN"] == 0
].copy()

night_y = nighttime["generation_kwh"]

night_pred = nighttime[
    "predicted_generation_kwh"
]

night_mae = mean_absolute_error(
    night_y,
    night_pred
)

night_rmse = np.sqrt(
    mean_squared_error(
        night_y,
        night_pred
    )
)

# --------------------------------
# ERROR
# --------------------------------

test["absolute_error"] = abs(
    test["generation_kwh"]
    -
    test["predicted_generation_kwh"]
)

# --------------------------------
# RESULTS
# --------------------------------

print()
print("--------------------------------")
print("OVERALL TEST RESULTS")
print("--------------------------------")

print(
    f"MAE  : {mae:.4f} kWh"
)

print(
    f"RMSE : {rmse:.4f} kWh"
)

print(
    f"R²   : {r2:.4f}"
)

print()
print("--------------------------------")
print("DAYTIME RESULTS")
print("--------------------------------")

print(
    "Daytime rows:",
    len(daytime)
)

print(
    f"MAE  : {day_mae:.4f} kWh"
)

print(
    f"RMSE : {day_rmse:.4f} kWh"
)

print(
    f"R²   : {day_r2:.4f}"
)

print()
print("--------------------------------")
print("NIGHTTIME RESULTS")
print("--------------------------------")

print(
    "Nighttime rows:",
    len(nighttime)
)

print(
    f"MAE  : {night_mae:.4f} kWh"
)

print(
    f"RMSE : {night_rmse:.4f} kWh"
)

# --------------------------------
# PREDICTION RANGE
# --------------------------------

print()
print("--------------------------------")
print("PREDICTION CHECK")
print("--------------------------------")

print(
    "Actual minimum:",
    y_test.min()
)

print(
    "Actual maximum:",
    y_test.max()
)

print(
    "Predicted minimum:",
    predictions.min()
)

print(
    "Predicted maximum:",
    predictions.max()
)

# --------------------------------
# SAVE SAMPLE RESULTS
# --------------------------------

sample = test[
    [
        "T2M",
        "RH2M",
        "WS10M",
        "ALLSKY_SFC_SW_DWN",
        "hour",
        "month",
        "generation_kwh",
        "predicted_generation_kwh",
        "absolute_error"
    ]
].head(10000)

sample.to_csv(
    "data/xgboost_validation_sample.csv",
    index=False
)

print()
print(
    "Validation sample saved:"
)

print(
    "data/xgboost_validation_sample.csv"
)

print()
print("--------------------------------")
print("STEP 44 COMPLETED")
print("--------------------------------")