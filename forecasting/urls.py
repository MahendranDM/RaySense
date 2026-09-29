from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    ForecastPredictionView,
    MLForecastPredictionView,
    WeatherMLForecastView,
    ForecastRecordViewSet,
)

router = DefaultRouter()

router.register(
    r"records",
    ForecastRecordViewSet,
    basename="forecast-record"
)

urlpatterns = [
    path(
        "predict/",
        ForecastPredictionView.as_view(),
        name="forecast-predict"
    ),
    path(
     "weather-predict/",
        WeatherMLForecastView.as_view(),
        name="weather-ml-predict"
    ),
    path(
        "ml-predict/",
        MLForecastPredictionView.as_view(),
        name="ml-forecast-predict"
    ),

    path(
        "",
        include(router.urls)
    ),
]