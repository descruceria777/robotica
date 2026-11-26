#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "03",
  titulo: [Movimiento y trayectorias],
  subtitulo: [Velocidad angular, integración y perfiles de movimiento suaves],
  capitulo: "3",
  herramientas: ("Python", "NumPy", "SciPy", "Robotics Toolbox", "ROS 2", "RViz2"),
  duracion: "1–2 sesiones",
  color: rgb("#c2410c"),
  objetivos: (
    [Relacionar la velocidad angular con el cambio de orientación en el tiempo.],
    [Integrar orientación con cuaterniones y medir el error de la integración discreta.],
    [Generar trayectorias quínticas y trapezoidales y comparar sus perfiles.],
    [Interpolar orientación con SLERP y animar un marco en RViz2.],
  ),
)

= De la pose a la pose en el tiempo

En el laboratorio anterior la pose era una foto fija. Ahora cambia: el robot tiene una pose $bold(T)(t)$ y nos interesan su *velocidad* y la forma de ir de una pose a otra.

Para la orientación, la velocidad es la *velocidad angular* $bold(omega)$: un vector cuyo eje es el eje de giro instantáneo y cuya magnitud es la rapidez de giro en rad/s. Si $bold(omega)$ se mantiene constante durante $Delta t$, la orientación avanza

$ bold(R)(t + Delta t) = bold(R)(t) thin e^([bold(omega)]_times Delta t) quad <==> quad q(t + Delta t) = q(t) times.o Delta q(bold(omega) Delta t) $

donde $Delta q$ es el cuaternión del giro $bold(omega) Delta t$. Repetir este paso es *integrar*.

#idea[Multiplicar *por la derecha* ($q times.o Delta q$) significa que $bold(omega)$ está expresada en el marco del cuerpo, que es como mide una IMU montada en el robot. Multiplicar por la izquierda correspondería a un $bold(omega)$ medido en el marco del mundo.]

= Integración de orientación

#actividad("1", [Integrar y comparar con la solución exacta])[
  Con $bold(omega)$ constante existe solución exacta: un solo giro de ángulo $norm(bold(omega)) t$. Eso permite medir el error de integrar paso a paso.

  #archivo("integracion.py", ```python
import numpy as np
from scipy.spatial.transform import Rotation as R

w = np.array([0.1, 0.2, 0.3])        # rad/s, en el marco del cuerpo
T = 10.0                             # duración [s]

exacta = R.from_rotvec(w * T)

for dt in [0.5, 0.1, 0.01, 0.001]:
    q = R.identity()
    for _ in range(int(T / dt)):
        q = q * R.from_rotvec(w * dt)
    err = np.degrees((q * exacta.inv()).magnitude())
    print(f"dt = {dt:<6} error = {err:.2e}°")
  ```)

  + ¿Por qué con $bold(omega)$ constante el error es prácticamente cero sin importar $Delta t$?
  + Cambia a $bold(omega)(t) = (0, 0.5 sin t, 0.3)$, evaluada al inicio de cada paso, y calcula una referencia con $Delta t = 10^(-5)$. ¿Cómo crece ahora el error con $Delta t$?
]

#cuidado[En un robot real $bold(omega)$ nunca es constante y además viene con ruido y sesgo (_bias_). Ambos errores se *acumulan* en la integración: esa es la deriva de un INS.]

= El nodo de ROS 2

El integrador del Laboratorio 00 ya hace esto en ROS 2: se suscribe a `/imu`, integra con $Delta t$ tomado de las marcas de tiempo y publica `world → imu_link` en TF.

#flujo([`imu_simulator`], "/imu", [`imu_integrator`], "/tf", [RViz2])

#actividad("2", [Reutilizar y extender el integrador])[
  + Ejecuta el simulador y el integrador del Laboratorio 00 y verifica la rotación en RViz2.
  + Modifica el simulador para que publique $omega_z(t) = 0.8 sin(0.5 t)$. ¿Qué movimiento esperas ver? Compruébalo.
  + Agrega al integrador un `get_logger().info` que imprima el ángulo acumulado una vez por segundo y compáralo con la integral analítica de $omega_z(t)$.
]

= Trayectorias en el tiempo

Una *trayectoria* dice *dónde* debe estar una variable en *cada instante*. Se describe con una función normalizada $s(tau)$, con $tau = t\/T in [0, 1]$, que va de 0 a 1:

$ q(t) = q_0 + s(t \/ T) (q_f - q_0) $

Dos perfiles muy usados:

#grid(columns: (1fr, 1fr), column-gutter: 14pt,
  block(fill: gris-claro.lighten(40%), inset: 10pt, radius: 5pt, width: 100%)[
    *Quíntico* \
    $s(tau) = 10 tau^3 - 15 tau^4 + 6 tau^5$. Velocidad y aceleración nulas en ambos extremos.
  ],
  block(fill: gris-claro.lighten(40%), inset: 10pt, radius: 5pt, width: 100%)[
    *Trapezoidal (LSPB)* \
    Acelera a ritmo constante, crucero a velocidad constante y frena. La velocidad tiene forma de trapecio.
  ],
)

#let quintica(t) = 10 * calc.pow(t, 3) - 15 * calc.pow(t, 4) + 6 * calc.pow(t, 5)
#let quintica-v(t) = 30 * calc.pow(t, 2) - 60 * calc.pow(t, 3) + 30 * calc.pow(t, 4)
// Trapezoidal con fase de aceleración de 1/3 del tiempo: velocidad crucero 1.5
#let trap(t) = if t < 1/3 { 2.25 * t * t } else if t < 2/3 { 0.25 + 1.5 * (t - 1/3) } else { 1 - 2.25 * calc.pow(1 - t, 2) }
#let trap-v(t) = if t < 1/3 { 4.5 * t } else if t < 2/3 { 1.5 } else { 4.5 * (1 - t) }

#figure(
  grid(columns: 2, column-gutter: 1.2cm,
    grafica(((quintica, rgb("#c2410c"), "quíntica"), (trap, rgb("#2563eb"), "trapezoidal")),
      ancho: 6.2cm, alto: 3.6cm, xlabel: $tau$, ylabel: $s(tau)$),
    grafica(((quintica-v, rgb("#c2410c"), "quíntica"), (trap-v, rgb("#2563eb"), "trapezoidal")),
      ancho: 6.2cm, alto: 3.6cm, ymax: 2.0, xlabel: $tau$, ylabel: $dot(s)(tau)$),
  ),
  caption: [Posición normalizada (izquierda) y velocidad (derecha). La trapezoidal tiene una velocidad máxima menor (1.5 frente a 1.875), pero su aceleración salta de forma brusca.],
)

#actividad("3", [Comparar perfiles])[
  #archivo("perfiles.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from roboticstoolbox import quintic, trapezoidal

t = np.linspace(0, 2, 201)            # 2 s de movimiento
perfiles = {"quíntico": quintic(0, 1, t), "trapezoidal": trapezoidal(0, 1, t)}

fig, ax = plt.subplots(3, 1, sharex=True, figsize=(7, 7))
for nombre, tr in perfiles.items():
    for a, datos, etq in zip(ax, (tr.q, tr.qd, tr.qdd), ("q", "q̇", "q̈")):
        a.plot(t, datos, label=nombre)
        a.set_ylabel(etq); a.grid(True)
ax[0].legend(); ax[2].set_xlabel("t [s]")
plt.tight_layout(); plt.show()
  ```)

  + Anota la velocidad y la aceleración máximas de cada perfil.
  + ¿Cuál de los dos tiene la aceleración continua? ¿Qué consecuencia tiene esto en los motores y la estructura del robot?
  + Repite con $T = 1$ s. ¿Cómo escalan la velocidad y la aceleración máximas con $T$?
]

