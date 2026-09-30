import pandas as pd


print("--------------------------------")
print("RaySense 2024 PV + Weather Merge")
print("--------------------------------")


# --------------------------------
# 1. Load PV data
# --------------------------------

pv_file = "data/raw/kerala_distpv_2015_2024.csv"

pv = pd.read_csv(pv_file)

pv_2024 = pv[
    pv["year"] == 2024
].copy()

print("PV 2024 rows:", len(pv_2024))


# --------------------------------
# 2. Load location mapping
# --------------------------------

mapping_file = "data/metadata/pv_location_mapping.csv"

mapping = pd.read_csv(mapping_file)

print("PV locations:", len(mapping))


# --------------------------------
# 3. Load weather data
# --------------------------------

weather_file = "data/weather/kerala_weather_2024.csv"

weather = pd.read_csv(weather_file)

weather["datetime"] = pd.to_datetime(
    weather["datetime"]
)

print("Weather rows:", len(weather))


# --------------------------------
# 4. Create datetime for PV data
# --------------------------------

# GridLab provides 8760 standardized
# hourly records for each year.

# For 2024, remove February 29
# from the weather dataset so both
# datasets use the same 8760-hour calendar.

weather = weather[
    ~(
        (weather["datetime"].dt.month == 2) &
        (weather["datetime"].dt.day == 29)
    )
].copy()

print(
    "Weather rows after removing leap day:",
    len(weather)
)


# --------------------------------
# 5. Create PV long-format dataset
# --------------------------------

point_columns = [
    f"point_{i}"
    for i in range(105)
]

pv_long = pv_2024[
    ["hour"] + point_columns
].melt(
    id_vars=["hour"],
    var_name="pv_point",
    value_name="pv_capacity_factor"
)


# --------------------------------
# 6. Add date/time
# --------------------------------

# Create standard 8760-hour timestamps
# for 2024 without February 29.

timestamps = pd.date_range(
    start="2024-01-01 00:00:00",
    end="2024-12-31 23:00:00",
    freq="h"
)

timestamps = timestamps[
    ~(
        (timestamps.month == 2) &
        (timestamps.day == 29)
    )
]

print("PV timestamps:", len(timestamps))


# Repeat timestamps for every location
pv_long["datetime"] = timestamps[
    pv_long["hour"].values
]


# --------------------------------
# 7. Add location information
# --------------------------------

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


# --------------------------------
# 8. Merge with weather
# --------------------------------

combined = pv_long.merge(
    weather,
    on=[
        "datetime",
        "gid"
    ],
    how="inner",
    suffixes=("_pv", "_weather")
)


# --------------------------------
# 9. Sort dataset
# --------------------------------

combined = combined.sort_values(
    ["gid", "datetime"]
).reset_index(drop=True)


# --------------------------------
# 10. Save
# --------------------------------

output_file = (
    "data/combined_2024_pv_weather.csv"
)

combined.to_csv(
    output_file,
    index=False
)


# --------------------------------
# 11. Validation
# --------------------------------

print()
print("--------------------------------")
print("MERGE RESULTS")
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
    "Missing values:",
    combined.isna().sum().sum()
)

print(
    "Expected rows:",
    105 * 8760
)

print(
    "Actual rows:",
    len(combined)
)

print()
print("Columns:")
print(combined.columns.tolist())

print()
print("First 5 rows:")
print(combined.head())

print()
print("--------------------------------")
print("STEP 35 COMPLETED")
print("--------------------------------")

