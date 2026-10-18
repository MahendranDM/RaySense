import hashlib
from datetime import datetime, time, timedelta

from django.db import transaction
from django.utils import timezone

from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from .models import SolarSystem, GenerationRecord
from .serializers import (
    SolarSystemSerializer,
    GenerationRecordSerializer,
)


class SolarSystemViewSet(viewsets.ModelViewSet):
    serializer_class = SolarSystemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SolarSystem.objects.filter(
            user=self.request.user
        )


class GenerationRecordViewSet(viewsets.ModelViewSet):
    serializer_class = GenerationRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        Return the authenticated user's generation history.

        History contains completed days only.
        Today's generation belongs in the current-generation
        section rather than completed daily history.
        """
        today = timezone.localdate()

        return (
            GenerationRecord.objects.filter(
                solar_system__user=self.request.user,
                generation_date__isnull=False,
                generation_date__lt=today,
            )
            .order_by("-generation_date", "-recorded_at")
        )

    def list(self, request, *args, **kwargs):
        """
        Ensure that historical simulated records exist before
        returning the user's generation history.
        """
        today = timezone.localdate()
        start_date = today - timedelta(days=29)

        systems = SolarSystem.objects.filter(
            user=request.user
        )

        for system in systems:
            self._create_missing_simulated_records(
                system=system,
                start_date=start_date,
                end_date=today - timedelta(days=1),
            )

        return super().list(request, *args, **kwargs)

    def _create_missing_simulated_records(
        self,
        system,
        start_date,
        end_date,
    ):
        """
        Create deterministic simulated estimates for missing
        historical dates.

        Never create a simulated record for a date that already
        has a record for this solar system.
        """
        capacity_kw = max(
            float(system.capacity_kw or 0),
            0,
        )

        panel_count = max(
            int(system.panel_count or 0),
            0,
        )

        if capacity_kw <= 0 or panel_count <= 0:
            return

        # Identify dates that already contain generation records.
        existing_dates = set(
            GenerationRecord.objects.filter(
                solar_system=system,
                generation_date__gte=start_date,
                generation_date__lte=end_date,
            ).values_list(
                "generation_date",
                flat=True,
            )
        )

        # Include legacy records that do not have generation_date.
        legacy_records = GenerationRecord.objects.filter(
            solar_system=system,
            generation_date__isnull=True,
        ).only(
            "recorded_at"
        )

        for record in legacy_records.iterator():
            if not record.recorded_at:
                continue

            local_date = timezone.localtime(
                record.recorded_at
            ).date()

            if start_date <= local_date <= end_date:
                existing_dates.add(local_date)

        panel_type = (
            system.panel_type or ""
        ).strip().lower()

        if "mono" in panel_type:
            panel_factor = 1.00
        elif "poly" in panel_type:
            panel_factor = 0.95
        elif "thin film" in panel_type:
            panel_factor = 0.85
        else:
            panel_factor = 0.95

        base_daily_kwh = (
            capacity_kw * 4.0 * 0.75 * panel_factor
        )

        current_date = start_date

        while current_date <= end_date:
            if current_date not in existing_dates:
                seed_text = (
                    f"{system.pk}:{current_date.isoformat()}"
                )

                digest = hashlib.sha256(
                    seed_text.encode("utf-8")
                ).hexdigest()

                seed_number = int(
                    digest[:8],
                    16,
                )

                variation = (
                    0.60
                    + (seed_number % 6001) / 10000
                )

                energy_kwh = round(
                    base_daily_kwh * variation,
                    2,
                )

                recorded_at = timezone.make_aware(
                    datetime.combine(
                        current_date,
                        time(hour=12),
                    ),
                    timezone.get_current_timezone(),
                )

                # Recheck before creating the simulated record.
                with transaction.atomic():
                    already_exists = (
                        GenerationRecord.objects.filter(
                            solar_system=system,
                            generation_date=current_date,
                        ).exists()
                    )

                    if not already_exists:
                        GenerationRecord.objects.create(
                            solar_system=system,
                            recorded_at=recorded_at,
                            generation_date=current_date,
                            energy_generated_kwh=energy_kwh,
                            power_output_kw=round(
                                energy_kwh / 24.0,
                                3,
                            ),
                            data_source="SIMULATED",
                        )

                        existing_dates.add(current_date)

            current_date += timedelta(days=1)