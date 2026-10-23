import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Create or reset the designated RaySense admin account when explicitly enabled."

    def handle(self, *args, **options):
        if os.environ.get("RAYSENSE_BOOTSTRAP_ADMIN") != "1":
            self.stdout.write(
                self.style.WARNING(
                    "Admin bootstrap disabled. No accounts were changed."
                )
            )
            return

        username = os.environ.get("RAYSENSE_ADMIN_USERNAME", "").strip()
        email = os.environ.get("RAYSENSE_ADMIN_EMAIL", "").strip()
        password = os.environ.get("RAYSENSE_ADMIN_PASSWORD", "")

        if not username or not email or not password:
            raise CommandError(
                "Set RAYSENSE_ADMIN_USERNAME, RAYSENSE_ADMIN_EMAIL, "
                "and RAYSENSE_ADMIN_PASSWORD."
            )

        if len(password) < 12:
            raise CommandError(
                "The bootstrap password must contain at least 12 characters."
            )

        User = get_user_model()

        user_by_username = User.objects.filter(username=username).first()
        user_by_email = User.objects.filter(email__iexact=email).first()

        if (
            user_by_username
            and user_by_email
            and user_by_username.pk != user_by_email.pk
        ):
            raise CommandError(
                "The username and email belong to different accounts. "
                "No account was changed."
            )

        user = user_by_username or user_by_email

        if user is None:
            user = User(
                username=username,
                email=email,
            )
            user.set_password(password)
            user.is_active = True
            user.is_staff = True
            user.is_superuser = True
            user.save()
            action = "created"
        else:
            user.username = username
            user.email = email
            user.set_password(password)
            user.is_active = True
            user.is_staff = True
            user.is_superuser = True
            user.save()
            action = "updated"

        self.stdout.write(
            self.style.SUCCESS(
                f"RaySense admin account {action} successfully: {username}"
            )
        )
