from django.contrib import admin

from .models import ElectricityTariff, ElectricityTariffSlab, SolarSystem


class ElectricityTariffSlabInline(admin.TabularInline):
    model = ElectricityTariffSlab
    extra = 1


@admin.register(ElectricityTariff)
class ElectricityTariffAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "solar_system",
        "provider",
        "consumer_category",
        "rate_per_kwh",
        "effective_date",
    )

    list_filter = (
        "provider",
        "consumer_category",
        "effective_date",
    )

    search_fields = (
        "solar_system__system_name",
        "solar_system__user__username",
        "provider",
        "consumer_category",
    )

    inlines = [ElectricityTariffSlabInline]


@admin.register(SolarSystem)
class SolarSystemAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "system_name",
        "user",
        "capacity_kw",
        "location",
    )

    search_fields = (
        "system_name",
        "user__username",
        "location",
    )

    list_filter = ("panel_type",)


@admin.register(ElectricityTariffSlab)
class ElectricityTariffSlabAdmin(admin.ModelAdmin):
    list_display = (
        "tariff",
        "calculation_method",
        "min_units",
        "max_units",
        "rate_per_kwh",
    )

    list_filter = ("calculation_method",)