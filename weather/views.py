from rest_framework import viewsets

from .models import WeatherRecord
from .serializers import WeatherRecordSerializer


class WeatherRecordViewSet(viewsets.ModelViewSet):
    queryset = WeatherRecord.objects.all()
    serializer_class = WeatherRecordSerializer