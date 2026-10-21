from datetime import datetime, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from forecasting.models import ForecastRecord
from solar.models import GenerationRecord, SolarSystem


class TodayPerformanceAPITests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            username="performance_test_user",
            password="test-password-only",
        )

        self.system = SolarSystem.objects.create(
            user=self.user,
            system_name="Performance Test System",
            location="Kochi, Kerala",
            latitude=9.9312,
            longitude=76.2673,
            capacity_kw=5.0,
            panel_count=10,
            panel_type="Monocrystalline",
        )

        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        self.evaluation_date = timezone.localdate() - timedelta(days=1)
        self.url = "/api/performance/today/"

    def create_forecast(self, predicted=10.0):
        return ForecastRecord.objects.create(
            solar_system=self.system,
            forecast_date=self.evaluation_date,
            predicted_generation_kwh=predicted,
            model_name="Test Model",
        )

    def create_generation(
        self,
        energy,
        source="ACTUAL",
        generation_date=None,
        recorded_at=None,
    ):
        if recorded_at is None:
            local_midday = datetime.combine(
                self.evaluation_date,
                datetime.min.time(),
            ) + timedelta(hours=12)

            recorded_at = timezone.make_aware(
                local_midday,
                timezone.get_current_timezone(),
            )

        return GenerationRecord.objects.create(
            solar_system=self.system,
            recorded_at=recorded_at,
            generation_date=generation_date,
            energy_generated_kwh=energy,
            power_output_kw=energy / 24,
            data_source=source,
        )

    def test_missing_forecast_returns_pending_response(self):
        self.create_generation(
            energy=4.0,
            generation_date=self.evaluation_date,
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], "Pending")
        self.assertFalse(response.data["forecast_available"])
        self.assertEqual(response.data["predicted_generation_kwh"], 0.0)
        self.assertEqual(response.data["actual_generation_kwh"], 4.0)

    def test_missing_generation_returns_pending(self):
        self.create_forecast(predicted=10.0)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], "Pending")
        self.assertTrue(response.data["forecast_available"])
        self.assertFalse(response.data["generation_data_available"])
        self.assertEqual(response.data["predicted_generation_kwh"], 10.0)

    def test_legacy_record_is_included_by_local_recorded_date(self):
        self.create_forecast(predicted=10.0)

        self.create_generation(
            energy=4.0,
            source="ACTUAL",
            generation_date=None,
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["actual_generation_kwh"], 4.0)
        self.assertEqual(response.data["data_source"], "ACTUAL")
        self.assertTrue(response.data["generation_data_available"])
        self.assertEqual(response.data["performance_percentage"], 40.0)

    def test_actual_records_take_precedence_over_simulated_records(self):
        self.create_forecast(predicted=10.0)

        self.create_generation(
            energy=4.0,
            source="ACTUAL",
            generation_date=self.evaluation_date,
        )
        self.create_generation(
            energy=8.0,
            source="SIMULATED",
            generation_date=self.evaluation_date,
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["actual_generation_kwh"], 4.0)
        self.assertEqual(response.data["data_source"], "ACTUAL")
        self.assertFalse(response.data["is_simulated"])

    def test_no_solar_system_returns_not_found(self):
        self.system.delete()

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 404)
        self.assertEqual(
            response.data["error"],
            "No solar system found.",
        )

    def test_legacy_record_outside_evaluation_day_is_excluded(self):
        self.create_forecast(predicted=10.0)

        next_day = self.evaluation_date + timedelta(days=1)
        outside_day = timezone.make_aware(
            datetime.combine(next_day, datetime.min.time()),
            timezone.get_current_timezone(),
        )

        self.create_generation(
            energy=7.0,
            source="ACTUAL",
            generation_date=None,
            recorded_at=outside_day,
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["actual_generation_kwh"], 0.0)
        self.assertFalse(response.data["generation_data_available"])
        self.assertEqual(response.data["status"], "Pending")
