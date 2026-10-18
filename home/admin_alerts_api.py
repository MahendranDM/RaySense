from django.contrib.auth import get_user_model
from django.db.models import Q
from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response

from alerts.models import Alert


@api_view(["GET", "PATCH"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAdminUser])
def admin_alerts_data(request):
    User = get_user_model()

    if request.method == "PATCH":
        alert_id = request.data.get("id")
        resolved = request.data.get("is_resolved")

        if alert_id is None or resolved is None:
            return Response(
                {"error": "Both id and is_resolved are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if isinstance(resolved, str):
            if resolved.lower() not in ("true", "false"):
                return Response(
                    {"error": "is_resolved must be true or false."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            resolved = resolved.lower() == "true"
        elif not isinstance(resolved, bool):
            return Response(
                {"error": "is_resolved must be a boolean."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            alert = Alert.objects.get(pk=alert_id)
        except Alert.DoesNotExist:
            return Response(
                {"error": "Alert not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        alert.is_resolved = resolved
        alert.save(update_fields=["is_resolved"])

        return Response({
            "message": "Alert status updated successfully.",
            "id": alert.id,
            "is_resolved": alert.is_resolved,
        })

    alerts = Alert.objects.select_related(
        "solar_system",
        "solar_system__user",
    ).order_by("-alert_date")

    search = request.query_params.get("search", "").strip()
    severity = request.query_params.get("severity", "").strip()
    alert_type = request.query_params.get("type", "").strip()
    resolved = request.query_params.get("resolved", "").strip().lower()

    if search:
        alerts = alerts.filter(
            Q(title__icontains=search)
            | Q(message__icontains=search)
            | Q(solar_system__system_name__icontains=search)
            | Q(solar_system__user__username__icontains=search)
            | Q(solar_system__user__email__icontains=search)
        )

    if severity in {"Info", "Warning", "Critical"}:
        alerts = alerts.filter(severity=severity)

    if alert_type in {"Performance", "Generation", "Weather", "Maintenance"}:
        alerts = alerts.filter(alert_type=alert_type)

    if resolved in {"true", "false"}:
        alerts = alerts.filter(is_resolved=(resolved == "true"))

    all_alerts = Alert.objects.all()

    results = []
    for alert in alerts:
        results.append({
            "id": alert.id,
            "title": alert.title,
            "message": alert.message,
            "alert_type": alert.alert_type,
            "severity": alert.severity,
            "is_resolved": alert.is_resolved,
            "alert_date": alert.alert_date.isoformat(),
            "solar_system_id": alert.solar_system_id,
            "system_name": alert.solar_system.system_name,
            "username": alert.solar_system.user.username,
            "email": alert.solar_system.user.email,
        })

    return Response({
        "total_alerts": all_alerts.count(),
        "active_alerts": all_alerts.filter(is_resolved=False).count(),
        "resolved_alerts": all_alerts.filter(is_resolved=True).count(),
        "critical_alerts": all_alerts.filter(
            severity="Critical",
            is_resolved=False,
        ).count(),
        "warning_alerts": all_alerts.filter(
            severity="Warning",
            is_resolved=False,
        ).count(),
        "info_alerts": all_alerts.filter(
            severity="Info",
            is_resolved=False,
        ).count(),
        "alerts": results,
    }, status=status.HTTP_200_OK)
