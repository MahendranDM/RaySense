from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import SolarSystemViewSet, GenerationRecordViewSet


router = DefaultRouter()

router.register(
    "systems",
    SolarSystemViewSet,
    basename="solar-system",
)

router.register(
    "generation",
    GenerationRecordViewSet,
    basename="generation",
)


urlpatterns = [
    path("", include(router.urls)),
]