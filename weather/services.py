import requests


OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


def get_weather_forecast(latitude, longitude, forecast_days=7):
    """
    Fetch hourly weather forecast for a solar-system location.

    Returns hourly weather data for solar generation forecasting,
    performance calculations, and weather alerts.
    """

    params = {
        "latitude": latitude,
        "longitude": longitude,
        "hourly": ",".join([
            "temperature_2m",
            "relative_humidity_2m",
            "wind_speed_10m",
            "wind_direction_10m",
            "surface_pressure",
            "shortwave_radiation",
            "cloud_cover",
        ]),
        "forecast_days": forecast_days,
        "timezone": "auto",
    }

    response = requests.get(
        OPEN_METEO_URL,
        params=params,
        timeout=30,
    )

    response.raise_for_status()
    data = response.json()

    hourly = data.get("hourly")

    if not hourly:
        raise ValueError("No hourly weather data received.")

    weather_records = []

    for i, time_value in enumerate(hourly["time"]):
        pressure_kpa = hourly["surface_pressure"][i] / 10

        record = {
            "time": time_value,
            "temperature": hourly["temperature_2m"][i],
            "humidity": hourly["relative_humidity_2m"][i],
            "wind_speed": hourly["wind_speed_10m"][i],
            "wind_direction": hourly["wind_direction_10m"][i],
            "pressure": pressure_kpa,
            "solar_radiation": hourly["shortwave_radiation"][i],
            "cloud_cover": hourly["cloud_cover"][i],
        }

        weather_records.append(record)

    return {
        "latitude": latitude,
        "longitude": longitude,
        "elevation": data.get("elevation"),
        "weather": weather_records,
    }