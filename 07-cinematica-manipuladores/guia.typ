#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "07",
  titulo: [Cinemática de manipuladores],
  subtitulo: [Directa, inversa, jacobiano y trayectorias en un brazo plano 2R],
  capitulo: "7",
  herramientas: ("Python", "Robotics Toolbox", "NumPy", "Matplotlib"),
  duracion: "2 sesiones",
  color: rgb("#4338ca"),
  objetivos: (
    [Calcular la posición del efector final a partir de los ángulos articulares.],
    [Describir el espacio de trabajo y distinguir puntos alcanzables e inalcanzables.],
    [Resolver la cinemática inversa y elegir entre codo arriba y codo abajo.],
    [Interpretar el jacobiano e identificar singularidades.],
    [Generar trayectorias articulares suaves y analizar el camino cartesiano resultante.],
  ),
)

= El brazo 2R

Todo el laboratorio usa el mismo robot: un brazo plano con dos articulaciones rotacionales (2R), de eslabones $L_1 = 0.6$ m y $L_2 = 0.4$ m. Es el manipulador más simple con todos los fenómenos interesantes: varias soluciones, límites de alcance y singularidades.

#let brazo = box(width: 8cm, height: 5cm, {
  let c = rgb("#4338ca")
  let O = (1.2cm, 4.3cm)
  let l1 = 3.3cm
  let l2 = 2.2cm
  let q1 = 35deg
  let q2 = 50deg
  let A = (O.at(0) + l1 * calc.cos(q1), O.at(1) - l1 * calc.sin(q1))
  let E = (A.at(0) + l2 * calc.cos(q1 + q2), A.at(1) - l2 * calc.sin(q1 + q2))
  place(line(start: (0.3cm, O.at(1)), end: (7.6cm, O.at(1)), stroke: 0.6pt + gris))
  place(line(start: O, end: (O.at(0) + 1.6cm, O.at(1)), stroke: (paint: gris, thickness: 0.6pt, dash: "dashed")))
  place(line(start: A, end: (A.at(0) + 1.3cm * calc.cos(q1), A.at(1) - 1.3cm * calc.sin(q1)), stroke: (paint: gris, thickness: 0.6pt, dash: "dashed")))
  place(line(start: O, end: A, stroke: (paint: c, thickness: 7pt, cap: "round")))
  place(line(start: A, end: E, stroke: (paint: c.lighten(30%), thickness: 6pt, cap: "round")))
  for p in (O, A) { place(dx: p.at(0) - 5pt, dy: p.at(1) - 5pt, circle(radius: 5pt, fill: white, stroke: 1.5pt + tinta)) }
  place(dx: E.at(0) - 4pt, dy: E.at(1) - 4pt, circle(radius: 4pt, fill: rgb("#dc2626")))
  place(dx: O.at(0) - 0.5cm, dy: O.at(1), rect(width: 1cm, height: 0.3cm, fill: gris-claro.darken(20%)))
  etiqueta((O.at(0) + 1.5cm, O.at(1) - 0.35cm), $q_1$)
  etiqueta((A.at(0) + 0.95cm, A.at(1) - 0.2cm), $q_2$)
  etiqueta((O.at(0) + 1.3cm, O.at(1) - 1.4cm), $L_1$, color: c)
  etiqueta((A.at(0) - 0.25cm, A.at(1) - 1.1cm), $L_2$, color: c)
  etiqueta((E.at(0) + 0.55cm, E.at(1)), $(x, y)$, tam: 9pt, color: rgb("#dc2626"))
})

