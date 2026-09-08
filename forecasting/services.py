import pandas as pd

from sklearn.ensemble import RandomForestRegressor

from solar.models import GenerationRecord
from weather.models import WeatherRecord


def train_forecasting_model(solar_system):
    """
    Train a Random Forest model using historical generation
    and weather data for a solar system.
    """

    generation_records = GenerationRecord.objects.filter(
        solar_system=solar_system
    ).order_by("recorded_at")

    weather_records = WeatherRecord.objects.filter(
        solar_system=solar_system
    ).order_by("recorded_at")

    generation_data = list(
        generation_records.values(
            "recorded_at",
            "energy_generated_kwh"
        )
    )

    weather_data = list(
        weather_records.values(
            "recorded_at",
            "temperature",
            "humidity",
            "cloud_cover",
            "wind_speed",
            "solar_irradiance"
        )
    )

    if not generation_data:
        raise ValueError("No generation data available.")

    if not weather_data:
        raise ValueError("No weather data available.")

    generation_df = pd.DataFrame(generation_data)
    weather_df = pd.DataFrame(weather_data)

    generation_df["recorded_at"] = pd.to_datetime(
        generation_df["recorded_at"]
    )

    weather_df["recorded_at"] = pd.to_datetime(
        weather_df["recorded_at"]
    )

    data = pd.merge(
        generation_df,
        weather_df,
        on="recorded_at",
        how="inner"
    )

    if len(data) < 2:
        raise ValueError(
            "At least 2 matching generation and weather records "
            "are required to train the model."
        )

    features = [
        "temperature",
        "humidity",
        "cloud_cover",
        "wind_speed",
        "solar_irradiance",
    ]

    X = data[features]
    y = data["energy_generated_kwh"]

    model = RandomForestRegressor(
        n_estimators=100,
        random_state=42
    )

    model.fit(X, y)

    return model


def predict_generation(model, weather_data):
    """
    Predict solar generation using a trained Random Forest model.
    """

    features = [
        "temperature",
        "humidity",
        "cloud_cover",
        "wind_speed",
        "solar_irradiance",
    ]

    input_data = pd.DataFrame(
        [weather_data],
        columns=features
    )

    prediction = model.predict(input_data)

    return float(prediction[0])