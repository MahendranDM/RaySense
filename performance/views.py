from datetime import timedelta
import math

from django.utils import timezone

from rest_framework import status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import PerformanceRecord
from .serializers import PerformanceRecordSerializer

from forecasting.models import ForecastRecord
from solar.models import SolarSystem, GenerationRecord
from alerts.models import Alert


# ============================================================
# COMMON HELPERS
# ============================================================

def safe_float(value, default=0.0):
    """Convert a value to a finite float."""
    try:
        number = float(value)
        return number if math.isfinite(number) else default
    except (TypeError, ValueError):
        return default


def get_forecast_achievement(actual, predicted):
    """Calculate generation as a percentage of the forecast."""
    if predicted <= 0:
        return 0.0

    return round((actual / predicted) * 100, 2)


def get_deviation(actual, predicted):
    """Positive means above forecast; negative means below."""
    return round(actual - predicted, 2)


def get_performance_status(percentage):
    """Classify forecast achievement."""
    if percentage >= 95:
        return "Excellent"
    if percentage >= 85:
        return "Good"
    if percentage >= 70:
        return "Warning"
    return "Poor"


def serialize_alert(alert):
    if alert is None:
        return None

    return {
        "id": alert.id,
        "type": alert.alert_type,
        "severity": alert.severity,
        "title": alert.title,
        "message": alert.message,
        "is_resolved": alert.is_resolved,
    }


# ============================================================
# PERFORMANCE ANALYSIS API
# ============================================================

