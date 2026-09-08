from django.db import models
from solar.models import SolarSystem


class WeatherRecord(models.Model):
    solar_system = models.ForeignKey(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="weather_records"
    )
    recorded_at = models.DateTimeField()

    temperature = models.FloatField()
    humidity = models.FloatField()
    cloud_cover = models.FloatField()
    wind_speed = models.FloatField()
    solar_irradiance = models.FloatField()

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.solar_system.system_name} - {self.recorded_at}"