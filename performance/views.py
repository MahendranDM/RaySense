from datetime import datetime, timedelta

from django.utils import timezone

from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import PerformanceRecordSerializer
from .models import PerformanceRecord

from forecasting.models import ForecastRecord
from solar.models import SolarSystem, GenerationRecord
from alerts.models import Alert

from weather.services import get_weather_forecast
from forecasting.ml_prediction import predict_generation


class PerformanceAnalysisView(APIView):

    def post(self, request):

        forecast_id = request.data.get("forecast_id")

        actual_generation = request.data.get(
            "actual_generation_kwh"
        )

        if not forecast_id:
            return Response(
                {
                    "error": "forecast_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if actual_generation is None:
            return Response(
                {
                    "error":
                    "actual_generation_kwh is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            forecast = ForecastRecord.objects.get(
                id=forecast_id
            )

            actual_generation = float(
                actual_generation
            )

            predicted_generation = float(
                forecast.predicted_generation_kwh
            )

            deviation = (
                actual_generation -
                predicted_generation
            )

            if predicted_generation != 0:

                performance_percentage = (
                    actual_generation /
                    predicted_generation
                ) * 100

            else:

                performance_percentage = 0

            # Determine performance status

            if performance_percentage >= 95:

                performance_status = "Excellent"

            elif performance_percentage >= 85:

                performance_status = "Good"

            elif performance_percentage >= 70:

                performance_status = "Warning"

            else:

                performance_status = "Poor"

            # Create performance record

            performance = PerformanceRecord.objects.create(

                solar_system=forecast.solar_system,

                forecast=forecast,

                evaluation_date=forecast.forecast_date,

                actual_generation_kwh=actual_generation,

                predicted_generation_kwh=predicted_generation,

                deviation_kwh=round(
                    deviation,
                    2
                ),

                performance_percentage=round(
                    performance_percentage,
                    2
                ),

                status=performance_status,
            )

            # =================================================
            # AUTOMATIC PERFORMANCE ALERT
            # =================================================

            if performance_percentage >= 95:

                alert_severity = "Info"

                alert_title = (
                    "Excellent Solar Performance"
                )

                alert_message = (
                    f"Solar generation performance is "
                    f"excellent at "
                    f"{round(performance_percentage, 2)}%."
                )

            elif performance_percentage >= 85:

                alert_severity = "Info"

                alert_title = (
                    "Good Solar Performance"
                )

                alert_message = (
                    f"Solar generation performance is "
                    f"good at "
                    f"{round(performance_percentage, 2)}%."
                )

            elif performance_percentage >= 70:

                alert_severity = "Warning"

                alert_title = (
                    "Low Solar Performance"
                )

                alert_message = (
                    f"Solar generation performance has "
                    f"dropped to "
                    f"{round(performance_percentage, 2)}%. "
                    f"Please monitor the system."
                )

            else:

                alert_severity = "Critical"

                alert_title = (
                    "Poor Solar Performance"
                )

                alert_message = (
                    f"Solar generation performance is "
                    f"poor at "
                    f"{round(performance_percentage, 2)}%. "
                    f"Inspection may be required."
                )

            performance_alert = Alert.objects.create(

                solar_system=forecast.solar_system,

                alert_type="Performance",

                severity=alert_severity,

                title=alert_title,

                message=alert_message,
            )

            # =================================================
            # AUTOMATIC GENERATION ALERT
            # =================================================

            generation_alert = None

            if actual_generation <= 0:

                generation_alert = Alert.objects.create(

                    solar_system=forecast.solar_system,

                    alert_type="Generation",

                    severity="Critical",

                    title="Solar Generation Stopped",

                    message=(
                        "No solar energy was generated "
                        "during the evaluated period. "
                        "Please check the solar system."
                    ),
                )

            # =================================================
            # RESPONSE
            # =================================================

            response_data = {

                "id": performance.id,

                "solar_system": (
                    forecast.solar_system.system_name
                ),

                "evaluation_date": (
                    str(performance.evaluation_date)
                ),

                "actual_generation_kwh": (
                    performance.actual_generation_kwh
                ),

                "predicted_generation_kwh": (
                    performance.predicted_generation_kwh
                ),

                "deviation_kwh": (
                    performance.deviation_kwh
                ),

                "performance_percentage": (
                    performance.performance_percentage
                ),

                "status": performance.status,

                "alert": {

                    "id": performance_alert.id,

                    "type": performance_alert.alert_type,

                    "severity": performance_alert.severity,

                    "title": performance_alert.title,

                    "message": performance_alert.message,

                    "is_resolved": (
                        performance_alert.is_resolved
                    ),
                },
            }

            if generation_alert is not None:

                response_data["generation_alert"] = {

                    "id": generation_alert.id,

                    "type": generation_alert.alert_type,

                    "severity": generation_alert.severity,

                    "title": generation_alert.title,

                    "message": generation_alert.message,

                    "is_resolved": (
                        generation_alert.is_resolved
                    ),
                }

            return Response(
                response_data,
                status=status.HTTP_201_CREATED
            )

        except ForecastRecord.DoesNotExist:

            return Response(
                {
                    "error":
                    "Forecast record not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        except ValueError:

            return Response(
                {
                    "error":
                    "actual_generation_kwh must be a number."
                },
                status=status.HTTP_400_BAD_REQUEST
            )


class PerformanceRecordViewSet(viewsets.ModelViewSet):

    queryset = PerformanceRecord.objects.all().order_by(
        "-evaluation_date"
    )

    serializer_class = PerformanceRecordSerializer


class TodayPerformanceView(APIView):
    """
    Calculate today's solar performance.

    Actual generation:
        Sum of today's GenerationRecord values.

    Expected generation:
        Reuses the same weather + XGBoost prediction
        pipeline used by the forecasting system.

    For an ongoing day:
        Compare actual generation so far with the
        expected generation for the elapsed hours.

    Before meaningful solar production:
        Return Pending instead of Poor.
    """

    def get(self, request):

        # -------------------------------------------------
        # Current local date and time
        # -------------------------------------------------

        now = timezone.localtime()

        today = timezone.localdate()

        # -------------------------------------------------
        # Get solar system
        # -------------------------------------------------

        system = SolarSystem.objects.first()

        if system is None:

            return Response(
                {
                    "error":
                    "No solar system found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # -------------------------------------------------
        # Get today's ForecastRecord
        # -------------------------------------------------

        forecast = ForecastRecord.objects.filter(

            solar_system=system,

            forecast_date=today,

        ).order_by("-id").first()

        if forecast is None:

            return Response(
                {
                    "error":
                    "Today's forecast record was not found.",

                    "date": str(today),
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # -------------------------------------------------
        # Actual generation for today
        # -------------------------------------------------

        # IMPORTANT:
        # Django stores DateTimeField values in UTC when
        # USE_TZ=True.
        #
        # Therefore, recorded_at__date=today can compare
        # against the UTC calendar date instead of the
        # user's local Asia/Kolkata date.
        #
        # We explicitly create the local start/end of today.

        local_start = timezone.make_aware(
            datetime.combine(
                today,
                datetime.min.time(),
            )
        )

        local_end = local_start + timedelta(
            days=1
        )

        generation_records = (
            GenerationRecord.objects.filter(

                solar_system=system,

                recorded_at__gte=local_start,

                recorded_at__lt=local_end,
            )
        )

        actual_generation = sum(

            float(record.energy_generated_kwh)

            for record in generation_records

        )

        actual_generation = round(
            actual_generation,
            2
        )

        # -------------------------------------------------
        # Before 06:00:
        # Solar production has not meaningfully started.
        # -------------------------------------------------

        if now.hour < 6:

            performance, created = (
                PerformanceRecord.objects.update_or_create(

                    solar_system=system,

                    forecast=forecast,

                    evaluation_date=today,

                    defaults={

                        "actual_generation_kwh":
                            actual_generation,

                        "predicted_generation_kwh":
                            0.0,

                        "deviation_kwh":
                            0.0,

                        "performance_percentage":
                            0.0,

                        "status":
                            "Pending",
                    },
                )
            )

            return Response(
                {
                    "id": performance.id,

                    "created": created,

                    "solar_system":
                        system.system_name,

                    "evaluation_date":
                        str(today),

                    "actual_generation_kwh":
                        actual_generation,

                    "predicted_generation_kwh":
                        0.0,

                    "full_day_forecast_kwh":
                        round(
                            float(
                                forecast.predicted_generation_kwh
                            ),
                            2
                        ),

                    "deviation_kwh":
                        0.0,

                    "performance_percentage":
                        0.0,

                    "status":
                        "Pending",

                    "evaluation_scope":
                        "Before solar production period",

                    "current_hour":
                        now.hour,

                    "model_name":
                        forecast.model_name,
                },

                status=status.HTTP_200_OK
            )

        # -------------------------------------------------
        # Get current weather forecast.
        #
        # This is the same weather source used by
        # the RaySense forecasting system.
        # -------------------------------------------------

        try:

            weather_data = get_weather_forecast(

                system.latitude,

                system.longitude,

                forecast_days=7,
            )

        except Exception as exc:

            return Response(
                {
                    "error":
                        "Unable to retrieve weather forecast.",

                    "details":
                        str(exc),
                },

                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        weather_records = weather_data.get(
            "weather",
            []
        )

        elevation = weather_data.get(
            "elevation"
        )

        if elevation is None:

            elevation = 0.0

        # -------------------------------------------------
        # Calculate expected generation for elapsed hours
        # -------------------------------------------------

        predicted_generation_so_far = 0.0

        for weather in weather_records:

            time_string = weather.get(
                "time"
            )

            if not time_string:

                continue

            try:

                weather_time = datetime.fromisoformat(
                    time_string
                )

            except ValueError:

                continue

            # -------------------------------------------------
            # Open-Meteo returns local time because the
            # weather service uses timezone="auto".
            # -------------------------------------------------

            if weather_time.date() != today:

                continue

            # -------------------------------------------------
            # Do not include future hours.
            # -------------------------------------------------

            if weather_time.hour > now.hour:

                continue

            # -------------------------------------------------
            # Calendar features required by XGBoost
            # -------------------------------------------------

            hour = weather_time.hour

            month = weather_time.month

            day_of_year = (
                weather_time.timetuple().tm_yday
            )

            day_of_week = (
                weather_time.weekday()
            )

            # -------------------------------------------------
            # Same XGBoost prediction function used by
            # the main forecasting system.
            # -------------------------------------------------

            hourly_prediction = predict_generation(

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

                latitude=float(
                    system.latitude
                ),

                longitude=float(
                    system.longitude
                ),

                elevation=float(
                    elevation
                ),

                hour=hour,

                month=month,

                day_of_year=day_of_year,

                day_of_week=day_of_week,

                system_capacity_kw=float(
                    system.capacity_kw
                ),
            )

            predicted_generation_so_far += (
                hourly_prediction
            )

        predicted_generation_so_far = round(
            predicted_generation_so_far,
            2
        )

        # -------------------------------------------------
        # No meaningful expected generation yet
        # -------------------------------------------------

        if predicted_generation_so_far <= 0:

            performance_percentage = 0.0

            performance_status = "Pending"

            deviation = round(
                actual_generation -
                predicted_generation_so_far,
                2
            )

            evaluation_scope = (
                "No meaningful solar forecast yet"
            )

        else:

            # -------------------------------------------------
            # Compare actual generation with expected
            # generation for the elapsed period.
            # -------------------------------------------------

            deviation = round(

                actual_generation -

                predicted_generation_so_far,

                2
            )

            performance_percentage = (

                actual_generation /

                predicted_generation_so_far

            ) * 100

            performance_percentage = round(
                performance_percentage,
                2
            )

            # -------------------------------------------------
            # Performance classification
            #
            # Only completed solar days are classified.
            # Ongoing days remain Pending.
            # -------------------------------------------------

            if now.hour < 18:

                performance_status = "Pending"

            elif performance_percentage >= 95:

                performance_status = "Excellent"

            elif performance_percentage >= 85:

                performance_status = "Good"

            elif performance_percentage >= 70:

                performance_status = "Warning"

            else:

                performance_status = "Poor"

            # -------------------------------------------------
            # Evaluation scope
            # -------------------------------------------------

            if now.hour >= 18:

                evaluation_scope = (
                    "Completed solar day"
                )

            else:

                evaluation_scope = (
                    "Today's generation so far"
                )

        # -------------------------------------------------
        # Update/create today's performance record
        # -------------------------------------------------

        performance, created = (
            PerformanceRecord.objects.update_or_create(

                solar_system=system,

                forecast=forecast,

                evaluation_date=today,

                defaults={

                    "actual_generation_kwh":
                        actual_generation,

                    "predicted_generation_kwh":
                        predicted_generation_so_far,

                    "deviation_kwh":
                        deviation,

                    "performance_percentage":
                        performance_percentage,

                    "status":
                        performance_status,
                },
            )
        )

        # -------------------------------------------------
        # Response
        # -------------------------------------------------

        return Response(

            {

                "id":
                    performance.id,

                "created":
                    created,

                "solar_system":
                    system.system_name,

                "evaluation_date":
                    str(today),

                "actual_generation_kwh":
                    actual_generation,

                "predicted_generation_kwh":
                    predicted_generation_so_far,

                "full_day_forecast_kwh":
                    round(
                        float(
                            forecast.predicted_generation_kwh
                        ),
                        2
                    ),

                "deviation_kwh":
                    deviation,

                "performance_percentage":
                    performance_percentage,

                "status":
                    performance_status,

                "evaluation_scope":
                    evaluation_scope,

                "current_hour":
                    now.hour,

                "model_name":
                    forecast.model_name,
            },

            status=status.HTTP_200_OK
        )