class PerformanceAnalysisView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        forecast_id = request.data.get("forecast_id")
        actual_value = request.data.get("actual_generation_kwh")
        data_source = str(
            request.data.get("data_source", "")
        ).strip().upper()

        if not forecast_id:
            return Response(
                {"error": "forecast_id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if actual_value is None:
            return Response(
                {"error": "actual_generation_kwh is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if data_source not in ("ACTUAL", "SIMULATED"):
            return Response(
                {
                    "error": (
                        "data_source must be ACTUAL or SIMULATED."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            actual = float(actual_value)
        except (TypeError, ValueError):
            return Response(
                {"error": "Generation must be a valid number."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not math.isfinite(actual) or actual < 0:
            return Response(
                {
                    "error": (
                        "Generation must be finite and "
                        "greater than or equal to zero."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            forecast = ForecastRecord.objects.get(
                id=forecast_id,
                solar_system__user=request.user,
            )
        except ForecastRecord.DoesNotExist:
            return Response(
                {"error": "Forecast record not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        predicted = safe_float(
            forecast.predicted_generation_kwh,
            default=-1,
        )

        if predicted < 0:
            return Response(
                {"error": "The forecast value is invalid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        percentage = get_forecast_achievement(actual, predicted)
        deviation = get_deviation(actual, predicted)

        if data_source == "SIMULATED":
            performance_status = "SIMULATED"
        elif predicted <= 0:
            performance_status = "Pending"
        else:
            performance_status = get_performance_status(percentage)

        performance = PerformanceRecord.objects.create(
            solar_system=forecast.solar_system,
            forecast=forecast,
            evaluation_date=forecast.forecast_date,
            actual_generation_kwh=round(actual, 2),
            predicted_generation_kwh=round(predicted, 2),
            deviation_kwh=deviation,
            performance_percentage=percentage,
            status=performance_status,
        )

        performance_alert = None
        generation_alert = None

        # Do not generate operational alerts from demonstration data.
        if data_source == "ACTUAL" and predicted > 0:

            if percentage >= 95:
                severity = "Info"
                title = "High Forecast Achievement"
                message = (
                    f"Generation reached {percentage:.2f}% "
                    "of the forecast."
                )
            elif percentage >= 85:
                severity = "Info"
                title = "Good Forecast Achievement"
                message = (
                    f"Generation reached {percentage:.2f}% "
                    "of the forecast."
                )
            elif percentage >= 70:
                severity = "Warning"
                title = "Below-Forecast Generation"
                message = (
                    f"Generation reached {percentage:.2f}% "
                    "of the forecast. Monitor the system."
                )
            else:
                severity = "Critical"
                title = "Low Solar Generation"
                message = (
                    f"Generation reached only {percentage:.2f}% "
                    "of the forecast. Check the system."
                )

            performance_alert = Alert.objects.create(
                solar_system=forecast.solar_system,
                alert_type="Performance",
                severity=severity,
                title=title,
                message=message,
            )

            if actual <= 0:
                generation_alert = Alert.objects.create(
                    solar_system=forecast.solar_system,
                    alert_type="Generation",
                    severity="Critical",
                    title="Solar Generation Stopped",
                    message=(
                        "No generation was recorded. Check the "
                        "system and measurement source."
                    ),
                )

        return Response(
            {
                "id": performance.id,
                "solar_system": forecast.solar_system.system_name,
                "evaluation_date": str(performance.evaluation_date),
                "actual_generation_kwh": performance.actual_generation_kwh,
                "predicted_generation_kwh": (
                    performance.predicted_generation_kwh
                ),
                "deviation_kwh": performance.deviation_kwh,
                "performance_percentage": percentage,
                "forecast_achievement_percentage": percentage,
                "status": performance.status,
                "data_source": data_source,
                "is_simulated": data_source == "SIMULATED",
                "verified_actual_data": False,
                "model_name": forecast.model_name,
                "alert": serialize_alert(performance_alert),
                "generation_alert": serialize_alert(generation_alert),
            },
            status=status.HTTP_201_CREATED,
        )


# ============================================================
# PERFORMANCE RECORDS API
# ============================================================

class PerformanceRecordViewSet(viewsets.ModelViewSet):
    serializer_class = PerformanceRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            PerformanceRecord.objects.filter(
                solar_system__user=self.request.user
            )
            .select_related("solar_system", "forecast")
            .order_by("-evaluation_date", "-id")
        )


# ============================================================
# LATEST PERFORMANCE API
# ============================================================

class TodayPerformanceView(APIView):
    """
    Compare the previous completed day's generation
    against a forecast for the same date.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        from datetime import datetime, time
        from django.db.models import Q

        today = timezone.localdate()
        evaluation_date = today - timedelta(days=1)

        system = (
            SolarSystem.objects.filter(user=request.user)
            .order_by("id")
            .first()
        )

        if system is None:
            return Response(
                {"error": "No solar system found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        current_timezone = timezone.get_current_timezone()

        day_start = timezone.make_aware(
            datetime.combine(evaluation_date, time.min),
            current_timezone,
        )

        next_day_start = timezone.make_aware(
            datetime.combine(
                evaluation_date + timedelta(days=1),
                time.min,
            ),
            current_timezone,
        )

        generation_date_filter = (
            Q(generation_date=evaluation_date)
            | Q(
                generation_date__isnull=True,
                recorded_at__gte=day_start,
                recorded_at__lt=next_day_start,
            )
        )

        actual_records = GenerationRecord.objects.filter(
            Q(solar_system=system)
            & generation_date_filter
            & Q(data_source="ACTUAL")
        )

        if actual_records.exists():
            records = actual_records
            data_source = "ACTUAL"
            is_simulated = False
        else:
            records = GenerationRecord.objects.filter(
                Q(solar_system=system)
                & generation_date_filter
                & Q(data_source="SIMULATED")
            )

            data_source = (
                "SIMULATED" if records.exists() else None
            )
            is_simulated = data_source == "SIMULATED"

        has_records = records.exists()

        generation_total = round(
            sum(
                safe_float(record.energy_generated_kwh)
                for record in records
            ),
            2,
        )

        # Prefer the exact-date forecast; fall back to the closest
        # available forecast only for simulated demonstration data.
        forecast = (
            ForecastRecord.objects.filter(
                solar_system=system,
                forecast_date=evaluation_date,
            )
            .order_by("-id")
            .first()
        )

        if forecast is None and is_simulated:
            forecast = (
                ForecastRecord.objects.filter(
                    solar_system=system,
                    forecast_date__lte=evaluation_date,
                    model_name__icontains="simulated",
                )
                .order_by("-forecast_date", "-id")
                .first()
            )

        # Do not compare generation against a forecast from another day.
        if forecast is None:
            return Response(
                {
                    "solar_system": system.system_name,
                    "evaluation_date": str(evaluation_date),
                    "date": str(evaluation_date),
                    "actual_generation_kwh": generation_total,
                    "recorded_generation_kwh": generation_total,
                    "predicted_generation_kwh": None,
                    "full_day_forecast_kwh": None,
                    "deviation_kwh": None,
                    "performance_percentage": None,
                    "forecast_achievement_percentage": None,
                    "status": "Pending",
                    "evaluation_scope": (
                        "Demonstration data; not verified real-world "
                        "production."
                        if is_simulated
                        else "Forecast unavailable for this evaluation date."
                    ),
                    "actual_data_available": (
                        has_records and not is_simulated
                    ),
                    "generation_data_available": has_records,
                    "data_source": data_source,
                    "is_simulated": is_simulated,
                    "verified_actual_data": False,
                    "model_name": None,
                    "forecast_available": False,
                    "message": (
                        "No forecast is available for the evaluation date. "
                        "Generate a forecast for this date to calculate "
                        "performance."
                    ),
                },
                status=status.HTTP_200_OK,
            )

        predicted = round(
            safe_float(forecast.predicted_generation_kwh),
            2,
        )

        if has_records and predicted > 0:
            percentage = get_forecast_achievement(
                generation_total,
                predicted,
            )

            deviation = get_deviation(
                generation_total,
                predicted,
            )

            result_status = (
                "SIMULATED"
                if is_simulated
                else get_performance_status(percentage)
            )
        else:
            percentage = None
            deviation = None
            result_status = "Pending"

        return Response(
            {
                "solar_system": system.system_name,
                "evaluation_date": str(evaluation_date),
                "date": str(evaluation_date),
                "actual_generation_kwh": generation_total,
                "recorded_generation_kwh": generation_total,
                "predicted_generation_kwh": predicted,
                "full_day_forecast_kwh": predicted,
                "deviation_kwh": deviation,
                "performance_percentage": percentage,
                "forecast_achievement_percentage": percentage,
                "status": result_status,
                "evaluation_scope": (
                    "Demonstration data; not verified real-world "
                    "production."
                    if is_simulated
                    else "Generation compared with the forecast."
                ),
                "actual_data_available": (
                    has_records and not is_simulated
                ),
                "generation_data_available": has_records,
                "data_source": data_source,
                "is_simulated": is_simulated,
                "verified_actual_data": False,
                "model_name": forecast.model_name,
                "forecast_available": True,
                "message": None,
            },
            status=status.HTTP_200_OK,
        )