from django.urls import path

from .admin_users_api import admin_users_data
from .admin_systems_api import admin_systems_data
from .admin_alerts_api import admin_alerts_data
from .admin_user_details_api import admin_user_details_data

from .views import (
    home,
    login_page,
    register_page,
    dashboard,
    generation,
    forecast,
    performance,
    weather,
    alerts,
    reports,
    settings_page,
    admin_dashboard,
    admin_dashboard_data,
    admin_users,
    admin_systems,
    admin_ml,
    admin_alerts,
    admin_user_details,
    admin_reports,
)


urlpatterns = [
    # ==========================================
    # ADMIN API ROUTES
    # ==========================================
    path(
        "api/admin/systems/",
        admin_systems_data,
        name="admin_systems_data",
    ),
    path(
        "api/admin/alerts/",
        admin_alerts_data,
        name="admin_alerts_data",
    ),
    path(
        "api/admin/users/",
        admin_users_data,
        name="admin_users_data",
    ),
    path(
        "api/admin/users/<int:user_id>/details/",
        admin_user_details_data,
        name="admin_user_details_data",
    ),
    path(
        "api/admin/dashboard/",
        admin_dashboard_data,
        name="admin_dashboard_data",
    ),

    # ==========================================
    # ADMIN WEB PAGES
    # ==========================================
    path(
        "admin-dashboard/",
        admin_dashboard,
        name="admin_dashboard",
    ),
    path(
        "admin-users/",
        admin_users,
        name="admin_users",
    ),
    path(
        "admin-user-details/<int:user_id>/",
        admin_user_details,
        name="admin_user_details",
    ),
    path(
        "admin-systems/",
        admin_systems,
        name="admin_systems",
    ),
    path(
        "admin-ml/",
        admin_ml,
        name="admin_ml",
    ),
    path(
        "admin-alerts/",
        admin_alerts,
        name="admin_alerts",
    ),
    path(
        "admin-reports/",
        admin_reports,
        name="admin_reports",
    ),

    # ==========================================
    # PUBLIC WEB PAGES
    # ==========================================
    path(
        "",
        home,
        name="home",
    ),
    path(
        "login/",
        login_page,
        name="login",
    ),
    path(
        "register/",
        register_page,
        name="register",
    ),

    # ==========================================
    # USER DASHBOARD PAGES
    # ==========================================
    path(
        "dashboard/",
        dashboard,
        name="dashboard",
    ),
    path(
        "generation/",
        generation,
        name="generation",
    ),
    path(
        "forecast/",
        forecast,
        name="forecast",
    ),
    path(
        "performance/",
        performance,
        name="performance",
    ),
    path(
        "weather/",
        weather,
        name="weather",
    ),
    path(
        "alerts/",
        alerts,
        name="alerts",
    ),
    path(
        "reports/",
        reports,
        name="reports",
    ),
    path(
        "settings/",
        settings_page,
        name="settings",
    ),
]