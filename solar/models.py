from django.db import models
from django.contrib.auth.models import User


class SolarSystem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="solar_systems"
    )
    system_name = models.CharField(max_length=100)
    location = models.CharField(max_length=255)
    capacity_kw = models.FloatField()
    panel_count = models.PositiveIntegerField()
    panel_type = models.CharField(max_length=100, blank=True)
    installation_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.system_name


class GenerationRecord(models.Model):
    solar_system = models.ForeignKey(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="generation_records"
    )
    recorded_at = models.DateTimeField()
    energy_generated_kwh = models.FloatField()
    power_output_kw = models.FloatField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return (
            f"{self.solar_system.system_name} - "
            f"{self.recorded_at}"
        )