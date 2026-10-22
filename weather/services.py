import logging
import requests

from django.core.cache import cache


logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

# Reuse successful responses for 1 hour.
WEATHER_CACHE_SECONDS = 60 * 60

# Keep the last successful response available for up to 24 hours.
STALE_CACHE_SECONDS = 24 * 60 * 60

# Don't repeatedly call Open-Meteo after a rate-limit response.
RATE_LIMIT_COOLDOWN_SECONDS = 15 * 60

REQUEST_TIMEOUT = 15


def get_weather_forecast(latitude, longitude, forecast_days=7):
    """
    Fetch hourly weather forecasts and cache successful results.

    Preserves the complete forecast period for RaySense's
    solar-generation prediction.

    Uses stale cached data when Open-Meteo is unavailable.
    """

    latitude = float(latitude)
    longitude = float(longitude)
    forecast_days = int(forecast_days)

    if not -90 <= latitude <= 90:
        raise ValueError("Invalid latitude.")

    if not -180 <= longitude <= 180:
        raise ValueError("Invalid longitude.")

    if not 1 <= forecast_days <= 16:
        raise ValueError("Forecast days must be between 1 and 16.")

    location_key = (
        f"{latitude:.4f}:{longitude:.4f}:{forecast_days}"
    )

    fresh_key = f"raysense_weather_fresh_v5:{location_key}"
    stale_key = f"raysense_weather_stale_v5:{location_key}"
    cooldown_key = f"raysense_weather_cooldown_v5:{location_key}"

    # 1. Return a fresh cached forecast without making an API call.
    fresh_data = cache.get(fresh_key)

    if fresh_data is not None:
        return fresh_data

    # 2. Retrieve the last successful response, if available.
    stale_data = cache.get(stale_key)

    # 3. During a rate-limit cooldown, do not call Open-Meteo again.
    if cache.get(cooldown_key):
        if stale_data is not None:
            logger.warning(
                "Open-Meteo cooldown active; using cached weather."
            )
            return stale_data

        raise requests.RequestException(
            "Weather provider is temporarily rate-limiting requests. "
            "Please try again later."
        )

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
        ]),
        "forecast_days": forecast_days,
        "timezone": "auto",
    }

    try:
        response = requests.get(
            OPEN_METEO_URL,
            params=params,
            timeout=REQUEST_TIMEOUT,
        )

        if response.status_code == 429:
            cache.set(
                cooldown_key,
                True,
                RATE_LIMIT_COOLDOWN_SECONDS,
            )

            logger.warning(
                "Open-Meteo returned HTTP 429 for %s.",
                location_key,
            )

            if stale_data is not None:
                return stale_data

            raise requests.RequestException(
                "Open-Meteo rate limit reached and no cached "
                "weather forecast is available."
            )

        response.raise_for_status()
        data = response.json()

    except (requests.RequestException, ValueError) as exc:
        logger.warning(
            "Weather request failed for %s: %s",
            location_key,
            exc,
        )

        if stale_data is not None:
            return stale_data

        if isinstance(exc, requests.RequestException):
            raise

        raise requests.RequestException(
            "The weather provider returned invalid JSON."
        ) from exc

    hourly = data.get("hourly")

    if not hourly or not hourly.get("time"):
        if stale_data is not None:
            return stale_data

        raise ValueError("No hourly weather data received.")

    required_fields = [
        "temperature_2m",
        "relative_humidity_2m",
        "wind_speed_10m",
        "wind_direction_10m",
        "surface_pressure",
        "shortwave_radiation",
    ]

    for field in required_fields:
        if field not in hourly:
            if stale_data is not None:
                return stale_data

            raise ValueError(
                f"Weather response is missing {field}."
            )

    weather_records = []

    try:
        for i, time_value in enumerate(hourly["time"]):
            weather_records.append({
                "time": time_value,
                "temperature": hourly["temperature_2m"][i],
                "humidity": hourly["relative_humidity_2m"][i],
                "wind_speed": hourly["wind_speed_10m"][i],
                "wind_direction": hourly["wind_direction_10m"][i],
                # Convert hPa to kPa for the existing model inputs.
                "pressure": hourly["surface_pressure"][i] / 10,
                "solar_radiation": hourly["shortwave_radiation"][i],
            })

    except (IndexError, TypeError) as exc:
        if stale_data is not None:
            return stale_data

        raise ValueError(
            "The weather provider returned incomplete hourly data."
        ) from exc

    result = {
        "latitude": latitude,
        "longitude": longitude,
        "elevation": data.get("elevation"),
        "weather": weather_records,
    }

    # Save both fresh and fallback copies in the configured Django cache.
    cache.set(fresh_key, result, WEATHER_CACHE_SECONDS)
    cache.set(stale_key, result, STALE_CACHE_SECONDS)

    # Successful request: clear the cooldown.
    cache.delete(cooldown_key)

    logger.info(
        "Cached %s hourly weather records for %s.",
        len(weather_records),
        location_key,
    )

    return result

