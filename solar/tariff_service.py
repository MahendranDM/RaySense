from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from .models import ElectricityTariff, ElectricityTariffSlab


class TariffCalculationError(ValueError):
    """Raised when a tariff cannot be calculated safely."""


def calculate_energy_charge(tariff_id, consumption_kwh):
    """Calculate energy charges using configured tariff slabs."""

    # Validate consumption
    try:
        consumption = Decimal(str(consumption_kwh))
    except (InvalidOperation, TypeError, ValueError):
        raise TariffCalculationError(
            "Consumption must be a valid number."
        )

    if not consumption.is_finite() or consumption < 0:
        raise TariffCalculationError(
            "Consumption must be finite and non-negative."
        )

    # Retrieve tariff
    try:
        tariff = ElectricityTariff.objects.get(pk=tariff_id)
    except (
        ElectricityTariff.DoesNotExist,
        ValueError,
        TypeError,
    ):
        raise TariffCalculationError(
            "The requested electricity tariff does not exist."
        )

    # Retrieve slabs
    slabs = list(
        ElectricityTariffSlab.objects.filter(tariff=tariff)
        .order_by("min_units", "id")
    )

    if not slabs:
        raise TariffCalculationError(
            "No tariff slabs are configured for this tariff."
        )

    # Validate slab configuration
    allowed_methods = {"TELESCOPIC", "NON_TELESCOPIC"}

    for index, slab in enumerate(slabs):
        if slab.calculation_method not in allowed_methods:
            raise TariffCalculationError(
                f"Unsupported calculation method in slab {slab.pk}."
            )

        if slab.min_units < 0:
            raise TariffCalculationError(
                f"Slab {slab.pk} has a negative lower limit."
            )

        if (
            slab.max_units is not None
            and slab.max_units <= slab.min_units
        ):
            raise TariffCalculationError(
                f"Slab {slab.pk} has an invalid range."
            )

        if (
            not slab.rate_per_kwh.is_finite()
            or slab.rate_per_kwh < 0
        ):
            raise TariffCalculationError(
                f"Slab {slab.pk} has an invalid electricity rate."
            )

        if index == 0:
            if slab.min_units != Decimal("0"):
                raise TariffCalculationError(
                    "The first slab must start at zero units."
                )
        else:
            previous = slabs[index - 1]

            if previous.max_units is None:
                raise TariffCalculationError(
                    "An unlimited slab must be the final slab."
                )

            if slab.min_units != previous.max_units:
                raise TariffCalculationError(
                    "Tariff slabs contain a gap or overlap."
                )

    methods = {slab.calculation_method for slab in slabs}
    calculation_method = (
        next(iter(methods)) if len(methods) == 1 else "MIXED"
    )

    # Check consumption coverage
    final_limit = slabs[-1].max_units

    if final_limit is not None and consumption > final_limit:
        raise TariffCalculationError(
            "The configured tariff does not cover this consumption."
        )

    # Prepare calculation
    total = Decimal("0")
    breakdown = []
    money = Decimal("0.01")

    def add_breakdown(slab, units, charge):
        breakdown.append({
            "min_units": str(slab.min_units),
            "max_units": (
                str(slab.max_units)
                if slab.max_units is not None
                else None
            ),
            "calculation_method": slab.calculation_method,
            "units_charged": str(units),
            "rate_per_kwh": str(slab.rate_per_kwh),
            "charge": str(
                charge.quantize(money, rounding=ROUND_HALF_UP)
            ),
        })

    # Calculate charges
    if consumption > 0:
        non_telescopic_slabs = [
            slab
            for slab in slabs
            if slab.calculation_method == "NON_TELESCOPIC"
        ]

        first_non_telescopic = (
            non_telescopic_slabs[0]
            if non_telescopic_slabs
            else None
        )

        # Switch to non-telescopic billing only ABOVE its
        # first lower threshold. Exact threshold values remain
        # eligible for telescopic calculation.
        use_non_telescopic = (
            first_non_telescopic is not None
            and consumption > first_non_telescopic.min_units
        )

        if use_non_telescopic:
            matching_slabs = [
                slab
                for slab in non_telescopic_slabs
                if consumption > slab.min_units
                and (
                    slab.max_units is None
                    or consumption <= slab.max_units
                )
            ]

            if len(matching_slabs) != 1:
                raise TariffCalculationError(
                    "No unique non-telescopic band covers this consumption."
                )

            selected_slab = matching_slabs[0]

            # Non-telescopic: apply the selected rate to all units.
            total = consumption * selected_slab.rate_per_kwh

            add_breakdown(
                selected_slab,
                consumption,
                total,
            )

        else:
            # Telescopic: calculate each applicable portion.
            for slab in slabs:
                if slab.calculation_method != "TELESCOPIC":
                    break

                lower = slab.min_units
                upper = slab.max_units

                if consumption <= lower:
                    break

                slab_end = (
                    min(consumption, upper)
                    if upper is not None
                    else consumption
                )

                units = slab_end - lower

                if units > 0:
                    charge = units * slab.rate_per_kwh
                    total += charge
                    add_breakdown(slab, units, charge)

                if upper is None or consumption <= upper:
                    break

            if not breakdown:
                raise TariffCalculationError(
                    "No applicable tariff slab covers this consumption."
                )

    # Return result
    return {
        "tariff_id": tariff.pk,
        "provider": tariff.provider,
        "consumer_category": tariff.consumer_category,
        "consumption_kwh": str(consumption),
        "calculation_method": calculation_method,
        "energy_charge": str(
            total.quantize(money, rounding=ROUND_HALF_UP)
        ),
        "breakdown": breakdown,
        "source": tariff.source,
        "effective_date": (
            tariff.effective_date.isoformat()
            if tariff.effective_date
            else None
        ),
        "note": (
            "Energy charges only. Fixed charges, taxes, surcharges, "
            "time-of-day adjustments, and other applicable billing "
            "components are not included."
        ),
    }