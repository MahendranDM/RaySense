from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from solar.models import SolarSystem
from .serializers import PerformanceRecordSerializer
from forecasting.models import ForecastRecord
from .models import PerformanceRecord


class PerformanceAnalysisView(APIView):

    def post(self, request):

        forecast_id = request.data.get("forecast_id")
        actual_generation = request.data.get("actual_generation_kwh")

        if not forecast_id:
            return Response(
                {"error": "forecast_id is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if actual_generation is None:
            return Response(
                {"error": "actual_generation_kwh is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            forecast = ForecastRecord.objects.get(
                id=forecast_id
            )

            actual_generation = float(
                actual_generation
            )

            predicted_generation = (
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

            if performance_percentage >= 95:
                performance_status = "Excellent"
            elif performance_percentage >= 85:
                performance_status = "Good"
            elif performance_percentage >= 70:
                performance_status = "Warning"
            else:
                performance_status = "Poor"

            performance = PerformanceRecord.objects.create(
                solar_system=forecast.solar_system,
                forecast=forecast,
                evaluation_date=forecast.forecast_date,
                actual_generation_kwh=actual_generation,
                predicted_generation_kwh=predicted_generation,
                deviation_kwh=round(deviation, 2),
                performance_percentage=round(
                    performance_percentage,
                    2
                ),
                status=performance_status,
            )

            return Response(
                {
                    "id": performance.id,
                    "solar_system": (
                        forecast.solar_system.system_name
                    ),
                    "evaluation_date": (
                        performance.evaluation_date
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
                },
                status=status.HTTP_201_CREATED
            )

        except ForecastRecord.DoesNotExist:
            return Response(
                {"error": "Forecast record not found."},
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