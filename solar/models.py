from django.db import models
from django.contrib.auth.models import User


class SolarSystem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="solar_systems"
    )

    system_name = models.CharField(max_length=100)

    # Location detected from the user's device
    location = models.CharField(max_length=255)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    # Solar system specifications
    capacity_kw = models.FloatField()
    panel_count = models.PositiveIntegerField()
    panel_type = models.CharField(max_length=100, blank=True)
    installation_date = models.DateField(null=True, blank=True)

    # Existing field kept for backward compatibility
    electricity_rate = models.FloatField(default=7.0)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.system_name


class ElectricityTariff(models.Model):
    solar_system = models.OneToOneField(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="electricity_tariff"
    )

    # Electricity provider, e.g. KSEB
    provider = models.CharField(
        max_length=100,
        blank=True
    )

    # Consumer category, e.g. Domestic
    consumer_category = models.CharField(
        max_length=100,
        blank=True
    )

    # Official/applicable electricity rate
    rate_per_kwh = models.FloatField(
        null=True,
        blank=True
    )

    # Optional value obtained from the electricity bill
    monthly_consumption_kwh = models.FloatField(
        null=True,
        blank=True
    )

    # Optional electricity bill uploaded by the user
    bill_file = models.FileField(
        upload_to="electricity_bills/",
        null=True,
        blank=True
    )

    # Where the tariff information came from
    source = models.CharField(
        max_length=255,
        blank=True
    )

    # Date from which the tariff is applicable
    effective_date = models.DateField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return (
            f"{self.solar_system.system_name} - "
            f"Electricity Tariff"
        )


class ElectricityTariffSlab(models.Model):
    CALCULATION_METHODS = [
        ("TELESCOPIC", "Telescopic"),
        ("NON_TELESCOPIC", "Non-telescopic"),
    ]

    tariff = models.ForeignKey(
        ElectricityTariff,
        on_delete=models.CASCADE,
        related_name="slabs",
    )

    calculation_method = models.CharField(
        max_length=20,
        choices=CALCULATION_METHODS,
        default="TELESCOPIC",
    )

    min_units = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        help_text=(
            "Minimum consumption for this slab, inclusive."
        ),
    )

    max_units = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text=(
            "Maximum consumption for this slab, inclusive. "
            "Leave blank for no upper limit."
        ),
    )

    rate_per_kwh = models.DecimalField(
        max_digits=10,
        decimal_places=4,
        help_text="Energy charge per kWh for this slab.",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        ordering = ["min_units"]
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(max_units__isnull=True)
                    | models.Q(
                        max_units__gte=models.F("min_units")
                    )
                ),
                name="valid_electricity_tariff_slab_range",
            ),
            models.CheckConstraint(
                condition=models.Q(rate_per_kwh__gte=0),
                name="nonnegative_electricity_tariff_rate",
            ),
        ]

    def __str__(self):
        upper_limit = (
            str(self.max_units)
            if self.max_units is not None
            else "Unlimited"
        )

        return (
            f"{self.tariff} | "
            f"{self.min_units}-{upper_limit} units | "
            f"₹{self.rate_per_kwh}/kWh"
        )


class GenerationRecord(models.Model):

    # Identifies the source of the generation record
    DATA_SOURCE_CHOICES = [
        ("ACTUAL", "Actual Measurement"),
        ("SIMULATED", "Simulated Estimate"),
    ]

    solar_system = models.ForeignKey(
        SolarSystem,
        on_delete=models.CASCADE,
        related_name="generation_records"
    )

    # Exact timestamp associated with the generation record
    recorded_at = models.DateTimeField()

    # Local calendar date for daily generation records
    # Nullable for compatibility with existing records
    generation_date = models.DateField(
        null=True,
        blank=True,
        db_index=True,
        help_text=(
            "Local calendar date associated with daily generation."
        )
    )

    energy_generated_kwh = models.FloatField()

    power_output_kw = models.FloatField(
        null=True,
        blank=True
    )

    # Distinguishes simulated values from actual measurements
    data_source = models.CharField(
        max_length=20,
        choices=DATA_SOURCE_CHOICES,
        default="ACTUAL",
        db_index=True,
        help_text=(
            "Identifies whether this record is an actual measurement "
            "or a simulated generation estimate."
        ),
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        ordering = ["-recorded_at"]



    def __str__(self):
        return (
            f"{self.solar_system.system_name} - "
            f"{self.recorded_at} - {self.data_source}"
        )
