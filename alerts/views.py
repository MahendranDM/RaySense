from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from solar.models import SolarSystem
from performance.models import PerformanceRecord

from .models import Alert
from .serializers import AlertSerializer


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


class AlertViewSet(viewsets.ModelViewSet):

    queryset = Alert.objects.all().order_by("-alert_date")
    serializer_class = AlertSerializer