from django.db import models
from solar.models import SolarSystem
from forecasting.models import ForecastRecord


class PerformanceRecord(models.Model):
    solar_system = models.ForeignKey(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="performance_records"
    )

    forecast = models.ForeignKey(
        ForecastRecord,
        on_delete=models.CASCADE,
        related_name="performance_records"
    )

    evaluation_date = models.DateField()

    actual_generation_kwh = models.FloatField()
    predicted_generation_kwh = models.FloatField()

    deviation_kwh = models.FloatField()
    performance_percentage = models.FloatField()

    status = models.CharField(
        max_length=30,
        default="Normal"
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return (
            f"{self.solar_system.system_name} - "
            f"{self.evaluation_date}"
        )