from django.urls import path

from .views import AuditoriaView

app_name = "auditoria"

urlpatterns = [
    path("", AuditoriaView.as_view(), name="auditoria"),
]