#let espacio = box(width: 5.2cm, height: 5cm, {
  let c = rgb("#4338ca")
  let O = (2.6cm, 2.5cm)
  let s = 2.2cm
  place(dx: O.at(0) - s, dy: O.at(1) - s, circle(radius: s, fill: c.lighten(85%), stroke: 1pt + c))
  place(dx: O.at(0) - 0.2 * s, dy: O.at(1) - 0.2 * s, circle(radius: 0.2 * s, fill: white, stroke: 1pt + c))
  place(dx: O.at(0) - 3pt, dy: O.at(1) - 3pt, circle(radius: 3pt, fill: tinta))
  flecha(O, (O.at(0) + s * calc.cos(30deg), O.at(1) - s * calc.sin(30deg)), color: tinta, grosor: 0.8pt)
  etiqueta((O.at(0) + 1.3cm, O.at(1) - 1.0cm), $r_max$, tam: 9pt)
  etiqueta((O.at(0), O.at(1) + 0.75cm), text(size: 7.5pt)[$r_min$], tam: 8pt)
})

#figure(grid(columns: 2, column-gutter: 0.8cm, align: bottom, brazo, espacio), kind: image,
  caption: [Izquierda: variables del brazo 2R. Derecha: su espacio de trabajo es un anillo entre $r_min = |L_1 - L_2|$ y $r_max = L_1 + L_2$.])

= Cinemática directa

La cinemática directa responde: _dados los ángulos, ¿dónde está la pinza?_ Sumando las proyecciones de cada eslabón:

$ x = L_1 cos q_1 + L_2 cos(q_1 + q_2), quad y = L_1 sin q_1 + L_2 sin(q_1 + q_2), quad phi = q_1 + q_2 $

En Robotics Toolbox el mismo modelo se escribe como una secuencia de transformaciones elementales: girar, avanzar $L_1$, girar, avanzar $L_2$.

#actividad("1", [Configuraciones y espacio de trabajo])[
  #archivo("cinematica_directa.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from roboticstoolbox import ET2

L1, L2 = 0.6, 0.4
robot = ET2.R() * ET2.tx(L1) * ET2.R() * ET2.tx(L2)

def articulaciones(q):
    """Puntos base, codo y efector para dibujar el brazo."""
    q1, q2 = q
    codo = np.array([L1 * np.cos(q1), L1 * np.sin(q1)])
    efector = codo + L2 * np.array([np.cos(q1 + q2), np.sin(q1 + q2)])
    return np.array([[0, 0], codo, efector])

configs = {"A": (0, 0), "B": (30, 45), "C": (60, -30), "D": (90, 90)}
th = np.linspace(0, 2 * np.pi, 300)
for r in (L1 + L2, abs(L1 - L2)):                       # límites del anillo
    plt.plot(r * np.cos(th), r * np.sin(th), "k--", linewidth=0.8)

for nombre, q_deg in configs.items():
    q = np.deg2rad(q_deg)
    p = articulaciones(q)
    T = robot.fkine(q)                                   # comprobación con RTB
    assert np.allclose(T.t, p[-1])
    plt.plot(p[:, 0], p[:, 1], "o-", linewidth=3, label=f"{nombre} {q_deg}")
    print(nombre, "efector:", np.round(p[-1], 3), "phi:", sum(q_deg), "°")

plt.axis("equal"); plt.grid(True); plt.legend(); plt.show()
  ```)

  + Completa una tabla con $(x, y, phi)$ de las cuatro configuraciones.
  + ¿Por qué hay una región central que el brazo no alcanza? ¿Qué pasaría si $L_1 = L_2$?
  + Si $q_2$ solo pudiera moverse entre $-90°$ y $90°$, ¿cómo cambiaría el espacio de trabajo? Dibújalo tomando muestras de $(q_1, q_2)$ al azar.
]

= Cinemática inversa

La pregunta contraria: _quiero la pinza en $(x, y)$; ¿qué ángulos necesito?_ Por la ley del coseno en el triángulo base–codo–efector:

$ cos q_2 = (x^2 + y^2 - L_1^2 - L_2^2) / (2 L_1 L_2), quad q_2 = plus.minus arccos(dots.c) $

$ q_1 = op("atan2")(y, x) - op("atan2")(L_2 sin q_2, thin L_1 + L_2 cos q_2) $

Los dos signos de $q_2$ dan las configuraciones *codo abajo* y *codo arriba*. Si $|cos q_2| > 1$, el punto está fuera del anillo y no tiene solución.

#actividad("2", [Resolver y verificar])[
  #archivo("cinematica_inversa.py", ```python
