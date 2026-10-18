from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response

from solar.models import SolarSystem, GenerationRecord
from weather.models import WeatherRecord
from forecasting.models import ForecastRecord
from performance.models import PerformanceRecord
from alerts.models import Alert


@api_view(["GET"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAdminUser])
def admin_user_details_data(request, user_id):
    """Return read-only RaySense records for one selected user."""

    User = get_user_model()
    user = get_object_or_404(User, id=user_id)

    systems = SolarSystem.objects.filter(
        user=user
    ).order_by("-created_at")

    system_data = []

    for system in systems:
        generations = GenerationRecord.objects.filter(
            solar_system=system
        ).order_by("-recorded_at")

        weather_records = WeatherRecord.objects.filter(
            solar_system=system
        ).order_by("-recorded_at")

        forecasts = ForecastRecord.objects.filter(
            solar_system=system
        ).order_by("-forecast_date")

        performances = PerformanceRecord.objects.filter(
            solar_system=system
        ).order_by("-evaluation_date")

        alerts = Alert.objects.filter(
            solar_system=system
        ).order_by("-alert_date")

        system_data.append({
            "id": system.id,
            "system_name": system.system_name,
            "location": system.location,
            "latitude": system.latitude,
            "longitude": system.longitude,
            "capacity_kw": system.capacity_kw,
            "panel_count": system.panel_count,
            "panel_type": system.panel_type,
            "installation_date": (
                system.installation_date.isoformat()
                if system.installation_date else None
            ),
            "electricity_rate": system.electricity_rate,
            "created_at": system.created_at.isoformat(),

            "generation_records": [
                {
                    "id": record.id,
                    "recorded_at": record.recorded_at.isoformat(),
                    "energy_generated_kwh": record.energy_generated_kwh,
                    "power_output_kw": record.power_output_kw,
                }
                for record in generations
            ],

            "weather_records": [
                {
                    "id": record.id,
                    "recorded_at": record.recorded_at.isoformat(),
                    "temperature": record.temperature,
                    "humidity": record.humidity,
                    "cloud_cover": record.cloud_cover,
                    "wind_speed": record.wind_speed,
                    "solar_irradiance": record.solar_irradiance,
                }
                for record in weather_records
            ],

            "forecast_records": [
                {
                    "id": record.id,
                    "forecast_date": record.forecast_date.isoformat(),
                    "predicted_generation_kwh": (
                        record.predicted_generation_kwh
                    ),
                    "model_name": record.model_name,
                    "confidence_score": record.confidence_score,
                }
                for record in forecasts
            ],

            "performance_records": [
                {
                    "id": record.id,
                    "evaluation_date": record.evaluation_date.isoformat(),
                    "actual_generation_kwh": (
                        record.actual_generation_kwh
                    ),
                    "predicted_generation_kwh": (
                        record.predicted_generation_kwh
                    ),
                    "deviation_kwh": record.deviation_kwh,
                    "performance_percentage": (
                        record.performance_percentage
                    ),
                    "status": record.status,
                }
                for record in performances
            ],

            "alerts": [
                {
                    "id": alert.id,
                    "alert_type": alert.alert_type,
                    "severity": alert.severity,
                    "title": alert.title,
                    "message": alert.message,
                    "alert_date": alert.alert_date.isoformat(),
                    "is_resolved": alert.is_resolved,
                }
                for alert in alerts
            ],
        })

    return Response({
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "is_active": user.is_active,
            "date_joined": user.date_joined.isoformat(),
        },
        "total_systems": len(system_data),
        "total_generation_records": sum(
            len(system["generation_records"])
            for system in system_data
        ),
        "total_weather_records": sum(
            len(system["weather_records"])
            for system in system_data
        ),
        "total_forecast_records": sum(
            len(system["forecast_records"])
            for system in system_data
        ),
        "total_performance_records": sum(
            len(system["performance_records"])
            for system in system_data
        ),
        "total_alerts": sum(
            len(system["alerts"])
            for system in system_data
        ),
        "systems": system_data,
    }, status=status.HTTP_200_OK)
