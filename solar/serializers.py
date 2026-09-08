from rest_framework import serializers

from .models import SolarSystem, GenerationRecord


class SolarSystemSerializer(serializers.ModelSerializer):
    class Meta:
        model = SolarSystem
        fields = "__all__"


class GenerationRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = GenerationRecord
        fields = "__all__"