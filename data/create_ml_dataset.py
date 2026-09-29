import pandas as pd
import numpy as np

print("--------------------------------")
print("RaySense ML Dataset Creation")
print("--------------------------------")

# --------------------------------
# LOAD COMBINED DATA
# --------------------------------

input_file = "data/combined_2015_2024_pv_weather.csv"

df = pd.read_csv(input_file)

print("Original rows:", len(df))

# --------------------------------
# DATETIME
# --------------------------------

df["datetime"] = pd.to_datetime(
    df["datetime"]
)

# --------------------------------
# TIME FEATURES
# --------------------------------

df["hour"] = df["datetime"].dt.hour

df["month"] = df["datetime"].dt.month

df["day_of_year"] = (
    df["datetime"].dt.dayofyear
)

df["day_of_week"] = (
    df["datetime"].dt.dayofweek
)

# --------------------------------
# SYSTEM CAPACITY
# --------------------------------
#
# The previous dataset used only:
#
#     system_capacity_kw = 5.0
#
# That meant the ML model had almost no
# opportunity to learn how system capacity
# affects generation.
#
# We now introduce multiple realistic
# rooftop solar system capacities.
#
# Capacities:
#     2 kW
#     3 kW
#     5 kW
#     8 kW
#     10 kW
#
# The capacities are distributed across
# the existing rows so the dataset size
# remains approximately the same.

capacities = np.array([
    2.0,
    3.0,
    5.0,
    8.0,
    10.0,
])

df["system_capacity_kw"] = np.resize(
    capacities,
    len(df)
)

# --------------------------------
# GENERATION TARGET
# --------------------------------
#
# GridLab provides PV capacity factor.
#
# Generation (kWh) =
#
#     PV Capacity Factor
#     ×
#     System Capacity (kW)
#
# For a 1-hour interval this gives the
# approximate energy generated.

df["generation_kwh"] = (
    df["pv_capacity_factor"]
    * df["system_capacity_kw"]
)

# --------------------------------
# SELECT ML FEATURES
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
    "system_capacity_kw",
]

target = "generation_kwh"

ml_data = df[
    features + [target]
].copy()

# --------------------------------
# REMOVE INVALID VALUES
# --------------------------------

ml_data = ml_data.dropna()

# --------------------------------
# VALIDATION
# --------------------------------

print()
print("--------------------------------")
print("ML DATASET RESULTS")
print("--------------------------------")

print(
    "Rows:",
    len(ml_data)
)

print(
    "Columns:",
    len(ml_data.columns)
)

print()
print("Features:")

for feature in features:
    print(" -", feature)

print()
print("Target:")
print(" -", target)

print()
print(
    "Missing values:",
    ml_data.isna().sum().sum()
)

# --------------------------------
# CAPACITY DISTRIBUTION
# --------------------------------

print()
print("--------------------------------")
print("SYSTEM CAPACITY DISTRIBUTION")
print("--------------------------------")

print(
    ml_data[
        "system_capacity_kw"
    ].value_counts().sort_index()
)

# --------------------------------
# GENERATION STATISTICS
# --------------------------------

print()
print("--------------------------------")
print("GENERATION STATISTICS")
print("--------------------------------")

print(
    ml_data[
        "generation_kwh"
    ].describe()
)

# --------------------------------
# VALIDATE CAPACITY RELATIONSHIP
# --------------------------------

print()
print("--------------------------------")
print("CAPACITY / GENERATION CHECK")
print("--------------------------------")

capacity_summary = (
    ml_data
    .groupby("system_capacity_kw")[
        "generation_kwh"
    ]
    .agg(
        [
            "count",
            "mean",
            "min",
            "max",
        ]
    )
)

print(capacity_summary)

# --------------------------------
# SAVE
# --------------------------------

output_file = (
    "data/raysense_ml_dataset.csv"
)

ml_data.to_csv(
    output_file,
    index=False
)

print()
print("--------------------------------")
print("ML DATASET SAVED")
print("--------------------------------")

print(
    "Output:",
    output_file
)

print("--------------------------------")
print("STEP 38 COMPLETED")
print("--------------------------------")