from datetime import datetime

from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from solar.models import SolarSystem
from performance.models import PerformanceRecord
from weather.services import get_weather_forecast

from .models import Alert
from .serializers import AlertSerializer


# ============================================================
# Performance Alert Generation
# ============================================================

class AlertGenerationView(APIView):

    def post(self, request):

        performance_id = request.data.get("performance_id")

        if not performance_id:
            return Response(
                {"error": "performance_id is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            performance = PerformanceRecord.objects.get(
                id=performance_id
            )

            percentage = performance.performance_percentage

            # ------------------------------------------------
            # Determine severity
            # ------------------------------------------------

            if percentage >= 95:
                severity = "Info"
                title = "Excellent Solar Performance"
                message = (
                    f"Solar generation performance is excellent "
                    f"at {percentage}%."
                )

            elif percentage >= 85:
                severity = "Info"
                title = "Good Solar Performance"
                message = (
                    f"Solar generation performance is good "
                    f"at {percentage}%."
                )

            elif percentage >= 70:
                severity = "Warning"
                title = "Low Solar Performance"
                message = (
                    f"Solar generation performance has dropped "
                    f"to {percentage}%. Please monitor the system."
                )

            else:
                severity = "Critical"
                title = "Poor Solar Performance"
                message = (
                    f"Solar generation performance is poor "
                    f"at {percentage}%. Inspection may be required."
                )

            # ------------------------------------------------
            # Create alert
            # ------------------------------------------------

            alert = Alert.objects.create(
                solar_system=performance.solar_system,
                alert_type="Performance",
                severity=severity,
                title=title,
                message=message,
            )

            return Response(
                {
                    "id": alert.id,
                    "solar_system": (
                        alert.solar_system.system_name
                    ),
                    "alert_type": alert.alert_type,
                    "severity": alert.severity,
                    "title": alert.title,
                    "message": alert.message,
                    "is_resolved": alert.is_resolved,
                },
                status=status.HTTP_201_CREATED
            )

        except PerformanceRecord.DoesNotExist:
            return Response(
                {"error": "Performance record not found."},
                status=status.HTTP_404_NOT_FOUND
            )


# ============================================================
# Weather Alert Generation
# ============================================================

class WeatherAlertGenerationView(APIView):

    def post(self, request):

        solar_system_id = request.data.get(
            "solar_system_id"
        )

        try:

            # ------------------------------------------------
            # Get Solar System
            # ------------------------------------------------

            if solar_system_id:

                solar_system = SolarSystem.objects.get(
                    id=solar_system_id
                )

            else:

                solar_system = SolarSystem.objects.first()

                if solar_system is None:
                    return Response(
                        {
                            "error":
                            "No solar system found."
                        },
                        status=status.HTTP_404_NOT_FOUND
                    )

            # ------------------------------------------------
            # Check coordinates
            # ------------------------------------------------

            if (
                solar_system.latitude is None
                or solar_system.longitude is None
            ):
                return Response(
                    {
                        "error":
                        "Solar system latitude and "
                        "longitude are required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ------------------------------------------------
            # Get current and future weather
            # ------------------------------------------------

            weather_data = get_weather_forecast(
                solar_system.latitude,
                solar_system.longitude,
                forecast_days=1,
            )

            weather_records = weather_data.get(
                "weather",
                []
            )

            # ------------------------------------------------
            # Find low solar radiation during daytime
            # ------------------------------------------------

            low_radiation_record = None

            for record in weather_records:

                time_value = record.get("time")

                if not time_value:
                    continue

                record_time = datetime.fromisoformat(
                    time_value
                )

                hour = record_time.hour

                solar_radiation = (
                    record.get("solar_radiation")
                )

                if solar_radiation is None:
                    continue

                # Ignore nighttime
                if hour < 6 or hour >= 18:
                    continue

                # Low solar radiation condition
                if solar_radiation < 150:
                    low_radiation_record = record
                    break

            # ------------------------------------------------
            # No weather problem detected
            # ------------------------------------------------

            if low_radiation_record is None:

                return Response(
                    {
                        "alert_created": False,
                        "message":
                            "No significant low solar "
                            "radiation condition detected.",
                        "solar_system":
                            solar_system.system_name,
                    },
                    status=status.HTTP_200_OK
                )

            # =================================================
            # Prevent duplicate active weather alerts
            # =================================================

            existing_alert = Alert.objects.filter(
                solar_system=solar_system,
                alert_type="Weather",
                title="Low Solar Radiation",
                is_resolved=False,
            ).first()

            if existing_alert:

                return Response(
                    {
                        "alert_created": False,
                        "duplicate": True,
                        "message":
                            "An active weather alert "
                            "already exists.",
                        "alert": {
                            "id": existing_alert.id,
                            "type":
                                existing_alert.alert_type,
                            "severity":
                                existing_alert.severity,
                            "title":
                                existing_alert.title,
                            "message":
                                existing_alert.message,
                            "is_resolved":
                                existing_alert.is_resolved,
                        },
                    },
                    status=status.HTTP_200_OK
                )

            # ------------------------------------------------
            # Create new weather alert
            # ------------------------------------------------

            radiation = low_radiation_record[
                "solar_radiation"
            ]

            alert = Alert.objects.create(
                solar_system=solar_system,
                alert_type="Weather",
                severity="Warning",
                title="Low Solar Radiation",
                message=(
                    f"Low solar radiation of "
                    f"{radiation} W/m² is expected at "
                    f"{low_radiation_record['time']}. "
                    f"This may reduce solar generation."
                ),
            )

            return Response(
                {
                    "alert_created": True,
                    "alert": {
                        "id": alert.id,
                        "solar_system":
                            solar_system.system_name,
                        "type":
                            alert.alert_type,
                        "severity":
                            alert.severity,
                        "title":
                            alert.title,
                        "message":
                            alert.message,
                        "is_resolved":
                            alert.is_resolved,
                    },
                    "weather": {
                        "time":
                            low_radiation_record["time"],
                        "solar_radiation":
                            radiation,
                        "temperature":
                            low_radiation_record[
                                "temperature"
                            ],
                        "humidity":
                            low_radiation_record[
                                "humidity"
                            ],
                    },
                },
                status=status.HTTP_201_CREATED
            )

        except SolarSystem.DoesNotExist:

            return Response(
                {
                    "error":
                        "Solar system not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        except ValueError:

            return Response(
                {
                    "error":
                        "Invalid weather time format."
                },
                status=status.HTTP_400_BAD_REQUEST
            )


# ============================================================
# Alert ViewSet
# ============================================================

class AlertViewSet(viewsets.ModelViewSet):

    queryset = Alert.objects.all().order_by(
        "-alert_date"
    )

    serializer_class = AlertSerializer

    # --------------------------------------------------------
    # Resolve / Unresolve Alert
    # --------------------------------------------------------

    def partial_update(
        self,
        request,
        *args,
        **kwargs
    ):
        """
        Update an alert partially.

        Example:

        PATCH /api/alerts/records/5/

        {
            "is_resolved": true
        }

        This changes the alert from Active to Resolved.
        """

        alert = self.get_object()

        # ----------------------------------------------------
        # Get is_resolved from request
        # ----------------------------------------------------

        is_resolved = request.data.get(
            "is_resolved"
        )

        if is_resolved is None:
            return Response(
                {
                    "error":
                        "is_resolved field is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ----------------------------------------------------
        # Convert string values if necessary
        # ----------------------------------------------------

        if isinstance(is_resolved, str):

            is_resolved = (
                is_resolved.lower() == "true"
            )

        # ----------------------------------------------------
        # Update alert
        # ----------------------------------------------------

        alert.is_resolved = bool(is_resolved)

        alert.save(
            update_fields=["is_resolved"]
        )

        # ----------------------------------------------------
        # Return updated alert
        # ----------------------------------------------------

        serializer = self.get_serializer(
            alert
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK
        )