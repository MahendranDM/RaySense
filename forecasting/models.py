from django.db import models
from solar.models import SolarSystem


class ForecastRecord(models.Model):
    solar_system = models.ForeignKey(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="forecast_records"
    )

    forecast_date = models.DateField()

    predicted_generation_kwh = models.FloatField()

    model_name = models.CharField(
        max_length=100,
        default="Random Forest"
    )

    confidence_score = models.FloatField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return (
            f"{self.solar_system.system_name} - "
            f"{self.forecast_date}"
        )