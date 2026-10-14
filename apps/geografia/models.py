"""Modelos de los catálogos geográficos.

managed = False: las tablas ya existen en MariaDB y Django no las crea ni
las modifica. Las escrituras de la API pasan por los procedimientos
almacenados; estos modelos sirven para consultas con el ORM, el shell y
para documentar el esquema.

Las llaves compuestas usan models.CompositePrimaryKey (Django 5.2+).
Django aún no soporta ForeignKey hacia una llave compuesta, por eso las
relaciones provincia -> cantón -> distrito se guardan como códigos y se
exponen con propiedades.
"""
from django.db import models


class Pais(models.Model):
    cod_pais = models.CharField(max_length=10, primary_key=True)
    nombre_pais = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = "geo_paises"
        verbose_name = "país"
        verbose_name_plural = "países"
        ordering = ["nombre_pais"]

    def __str__(self):
        return self.nombre_pais


class Provincia(models.Model):
    pk = models.CompositePrimaryKey("pais_id", "cod_provincia")
    pais = models.ForeignKey(Pais, on_delete=models.DO_NOTHING, db_column="cod_pais",
                             related_name="provincias")
    cod_provincia = models.CharField(max_length=10)
    nombre_provincia = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = "geo_provincias"
        verbose_name = "provincia"
        verbose_name_plural = "provincias"
        ordering = ["pais_id", "cod_provincia"]

    def __str__(self):
        return self.nombre_provincia

    @property
    def cantones(self):
        return Canton.objects.filter(pais_id=self.pais_id, cod_provincia=self.cod_provincia)


class Canton(models.Model):
    pk = models.CompositePrimaryKey("pais_id", "cod_provincia", "cod_canton")
    pais = models.ForeignKey(Pais, on_delete=models.DO_NOTHING, db_column="cod_pais",
                             related_name="+")
    cod_provincia = models.CharField(max_length=10)
    cod_canton = models.CharField(max_length=10)
    nombre_canton = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = "geo_cantones"
        verbose_name = "cantón"
        verbose_name_plural = "cantones"
        ordering = ["pais_id", "cod_provincia", "cod_canton"]

    def __str__(self):
        return self.nombre_canton

    @property
    def provincia(self):
        return Provincia.objects.filter(pais_id=self.pais_id, cod_provincia=self.cod_provincia).first()

    @property
    def distritos(self):
        return Distrito.objects.filter(pais_id=self.pais_id, cod_provincia=self.cod_provincia,
                                       cod_canton=self.cod_canton)


class Distrito(models.Model):
    pk = models.CompositePrimaryKey("pais_id", "cod_provincia", "cod_canton", "cod_distrito")
    pais = models.ForeignKey(Pais, on_delete=models.DO_NOTHING, db_column="cod_pais",
                             related_name="+")
    cod_provincia = models.CharField(max_length=10)
    cod_canton = models.CharField(max_length=10)
    cod_distrito = models.CharField(max_length=10)
    nombre_distrito = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = "geo_distritos"
        verbose_name = "distrito"
        verbose_name_plural = "distritos"
        ordering = ["pais_id", "cod_provincia", "cod_canton", "cod_distrito"]

    def __str__(self):
        return self.nombre_distrito

    @property
    def canton(self):
        return Canton.objects.filter(pais_id=self.pais_id, cod_provincia=self.cod_provincia,
                                     cod_canton=self.cod_canton).first()
