from django.shortcuts import render
from django.http import JsonResponse
from django.db.models import Sum
from django.contrib.auth import get_user_model
from django.contrib.admin.views.decorators import staff_member_required

from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import IsAdminUser
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)

from solar.models import SolarSystem, GenerationRecord
from alerts.models import Alert


# ============================================================
# RAYSENSE PUBLIC PAGES
# ============================================================

def home(request):
    return render(request, "home/index.html")


def login_page(request):
    return render(request, "home/login.html")


def register_page(request):
    return render(request, "home/register.html")


# ============================================================
# RAYSENSE USER DASHBOARD AND PAGES
# ============================================================

def dashboard(request):
    return render(request, "home/dashboard.html")


def generation(request):
    return render(request, "home/generation.html")


def forecast(request):
    return render(request, "home/forecast.html")


def performance(request):
    return render(request, "home/performance.html")


def weather(request):
    return render(request, "home/weather.html")


def alerts(request):
    return render(request, "home/alerts.html")


def reports(request):
    return render(request, "home/reports.html")


def settings_page(request):
    return render(request, "home/settings.html")


# ============================================================
# RAYSENSE ADMIN DASHBOARD API
# ============================================================

@api_view(["GET"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAdminUser])
def admin_dashboard_data(request):
    User = get_user_model()

    # --------------------------------------------------------
    # 1. TOTAL REGISTERED USERS
    # Exclude the superuser account.
    # --------------------------------------------------------

    regular_users = User.objects.filter(is_superuser=False)

    total_users = regular_users.count()

    # --------------------------------------------------------
    # 2. REGULAR USERS' SOLAR SYSTEMS
    # Exclude administrator and staff-owned systems.
    # --------------------------------------------------------

    regular_systems = SolarSystem.objects.filter(
        user__is_superuser=False,
        user__is_staff=False,
    )

    total_systems = regular_systems.count()

    # --------------------------------------------------------
    # 3. TOTAL INSTALLED SOLAR CAPACITY
    # --------------------------------------------------------

    total_capacity = (
        regular_systems.aggregate(
            total=Sum("capacity_kw")
        )["total"] or 0
    )

    # --------------------------------------------------------
    # 4. TOTAL ENERGY GENERATION
    # Include records only from regular users' systems.
    # --------------------------------------------------------

    total_generation = (
        GenerationRecord.objects.filter(
            solar_system__user__is_superuser=False,
            solar_system__user__is_staff=False,
        ).aggregate(
            total=Sum("energy_generated_kwh")
        )["total"] or 0
    )

    # --------------------------------------------------------
    # 5. UNRESOLVED ALERTS
    # Include alerts associated with regular users' systems.
    # --------------------------------------------------------

    unresolved_alerts = Alert.objects.filter(
        solar_system__user__is_superuser=False,
        solar_system__user__is_staff=False,
        is_resolved=False,
    ).count()

    # --------------------------------------------------------
    # 6. RECENT REGULAR USERS
    # --------------------------------------------------------

    recent_users = list(
        regular_users.order_by("-date_joined")
        .values(
            "id",
            "username",
            "email",
            "is_active",
            "date_joined",
        )[:5]
    )

    for account in recent_users:
        if account["date_joined"]:
            account["date_joined"] = (
                account["date_joined"].isoformat()
            )

    # --------------------------------------------------------
    # 7. RETURN DASHBOARD DATA
    # Preserve the existing API response structure.
    # --------------------------------------------------------

    return JsonResponse({
        "total_users": total_users,
        "total_systems": total_systems,
        "total_capacity": float(total_capacity),
        "total_generation": float(total_generation),
        "unresolved_alerts": unresolved_alerts,
        "recent_users": recent_users,
    })


# ============================================================
# RAYSENSE ADMIN PAGES
# ============================================================

@staff_member_required
def admin_dashboard(request):
    return render(request, "home/admin_dashboard.html")


@staff_member_required
def admin_users(request):
    return render(request, "home/admin_users.html")


@staff_member_required
def admin_systems(request):
    return render(request, "home/admin_systems.html")


@staff_member_required
def admin_ml(request):
    return render(request, "home/admin_ml.html")


@staff_member_required
def admin_alerts(request):
    return render(request, "home/admin_alerts.html")


@staff_member_required
def admin_user_details(request, user_id):
    return render(
        request,
        "home/admin_user_details.html",
        {"user_id": user_id},
    )


@staff_member_required
def admin_reports(request):
    from django.contrib.auth import get_user_model
    from django.db.models import Sum, Count
    from solar.models import SolarSystem, GenerationRecord
    from alerts.models import Alert
    from forecasting.models import ForecastRecord

    User = get_user_model()

    users_count = User.objects.filter(is_superuser=False).count()
    systems = SolarSystem.objects.all()

    total_capacity = systems.aggregate(
        total=Sum("capacity_kw")
    )["total"] or 0

    total_generation = GenerationRecord.objects.aggregate(
        total=Sum("energy_generated_kwh")
    )["total"] or 0

    total_alerts = Alert.objects.count()

    unresolved_alerts = Alert.objects.filter(
        is_resolved=False
    ).count() if any(
        field.name == "is_resolved"
        for field in Alert._meta.fields
    ) else 0

    forecast_count = ForecastRecord.objects.count()

    context = {
        "users_count": users_count,
        "systems_count": systems.count(),
        "total_capacity": total_capacity,
        "total_generation": total_generation,
        "total_alerts": total_alerts,
        "unresolved_alerts": unresolved_alerts,
        "forecast_count": forecast_count,
    }

    return render(request, "home/admin_reports.html", context)
