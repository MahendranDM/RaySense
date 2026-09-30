import pandas as pd

print("--------------------------------")
print("RaySense Train/Test Preparation")
print("--------------------------------")

# --------------------------------
# LOAD DATA
# --------------------------------

input_file = "data/raysense_ml_dataset.csv"

df = pd.read_csv(input_file)

print("Total rows:", len(df))

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
    "system_capacity_kw",
]

target = "generation_kwh"

# --------------------------------
# CREATE DATE INFORMATION
# --------------------------------

# The current ML dataset does not contain
# datetime, so reconstruct the year using
# the original combined dataset.

original = pd.read_csv(
    "data/combined_2015_2024_pv_weather.csv",
    usecols=["datetime"]
)

original["datetime"] = pd.to_datetime(
    original["datetime"]
)

df["year"] = original["datetime"].dt.year.values

# --------------------------------
# TRAIN / TEST SPLIT
# --------------------------------

train = df[
    df["year"] <= 2022
].copy()

test = df[
    df["year"] >= 2023
].copy()

# --------------------------------
# CREATE X AND Y
# --------------------------------

X_train = train[features]

y_train = train[target]

X_test = test[features]

y_test = test[target]

# --------------------------------
# VALIDATION
# --------------------------------

print()
print("--------------------------------")
print("TRAIN / TEST RESULTS")
print("--------------------------------")

print(
    "Training rows:",
    len(X_train)
)

print(
    "Testing rows:",
    len(X_test)
)

print(
    "Training years:",
    sorted(train["year"].unique())
)

print(
    "Testing years:",
    sorted(test["year"].unique())
)

print()
print(
    "X_train shape:",
    X_train.shape
)

print(
    "y_train shape:",
    y_train.shape
)

print(
    "X_test shape:",
    X_test.shape
)

print(
    "y_test shape:",
    y_test.shape
)

print()
print("--------------------------------")
print("STEP 40 COMPLETED")
print("--------------------------------")