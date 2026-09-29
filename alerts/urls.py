from django.urls import path, include

from rest_framework.routers import DefaultRouter

from .views import (
    AlertGenerationView,
    WeatherAlertGenerationView,
    AlertViewSet,
)


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
        "weather-generate/",
        WeatherAlertGenerationView.as_view(),
        name="weather-alert-generate"
    ),

    path(
        "",
        include(router.urls)
    ),

]