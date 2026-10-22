from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from rest_framework import serializers


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8
    )

    password2 = serializers.CharField(
        write_only=True,
        min_length=8
    )

    class Meta:
        model = User
        fields = ["first_name", "last_name", "username", "email", "password", "password2"]

    def validate(self, data):
        first_name = data.get("first_name", "").strip()
        last_name = data.get("last_name", "").strip()

        errors = {}

        if not first_name:
            errors["first_name"] = "First name is required."

        if not last_name:
            errors["last_name"] = "Last name is required."

        if errors:
            raise serializers.ValidationError(errors)

        data["first_name"] = first_name
        data["last_name"] = last_name

        if data["password"] != data["password2"]:
            raise serializers.ValidationError({
                "password": "Passwords do not match."
            })

        if User.objects.filter(
            username=data["username"]
        ).exists():
            raise serializers.ValidationError({
                "username": "Username already exists."
            })

        if User.objects.filter(
            email=data["email"]
        ).exists():
            raise serializers.ValidationError({
                "email": "Email already exists."
            })

        return data

    def create(self, validated_data):
        validated_data.pop("password2")

        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=validated_data["first_name"].strip(),
            last_name=validated_data["last_name"].strip(),
        )

        return user


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(
        write_only=True
    )

    def validate(self, data):
        username = data.get("username")
        password = data.get("password")

        user = authenticate(
            username=username,
            password=password
        )

        if user is None:
            raise serializers.ValidationError({
                "detail": "Invalid username or password."
            })

        if not user.is_active:
            raise serializers.ValidationError({
                "detail": "This account is inactive."
            })

        data["user"] = user

        return data