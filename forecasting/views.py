from datetime import datetime, timedelta
import math

import requests

from django.utils import timezone

from rest_framework.permissions import IsAuthenticated
from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from solar.models import SolarSystem
from weather.services import get_weather_forecast

from .models import ForecastRecord
from .serializers import ForecastRecordSerializer
from .services import train_forecasting_model, predict_generation
from .ml_prediction import predict_generation as ml_predict_generation


# ============================================================
# COMMON HELPERS
# ============================================================

def maintain_forecast_history(system, today):
    """
    Retain forecasts from the last five completed days,
    respecting the system installation date.

    Today's and future forecasts are retained.
    Missing historical predictions are never fabricated.
    """
    first_history_date = today - timedelta(days=5)

    if system.installation_date:
        first_history_date = max(
            first_history_date,
            system.installation_date,
        )

    ForecastRecord.objects.filter(
        solar_system=system,
        forecast_date__lt=first_history_date,
    ).delete()


# ============================================================
# 1. EXISTING RANDOM FOREST FORECAST API
# ============================================================

class ForecastPredictionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        system = SolarSystem.objects.filter(
            user=request.user
        ).first()

        if system is None:
            return Response(
                {"error": "No solar system found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        required_fields = [
            "temperature",
            "humidity",
            "cloud_cover",
            "wind_speed",
            "solar_irradiance",
        ]

        for field in required_fields:
            if field not in request.data:
                return Response(
                    {"error": f"Missing field: {field}"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        try:
            weather_data = {
                "temperature": float(request.data["temperature"]),
                "humidity": float(request.data["humidity"]),
                "cloud_cover": float(request.data["cloud_cover"]),
                "wind_speed": float(request.data["wind_speed"]),
                "solar_irradiance": float(
                    request.data["solar_irradiance"]
                ),
            }

            forecast_date = request.data.get("forecast_date")

            if not forecast_date:
                return Response(
                    {"error": "forecast_date is required."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            model = train_forecasting_model(system)

            prediction = predict_generation(
                model,
                weather_data,
            )

            forecast = ForecastRecord.objects.update_or_create(
                solar_system=system,
                forecast_date=forecast_date,
                defaults={
                    "predicted_generation_kwh": round(prediction, 2),
                    "model_name": "Random Forest",
                    "confidence_score": None,
                },
            )[0]

            maintain_forecast_history(
                system,
                timezone.localdate(),
            )

            return Response(
                {
                    "id": forecast.id,
                    "solar_system": system.system_name,
                    "forecast_date": forecast.forecast_date,
                    "predicted_generation_kwh": round(prediction, 2),
                    "model": "Random Forest",
                },
                status=status.HTTP_200_OK,
            )

        except (TypeError, ValueError) as error:
            return Response(
                {"error": str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        except Exception:
            return Response(
                {"error": "Unable to generate the forecast."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# ============================================================
# 2. DIRECT XGBOOST ML PREDICTION API
# ============================================================

class MLForecastPredictionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        required_fields = [
            "temperature",
            "humidity",
            "wind_speed",
            "wind_direction",
            "pressure",
            "solar_radiation",
            "latitude",
            "longitude",
            "elevation",
            "hour",
            "month",
            "day_of_year",
            "day_of_week",
            "system_capacity_kw",
        ]

        for field in required_fields:
            if field not in request.data:
                return Response(
                    {"error": f"Missing field: {field}"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        try:
            prediction = ml_predict_generation(
                temperature=float(request.data["temperature"]),
                humidity=float(request.data["humidity"]),
                wind_speed=float(request.data["wind_speed"]),
                wind_direction=float(request.data["wind_direction"]),
                pressure=float(request.data["pressure"]),
                solar_radiation=float(request.data["solar_radiation"]),
                latitude=float(request.data["latitude"]),
                longitude=float(request.data["longitude"]),
                elevation=float(request.data["elevation"]),
                hour=int(request.data["hour"]),
                month=int(request.data["month"]),
                day_of_year=int(request.data["day_of_year"]),
                day_of_week=int(request.data["day_of_week"]),
                system_capacity_kw=float(
                    request.data["system_capacity_kw"]
                ),
            )

            return Response(
                {
                    "predicted_generation_kwh": prediction,
                    "model": "XGBoost",
                },
                status=status.HTTP_200_OK,
            )

        except (TypeError, ValueError) as error:
            return Response(
                {"error": str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        except Exception:
            return Response(
                {"error": "Unable to generate the prediction."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# ============================================================
# 3. AUTOMATIC WEATHER + XGBOOST FORECAST API
# ============================================================

class WeatherMLForecastView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            system = SolarSystem.objects.filter(
                user=request.user
            ).first()

            if system is None:
                return Response(
                    {"error": "No solar system found."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if (
                system.latitude is None
                or system.longitude is None
                or system.capacity_kw is None
            ):
                return Response(
                    {
                        "error": (
                            "Solar system location and capacity "
                            "must be configured."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            latitude = float(system.latitude)
            longitude = float(system.longitude)
            system_capacity_kw = float(system.capacity_kw)

            forecast_data = get_weather_forecast(
                latitude,
                longitude,
                7,
            )

            elevation = forecast_data["elevation"]
            weather_records = forecast_data["weather"]

            if not weather_records:
                return Response(
                    {"error": "No future weather forecast available."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            predictions = []

            for weather in weather_records:
                forecast_time = datetime.fromisoformat(
                    weather["time"]
                )

                prediction = ml_predict_generation(
                    temperature=float(weather["temperature"]),
                    humidity=float(weather["humidity"]),
                    wind_speed=float(weather["wind_speed"]),
                    wind_direction=float(weather["wind_direction"]),
                    pressure=float(weather["pressure"]),
                    solar_radiation=float(weather["solar_radiation"]),
                    latitude=latitude,
                    longitude=longitude,
                    elevation=float(elevation),
                    hour=forecast_time.hour,
                    month=forecast_time.month,
                    day_of_year=forecast_time.timetuple().tm_yday,
                    day_of_week=forecast_time.weekday(),
                    system_capacity_kw=system_capacity_kw,
                )

                predictions.append(
                    {
                        "time": weather["time"],
                        "temperature": weather["temperature"],
                        "humidity": weather["humidity"],
                        "wind_speed": weather["wind_speed"],
                        "wind_direction": weather["wind_direction"],
                        "pressure": weather["pressure"],
                        "solar_radiation": weather["solar_radiation"],
                        "predicted_generation_kwh": prediction,
                    }
                )

            if not predictions:
                return Response(
                    {"error": "No predictions were generated."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            def total_generation(records):
                return round(
                    sum(
                        float(item["predicted_generation_kwh"])
                        for item in records
                    ),
                    2,
                )

            current_date = datetime.fromisoformat(
                predictions[0]["time"]
            ).date()

            tomorrow_date = current_date + timedelta(days=1)
            day_after_tomorrow_date = current_date + timedelta(days=2)

            today_predictions = []
            tomorrow_predictions = []
            day_after_tomorrow_predictions = []

            for item in predictions:
                item_date = datetime.fromisoformat(
                    item["time"]
                ).date()

                if item_date == current_date:
                    today_predictions.append(item)
                elif item_date == tomorrow_date:
                    tomorrow_predictions.append(item)
                elif item_date == day_after_tomorrow_date:
                    day_after_tomorrow_predictions.append(item)

            daily_forecasts = [
                (
                    current_date,
                    total_generation(today_predictions),
                ),
                (
                    tomorrow_date,
                    total_generation(tomorrow_predictions),
                ),
                (
                    day_after_tomorrow_date,
                    total_generation(day_after_tomorrow_predictions),
                ),
            ]

            for forecast_date, generation in daily_forecasts:
                # Only save dates that have prediction records.
                if not any(
                    datetime.fromisoformat(item["time"]).date()
                    == forecast_date
                    for item in predictions
                ):
                    continue

                ForecastRecord.objects.update_or_create(
                    solar_system=system,
                    forecast_date=forecast_date,
                    defaults={
                        "predicted_generation_kwh": generation,
                        "model_name": "XGBoost",
                        "confidence_score": None,
                    },
                )

            maintain_forecast_history(
                system,
                timezone.localdate(),
            )

            return Response(
                {
                    "latitude": latitude,
                    "longitude": longitude,
                    "elevation": elevation,
                    "system_id": system.id,
                    "system_name": system.system_name,
                    "system_location": system.location,
                    "system_capacity_kw": system_capacity_kw,
                    "model": "XGBoost",
                    "forecast_hours": len(predictions),
                    "next_1_hour": {
                        "generation_kwh": total_generation(
                            predictions[:1]
                        )
                    },
                    "next_5_hours": {
                        "generation_kwh": total_generation(
                            predictions[:5]
                        )
                    },
                    "next_12_hours": {
                        "generation_kwh": total_generation(
                            predictions[:12]
                        )
                    },
                    "today": {
                        "date": str(current_date),
                        "generation_kwh": total_generation(
                            today_predictions
                        ),
                    },
                    "tomorrow": {
                        "date": str(tomorrow_date),
                        "generation_kwh": total_generation(
                            tomorrow_predictions
                        ),
                    },
                    "day_after_tomorrow": {
                        "date": str(day_after_tomorrow_date),
                        "generation_kwh": total_generation(
                            day_after_tomorrow_predictions
                        ),
                    },
                    "predictions": predictions,
                },
                status=status.HTTP_200_OK,
            )

        except (ValueError, TypeError) as error:
            return Response(
                {"error": str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        except requests.RequestException:
            return Response(
                {
                    "error": (
                        "Weather service is temporarily unavailable. "
                        "Please try again shortly."
                    )
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        except Exception:
            return Response(
                {
                    "error": (
                        "Unable to generate the weather-based forecast "
                        "at this time."
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# ============================================================
# 4. FORECAST RECORD VIEWSET
# ============================================================

class ForecastRecordViewSet(viewsets.ModelViewSet):
    serializer_class = ForecastRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            ForecastRecord.objects.filter(
                solar_system__user=self.request.user
            )
            .order_by("-forecast_date")
        )