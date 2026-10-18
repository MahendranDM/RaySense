from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from .models import WeatherRecord
from .serializers import WeatherRecordSerializer


class WeatherRecordViewSet(viewsets.ModelViewSet):

    serializer_class = WeatherRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return WeatherRecord.objects.filter(
            solar_system__user=self.request.user
        )