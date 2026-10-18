from django.contrib.auth import get_user_model
from django.db.models import Q
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
def admin_users_data(request):
    User = get_user_model()

    # Exclude superuser and staff accounts from ordinary user management.
    users = User.objects.filter(
        is_superuser=False,
        is_staff=False,
    ).order_by("-date_joined")

    # Search by username or email.
    search = request.query_params.get("search", "").strip()

    if search:
        users = users.filter(
            Q(username__icontains=search)
            | Q(email__icontains=search)
        )

    # Count regular users and their associated solar systems.
    total_users = User.objects.filter(
        is_superuser=False,
        is_staff=False,
    ).count()

    active_users = User.objects.filter(
        is_superuser=False,
        is_staff=False,
        is_active=True,
    ).count()

    total_solar_systems = SolarSystem.objects.filter(
        user__is_superuser=False,
        user__is_staff=False,
    ).count()

    results = []

    for user in users:
        results.append({
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "is_active": user.is_active,
            "is_staff": user.is_staff,
            "is_superuser": user.is_superuser,
            "date_joined": user.date_joined.isoformat(),
            "solar_system_count": SolarSystem.objects.filter(
                user=user
            ).count(),
        })

    return Response(
        {
            "total": total_users,
            "active": active_users,
            "total_solar_systems": total_solar_systems,
            "users": results,
        },
        status=status.HTTP_200_OK,
    )