import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'hoja_inferior.dart';

class _Parrafo {
  const _Parrafo(this.texto, {this.termino, this.resaltado = false});

  final String texto;

  /// Encabezado en negrita sobre el texto (tipos de cookies, derechos).
  final String? termino;
  final bool resaltado;
}

class _Seccion {
  const _Seccion(this.titulo, this.parrafos);

  final String titulo;
  final List<_Parrafo> parrafos;
}

const _correo = _Parrafo('informacion@equilibra.ec', resaltado: true);

// Texto legal de equilibra.ec: se copia tal cual, no se reescribe aquí.
const _privacidad = [
  _Seccion('¿Qué información recopilamos?', [
    _Parrafo(
      'Recopilamos datos personales que usted nos proporciona voluntariamente '
      'cuando utiliza nuestro sitio, como nombre, correo electrónico y otra '
      'información necesaria para ofrecer nuestros servicios.',
    ),
  ]),
  _Seccion('¿Cómo usamos su información?', [
    _Parrafo(
      'Utilizamos su información exclusivamente para proporcionarle los '
      'servicios solicitados, mejorar su experiencia en el sitio y '
      'comunicarnos con usted en relación con nuestros productos o servicios.',
    ),
  ]),
  _Seccion('¿Con quién compartimos sus datos?', [
    _Parrafo('No compartimos sus datos personales con terceros.'),
  ]),
  _Seccion('Cookies y tecnologías similares', [
    _Parrafo(
      'Utilizamos cookies propias y de terceros para mejorar su experiencia de '
      'navegación, analizar el tráfico y personalizar contenidos. Para más '
      'información, consulte nuestra Política de Cookies.',
    ),
  ]),
  _Seccion('Derechos del usuario', [
    _Parrafo(
      'Sobre los datos personales que tenemos suyos, usted puede pedirnos en '
      'cualquier momento:',
    ),
    _Parrafo(
      'Conocer qué datos personales suyos tratamos y con qué finalidad.',
      termino: 'Acceder',
    ),
    _Parrafo(
      'Corregir cualquier dato que esté incompleto o sea inexacto.',
      termino: 'Rectificar',
    ),
    _Parrafo(
      'Solicitar que borremos sus datos personales de nuestros registros.',
      termino: 'Eliminar',
    ),
    _Parrafo(
      'Restringir el uso que hacemos de sus datos sin llegar a eliminarlos.',
      termino: 'Limitar el tratamiento',
    ),
    _Parrafo(
      'Puede ejercer estos derechos contactándonos a través del correo '
      'electrónico que aparece más abajo.',
    ),
  ]),
  _Seccion('Responsable del tratamiento', [
    _Parrafo(
      'Escríbenos para ejercer sus derechos o resolver cualquier duda.',
      termino: 'Equilibra',
    ),
    _correo,
  ]),
  _Seccion('Cambios en la Política de Privacidad', [
    _Parrafo(
      'Nos reservamos el derecho a modificar esta Política de Privacidad para '
      'adaptarla a cambios legales o técnicos. Le recomendamos revisarla '
      'periódicamente.',
    ),
  ]),
];

const _cookies = [
  _Seccion('¿Qué son las cookies?', [
    _Parrafo(
      'Las cookies son pequeños archivos de texto que se almacenan en tu '
      'dispositivo cuando visitas un sitio web. Sirven para reconocer tu '
      'navegador, recordar tus preferencias y mejorar tu experiencia de '
      'navegación.',
    ),
  ]),
  _Seccion('¿Qué tipos de cookies utilizamos?', [
    _Parrafo('En Equilibra utilizamos los siguientes tipos de cookies:'),
    _Parrafo(
      'Son esenciales para que Equilibra funcione correctamente, como mantener '
      'la sesión iniciada o recordar configuraciones básicas. Estas cookies no '
      'suelen recopilar información personal identificable.',
      termino: 'Cookies necesarias',
    ),
    _Parrafo(
      'Nos permiten conocer cómo se utiliza el sitio para mejorar su '
      'rendimiento y ofrecerte una mejor experiencia.',
      termino: 'Cookies de análisis',
    ),
    _Parrafo(
      'Recuerdan tus preferencias para mostrar contenido ajustado a tus '
      'intereses.',
      termino: 'Cookies de personalización',
    ),
    _Parrafo(
      'Pueden ser instaladas por servicios externos que usamos, como '
      'reproductores de video o redes sociales.',
      termino: 'Cookies de terceros',
    ),
  ]),
  _Seccion('¿Con qué finalidad tratamos los datos?', [
    _Parrafo(
      'Las cookies que utilizamos se emplean exclusivamente para los fines '
      'asociados al producto o servicio que promocionamos. No compartimos tus '
      'datos con terceros con fines comerciales no relacionados, y nunca '
      'realizamos perfiles automatizados sin tu consentimiento explícito.',
    ),
  ]),
  _Seccion('¿Cómo puedes gestionar tus cookies?', [
    _Parrafo(
      'Puedes aceptar, rechazar o configurar el uso de cookies en cualquier '
      'momento desde el banner inicial o ajustando la configuración de tu '
      'navegador.',
    ),
    _Parrafo(
      'Consulta estos enlaces para instrucciones específicas según tu '
      'navegador:',
    ),
    _Parrafo('Google Chrome\nMozilla Firefox\nSafari\nMicrosoft Edge'),
  ]),
  _Seccion('¿Quién es el responsable del tratamiento?', [
    _Parrafo(
      'Escríbenos para cualquier consulta sobre el uso de cookies.',
      termino: 'Equilibra.ec',
    ),
    _correo,
  ]),
  _Seccion('Modificaciones', [
    _Parrafo(
      'Nos reservamos el derecho de modificar esta Política de Cookies en '
      'cualquier momento para adaptarla a cambios legales o técnicos. Te '
      'recomendamos revisarla periódicamente.',
    ),
    _Parrafo('También puedes consultar nuestra Política de Privacidad.'),
  ]),
];

enum Politica {
  privacidad('Política de privacidad', _privacidad),
  cookies('Política de cookies', _cookies);

  const Politica(this.titulo, this._secciones);

  final String titulo;
  final List<_Seccion> _secciones;
}

Future<void> abrirPolitica(BuildContext context, Politica politica) =>
    abrirHoja<void>(context, _HojaPolitica(politica));

class _HojaPolitica extends StatelessWidget {
  const _HojaPolitica(this.politica);

  final Politica politica;

  @override
  Widget build(BuildContext context) {
    return HojaInferior(
      titulo: politica.titulo,
      // SelectionArea permite copiar el correo de contacto.
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(EqSpace.lg),
          children: [
            for (final (i, seccion) in politica._secciones.indexed) ...[
              if (i > 0) const SizedBox(height: EqSpace.lg),
              Text('${i + 1}. ${seccion.titulo}', style: EqText.h4),
              for (final parrafo in seccion.parrafos) ...[
                const SizedBox(height: EqSpace.sm),
                if (parrafo.termino != null)
                  Text(parrafo.termino!, style: EqText.label),
                Text(
                  parrafo.texto,
                  style: parrafo.resaltado
                      ? EqText.bodySm.copyWith(
                          color: EqColors.primary,
                          fontWeight: FontWeight.w600,
                        )
                      : EqText.bodySm,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
