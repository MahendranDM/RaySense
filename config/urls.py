from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    # Django Admin
    path("admin/", admin.site.urls),

    # Public RaySense Website
    path("", include("home.urls")),

    # API Endpoints
    path("api/users/", include("users.urls")),
    path("api/solar/", include("solar.urls")),
    path("api/weather/", include("weather.urls")),
    path("api/forecasting/", include("forecasting.urls")),
    path("api/performance/", include("performance.urls")),
    path("api/alerts/", include("alerts.urls")),
]

# Media files
urlpatterns += static(
    settings.MEDIA_URL,
    document_root=settings.MEDIA_ROOT,
)