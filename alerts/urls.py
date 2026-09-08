from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import AlertGenerationView, AlertViewSet


router = DefaultRouter()

router.register(
    r"records",
    AlertViewSet,
    basename="alert-record"
)

urlpatterns = [
    path(
        "generate/",
        AlertGenerationView.as_view(),
        name="alert-generate"
    ),
    path(
        "",
        include(router.urls)
    ),
]