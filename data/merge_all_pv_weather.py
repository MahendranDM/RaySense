import pandas as pd
import os

print("--------------------------------")
print("RaySense 2015-2024 PV + Weather Merge")
print("--------------------------------")

pv_file = "data/raw/kerala_distpv_2015_2024.csv"
mapping_file = "data/metadata/pv_location_mapping.csv"

# Load PV data
pv = pd.read_csv(pv_file)

# Load location mapping
mapping = pd.read_csv(mapping_file)

point_columns = [
    f"point_{i}"
    for i in range(105)
]

all_years = []

for year in range(2015, 2025):

    print()
    print(f"Processing {year}...")

    weather_file = (
        f"data/weather/yearly/kerala_weather_{year}.csv"
    )

    # Load weather
    weather = pd.read_csv(weather_file)
    weather["datetime"] = pd.to_datetime(
        weather["datetime"]
    )

    # Get PV for this year
    pv_year = pv[
        pv["year"] == year
    ].copy()

    # Convert PV wide → long
    pv_long = pv_year[
        ["hour"] + point_columns
    ].melt(
        id_vars=["hour"],
        var_name="pv_point",
        value_name="pv_capacity_factor"
    )

    # GridLab uses 8760 hourly records
    timestamps = pd.date_range(
        start=f"{year}-01-01 00:00:00",
        periods=8760,
        freq="h"
    )

    # Assign timestamps
    pv_long["datetime"] = timestamps[
        pv_long["hour"].values
    ]

    # Add location information
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

    # Remove Feb 29 from NASA weather for leap years
    # because GridLab uses 8760-hour yearly profiles
    if year % 4 == 0:

        weather = weather[
            ~(
                (weather["datetime"].dt.month == 2)
                &
                (weather["datetime"].dt.day == 29)
            )
        ].copy()

    # Merge PV + weather
    combined = pv_long.merge(
        weather,
        on=["datetime", "gid"],
        how="inner",
        suffixes=("_pv", "_weather")
    )

    combined = combined.sort_values(
        ["gid", "datetime"]
    ).reset_index(drop=True)

    print(
        f"   Rows: {len(combined)}"
    )

    print(
        f"   Locations: {combined['gid'].nunique()}"
    )

    print(
        f"   Missing: {combined.isna().sum().sum()}"
    )

    all_years.append(combined)

print()
print("Combining all years...")

final_data = pd.concat(
    all_years,
    ignore_index=True
)

output_file = (
    "data/combined_2015_2024_pv_weather.csv"
)

final_data.to_csv(
    output_file,
    index=False
)

print()
print("--------------------------------")
print("FINAL DATASET")
print("--------------------------------")

print(
    "Rows:",
    len(final_data)
)

print(
    "Columns:",
    len(final_data.columns)
)

print(
    "Locations:",
    final_data["gid"].nunique()
)

print(
    "Years:",
    sorted(final_data["datetime"].dt.year.unique())
)

print(
    "Missing values:",
    final_data.isna().sum().sum()
)

print(
    "Output:",
    output_file
)

print("--------------------------------")
print("STEP 37 COMPLETED")
print("--------------------------------")