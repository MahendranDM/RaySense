from datetime import datetime

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from solar.models import SolarSystem
from weather.models import WeatherRecord
from weather.services import get_weather_forecast


class Command(BaseCommand):
    help = "Refresh hourly weather forecasts for all solar systems."

    def handle(self, *args, **options):
        systems = SolarSystem.objects.all()

        if not systems.exists():
            self.stdout.write(
                self.style.WARNING("No solar systems found.")
            )
            return

        total_created = 0
        total_updated = 0
        failures = 0

        for system in systems:
            self.stdout.write(
                f"Fetching weather for {system.system_name} "
                f"({system.location})..."
            )

            try:
                result = get_weather_forecast(
                    latitude=system.latitude,
                    longitude=system.longitude,
                    forecast_days=7,
                )

                created_count = 0
                updated_count = 0

                for item in result["weather"]:
                    recorded_at = datetime.fromisoformat(item["time"])

                    if timezone.is_naive(recorded_at):
                        recorded_at = timezone.make_aware(recorded_at)

                    _, created = WeatherRecord.objects.update_or_create(
                        solar_system=system,
                        recorded_at=recorded_at,
                        defaults={
                            "temperature": float(item["temperature"]),
                            "humidity": float(item["humidity"]),
                            "cloud_cover": float(item["cloud_cover"]),
                            "wind_speed": float(item["wind_speed"]),
                            "solar_irradiance": float(
                                item["solar_radiation"]
                            ),
                        },
                    )

                    if created:
                        created_count += 1
                    else:
                        updated_count += 1

                total_created += created_count
                total_updated += updated_count

                self.stdout.write(
                    self.style.SUCCESS(
                        f"Updated {system.system_name}: "
                        f"{created_count} new, "
                        f"{updated_count} refreshed."
                    )
                )

            except Exception as exc:
                failures += 1
                self.stderr.write(
                    self.style.ERROR(
                        f"Failed for {system.system_name}: "
                        f"{type(exc).__name__}: {exc}"
                    )
                )

        self.stdout.write(
            f"\nWeather refresh finished. "
            f"New records: {total_created}; "
            f"refreshed records: {total_updated}; "
            f"failed systems: {failures}."
        )

        if failures:
            raise CommandError(
                f"Weather refresh failed for {failures} solar system(s)."
            )
