from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("solar", "0006_alter_generationrecord_options_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="generationrecord",
            name="generation_date",
            field=models.DateField(
                blank=True,
                db_index=True,
                help_text=(
                    "Local calendar date associated with daily generation."
                ),
                null=True,
            ),
        ),
    ]