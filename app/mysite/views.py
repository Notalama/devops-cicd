from django.http import JsonResponse
from django.db import connection


def home(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT version();")
        pg_version = cursor.fetchone()[0]

    return JsonResponse({
        "status": "ok",
        "message": "Django + PostgreSQL + Nginx is running!",
        "database": pg_version,
    })
