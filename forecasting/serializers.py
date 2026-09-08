from rest_framework import serializers
from .models import ForecastRecord


class ForecastRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = ForecastRecord
        fields = "__all__"