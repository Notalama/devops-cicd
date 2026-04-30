from django.http import JsonResponse
from django.views import View


class HealthView(View):
    def get(self, request):
        return JsonResponse({"status": "ok", "service": "django-app"})


class ItemListView(View):
    def get(self, request):
        items = [
            {"id": 1, "name": "Item One"},
            {"id": 2, "name": "Item Two"},
        ]
        return JsonResponse({"items": items})
