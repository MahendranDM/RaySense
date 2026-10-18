from django.contrib.auth import get_user_model
from django.db import transaction

from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.parsers import (
    MultiPartParser,
    FormParser,
    JSONParser,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import UserProfile
from .serializers import RegisterSerializer, LoginSerializer
from solar.models import SolarSystem, ElectricityTariff


User = get_user_model()


# ============================================================
# USER REGISTRATION
# ============================================================

class RegisterView(APIView):

    parser_classes = [
        MultiPartParser,
        FormParser,
        JSONParser,
    ]

    def validate_solar_data(self, data):

        required_fields = [
            "system_name",
            "location",
            "latitude",
            "longitude",
            "capacity_kw",
            "panel_count",
            "installation_date",
        ]

        missing_fields = [
            field
            for field in required_fields
            if not data.get(field)
        ]

        if missing_fields:
            return {
                field: "This field is required."
                for field in missing_fields
            }

        try:
            latitude = float(
                data["latitude"]
            )

            longitude = float(
                data["longitude"]
            )

            capacity_kw = float(
                data["capacity_kw"]
            )

            panel_count = int(
                data["panel_count"]
            )

        except (
            TypeError,
            ValueError,
        ):
            return {
                "solar_data":
                "Solar numeric fields contain invalid values."
            }

        if not -90 <= latitude <= 90:
            return {
                "latitude":
                "Latitude must be between -90 and 90."
            }

        if not -180 <= longitude <= 180:
            return {
                "longitude":
                "Longitude must be between -180 and 180."
            }

        if capacity_kw <= 0:
            return {
                "capacity_kw":
                "Capacity must be greater than 0."
            }

        if panel_count <= 0:
            return {
                "panel_count":
                "Panel count must be greater than 0."
            }

        return {}

    @transaction.atomic
    def post(self, request):

        # ----------------------------------------------------
        # Validate account information
        # ----------------------------------------------------

        serializer = RegisterSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                serializer.errors,
                status=status.HTTP_400_BAD_REQUEST
            )

        # ----------------------------------------------------
        # Validate solar-system information
        # ----------------------------------------------------

        solar_errors = self.validate_solar_data(
            request.data
        )

        if solar_errors:

            return Response(
                solar_errors,
                status=status.HTTP_400_BAD_REQUEST
            )

        # ----------------------------------------------------
        # Create Django user
        # ----------------------------------------------------

        user = serializer.save()

        # ----------------------------------------------------
        # Create user profile
        # ----------------------------------------------------

        UserProfile.objects.create(
            user=user,
            location=request.data.get(
                "location",
                ""
            )
        )

        # ----------------------------------------------------
        # Create solar system
        # ----------------------------------------------------

        solar_system = SolarSystem.objects.create(
            user=user,
            system_name=request.data.get(
                "system_name"
            ),
            location=request.data.get(
                "location"
            ),
            latitude=float(
                request.data.get(
                    "latitude"
                )
            ),
            longitude=float(
                request.data.get(
                    "longitude"
                )
            ),
            capacity_kw=float(
                request.data.get(
                    "capacity_kw"
                )
            ),
            panel_count=int(
                request.data.get(
                    "panel_count"
                )
            ),
            panel_type=request.data.get(
                "panel_type",
                ""
            ),
            installation_date=request.data.get(
                "installation_date"
            ),
        )

        # ----------------------------------------------------
        # Create electricity tariff record
        # ----------------------------------------------------

        ElectricityTariff.objects.create(
            solar_system=solar_system,
            provider=request.data.get(
                "provider",
                ""
            ),
            consumer_category=request.data.get(
                "consumer_category",
                ""
            ),
            bill_file=request.FILES.get(
                "bill_file"
            ),
        )

        # ----------------------------------------------------
        # Registration response
        # ----------------------------------------------------

        return Response(
            {
                "message":
                "Registration successful.",

                "user": {
    "id": user.id,
    "username": user.username,
    "email": user.email,
    "is_staff": user.is_staff,
    "is_superuser": user.is_superuser,
    "is_admin": user.is_staff or user.is_superuser,
},

                "solar_system": {
                    "id":
                    solar_system.id,

                    "system_name":
                    solar_system.system_name,

                    "location":
                    solar_system.location,

                    "latitude":
                    solar_system.latitude,

                    "longitude":
                    solar_system.longitude,

                    "capacity_kw":
                    solar_system.capacity_kw,

                    "panel_count":
                    solar_system.panel_count,

                    "panel_type":
                    solar_system.panel_type,

                    "installation_date":
                    solar_system.installation_date,
                },
            },
            status=status.HTTP_201_CREATED
        )


# ============================================================
# USER LOGIN
# ============================================================

class LoginView(APIView):

    def post(self, request):

        serializer = LoginSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                serializer.errors,
                status=status.HTTP_400_BAD_REQUEST
            )

        user = serializer.validated_data[
            "user"
        ]

        # ----------------------------------------------------
        # Get existing token or create a new one
        # ----------------------------------------------------

        token, created = Token.objects.get_or_create(
            user=user
        )

        return Response(
            {
                "message":
                "Login successful.",

                "token":
                token.key,

                "user": {
                    "id":
                    user.id,

                    "username":
                    user.username,

                    "email":
                    user.email,

                    "is_staff": user.is_staff,
                    "is_superuser": user.is_superuser,
                    "is_admin": user.is_staff or user.is_superuser,
                }
            },
            status=status.HTTP_200_OK
        )


# ============================================================
# CURRENT USER / PROFILE
# ============================================================

class MeView(APIView):

    permission_classes = [
        IsAuthenticated,
    ]

    def get(self, request):

        user = request.user

        # ----------------------------------------------------
        # Get user profile
        # ----------------------------------------------------

        try:

            profile = UserProfile.objects.get(
                user=user
            )

        except UserProfile.DoesNotExist:

            profile = None

        # ----------------------------------------------------
        # Get user's solar systems only
        # ----------------------------------------------------

        solar_systems = SolarSystem.objects.filter(
            user=user
        )

        solar_data = []

        for system in solar_systems:

            solar_data.append(
                {
                    "id":
                    system.id,

                    "system_name":
                    system.system_name,

                    "location":
                    system.location,

                    "latitude":
                    system.latitude,

                    "longitude":
                    system.longitude,

                    "capacity_kw":
                    system.capacity_kw,

                    "panel_count":
                    system.panel_count,

                    "panel_type":
                    system.panel_type,

                    "installation_date":
                    system.installation_date,
                }
            )

        # ----------------------------------------------------
        # Response
        # ----------------------------------------------------

        return Response(
            {
                "user": {
                    "id":
                    user.id,

                    "username":
                    user.username,

                    "email":
                    user.email,

                    "first_name":
                    user.first_name,

                    "last_name":
                    user.last_name,
                },

                "profile": {
                    "phone":
                    profile.phone
                    if profile
                    else "",

                    "location":
                    profile.location
                    if profile
                    else "",
                },

                "solar_systems":
                solar_data,
            },
            status=status.HTTP_200_OK
        )


# ============================================================
# USER LOGOUT
# ============================================================

class LogoutView(APIView):

    permission_classes = [
        IsAuthenticated,
    ]

    def post(self, request):

        Token.objects.filter(
            user=request.user
        ).delete()

        return Response(
            {
                "message":
                "Logout successful."
            },
            status=status.HTTP_200_OK
        )
