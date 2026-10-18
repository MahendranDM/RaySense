from django.db.models import Sum
from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response

from solar.models import SolarSystem


@api_view(["GET"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAdminUser])
def admin_systems_data(request):
    # Only show solar systems belonging to regular users.
    systems = (
        SolarSystem.objects
        .filter(user__is_superuser=False, user__is_staff=False)
        .select_related("user")
        .order_by("-created_at")
    )

    search = request.query_params.get("search", "").strip()

    if search:
        from django.db.models import Q

        systems = systems.filter(
            Q(system_name__icontains=search)
            | Q(user__username__icontains=search)
            | Q(user__email__icontains=search)
            | Q(location__icontains=search)
        )

    results = []

    for system in systems:
        results.append({
            "id": system.id,
            "system_name": system.system_name,
            "username": system.user.username,
            "email": system.user.email,
            "location": system.location,
            "latitude": system.latitude,
            "longitude": system.longitude,
            "capacity_kw": system.capacity_kw,
            "panel_count": system.panel_count,
            "panel_type": system.panel_type,
            "installation_date": (
                system.installation_date.isoformat()
                if system.installation_date else None
            ),
            "created_at": system.created_at.isoformat(),
        })

    # Aggregate only regular users' systems.
    all_systems = SolarSystem.objects.filter(
        user__is_superuser=False,
        user__is_staff=False,
    )

    return Response({
        "total_systems": all_systems.count(),
        "total_capacity_kw": all_systems.aggregate(
            total=Sum("capacity_kw")
        )["total"] or 0,
        "total_panels": all_systems.aggregate(
            total=Sum("panel_count")
        )["total"] or 0,
        "systems": results,
    }, status=status.HTTP_200_OK)