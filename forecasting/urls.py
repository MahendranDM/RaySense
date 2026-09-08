from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import ForecastRecordViewSet


router = DefaultRouter()

router.register(
    r"records",
    ForecastRecordViewSet,
    basename="forecast-record"
)

urlpatterns = [
    path("", include(router.urls)),
]