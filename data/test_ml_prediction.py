from forecasting.ml_prediction import predict_generation

print("--------------------------------")
print("RaySense ML Capacity Test")
print("--------------------------------")

# Same weather/location conditions for all tests
weather = {
    "temperature": 30.0,
    "humidity": 70.0,
    "wind_speed": 10.0,
    "wind_direction": 180.0,
    "pressure": 1.01,
    "solar_radiation": 700.0,
    "latitude": 10.196,
    "longitude": 76.386,
    "elevation": 20.0,
    "hour": 12,
    "month": 6,
    "day_of_year": 165,
    "day_of_week": 2,
}

for capacity in [2.0, 3.0, 5.0, 8.0, 10.0]:

    prediction = predict_generation(
        **weather,
        system_capacity_kw=capacity,
    )

    print(
        f"Capacity: {capacity:>4.1f} kW"
        f"  ->  Predicted generation: {prediction:.4f} kWh"
    )

print("--------------------------------")
print("STEP 45 COMPLETED")
print("--------------------------------")