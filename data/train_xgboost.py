import pandas as pd
import numpy as np
import joblib

from xgboost import XGBRegressor
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score
)

print("--------------------------------")
print("RaySense XGBoost Training")
print("--------------------------------")

# --------------------------------
# LOAD DATA
# --------------------------------

file = "data/raysense_ml_dataset.csv"

df = pd.read_csv(file)

print("Total rows:", len(df))

# --------------------------------
# RECREATE YEAR
# --------------------------------

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
# TRAIN / TEST
# --------------------------------

train = df[df["year"] <= 2022]
test = df[df["year"] >= 2023]

X_train = train[features]
y_train = train[target]

X_test = test[features]
y_test = test[target]

print("Training rows:", len(X_train))
print("Testing rows:", len(X_test))

# --------------------------------
# TRAIN XGBOOST
# --------------------------------

print()
print("Training XGBoost...")
print("This may take some time.")

model = XGBRegressor(
    n_estimators=300,
    max_depth=8,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    objective="reg:squarederror",
    eval_metric="rmse",
    tree_method="hist",
    n_jobs=-1,
    random_state=42
)

model.fit(
    X_train,
    y_train
)

print("Training completed.")

# --------------------------------
# PREDICTION
# --------------------------------

print()
print("Generating predictions...")

predictions = model.predict(X_test)

# --------------------------------
# METRICS
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
# SAFE MAPE
# --------------------------------

non_zero = y_test != 0

mape = np.mean(
    np.abs(
        (
            y_test[non_zero]
            - predictions[non_zero]
        )
        /
        y_test[non_zero]
    )
) * 100

# --------------------------------
# RESULTS
# --------------------------------

print()
print("--------------------------------")
print("XGBOOST RESULTS")
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

print(
    f"MAPE : {mape:.2f}%"
)

# --------------------------------
# SAVE MODEL
# --------------------------------

model_file = "data/xgboost_model.pkl"

joblib.dump(
    model,
    model_file
)

print()
print("Model saved:")
print(model_file)

print()
print("--------------------------------")
print("STEP 43 COMPLETED")
print("--------------------------------")