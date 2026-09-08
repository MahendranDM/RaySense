from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    PerformanceAnalysisView,
    PerformanceRecordViewSet,
)


router = DefaultRouter()

router.register(
    r"records",
    PerformanceRecordViewSet,
    basename="performance-record"
)


urlpatterns = [
    path(
        "analyze/",
        PerformanceAnalysisView.as_view(),
        name="performance-analyze"
    ),
    path(
        "",
        include(router.urls)
    ),
]