import numpy as np

L1, L2 = 0.6, 0.4

def directa(q1, q2):
    return np.array([L1 * np.cos(q1) + L2 * np.cos(q1 + q2),
                     L1 * np.sin(q1) + L2 * np.sin(q1 + q2)])

def inversa(x, y):
    """Devuelve las soluciones (q1, q2) o una lista vacía si no es alcanzable."""
    c2 = (x**2 + y**2 - L1**2 - L2**2) / (2 * L1 * L2)
    if abs(c2) > 1:
        return []
    sols = []
    for q2 in (np.arccos(c2), -np.arccos(c2)):
        q1 = np.arctan2(y, x) - np.arctan2(L2 * np.sin(q2), L1 + L2 * np.cos(q2))
        sols.append((q1, q2))
    return sols

for p in [(0.5, 0.5), (0.95, 0.10), (1.20, 0.20)]:
    sols = inversa(*p)
    if not sols:
        print(p, "-> fuera del espacio de trabajo")
    for q in sols:
        err = np.linalg.norm(directa(*q) - p)
        print(p, "-> q =", np.round(np.degrees(q), 2), "°  error =", f"{err:.1e} m")
  ```)

  + Dibuja las dos configuraciones para $(0.5, 0.5)$ usando la función de la Actividad 1.
  + ¿Qué pasa en un punto sobre el borde exterior, $(1.0, 0)$? ¿Cuántas soluciones hay?
  + Propón un criterio para elegir entre codo arriba y codo abajo en una tarea real.
]

= Jacobiano y singularidades

El jacobiano relaciona las velocidades articulares con la velocidad de la pinza:

$ mat(dot(x); dot(y)) = bold(J)(bold(q)) mat(dot(q)_1; dot(q)_2), quad bold(J) = mat(-L_1 sin q_1 - L_2 sin(q_1 + q_2), -L_2 sin(q_1 + q_2); L_1 cos q_1 + L_2 cos(q_1 + q_2), L_2 cos(q_1 + q_2)) $

Su determinante es sorprendentemente simple: $det bold(J) = L_1 L_2 sin q_2$. Cuando se anula, el brazo está *estirado* ($q_2 = 0$) o *plegado* ($q_2 = plus.minus 180°$) y pierde la capacidad de moverse en alguna dirección: es una *singularidad*.

#let detJ(q) = 0.24 * calc.sin(q * 1rad)
#figure(
  grafica(((detJ, rgb("#4338ca"), $det bold(J)$),), ancho: 9cm, alto: 3.4cm,
    xmin: -calc.pi, xmax: calc.pi, ymin: -0.3, ymax: 0.3, xlabel: [$q_2$ de $-pi$ a $pi$], ylabel: [m²]),
  kind: image,
  caption: [El determinante del jacobiano solo depende de $q_2$ y se anula en $q_2 = 0$ y $q_2 = plus.minus pi$.],
)

#actividad("3", [Encontrar las singularidades])[
  #archivo("jacobiano.py", ```python
import numpy as np

L1, L2 = 0.6, 0.4

def jacobiano(q1, q2):
    s1, c1 = np.sin(q1), np.cos(q1)
    s12, c12 = np.sin(q1 + q2), np.cos(q1 + q2)
    return np.array([[-L1 * s1 - L2 * s12, -L2 * s12],
                     [ L1 * c1 + L2 * c12,  L2 * c12]])

