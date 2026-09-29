from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    PerformanceAnalysisView,
    PerformanceRecordViewSet,
    TodayPerformanceView,
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
        name="performance-analyze",
    ),

    path(
        "today/",
        TodayPerformanceView.as_view(),
        name="today-performance",
    ),

    path(
        "",
        include(router.urls)
    ),
]