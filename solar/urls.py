from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import SolarSystemViewSet, GenerationRecordViewSet
from .tariff_api import tariff_calculation_api


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
    path(
        "tariff/calculate/",
        tariff_calculation_api,
        name="tariff-calculation",
    ),
    path("", include(router.urls)),
]