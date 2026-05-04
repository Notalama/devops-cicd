from django.urls import path
from .views import HealthView, ItemListView

urlpatterns = [
    path("health/", HealthView.as_view()),
    path("items/", ItemListView.as_view()),
]
