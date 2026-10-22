import logging
import requests

from django.core.cache import cache

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

WEATHER_CACHE_SECONDS = 30 * 60
STALE_CACHE_SECONDS = 24 * 60 * 60
RATE_LIMIT_COOLDOWN_SECONDS = 5 * 60
REQUEST_TIMEOUT = 15


def get_weather_forecast(latitude, longitude, forecast_days=7):
    """
    Fetch weather from Open-Meteo and cache successful responses.

    Returns fresh cached data when available.
    Falls back to previously cached data during API failures.
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

    fresh_key = f"raysense_weather_fresh_v3:{location_key}"
    stale_key = f"raysense_weather_stale_v3:{location_key}"
    cooldown_key = f"raysense_weather_cooldown_v3:{location_key}"

    # Return previously fetched weather without calling Open-Meteo.
    fresh_data = cache.get(fresh_key)

    if fresh_data is not None:
        return fresh_data

    # Keep old data available even when fresh data expires.
    stale_data = cache.get(stale_key)

    # Do not repeatedly call an API that has rate-limited us.
    if cache.get(cooldown_key):
        if stale_data is not None:
            logger.warning("Using cached weather during API cooldown.")
            return stale_data

        raise requests.RequestException(
            "Weather provider is rate-limited and no cached data exists."
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
            "cloud_cover",
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
                timeout=RATE_LIMIT_COOLDOWN_SECONDS,
            )

            if stale_data is not None:
                logger.warning("Open-Meteo returned 429; using cached weather.")
                return stale_data

            response.raise_for_status()

        response.raise_for_status()

        data = response.json()
        hourly = data.get("hourly")

        if not hourly or not hourly.get("time"):
            raise ValueError("No hourly weather data received.")

        field_map = {
            "temperature_2m": "temperature",
            "relative_humidity_2m": "humidity",
            "wind_speed_10m": "wind_speed",
            "wind_direction_10m": "wind_direction",
            "surface_pressure": "pressure",
            "shortwave_radiation": "solar_radiation",
            "cloud_cover": "cloud_cover",
        }

        records = []
        times = hourly["time"]

        for index, timestamp in enumerate(times):
            record = {"time": timestamp}

            for api_field, output_field in field_map.items():
                values = hourly.get(api_field)

                if values is None or index >= len(values):
                    raise ValueError(
                        f"Incomplete weather data: {api_field}"
                    )

                value = values[index]

                if value is not None and api_field == "surface_pressure":
                    value = value / 10

                record[output_field] = value

            records.append(record)

        result = {
            "latitude": latitude,
            "longitude": longitude,
            "elevation": data.get("elevation"),
            "weather": records,
        }

        # Cache the last successful response for both fresh and stale use.
        cache.set(
            fresh_key,
            result,
            timeout=WEATHER_CACHE_SECONDS,
        )

        cache.set(
            stale_key,
            result,
            timeout=STALE_CACHE_SECONDS,
        )

        cache.delete(cooldown_key)

        return result

    except requests.RequestException as error:
        logger.warning(
            "Open-Meteo request failed for %s: %s",
            location_key,
            error,
        )

        stale_data = cache.get(stale_key)

        if stale_data is not None:
            logger.warning("Using stale cached weather after provider failure.")
            return stale_data

        raise requests.RequestException(
            "Weather service is unavailable and no cached weather exists."
        ) from error