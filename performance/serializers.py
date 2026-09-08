from rest_framework import serializers
from .models import PerformanceRecord


class PerformanceRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = PerformanceRecord
        fields = "__all__"