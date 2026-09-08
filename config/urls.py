from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    path('api/users/', include('users.urls')),
    path('api/solar/', include('solar.urls')),
    path('api/weather/', include('weather.urls')),
    path('api/forecasting/', include('forecasting.urls')),
    path('api/performance/', include('performance.urls')),
    path('api/alerts/', include('alerts.urls')),
]