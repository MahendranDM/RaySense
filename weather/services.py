import logging
import requests

from django.core.cache import cache

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

WEATHER_CACHE_SECONDS = 30 * 60
STALE_CACHE_SECONDS = 24 * 60 * 60
REQUEST_TIMEOUT = 15


def get_weather_forecast(latitude, longitude, forecast_days=7):
    """
    Retrieve hourly weather for RaySense forecasting.

    Try the requested forecast first. If the full request is
    rate-limited, try a shorter one-day hourly request.

    Cache successful responses and reuse them during outages.
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

    location_key = f"{latitude:.4f}:{longitude:.4f}"

    fresh_key = f"raysense_weather_fresh_v5:{location_key}:{forecast_days}"
    stale_key = f"raysense_weather_stale_v5:{location_key}:{forecast_days}"

    cached = cache.get(fresh_key)

    if cached is not None:
        return cached

    stale = cache.get(stale_key)

    field_map = {
        "temperature_2m": "temperature",
        "relative_humidity_2m": "humidity",
        "wind_speed_10m": "wind_speed",
        "wind_direction_10m": "wind_direction",
        "surface_pressure": "pressure",
        "shortwave_radiation": "solar_radiation",
        "cloud_cover": "cloud_cover",
    }

    # Try the requested horizon first, then one day if rate-limited.
    horizons = [forecast_days]

    if forecast_days > 1:
        horizons.append(1)

    last_error = None

    for days in horizons:
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "hourly": ",".join(field_map.keys()),
            "forecast_days": days,
            "timezone": "auto",
        }

        try:
            response = requests.get(
                OPEN_METEO_URL,
                params=params,
                timeout=REQUEST_TIMEOUT,
            )

            if response.status_code == 429:
                last_error = requests.HTTPError(
                    "Open-Meteo rate limit exceeded.",
                    response=response,
                )

                # Try the smaller request, if available.
                continue

            response.raise_for_status()

            data = response.json()
            hourly = data.get("hourly", {})

            times = hourly.get("time", [])

            if not times:
                raise ValueError("No hourly weather data received.")

            records = []

            for index, timestamp in enumerate(times):
                record = {"time": timestamp}

                for api_field, output_field in field_map.items():
                    values = hourly.get(api_field)

                    if not isinstance(values, list) or index >= len(values):
                        raise ValueError(
                            f"Incomplete weather data: {api_field}"
                        )

                    value = values[index]

                    if value is not None and api_field == "surface_pressure":
                        value = value / 10

                    record[output_field] = value

                records.append(record)

            result = {
                "latitude": data.get("latitude", latitude),
                "longitude": data.get("longitude", longitude),
                "elevation": data.get("elevation"),
                "weather": records,
            }

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

            return result

        except (requests.RequestException, ValueError) as error:
            last_error = error
            logger.warning(
                "Weather request failed for %s, horizon %s: %s",
                location_key,
                days,
                error,
            )

    # Never invent weather data. Use only a previously successful response.
    if stale is not None:
        logger.warning("Using cached weather after provider failure.")
        return stale

    raise requests.RequestException(
        "Weather provider is temporarily unavailable. "
        "No previously cached hourly forecast is available."
    ) from last_error