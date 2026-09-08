from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from solar.models import SolarSystem
from .models import ForecastRecord
from .serializers import ForecastRecordSerializer
from .services import train_forecasting_model, predict_generation


class ForecastPredictionView(APIView):

    def post(self, request):

        system = SolarSystem.objects.first()

        if system is None:
            return Response(
                {"error": "No solar system found."},
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
                    {"error": f"Missing field: {field}"},
                    status=status.HTTP_400_BAD_REQUEST
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

            # Train the Random Forest model
            model = train_forecasting_model(system)

            # Generate prediction
            prediction = predict_generation(
                model,
                weather_data
            )

            # Save prediction to ForecastRecord
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

            return Response({
                "id": forecast.id,
                "solar_system": system.system_name,
                "forecast_date": forecast.forecast_date,
                "predicted_generation_kwh": round(
                    prediction,
                    2
                ),
                "model": "Random Forest",
            })

        except ValueError as error:
            return Response(
                {"error": str(error)},
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as error:
            return Response(
                {"error": str(error)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
class ForecastRecordViewSet(viewsets.ModelViewSet):

    queryset = ForecastRecord.objects.all().order_by("-forecast_date")
    serializer_class = ForecastRecordSerializer