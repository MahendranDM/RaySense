from rest_framework import viewsets

from .models import SolarSystem, GenerationRecord
from .serializers import (
    SolarSystemSerializer,
    GenerationRecordSerializer,
)


class SolarSystemViewSet(viewsets.ModelViewSet):
    queryset = SolarSystem.objects.all()
    serializer_class = SolarSystemSerializer


class GenerationRecordViewSet(viewsets.ModelViewSet):
    queryset = GenerationRecord.objects.all()
    serializer_class = GenerationRecordSerializer