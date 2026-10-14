from rest_framework import serializers


class Descripcion50Serializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=50)


class Descripcion80Serializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=80)


class Descripcion120Serializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=120)
