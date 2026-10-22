import logging

import requests
from django.core.cache import cache

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

# Cache successful weather responses for 30 minutes.
WEATHER_CACHE_SECONDS = 30 * 60

# Keep the last successful response for up to 24 hours.
STALE_CACHE_SECONDS = 24 * 60 * 60

# Pause requests after an HTTP 429 response.
RATE_LIMIT_COOLDOWN_SECONDS = 5 * 60

REQUEST_TIMEOUT = 15


def get_weather_forecast(latitude, longitude, forecast_days=7):
    """
    Fetch hourly weather data from Open-Meteo.

    Behaviour:
    1. Return fresh cached data when available.
    2. Reuse the last successful response during rate limiting
       or temporary provider failures.
    3. Cache successful responses for 30 minutes.
    4. Retain successful responses for up to 24 hours as fallback.

    The returned data format remains compatible with RaySense.
    """

    # ---------------------------------------------------------
    # 1. Validate input
    # ---------------------------------------------------------
    try:
        latitude = float(latitude)
        longitude = float(longitude)
        forecast_days = int(forecast_days)
    except (TypeError, ValueError) as error:
        raise ValueError(
            "Latitude, longitude, and forecast days must be valid numbers."
        ) from error

    if not -90 <= latitude <= 90:
        raise ValueError("Latitude must be between -90 and 90.")

    if not -180 <= longitude <= 180:
        raise ValueError("Longitude must be between -180 and 180.")

    if not 1 <= forecast_days <= 16:
        raise ValueError("Forecast days must be between 1 and 16.")

    # ---------------------------------------------------------
    # 2. Build cache keys
    # ---------------------------------------------------------
    location_key = (
        f"{latitude:.4f}:{longitude:.4f}:{forecast_days}"
    )

    fresh_key = f"raysense_weather_fresh_v2:{location_key}"
    stale_key = f"raysense_weather_stale_v2:{location_key}"
    cooldown_key = f"raysense_weather_cooldown_v2:{location_key}"

    # ---------------------------------------------------------
    # 3. Return fresh cached weather
    # ---------------------------------------------------------
    cached_data = cache.get(fresh_key)

    if cached_data is not None:
        logger.debug("Returning fresh cached weather for %s.", location_key)
        return cached_data

    # Retrieve the last successful response, if one exists.
    stale_data = cache.get(stale_key)

    # ---------------------------------------------------------
    # 4. Respect rate-limit cooldown
    # ---------------------------------------------------------
    if cache.get(cooldown_key):
        if stale_data is not None:
            logger.warning(
                "Weather API cooldown active; returning cached weather."
            )
            return stale_data

        raise requests.RequestException(
            "Weather service is temporarily rate-limited, "
            "and no previously cached weather is available."
        )

    # ---------------------------------------------------------
    # 5. Prepare Open-Meteo request
    # ---------------------------------------------------------
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

        # -----------------------------------------------------
        # 6. Handle HTTP 429 without repeatedly retrying
        # -----------------------------------------------------
        if response.status_code == 429:
            cache.set(
                cooldown_key,
                True,
                timeout=RATE_LIMIT_COOLDOWN_SECONDS,
            )

            if stale_data is not None:
                logger.warning(
                    "Open-Meteo returned HTTP 429; using cached weather."
                )
                return stale_data

            response.raise_for_status()

        response.raise_for_status()

        data = response.json()
        hourly = data.get("hourly")

        if not isinstance(hourly, dict) or not hourly.get("time"):
            raise ValueError("No hourly weather data received.")

        # -----------------------------------------------------
        # 7. Map API fields to RaySense's existing field names
        # -----------------------------------------------------
        fields = {
            "temperature_2m": "temperature",
            "relative_humidity_2m": "humidity",
            "wind_speed_10m": "wind_speed",
            "wind_direction_10m": "wind_direction",
            "surface_pressure": "pressure",
            "shortwave_radiation": "solar_radiation",
            "cloud_cover": "cloud_cover",
        }

        for api_field in fields:
            if api_field not in hourly:
                raise ValueError(
                    f"Weather response is missing '{api_field}'."
                )

        times = hourly["time"]
        records = []

        for index, time_value in enumerate(times):
            record = {"time": time_value}

            for api_field, output_field in fields.items():
                values = hourly[api_field]

                if not isinstance(values, list) or index >= len(values):
                    raise ValueError(
                        f"Incomplete weather data for '{api_field}'."
                    )

                value = values[index]

                # Convert surface pressure from hPa to kPa,
                # preserving the existing RaySense data format.
                if api_field == "surface_pressure":
                    value = value / 10

                record[output_field] = value

            records.append(record)

        result = {
            "latitude": latitude,
            "longitude": longitude,
            "elevation": data.get("elevation"),
            "weather": records,
        }

        # -----------------------------------------------------
        # 8. Cache successful results
        # -----------------------------------------------------
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

        # Clear the cooldown after a successful response.
        cache.delete(cooldown_key)

        logger.info(
            "Fetched and cached %s hourly weather records for %s.",
            len(records),
            location_key,
        )

        return result

    except requests.RequestException as error:
        logger.warning(
            "Open-Meteo request failed for %s: %s",
            location_key,
            error,
        )

        # -----------------------------------------------------
        # 9. Use the last successful response on network failure
        # -----------------------------------------------------
        stale_data = cache.get(stale_key)

        if stale_data is not None:
            logger.warning(
                "Returning previously cached weather after provider failure."
            )
            return stale_data

        raise requests.RequestException(
            "Weather service is temporarily unavailable, "
            "and no previously cached weather is available."
        ) from error

    except ValueError:
        # Invalid or incomplete API data is not silently cached.
        logger.exception(
            "Open-Meteo returned invalid weather data for %s.",
            location_key,
        )

        raise