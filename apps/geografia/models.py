from django.db import models

class Pais(models.Model):
    # Identidad territorial
    cod_pais = models.CharField(primary_key=True, max_length=10, db_column='cod_pais')
    nombre_pais = models.CharField(max_length=100, db_column='nombre_pais')

    # Metadatos del modelo
    class Meta:
        db_table = 'geo_paises'
        verbose_name = 'País'
        verbose_name_plural = 'Países'

    # Representación en texto
    def __str__(self):
        return f"{self.cod_pais} {self.nombre_pais}"

class Provincia(models.Model):
    # Identidad territorial
    cod_provincia = models.CharField(primary_key=True, max_length=10, db_column='cod_provincia')
    nombre_provincia = models.CharField(max_length=100, db_column='nombre_provincia')
    
    # Relaciones jerárquicas
    cod_pais = models.ForeignKey(Pais, on_delete=models.CASCADE, db_column='cod_pais')

    # Metadatos del modelo
    class Meta:
        db_table = 'geo_provincias'
        unique_together = (('cod_pais', 'cod_provincia'),)
        verbose_name = 'Provincia'
        verbose_name_plural = 'Provincias'

    # Representación en texto
    def __str__(self):
        return f"{self.nombre_provincia} ({self.cod_pais_id})"

class Canton(models.Model):
    # Identidad territorial
    cod_canton = models.CharField(primary_key=True, max_length=10, db_column='cod_canton')
    nombre_canton = models.CharField(max_length=100, db_column='nombre_canton')
    
    # Relaciones jerárquicas directas e indirectas
    cod_pais = models.CharField(max_length=10, db_column='cod_pais')
    cod_provincia = models.ForeignKey(Provincia, on_delete=models.CASCADE, db_column='cod_provincia')

    # Metadatos del modelo
    class Meta:
        db_table = 'geo_cantones'
        unique_together = (('cod_pais', 'cod_provincia', 'cod_canton'),)
        verbose_name = 'Cantón'
        verbose_name_plural = 'Cantones'

    # Representación en texto
    def __str__(self):
        return self.nombre_canton

class Distrito(models.Model):
    # Identidad territorial
    cod_distrito = models.CharField(primary_key=True, max_length=10, db_column='cod_distrito')
    nombre_distrito = models.CharField(max_length=100, db_column='nombre_distrito')
    
    # Relaciones jerárquicas directas e indirectas
    cod_pais = models.CharField(max_length=10, db_column='cod_pais')
    cod_provincia = models.CharField(max_length=10, db_column='cod_provincia')
    cod_canton = models.ForeignKey(Canton, on_delete=models.CASCADE, db_column='cod_canton')

    # Metadatos del modelo
    class Meta:
        db_table = 'geo_distritos'
        unique_together = (('cod_pais', 'cod_provincia', 'cod_canton', 'cod_distrito'),)
        verbose_name = 'Distrito'
        verbose_name_plural = 'Distritos'

    # Representación en texto
    def __str__(self):
        return self.nombre_distrito