from datetime import datetime, timedelta

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from solar.models import SolarSystem, GenerationRecord
from weather.models import WeatherRecord


system = SolarSystem.objects.first()

if system is None:
    print("ERROR: No SolarSystem found.")
    exit()


start = datetime(2026, 8, 1, 10, 0)

for i in range(20):
    recorded_at = start + timedelta(days=i)

    temperature = 27 + (i % 6)
    humidity = 60 + (i % 20)
    cloud_cover = 10 + (i % 50)
    wind_speed = 2 + (i % 5)
    solar_irradiance = 700 + (i * 15)

    energy_generated = (
        solar_irradiance * 0.02
        - cloud_cover * 0.05
        + temperature * 0.1
    )

    if energy_generated < 0:
        energy_generated = 0

    WeatherRecord.objects.get_or_create(
        solar_system=system,
        recorded_at=recorded_at,
        defaults={
            "temperature": temperature,
            "humidity": humidity,
            "cloud_cover": cloud_cover,
            "wind_speed": wind_speed,
            "solar_irradiance": solar_irradiance,
        },
    )

    GenerationRecord.objects.get_or_create(
        solar_system=system,
        recorded_at=recorded_at,
        defaults={
            "energy_generated_kwh": round(energy_generated, 2),
            "power_output_kw": round(energy_generated / 4, 2),
        },
    )


print("Training data generation completed.")
print(
    "Generation records:",
    GenerationRecord.objects.filter(solar_system=system).count(),
)
print(
    "Weather records:",
    WeatherRecord.objects.filter(solar_system=system).count(),
)