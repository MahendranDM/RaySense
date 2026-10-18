from datetime import datetime, timedelta
import os
import sys

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from django.contrib.auth import get_user_model
from solar.models import SolarSystem, GenerationRecord
from weather.models import WeatherRecord


User = get_user_model()

# Optional: specify a username when running the script.
# Example: python create_training_data.py raysense_test
if len(sys.argv) > 1:
    username = sys.argv[1]
    user = User.objects.filter(username=username).first()

    if user is None:
        print(f"ERROR: User '{username}' was not found.")
        sys.exit(1)
else:
    # Never select an administrator automatically.
    user = User.objects.filter(
        is_superuser=False,
        is_staff=False,
    ).order_by("id").first()

    if user is None:
        print("ERROR: No regular user found.")
        sys.exit(1)

if user.is_superuser or user.is_staff:
    print("ERROR: Training data cannot be generated for an admin/staff user.")
    sys.exit(1)

system = SolarSystem.objects.filter(user=user).order_by("id").first()

if system is None:
    print(f"ERROR: User '{user.username}' has no solar system.")
    sys.exit(1)

print(f"Generating demonstration data for user: {user.username}")
print(f"Solar system: {system.system_name} (ID: {system.id})")

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

    energy_generated = max(energy_generated, 0)

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

print("Demonstration data generation completed.")
print(
    "Generation records:",
    GenerationRecord.objects.filter(solar_system=system).count(),
)
print(
    "Weather records:",
    WeatherRecord.objects.filter(solar_system=system).count(),
)