for q2_deg in [90, 45, 10, 1, 0]:
    J = jacobiano(np.deg2rad(30), np.deg2rad(q2_deg))
    # velocidades articulares para mover la pinza a 0.1 m/s en x
    qd = np.linalg.pinv(J) @ np.array([0.1, 0.0])
    print(f"q2 = {q2_deg:3d}°  det = {np.linalg.det(J):+.4f}  "
          f"q̇ = {np.round(qd, 3)} rad/s")
  ```)

  + ¿Qué pasa con las velocidades articulares necesarias al acercarse a $q_2 = 0$?
  + Dibuja el brazo en $q_2 = 0$ y en $q_2 = 180°$. ¿En qué dirección no puede moverse la pinza en cada caso?
  + ¿Por qué un planificador de movimiento debe evitar pasar cerca de una singularidad?
]

= Trayectorias articulares

Para ir de $bold(q)_0$ a $bold(q)_f$ en un tiempo $T$ se usa el polinomio quíntico del Laboratorio 03 en cada articulación:

$ bold(q)(t) = bold(q)_0 + s(tau)(bold(q)_f - bold(q)_0), quad s(tau) = 10 tau^3 - 15 tau^4 + 6 tau^5, quad tau = t \/ T $

#actividad("4", [Mover el brazo de A a B])[
  #archivo("trayectorias.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from roboticstoolbox import jtraj

L1, L2 = 0.6, 0.4
q0, qf = np.deg2rad([0, 0]), np.deg2rad([60, -45])

fig, ax = plt.subplots(1, 2, figsize=(11, 4.5))
for T, estilo in [(5.0, "-"), (3.0, "--")]:
    t = np.linspace(0, T, 251)
    tr = jtraj(q0, qf, t)
    for j in range(2):
        ax[0].plot(t, np.degrees(tr.qd[:, j]), estilo, label=f"q{j + 1}', T = {T} s")
    print(f"T = {T}s  |q̇|max = {np.degrees(abs(tr.qd).max()):.1f} °/s  "
          f"|q̈|max = {np.degrees(abs(tr.qdd).max()):.1f} °/s²")

    q1, q2 = tr.q[:, 0], tr.q[:, 1]
    x = L1 * np.cos(q1) + L2 * np.cos(q1 + q2)
    y = L1 * np.sin(q1) + L2 * np.sin(q1 + q2)
    if T == 5.0:
        ax[1].plot(x, y, label="camino de la pinza")
        ax[1].plot([x[0], x[-1]], [y[0], y[-1]], "k--", label="línea recta")

ax[0].set_xlabel("t [s]"); ax[0].set_ylabel("°/s"); ax[0].legend(); ax[0].grid(True)
ax[1].axis("equal"); ax[1].legend(); ax[1].grid(True)
plt.tight_layout(); plt.show()
  ```)

  + Verifica que la velocidad y la aceleración son cero al inicio y al final.
  + ¿Cómo escalan la velocidad y la aceleración máximas al pasar de $T = 5$ s a $T = 3$ s? Compara con $5\/3$ y $(5\/3)^2$.
  + ¿Por qué la pinza no se mueve en línea recta aunque cada articulación se mueva suavemente?
]

#reto[Haz que la pinza recorra la *línea recta* entre los dos puntos: interpola $(x, y)$ con el perfil quíntico y resuelve la cinemática inversa en cada instante (siempre con la misma rama, codo arriba o abajo). Compara las velocidades articulares con las de la Actividad 4.]

#preguntas[
  + ¿Cómo influye cada articulación en la posición y la orientación de la pinza?
  + ¿Por qué una misma posición puede tener dos configuraciones articulares?
  + ¿Qué representa físicamente el jacobiano y qué significa que su determinante sea cero?
  + ¿Qué ventajas tiene la interpolación quíntica frente a una lineal en las articulaciones?
]

#entregables(
  [Tabla de configuraciones de la Actividad 1 y la figura del espacio de trabajo.],
  [Soluciones de cinemática inversa con su verificación y error.],
  [Tabla de la Actividad 3 y el dibujo de las dos singularidades.],
  [Gráficas de la Actividad 4 con la comparación de $T = 5$ s y $T = 3$ s.],
)
