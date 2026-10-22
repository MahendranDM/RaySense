import logging
import time

import requests
from django.core.cache import cache

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
WEATHER_CACHE_SECONDS = 30 * 60
REQUEST_TIMEOUT = 15
MAX_RETRIES = 2


def get_weather_forecast(latitude, longitude, forecast_days=7):
    """Return cached hourly weather data or fetch it from Open-Meteo."""

    latitude = float(latitude)
    longitude = float(longitude)
    forecast_days = int(forecast_days)

    if not -90 <= latitude <= 90:
        raise ValueError("Latitude must be between -90 and 90.")
    if not -180 <= longitude <= 180:
        raise ValueError("Longitude must be between -180 and 180.")
    if not 1 <= forecast_days <= 16:
        raise ValueError("Forecast days must be between 1 and 16.")

    cache_key = (
        f"raysense_weather_v1:"
        f"{latitude:.4f}:{longitude:.4f}:{forecast_days}"
    )

    cached_data = cache.get(cache_key)
    if cached_data is not None:
        return cached_data

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

    last_error = None

    for attempt in range(MAX_RETRIES + 1):
        try:
            response = requests.get(
                OPEN_METEO_URL,
                params=params,
                timeout=REQUEST_TIMEOUT,
            )

            if response.status_code == 429 or response.status_code >= 500:
                if attempt < MAX_RETRIES:
                    retry_after = response.headers.get("Retry-After")
                    try:
                        delay = (
                            min(float(retry_after), 5)
                            if retry_after else 2 ** attempt
                        )
                    except (TypeError, ValueError):
                        delay = 2 ** attempt
                    time.sleep(delay)
                    continue

            response.raise_for_status()
            data = response.json()
            hourly = data.get("hourly")

            if not hourly or not hourly.get("time"):
                raise ValueError("No hourly weather data received.")

            fields = {
                "temperature_2m": "temperature",
                "relative_humidity_2m": "humidity",
                "wind_speed_10m": "wind_speed",
                "wind_direction_10m": "wind_direction",
                "surface_pressure": "pressure",
                "shortwave_radiation": "solar_radiation",
                "cloud_cover": "cloud_cover",
            }

            for field in fields:
                if field not in hourly:
                    raise ValueError(
                        f"Weather response is missing '{field}'."
                    )

            records = []
            for index, time_value in enumerate(hourly["time"]):
                try:
                    record = {"time": time_value}
                    for api_field, output_field in fields.items():
                        value = hourly[api_field][index]
                        if api_field == "surface_pressure":
                            value = value / 10
                        record[output_field] = value
                    records.append(record)
                except (IndexError, TypeError) as error:
                    raise ValueError(
                        "Weather API returned incomplete hourly data."
                    ) from error

            result = {
                "latitude": latitude,
                "longitude": longitude,
                "elevation": data.get("elevation"),
                "weather": records,
            }

            cache.set(cache_key, result, timeout=WEATHER_CACHE_SECONDS)
            return result

        except (requests.RequestException, ValueError) as error:
            last_error = error
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)

    logger.warning(
        "Open-Meteo request failed for %.4f, %.4f: %s",
        latitude, longitude, last_error,
    )
    raise requests.RequestException(
        "Weather service is temporarily unavailable. Please try again later."
    ) from last_error
