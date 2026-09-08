from django.db import models
from solar.models import SolarSystem


class Alert(models.Model):

    ALERT_TYPES = [
        ("Performance", "Performance"),
        ("Generation", "Generation"),
        ("Weather", "Weather"),
        ("Maintenance", "Maintenance"),
    ]

    SEVERITY_LEVELS = [
        ("Info", "Info"),
        ("Warning", "Warning"),
        ("Critical", "Critical"),
    ]

    solar_system = models.ForeignKey(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="alerts"
    )

    alert_type = models.CharField(
        max_length=30,
        choices=ALERT_TYPES
    )

    severity = models.CharField(
        max_length=20,
        choices=SEVERITY_LEVELS
    )

    title = models.CharField(max_length=200)

    message = models.TextField()

    alert_date = models.DateTimeField(
        auto_now_add=True
    )

    is_resolved = models.BooleanField(
        default=False
    )

    def __str__(self):
        return (
            f"{self.solar_system.system_name} - "
            f"{self.title}"
        )