#!/usr/bin/env bash
# =====================================================================
#  verificar_archivos.sh - módulo de usuarios y proveedores
# ---------------------------------------------------------------------
#  Revisa que cada archivo copiado al servidor esté completo (tamaño y
#  código md5) y que settings.py tenga lo que el módulo necesita.
#  Ejecute en la carpeta backend del módulo:  bash verificar_archivos.sh
# =====================================================================
cd "$(dirname "$0")" || exit 1
mal=0
while read -r tam md5 ruta; do
  if [ ! -f "$ruta" ]; then echo "MAL: falta $ruta"; mal=1; continue; fi
  real_tam=$(wc -c < "$ruta" | tr -d ' ')
  real_md5=$(md5sum "$ruta" | cut -d' ' -f1)
  if [ "$real_tam" != "$tam" ]; then echo "MAL: $ruta tiene $real_tam bytes y debe tener $tam"; mal=1
  elif [ "$real_md5" != "$md5" ]; then echo "MAL: $ruta tiene el mismo tamaño pero otro contenido"; mal=1
  else echo "ok  $ruta"; fi
done <<'LISTA'
3020 182798d5939cac0ce225c38e0e1c45e8 README.md
668 e1734bb8d3090035981e174ccc8441f6 manage.py
254 9073ec6c8ad5b718618b325d3306d254 requirements.txt
0 d41d8cd98f00b204e9800998ecf8427e apps/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/auditoria/__init__.py
63 e3dc717de887db03a015667a5fec59d8 apps/auditoria/admin.py
211 48290eaa610d96566aa23223c9ab9423 apps/auditoria/apps.py
1008 c743c787f16639be728a9094da884fc4 apps/auditoria/models.py
60 465b7e9f69bfd158c850cdfbc7306818 apps/auditoria/tests.py
163 89f7558cf80f7cd47550965268774ed8 apps/auditoria/urls.py
4123 7ca8104317da33380a3bac3c5a8f50ce apps/auditoria/views.py
0 d41d8cd98f00b204e9800998ecf8427e apps/auditoria/migrations/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/catalogos/__init__.py
63 e3dc717de887db03a015667a5fec59d8 apps/catalogos/admin.py
208 fb974b66f5d39a222afa67c338f7e000 apps/catalogos/apps.py
2584 0bb63d4faa262678837f00060f1ecac5 apps/catalogos/models.py
491 62cf133d87e3cab2dd64a0fb8cb31696 apps/catalogos/serializers.py
60 465b7e9f69bfd158c850cdfbc7306818 apps/catalogos/tests.py
905 dee21727e5590b8ded7d31e4d76efd27 apps/catalogos/urls.py
1498 d0b13a5f08bf60d30f81675ca43df262 apps/catalogos/views.py
0 d41d8cd98f00b204e9800998ecf8427e apps/catalogos/migrations/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/core/__init__.py
301 4a6bae1e3dc9ca4f0860d2b66aafcca8 apps/core/apps.py
11856 158fa29610beb34bba03be64e187239c apps/core/archivos.py
2463 3f0341741dc7cb1405d973a2d48f1570 apps/core/auditoria.py
3138 128e9d2ffcd44ce7d6e0bea06924e570 apps/core/autenticacion.py
5212 432007f050602d4b3608b91fe7554431 apps/core/consultas.py
2375 8759c9a627e64e0ec4f2bb336cdd83b2 apps/core/db.py
562 5c720615aa4af26614a07b4c62193399 apps/core/esquema.py
3484 a74d8d78614989a8ac5dd193e145a0b9 apps/core/excepciones.py
635 573204f7d69ee1c747fa7cff6928e745 apps/core/frontend.py
2771 8ac75a1eb8947bf1d4d1aa654003337c apps/core/nombres.py
1037 c64a9023b7bb9122fd24b204b25a53eb apps/core/permisos.py
790 fa61e23c7ba05dd7271012c9b95b5024 apps/core/rutas.py
5355 89a1f88ac043925a9e66d0a67fb93bfb apps/core/viewsets.py
0 d41d8cd98f00b204e9800998ecf8427e apps/core/migrations/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/geografia/__init__.py
63 e3dc717de887db03a015667a5fec59d8 apps/geografia/admin.py
208 5e406124f696a9364f6406fc6654792d apps/geografia/apps.py
3652 d8aae072955bfd838b27a491601cab83 apps/geografia/models.py
2868 142baef56bf32bdb39e5e6cc2393c871 apps/geografia/serializers.py
60 465b7e9f69bfd158c850cdfbc7306818 apps/geografia/tests.py
618 25bd1d255fb7bc43cb6c5a6cce03794f apps/geografia/urls.py
2119 23acd8ba353d2a63fccab031e9b71c34 apps/geografia/views.py
0 d41d8cd98f00b204e9800998ecf8427e apps/geografia/migrations/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/proveedores/__init__.py
63 e3dc717de887db03a015667a5fec59d8 apps/proveedores/admin.py
215 75934b890dc3aabc5f4b813aa7158325 apps/proveedores/apps.py
3447 8b765b2c02607d932f59dd8ae20e90dc apps/proveedores/archivos.py
718 318ab3ab0c7ed2eb04bae66c753d34c4 apps/proveedores/models.py
2647 4ee90a40eb89383731fba88612332b96 apps/proveedores/serializers.py
60 465b7e9f69bfd158c850cdfbc7306818 apps/proveedores/tests.py
1485 52d6f56c5b9fb88b399708021855d3f3 apps/proveedores/urls.py
3785 7c112fde51979234074e091777840a94 apps/proveedores/views.py
0 d41d8cd98f00b204e9800998ecf8427e apps/proveedores/migrations/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/usuarios/__init__.py
63 e3dc717de887db03a015667a5fec59d8 apps/usuarios/admin.py
153 d236e5f123ecd4aafe56045718ed3a06 apps/usuarios/apps.py
6971 cc48aef18e9e571f19a09aed49527734 apps/usuarios/models.py
4025 45279fd10dbb879a786caa31fc6715be apps/usuarios/serializers.py
60 465b7e9f69bfd158c850cdfbc7306818 apps/usuarios/tests.py
1648 905ef4bbf990fb627bb95ce056535fed apps/usuarios/urls.py
10924 c19fb984e81e449cbd869a3ed4976565 apps/usuarios/views.py
0 d41d8cd98f00b204e9800998ecf8427e apps/usuarios/management/__init__.py
0 d41d8cd98f00b204e9800998ecf8427e apps/usuarios/management/commands/__init__.py
5032 f6faea971da91a116d317a0597f5ab43 apps/usuarios/management/commands/inicializar.py
0 d41d8cd98f00b204e9800998ecf8427e apps/usuarios/migrations/__init__.py
23014 4647222f2a0c123cc152944cc89745cf frontend/index.html
136705 28645f63a64c12e2776818b77d41f482 frontend/css/app.css
6517 c1f6b0b1fd73d9d3d50a369dd2096b7d frontend/js/api.js
18249 d4902764ed146a32b9422d654854bf7f frontend/js/app.js
18747 c21feab606c65a3ab68c21e0ec582d1a frontend/js/auditoria.js
503 b6a4af595e8068cb76de87753a5803cd frontend/js/config.js
5934 d54311adb4c0981a0ff1401a6966cd27 frontend/js/datos.js
6181 8f61e8e33a359ef5f27f1c809d4771d9 frontend/js/foto.js
30192 15e3ae0c0961c805bb02ec00fdd60250 frontend/js/proveedores.js
12558 d7e5107dd68e672833717ffb697ea39e frontend/js/recursos.js
17815 891ff564cb18d33091177fe79bc0c274 frontend/js/ui.js
43007 61f3ebae112627dae5cea53420c15786 frontend/js/usuarios.js
9167 1ec456695449d31204ed99a3fc24162d frontend/js/zoom.js
0 d41d8cd98f00b204e9800998ecf8427e muni_backend/__init__.py
401 fc1b90e9ca33cb8492f758c507ace08b muni_backend/asgi.py
1118 43ee6bdcac702ec7b11a89c33f49a097 muni_backend/urls.py
401 ac63627a674cec129c1b2327a7ef6b3c muni_backend/wsgi.py
8031 d9ce33d0c04feddbbd3a8c3243f2d9ce sql/reinstalar_base.sh
2996 492174de092bfd3f997291d91a958cbe sql/reparar_letras.sql
58506 e10904c0c16ad9d081a6bc6a72fe0f35 sql/revisar_base.sql
54703 01fa95ae3e7796e110031a1583424a36 sql/instalacion/01_estructura.sql
106520 c748b858560d418f3f7783f3feaf9771 sql/instalacion/02_procedimientos.sql
38273 5ad762f6d97aa7e8332750ed9eb2c71c sql/instalacion/03_datos.sql
1693 f8a3a999303998cd755d2e31c9414bc6 sql/pruebas/borrarDatosEjemplo.sql
19133 f3a3d0185a7cc7e8a1fa582523ab623b sql/pruebas/poblarDatosEjemplo.sql
LISTA
# muni_backend/settings.py puede tener su propia clave y datos de conexión:
# por eso de ese archivo solo se revisa lo que el módulo necesita.
for app in apps.core apps.geografia apps.catalogos apps.usuarios apps.proveedores apps.auditoria; do
  grep -qE "[\"']$app[\"']" muni_backend/settings.py || { echo "MAL: falta '$app' en INSTALLED_APPS (muni_backend/settings.py)"; mal=1; }
done
for app in apps.dispositivos apps.logs apps.correo; do
  grep -qE "[\"']$app[\"']" muni_backend/settings.py && { echo "MAL: '$app' es de otro módulo: quítelo de INSTALLED_APPS"; mal=1; }
done
grep -qE "[\"']NAME[\"']: *[\"']gestion_redes[\"']" muni_backend/settings.py || { echo "MAL: en muni_backend/settings.py la base debe llamarse 'gestion_redes'"; mal=1; }
[ $mal = 0 ] && echo "Todo coincide." || echo "Hay archivos por copiar de nuevo."
