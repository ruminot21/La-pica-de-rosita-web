# La Pica de Rosita — fidelización web

Web responsive con registro de clientes, QR permanente, 5 sellos, elección de recompensa, escaneo y panel del local.

## Puesta en marcha
1. Crea un proyecto en Supabase (https://supabase.com).
2. Ejecuta `schema.sql` completo en SQL Editor.
3. En Authentication > Users, crea el usuario del local (correo y contraseña).
4. En SQL Editor ejecuta `insert into public.staff (user_id) values ('UUID_DEL_USUARIO');` reemplazando el UUID por el ID del usuario creado.
5. En `config.js`, pega la **Project URL** y la clave **anon/publishable** de Supabase. NUNCA la service_role.
6. Publica estos archivos en un hosting estático HTTPS (Netlify, Vercel o similar). Puedes probar con un servidor local, pero el escáner de cámara requiere HTTPS o localhost.
7. Abre la página. Clientes usan «Mi tarjeta» y personal «Acceso local».

## Seguridad y operación
- Los sellos y canjes se validan en la base de datos mediante funciones SQL que comprueban que el usuario autenticado pertenece a `staff`.
- Los clientes solo pueden consultar la tarjeta si tienen el enlace secreto de su QR. Guarda ese enlace como una credencial; si se comparte, otra persona podrá ver la tarjeta.
- Para producción, añade protección contra registros automatizados (CAPTCHA/rate limiting mediante un backend/Edge Function). Esta versión inicial limita por teléfono pero no incorpora un control anti-bots robusto.
- Los teléfonos se guardan en la base de datos: publica aviso de privacidad y gestiona consentimientos y borrado según la legislación local.
- No uses un archivo abierto directamente (`file://`); sírvelo por HTTPS.
- La elección de premio queda pendiente de confirmación por el personal; después del canje, se inicia un ciclo nuevo con el mismo QR.


## Administración independiente (NUEVO)
- **index.html**: registro y tarjeta del cliente.
- **admin.html**: panel independiente para el negocio, con inicio de sesión, personalización del nombre, logo mediante URL HTTPS, eslogan, escáner QR, sellos, canjes, clientes e historial (últimos 500 movimientos).
- Ejecuta **admin.sql** en Supabase SQL Editor después de **schema.sql**.
- Crea el usuario de administrador en Authentication > Users y autorízalo en la tabla `staff` como se explica arriba. Solo personal autorizado puede usar el panel.
- Configura URL y clave pública en `config.js`. No pongas nunca la clave service_role en archivos web.
- Para el logo, sube la imagen a un alojamiento público HTTPS y pega su enlace en Administración > Personalizar negocio.
- Publica ambos HTML y los scripts en el mismo sitio HTTPS. La cámara requiere HTTPS o localhost.
- Los datos se guardan en Supabase, no solo en el navegador. No basta con abrir el HTML desde archivos locales.
- Antes de usarlo con clientes reales: configura protección contra registros automatizados, aviso de privacidad y política de retención de datos.
