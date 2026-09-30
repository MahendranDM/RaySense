from datetime import datetime, timedelta

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
# 1. EXISTING RANDOM FOREST FORECAST API
# ============================================================

class ForecastPredictionView(APIView):

    def post(self, request):

        system = SolarSystem.objects.first()

        if system is None:
            return Response(
                {
                    "error": "No solar system found."
                },
                status=status.HTTP_404_NOT_FOUND
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
                    {
                        "error": f"Missing field: {field}"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

        try:

            weather_data = {
                "temperature": float(
                    request.data["temperature"]
                ),

                "humidity": float(
                    request.data["humidity"]
                ),

                "cloud_cover": float(
                    request.data["cloud_cover"]
                ),

                "wind_speed": float(
                    request.data["wind_speed"]
                ),

                "solar_irradiance": float(
                    request.data["solar_irradiance"]
                ),
            }

            # Train existing Random Forest model
            model = train_forecasting_model(system)

            # Generate prediction
            prediction = predict_generation(
                model,
                weather_data
            )

            # Save prediction
            forecast = ForecastRecord.objects.create(
                solar_system=system,

                forecast_date=request.data.get(
                    "forecast_date"
                ),

                predicted_generation_kwh=round(
                    prediction,
                    2
                ),

                model_name="Random Forest",

                confidence_score=None,
            )

            return Response(
                {
                    "id": forecast.id,

                    "solar_system": system.system_name,

                    "forecast_date":
                        forecast.forecast_date,

                    "predicted_generation_kwh":
                        round(
                            prediction,
                            2
                        ),

                    "model": "Random Forest",
                },
                status=status.HTTP_200_OK
            )

        except ValueError as error:

            return Response(
                {
                    "error": str(error)
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as error:

            return Response(
                {
                    "error": str(error)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ============================================================
# 2. DIRECT XGBOOST ML PREDICTION API
# ============================================================

class MLForecastPredictionView(APIView):

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

        # Check required fields
        for field in required_fields:

            if field not in request.data:

                return Response(
                    {
                        "error": f"Missing field: {field}"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

        try:

            prediction = ml_predict_generation(

                temperature=float(
                    request.data["temperature"]
                ),

                humidity=float(
                    request.data["humidity"]
                ),

                wind_speed=float(
                    request.data["wind_speed"]
                ),

                wind_direction=float(
                    request.data["wind_direction"]
                ),

                pressure=float(
                    request.data["pressure"]
                ),

                solar_radiation=float(
                    request.data["solar_radiation"]
                ),

                latitude=float(
                    request.data["latitude"]
                ),

                longitude=float(
                    request.data["longitude"]
                ),

                elevation=float(
                    request.data["elevation"]
                ),

                hour=int(
                    request.data["hour"]
                ),

                month=int(
                    request.data["month"]
                ),

                day_of_year=int(
                    request.data["day_of_year"]
                ),

                day_of_week=int(
                    request.data["day_of_week"]
                ),

                system_capacity_kw=float(
                    request.data["system_capacity_kw"]
                ),
            )

            return Response(
                {
                    "predicted_generation_kwh":
                        prediction,

                    "model": "XGBoost",
                },
                status=status.HTTP_200_OK
            )

        except ValueError as error:

            return Response(
                {
                    "error": str(error)
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as error:

            return Response(
                {
                    "error": str(error)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ============================================================
# 3. AUTOMATIC WEATHER + XGBOOST FORECAST API
#
# SolarSystem database
#        ↓
# latitude / longitude / capacity
#        ↓
# Weather API
#        ↓
# XGBoost
#        ↓
# Hourly Forecast
#        ↓
# Daily ForecastRecord
# ============================================================

class WeatherMLForecastView(APIView):

    def get(self, request):

        try:

            # ------------------------------------------------
            # Get the solar system from database
            # ------------------------------------------------

            system = SolarSystem.objects.first()

            if system is None:

                return Response(
                    {
                        "error":
                            "No solar system found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # ------------------------------------------------
            # Get latitude from database
            # ------------------------------------------------

            if system.latitude is None:

                return Response(
                    {
                        "error":
                            "Solar system latitude is not configured."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ------------------------------------------------
            # Get longitude from database
            # ------------------------------------------------

            if system.longitude is None:

                return Response(
                    {
                        "error":
                            "Solar system longitude is not configured."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ------------------------------------------------
            # Get system capacity from database
            # ------------------------------------------------

            if system.capacity_kw is None:

                return Response(
                    {
                        "error":
                            "Solar system capacity is not configured."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            latitude = float(
                system.latitude
            )

            longitude = float(
                system.longitude
            )

            system_capacity_kw = float(
                system.capacity_kw
            )

            # ------------------------------------------------
            # Get 7 days of future weather
            # ------------------------------------------------

            forecast_data = get_weather_forecast(
                latitude,
                longitude,
                7
            )

            elevation = forecast_data[
                "elevation"
            ]

            weather_records = forecast_data[
                "weather"
            ]

            if not weather_records:

                return Response(
                    {
                        "error":
                            "No future weather forecast available."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            predictions = []

            # ------------------------------------------------
            # XGBoost prediction for every future hour
            # ------------------------------------------------

            for weather in weather_records:

                forecast_time = datetime.fromisoformat(
                    weather["time"]
                )

                prediction = ml_predict_generation(

                    temperature=float(
                        weather["temperature"]
                    ),

                    humidity=float(
                        weather["humidity"]
                    ),

                    wind_speed=float(
                        weather["wind_speed"]
                    ),

                    wind_direction=float(
                        weather["wind_direction"]
                    ),

                    pressure=float(
                        weather["pressure"]
                    ),

                    solar_radiation=float(
                        weather["solar_radiation"]
                    ),

                    latitude=latitude,

                    longitude=longitude,

                    elevation=float(
                        elevation
                    ),

                    hour=forecast_time.hour,

                    month=forecast_time.month,

                    day_of_year=
                        forecast_time
                        .timetuple()
                        .tm_yday,

                    day_of_week=
                        forecast_time.weekday(),

                    system_capacity_kw=
                        system_capacity_kw,
                )

                predictions.append(
                    {
                        "time":
                            weather["time"],

                        "temperature":
                            weather["temperature"],

                        "humidity":
                            weather["humidity"],

                        "wind_speed":
                            weather["wind_speed"],

                        "wind_direction":
                            weather["wind_direction"],

                        "pressure":
                            weather["pressure"],

                        "solar_radiation":
                            weather[
                                "solar_radiation"
                            ],

                        "predicted_generation_kwh":
                            prediction,
                    }
                )

            # ------------------------------------------------
            # Forecast horizon calculations
            # ------------------------------------------------

            next_1_hour = predictions[:1]

            next_5_hours = predictions[:5]

            next_12_hours = predictions[:12]

            # ------------------------------------------------
            # Determine dates
            # ------------------------------------------------

            first_forecast_time = datetime.fromisoformat(
                predictions[0]["time"]
            )

            current_date = (
                first_forecast_time.date()
            )

            tomorrow_date = (
                current_date +
                timedelta(days=1)
            )

            day_after_tomorrow_date = (
                current_date +
                timedelta(days=2)
            )

            # ------------------------------------------------
            # Today's predictions
            # ------------------------------------------------

            today_predictions = []

            tomorrow_predictions = []

            day_after_tomorrow_predictions = []

            for item in predictions:

                item_time = datetime.fromisoformat(
                    item["time"]
                )

                item_date = item_time.date()

                if item_date == current_date:

                    today_predictions.append(
                        item
                    )

                elif item_date == tomorrow_date:

                    tomorrow_predictions.append(
                        item
                    )

                elif (
                    item_date ==
                    day_after_tomorrow_date
                ):

                    day_after_tomorrow_predictions.append(
                        item
                    )

            # ------------------------------------------------
            # Helper function
            # ------------------------------------------------

            def total_generation(records):

                return round(
                    sum(
                        float(
                            item[
                                "predicted_generation_kwh"
                            ]
                        )
                        for item in records
                    ),
                    2
                )

            # ------------------------------------------------
            # Save today's remaining XGBoost forecast
            # ------------------------------------------------

            today_generation = total_generation(
                today_predictions
            )

            ForecastRecord.objects.update_or_create(
                solar_system=system,
                forecast_date=current_date,
                defaults={
                    "predicted_generation_kwh":
                        today_generation,

                    "model_name":
                        "XGBoost",

                    "confidence_score":
                        None,
                },
            )

            # ------------------------------------------------
            # Save tomorrow's XGBoost forecast
            # ------------------------------------------------

            tomorrow_generation = total_generation(
                tomorrow_predictions
            )

            ForecastRecord.objects.update_or_create(
                solar_system=system,
                forecast_date=tomorrow_date,
                defaults={
                    "predicted_generation_kwh":
                        tomorrow_generation,

                    "model_name":
                        "XGBoost",

                    "confidence_score":
                        None,
                },
            )

            # ------------------------------------------------
            # Save day-after-tomorrow XGBoost forecast
            # ------------------------------------------------

            day_after_tomorrow_generation = total_generation(
                day_after_tomorrow_predictions
            )

            ForecastRecord.objects.update_or_create(
                solar_system=system,
                forecast_date=day_after_tomorrow_date,
                defaults={
                    "predicted_generation_kwh":
                        day_after_tomorrow_generation,

                    "model_name":
                        "XGBoost",

                    "confidence_score":
                        None,
                },
            )

            # ------------------------------------------------
            # Build response
            # ------------------------------------------------

            return Response(
                {
                    # ----------------------------
                    # Location
                    # ----------------------------

                    "latitude":
                        latitude,

                    "longitude":
                        longitude,

                    "elevation":
                        elevation,

                    # ----------------------------
                    # System
                    # ----------------------------

                    "system_id":
                        system.id,

                    "system_name":
                        system.system_name,

                    "system_location":
                        system.location,

                    "system_capacity_kw":
                        system_capacity_kw,

                    # ----------------------------
                    # Model
                    # ----------------------------

                    "model":
                        "XGBoost",

                    "forecast_hours":
                        len(predictions),

                    # ----------------------------
                    # Next 1 hour
                    # ----------------------------

                    "next_1_hour": {
                        "generation_kwh":
                            total_generation(
                                next_1_hour
                            )
                    },

                    # ----------------------------
                    # Next 5 hours
                    # ----------------------------

                    "next_5_hours": {
                        "generation_kwh":
                            total_generation(
                                next_5_hours
                            )
                    },

                    # ----------------------------
                    # Next 12 hours
                    # ----------------------------

                    "next_12_hours": {
                        "generation_kwh":
                            total_generation(
                                next_12_hours
                            )
                    },

                    # ----------------------------
                    # Today
                    # ----------------------------

                    "today": {
                        "date":
                            str(
                                current_date
                            ),

                        "generation_kwh":
                            today_generation
                    },

                    # ----------------------------
                    # Tomorrow
                    # ----------------------------

                    "tomorrow": {
                        "date":
                            str(
                                tomorrow_date
                            ),

                        "generation_kwh":
                            total_generation(
                                tomorrow_predictions
                            )
                    },

                    # ----------------------------
                    # Day after tomorrow
                    # ----------------------------

                    "day_after_tomorrow": {
                        "date":
                            str(
                                day_after_tomorrow_date
                            ),

                        "generation_kwh":
                            total_generation(
                                day_after_tomorrow_predictions
                            )
                    },

                    # ----------------------------
                    # Hourly predictions
                    # ----------------------------

                    "predictions":
                        predictions,
                },

                status=status.HTTP_200_OK
            )

        except ValueError as error:

            return Response(
                {
                    "error": str(error)
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as error:

            return Response(
                {
                    "error": str(error)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ============================================================
# 4. FORECAST RECORD VIEWSET
# ============================================================

class ForecastRecordViewSet(
    viewsets.ModelViewSet
):

    queryset = (
        ForecastRecord.objects.all()
        .order_by("-forecast_date")
    )

    serializer_class = ForecastRecordSerializer