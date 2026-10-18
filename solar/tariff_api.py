from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import ElectricityTariff
from .tariff_service import (
    calculate_energy_charge,
    TariffCalculationError,
)


@api_view(["GET"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def tariff_calculation_api(request):
    """
    Return the tariff associated with one of the current user's
    solar systems and optionally calculate energy charges.

    Query parameters:
        system_id: required solar-system ID
        consumption_kwh: optional consumption amount
    """

    system_id = request.query_params.get("system_id")
    consumption_kwh = request.query_params.get("consumption_kwh")

    if not system_id:
        return Response(
            {"error": "The system_id parameter is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Only allow access to the authenticated user's solar systems.
    from .models import SolarSystem

    try:
        system = SolarSystem.objects.get(
            id=system_id,
            user=request.user,
        )
    except (SolarSystem.DoesNotExist, ValueError):
        return Response(
            {"error": "Solar system not found."},
            status=status.HTTP_404_NOT_FOUND,
        )

    try:
        tariff = ElectricityTariff.objects.get(
            solar_system=system,
        )
    except ElectricityTariff.DoesNotExist:
        return Response(
            {
                "error": "No electricity tariff is configured for this system.",
                "system_id": system.id,
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    response_data = {
        "system_id": system.id,
        "system_name": system.system_name,
        "provider": tariff.provider,
        "consumer_category": tariff.consumer_category,
        "source": tariff.source,
        "effective_date": (
            tariff.effective_date.isoformat()
            if tariff.effective_date
            else None
        ),
        "rate_per_kwh": (
            str(tariff.rate_per_kwh)
            if tariff.rate_per_kwh is not None
            else None
        ),
        "monthly_consumption_kwh": (
            str(tariff.monthly_consumption_kwh)
            if tariff.monthly_consumption_kwh is not None
            else None
        ),
        "slabs": [
            {
                "calculation_method": slab.calculation_method,
                "min_units": str(slab.min_units),
                "max_units": (
                    str(slab.max_units)
                    if slab.max_units is not None
                    else None
                ),
                "rate_per_kwh": str(slab.rate_per_kwh),
            }
            for slab in tariff.slabs.all()
        ],
    }

    if consumption_kwh is not None:
        try:
            calculation = calculate_energy_charge(
                tariff.id,
                consumption_kwh,
            )
        except TariffCalculationError as exc:
            return Response(
                {"error": str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        response_data["calculation"] = calculation

    return Response(
        response_data,
        status=status.HTTP_200_OK,
    )