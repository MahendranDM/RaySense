from django.contrib import admin
from .models import Alert


@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):

    # Columns displayed in the admin list
    list_display = (
        "id",
        "title",
        "solar_system",
        "alert_type",
        "severity",
        "is_resolved",
        "alert_date",
    )

    # Filters on the right side
    list_filter = (
        "alert_type",
        "severity",
        "is_resolved",
        "alert_date",
    )

    # Search functionality
    search_fields = (
        "title",
        "message",
        "solar_system__system_name",
    )

    # Default sorting: newest alerts first
    ordering = ("-alert_date",)

    # Pagination
    list_per_page = 25

    # Make alert dates read-only
    readonly_fields = ("alert_date",)

    # Organize the edit page
    fieldsets = (
        (
            "Alert Information",
            {
                "fields": (
                    "solar_system",
                    "alert_type",
                    "severity",
                    "title",
                    "message",
                )
            },
        ),
        (
            "Alert Status",
            {
                "fields": (
                    "is_resolved",
                    "alert_date",
                )
            },
        ),
    )

    # Allow administrators to resolve multiple alerts at once
    actions = (
        "mark_as_resolved",
        "mark_as_active",
    )

    @admin.action(description="Mark selected alerts as resolved")
    def mark_as_resolved(self, request, queryset):
        updated = queryset.update(is_resolved=True)

        self.message_user(
            request,
            f"{updated} alert(s) marked as resolved."
        )

    @admin.action(description="Mark selected alerts as active")
    def mark_as_active(self, request, queryset):
        updated = queryset.update(is_resolved=False)

        self.message_user(
            request,
            f"{updated} alert(s) marked as active."
        )