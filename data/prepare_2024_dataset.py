import pandas as pd


print("--------------------------------")
print("RaySense 2024 Dataset Preparation")
print("--------------------------------")


# -----------------------------
# 1. Load Kerala PV data
# -----------------------------

pv_file = "data/raw/kerala_distpv_2015_2024.csv"

pv = pd.read_csv(pv_file)

print("PV dataset loaded")
print("Shape:", pv.shape)


# -----------------------------
# 2. Load Kerala weather data
# -----------------------------

weather_file = "data/weather/kerala_weather_2024.csv"

weather = pd.read_csv(weather_file)

print("Weather dataset loaded")
print("Shape:", weather.shape)


# -----------------------------
# 3. Convert weather datetime
# -----------------------------

weather["datetime"] = pd.to_datetime(
    weather["datetime"]
)


# -----------------------------
# 4. Inspect PV dataset
# -----------------------------

print()
print("PV columns:")
print(pv.columns[:10].tolist())


print()
print("PV years:")
print(pv["year"].unique())


# -----------------------------
# 5. Select 2024 PV data
# -----------------------------

pv_2024 = pv[
    pv["year"] == 2024
].copy()


print()
print("2024 PV shape:", pv_2024.shape)


# -----------------------------
# 6. Check PV hourly records
# -----------------------------

print()
print("2024 PV hours:", len(pv_2024))


# -----------------------------
# 7. Check weather records
# -----------------------------

print(
    "2024 Weather rows:",
    len(weather)
)


print(
    "Weather locations:",
    weather["gid"].nunique()
)


# -----------------------------
# 8. Display samples
# -----------------------------

print()
print("PV sample:")
print(pv_2024.head())


print()
print("Weather sample:")
print(weather.head())


print()
print("--------------------------------")
print("STEP 33 CHECK COMPLETED")
print("--------------------------------")