= Interpolar orientación

Para la orientación se usa SLERP (Laboratorio 02) con el parámetro $s(tau)$ de un perfil suave. Así el giro empieza y termina sin sacudidas.

#actividad("4", [Orientación con perfil quíntico])[
  #archivo("slerp_suave.py", ```python
import numpy as np
from scipy.spatial.transform import Rotation as R, Slerp

slerp = Slerp([0, 1], R.from_euler('z', [0, 120], degrees=True))
tau = np.linspace(0, 1, 11)
s = 10 * tau**3 - 15 * tau**4 + 6 * tau**5          # perfil quíntico
yaw = slerp(s).as_euler('xyz', degrees=True)[:, 2]
for a, b in zip(tau, yaw):
    print(f"tau = {a:.1f}   yaw = {b:7.2f}°")
  ```)

  Compara con usar `slerp(tau)` directamente. ¿Qué diferencia hay en el espaciado de los ángulos al inicio y al final?
]

= Todo junto en RViz2

#actividad("5", [Un marco que sigue una trayectoria])[
  Escribe un nodo `tf_trayectoria` que publique `world → herramienta` a 30 Hz moviendo el marco:

  - en posición, de $(0, 0, 0)$ a $(1, 1, 0.5)$ m con perfil quíntico en $T = 4$ s;
  - en orientación, de 0° a 180° en $Z$ con SLERP usando el mismo $s(tau)$;
  - al terminar, que repita el movimiento en sentido contrario.

  Visualízalo en RViz2 con *TF* y *Axes* (Fixed Frame: `world`). Usa como base el nodo `tf_orbita` del Laboratorio 02.
]

#reto[Agrega un display *Path* en RViz2 publicando en `/trayectoria` un `nav_msgs/Path` con las posiciones ya recorridas, para ver la estela del movimiento.]

#preguntas[
  + ¿Qué relación hay entre la velocidad angular y la orientación? ¿Por qué no basta con «sumar ángulos»?
  + ¿Qué errores introduce la integración discreta y de qué depende su tamaño?
  + ¿Por qué se integra con cuaterniones y no con matrices de rotación?
  + ¿Qué diferencia hay entre una *trayectoria* y una *ley de velocidad*?
  + ¿Por qué el perfil trapezoidal es tan común en la industria aunque su aceleración sea discontinua?
  + Da un ejemplo real donde importe la suavidad de la trayectoria (piensa en un brazo que transporta un líquido).
]

#entregables(
  [Tabla de errores de la Actividad 1 y su análisis.],
  [Gráficas de la Actividad 3 con la tabla de valores máximos.],
  [Código del nodo `tf_trayectoria` y una captura o video corto de RViz2.],
  [Respuestas a las preguntas.],
)
