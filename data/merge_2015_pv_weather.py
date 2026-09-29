import pandas as pd

print("--------------------------------")
print("RaySense 2015 PV + Weather Merge")
print("--------------------------------")

# -----------------------------
# FILES
# -----------------------------

pv_file = "data/raw/kerala_distpv_2015_2024.csv"
weather_file = "data/weather/yearly/kerala_weather_2015.csv"
mapping_file = "data/metadata/pv_location_mapping.csv"

# -----------------------------
# LOAD PV DATA
# -----------------------------

pv = pd.read_csv(pv_file)

pv_2015 = pv[pv["year"] == 2015].copy()

print("PV 2015 rows:", len(pv_2015))

# -----------------------------
# LOAD LOCATION MAPPING
# -----------------------------

mapping = pd.read_csv(mapping_file)

print("PV locations:", len(mapping))

# -----------------------------
# LOAD WEATHER
# -----------------------------

weather = pd.read_csv(weather_file)

weather["datetime"] = pd.to_datetime(weather["datetime"])

print("Weather rows:", len(weather))

# -----------------------------
# PV POINT COLUMNS
# -----------------------------

point_columns = [
    f"point_{i}"
    for i in range(105)
]

# -----------------------------
# CONVERT PV FROM WIDE → LONG
# -----------------------------

pv_long = pv_2015[
    ["hour"] + point_columns
].melt(
    id_vars=["hour"],
    var_name="pv_point",
    value_name="pv_capacity_factor"
)

# -----------------------------
# CREATE 2015 HOURLY TIMESTAMPS
# -----------------------------

timestamps = pd.date_range(
    start="2015-01-01 00:00:00",
    end="2015-12-31 23:00:00",
    freq="h"
)

print("PV timestamps:", len(timestamps))

# -----------------------------
# ASSIGN TIMESTAMP
# -----------------------------

pv_long["datetime"] = timestamps[
    pv_long["hour"].values
]

# -----------------------------
# ADD LOCATION INFORMATION
# -----------------------------

pv_long = pv_long.merge(
    mapping[
        [
            "pv_point",
            "gid",
            "latitude",
            "longitude",
            "elevation"
        ]
    ],
    on="pv_point",
    how="left"
)

# -----------------------------
# MERGE WITH WEATHER
# -----------------------------

combined = pv_long.merge(
    weather,
    on=["datetime", "gid"],
    how="inner",
    suffixes=("_pv", "_weather")
)

# -----------------------------
# SORT
# -----------------------------

combined = combined.sort_values(
    ["gid", "datetime"]
).reset_index(drop=True)

# -----------------------------
# SAVE
# -----------------------------

output_file = "data/combined_2015_pv_weather.csv"

combined.to_csv(
    output_file,
    index=False
)

# -----------------------------
# VALIDATION
# -----------------------------

print()
print("--------------------------------")
print("2015 MERGE RESULTS")
print("--------------------------------")

print("Combined shape:", combined.shape)

print(
    "Locations:",
    combined["gid"].nunique()
)

print(
    "Date range:",
    combined["datetime"].min(),
    "to",
    combined["datetime"].max()
)

print(
    "Expected rows:",
    105 * 8760
)

print(
    "Actual rows:",
    len(combined)
)

print(
    "Missing values:",
    combined.isna().sum().sum()
)

print()
print("Columns:")

print(
    combined.columns.tolist()
)

print()
print("First 5 rows:")

print(
    combined.head().to_string()
)

print()
print("--------------------------------")
print("STEP 36 COMPLETED")
print("--------------------------------")