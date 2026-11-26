#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "05",
  titulo: [Navegación de robots móviles],
  subtitulo: [De los vehículos de Braitenberg a Nav2 en ROS 2],
  capitulo: "5",
  herramientas: ("Python", "NumPy", "Matplotlib", "ROS 2 Jazzy", "Nav2", "Gazebo"),
  duracion: "2–3 sesiones",
  color: rgb("#0369a1"),
  objetivos: (
    [Programar un comportamiento reactivo que busca un objetivo usando solo sensores.],
    [Simular Bug2 y reconocer sus limitaciones frente a un planificador con mapa.],
    [Implementar A\* y la transformada de distancia sobre un mapa de ocupación.],
    [Navegar con Nav2 en Gazebo e identificar sus componentes.],
    [Escribir un nodo reactivo con LiDAR y compararlo con Nav2.],
  ),
)

= Dos formas de llegar

Todo sistema de navegación responde a la pregunta _¿cómo llego de aquí allá?_ Hay dos grandes familias de respuestas:

#tabla(columnas: (auto, 1fr, 1fr),
  [], [*Reactiva*], [*Basada en mapa*],
  [Información], [Solo lo que miden los sensores ahora], [Un mapa del entorno y la pose del robot en él],
  [Decide], [Paso a paso, sin plan], [Calcula una ruta completa antes de moverse],
  [Ventajas], [Simple, rápida, robusta ante cambios], [Rutas óptimas; garantiza llegar si hay camino],
  [Problemas], [Mínimos locales, trampas, sin garantía], [Necesita mapa y localización confiables],
)

El laboratorio recorre ambas: primero reactiva (partes A y B), luego planificación (C y D) y finalmente su combinación en ROS 2 (E).

= Parte A — Vehículo de Braitenberg

Un vehículo de Braitenberg conecta sensores directamente a motores, sin «pensar». Si el objetivo emite una señal más intensa cuanto más cerca está (luz, calor, olor), dos sensores separados lateralmente medirán valores distintos, y *esa diferencia* basta para girar hacia la fuente.

#let braitenberg = box(width: 9cm, height: 5.8cm, {
  let c = rgb("#0369a1")
  let G = (6.1cm, 2.9cm)
  for (i, r) in (2.8cm, 2.1cm, 1.4cm, 0.7cm).enumerate() {
    place(dx: G.at(0) - r, dy: G.at(1) - r, circle(radius: r, fill: rgb("#f59e0b").transparentize(88% - i * 6%), stroke: none))
  }
  place(dx: G.at(0) - 4pt, dy: G.at(1) - 4pt, circle(radius: 4pt, fill: rgb("#dc2626")))
  etiqueta((G.at(0), G.at(1) - 0.4cm), [objetivo], tam: 8pt)
  let P = (1.4cm, 4.3cm)
  let a = 15deg
  let u = (calc.cos(a), -calc.sin(a))
  let n = (-calc.sin(a), -calc.cos(a))
  place(dx: P.at(0) - 0.45cm, dy: P.at(1) - 0.45cm, circle(radius: 0.45cm, fill: white, stroke: 1.2pt + tinta))
  flecha(P, (P.at(0) + 0.9cm * u.at(0), P.at(1) + 0.9cm * u.at(1)), color: tinta)
  let sL = (P.at(0) + 0.55cm * n.at(0) + 0.3cm * u.at(0), P.at(1) + 0.55cm * n.at(1) + 0.3cm * u.at(1))
  let sR = (P.at(0) - 0.55cm * n.at(0) + 0.3cm * u.at(0), P.at(1) - 0.55cm * n.at(1) + 0.3cm * u.at(1))
  for s in (sL, sR) { place(dx: s.at(0) - 3.5pt, dy: s.at(1) - 3.5pt, circle(radius: 3.5pt, fill: c)) }
  etiqueta((sL.at(0) - 0.35cm, sL.at(1) - 0.2cm), $s_L$, tam: 9pt, color: c)
  etiqueta((sR.at(0) - 0.1cm, sR.at(1) + 0.3cm), $s_R$, tam: 9pt, color: c)
})

#figure(braitenberg, kind: image, caption: [El sensor más cercano al objetivo mide más. La diferencia $s_L - s_R$ dice hacia dónde girar y la suma $s_L + s_R$, qué tan cerca está.])

Una ley de control posible es

$ omega = K_s (s_L - s_R), quad v = v_0 / (1 + K_v (s_L + s_R)) $

de modo que el robot gira hacia el lado que «siente» más y frena a medida que se acerca.

#actividad("A", [Buscar la fuente])[
  #archivo("braitenberg.py", ```python
import numpy as np
import matplotlib.pyplot as plt

META = np.array([60.0, 90.0])

def campo(p):
    """Intensidad de la señal en el punto p (máxima en la meta)."""
    return 1000 / (np.sum((p - META) ** 2) + 50)

def simular(x, y, th, v0=2.0, Ks=40.0, Kv=0.5, d=2.0, dt=0.1, pasos=600):
    tray = [(x, y)]
    for _ in range(pasos):
        n = np.array([-np.sin(th), np.cos(th)])          # normal izquierda
        sL, sR = campo(np.array([x, y]) + d * n), campo(np.array([x, y]) - d * n)
        omega = Ks * (sL - sR)
        v = v0 / (1 + Kv * (sL + sR))                  # frena cerca de la fuente
        x, y, th = x + v * np.cos(th) * dt, y + v * np.sin(th) * dt, th + omega * dt
        tray.append((x, y))
    return np.array(tray)

for inicio in [(10, 10, 0), (100, 20, np.pi), (20, 120, -np.pi / 2)]:
    t = simular(*inicio)
    plt.plot(t[:, 0], t[:, 1])
plt.plot(*META, "r*", markersize=15)
plt.axis("equal"); plt.grid(True); plt.title("Vehículo de Braitenberg"); plt.show()
  ```)

  + ¿Qué pasa si intercambias los sensores (cruzas los «cables»)?
  + ¿Cómo se comporta cerca de la meta? Aumenta `pasos` a 3000 y descríbelo.
  + Agrega una segunda fuente más débil. ¿Puede el robot quedar atrapado en la equivocada?
]

= Parte B — Bug2

Bug2 sí sabe dónde está la meta, pero no tiene mapa: solo detecta obstáculos al tocarlos. Su regla es sencilla:

+ Avanzar por la *línea M*, la recta que une el inicio con la meta.
+ Al chocar con un obstáculo, rodear su borde (siempre hacia el mismo lado).
+ Abandonar el borde al volver a cruzar la línea M en un punto *más cercano* a la meta que donde se chocó.

#let bug2 = box(width: 8cm, height: 4.6cm, {
  let c = rgb("#0369a1")
  place(dx: 2.6cm, dy: 1.5cm, rect(width: 2.6cm, height: 1.6cm, fill: gris-claro.darken(15%), stroke: 1pt + gris, radius: 3pt))
  place(line(start: (0.6cm, 4.0cm), end: (7.4cm, 0.6cm), stroke: (paint: gris, thickness: 0.8pt, dash: "dashed")))
  etiqueta((6.2cm, 1.6cm), [línea M], tam: 8pt, color: gris)
  let ruta = ((0.6cm, 4.0cm), (2.45cm, 3.07cm), (2.45cm, 3.25cm), (5.35cm, 3.25cm), (5.35cm, 1.8cm), (7.4cm, 0.6cm))
  place(curve(stroke: 2pt + c, curve.move(ruta.at(0)), ..ruta.slice(1).map(p => curve.line(p))))
  place(dx: 0.6cm - 4pt, dy: 4.0cm - 4pt, circle(radius: 4pt, fill: rgb("#2563eb")))
  place(dx: 7.4cm - 4pt, dy: 0.6cm - 4pt, circle(radius: 4pt, fill: rgb("#dc2626")))
  etiqueta((0.6cm, 4.35cm), [inicio], tam: 8pt)
  etiqueta((7.4cm, 0.3cm), [meta], tam: 8pt)
  etiqueta((2.1cm, 2.8cm), [choque], tam: 7.5pt, color: c)
  etiqueta((5.95cm, 2.1cm), [salida], tam: 7.5pt, color: c)
})

#figure(bug2, kind: image, caption: [Bug2 sigue la línea M, bordea el obstáculo y la retoma al volver a cruzarla más cerca de la meta.])

#actividad("B", [Bug2 en una grilla])[
  Implementa Bug2 en una grilla de $20 times 20$ con el obstáculo `grid[8:12, 5:15] = 1`, inicio $(2, 2)$ y meta $(18, 18)$. Usa movimientos de 4 vecinos y estas funciones como base:

  #archivo("bug2.py (esqueleto)", ```python
import numpy as np

grid = np.zeros((20, 20), dtype=int)
grid[8:12, 5:15] = 1                       # fila = y, columna = x
inicio, meta = np.array([2, 2]), np.array([18, 18])

def libre(p):
    x, y = p
    return 0 <= x < 20 and 0 <= y < 20 and grid[y, x] == 0

def distancia_a_linea_m(p):
    """Distancia del punto p a la recta inicio–meta."""
    d = meta - inicio
    return abs(np.cross(d, p - inicio)) / np.linalg.norm(d)

def paso_hacia_meta(p):
    d = meta - p
    eje = 0 if abs(d[0]) >= abs(d[1]) else 1
    paso = np.zeros(2, int); paso[eje] = np.sign(d[eje])
    return p + paso

# Completa: modo "ir a la meta" ↔ modo "seguir borde" (mano derecha)
# y la condición de salida del borde.
  ```)

  + Grafica la grilla con `plt.imshow(grid, origin="lower")` y la ruta encima.
  + ¿Es óptima la ruta? Compárala con la de la Parte C.
  + Diseña un obstáculo en forma de «U» abierta hacia el inicio. ¿Qué ocurre?
]

= Parte C — Planificación con A\*

Con un mapa, el problema se convierte en buscar el camino más corto en un grafo: cada celda libre es un nodo y está conectada con sus vecinas. A\* explora primero los nodos con menor

$ f(n) = g(n) + h(n) $

donde $g(n)$ es el costo real desde el inicio y $h(n)$ una *estimación* del costo hasta la meta. Si $h$ nunca sobreestima (heurística admisible), A\* encuentra el camino óptimo.

#tabla(columnas: (auto, auto, 1fr),
  [*Algoritmo*], [*Prioridad*], [*Comportamiento*],
  [BFS], [orden de llegada], [Óptimo solo si todos los pasos cuestan igual.],
  [Dijkstra (UCS)], [$g(n)$], [Óptimo; explora en todas las direcciones.],
  [Voraz], [$h(n)$], [Rápido, pero no garantiza el camino más corto.],
  [A\*], [$g(n) + h(n)$], [Óptimo con $h$ admisible y explora mucho menos que Dijkstra.],
)

#actividad("C", [A\* desde cero])[
  #archivo("astar.py", ```python
import heapq
import numpy as np
import matplotlib.pyplot as plt

grid = np.zeros((20, 20), dtype=int)
grid[8:12, 5:15] = 1

VECINOS_4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
VECINOS_8 = VECINOS_4 + [(1, 1), (1, -1), (-1, 1), (-1, -1)]

def astar(grid, inicio, meta, vecinos=VECINOS_4, peso_h=1.0):
    h = lambda n: np.hypot(n[0] - meta[0], n[1] - meta[1])
    abiertos = [(h(inicio), inicio)]
    g, padre, expandidos = {inicio: 0.0}, {}, 0
    while abiertos:
        _, actual = heapq.heappop(abiertos)
        expandidos += 1
        if actual == meta:
            break
        for dx, dy in vecinos:
            nx, ny = actual[0] + dx, actual[1] + dy
            if not (0 <= nx < grid.shape[1] and 0 <= ny < grid.shape[0]) or grid[ny, nx]:
                continue
            nuevo = g[actual] + np.hypot(dx, dy)
            if nuevo < g.get((nx, ny), np.inf):
                g[(nx, ny)], padre[(nx, ny)] = nuevo, actual
                heapq.heappush(abiertos, (nuevo + peso_h * h((nx, ny)), (nx, ny)))
    camino, n = [meta], meta
    while n != inicio:
        n = padre[n]
        camino.append(n)
    return np.array(camino[::-1]), g[meta], expandidos

for nombre, kw in [("A* (4)", {}), ("A* (8)", {"vecinos": VECINOS_8}),
                   ("Dijkstra", {"peso_h": 0.0})]:
    c, costo, exp = astar(grid, (2, 2), (18, 18), **kw)
    print(f"{nombre:9s} costo = {costo:5.2f}   nodos expandidos = {exp}")
    plt.plot(c[:, 0], c[:, 1], label=nombre)
plt.imshow(grid, origin="lower", cmap="Greys"); plt.legend(); plt.show()
  ```)

  + Compara costo y nodos expandidos de las tres variantes.
  + Prueba `peso_h = 3`. ¿El camino sigue siendo óptimo? ¿Por qué?
  + ¿Qué pasa si la heurística es $h = 0$? ¿Y si sobreestima mucho?
]

= Parte D — Transformada de distancia

En lugar de buscar un camino para un inicio concreto, se puede calcular para *cada celda* su distancia a la meta. Ese mapa se obtiene con un frente de onda (BFS) que parte de la meta y se expande por las celdas libres. Luego, desde cualquier inicio, basta con bajar siempre a la vecina de menor valor.

#actividad("D", [Frente de onda y descenso])[
  #archivo("distance_transform.py", ```python
from collections import deque
import numpy as np
import matplotlib.pyplot as plt

grid = np.zeros((20, 20), dtype=int)
grid[8:12, 5:15] = 1
meta, inicio = (2, 2), (18, 18)

dist = np.full(grid.shape, np.inf)
dist[meta[1], meta[0]] = 0
cola = deque([meta])
while cola:                                   # BFS: cada celda se visita una vez
    x, y = cola.popleft()
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        nx, ny = x + dx, y + dy
        if 0 <= nx < 20 and 0 <= ny < 20 and not grid[ny, nx] and dist[ny, nx] == np.inf:
            dist[ny, nx] = dist[y, x] + 1
            cola.append((nx, ny))

camino = [inicio]
while camino[-1] != meta:                     # descenso por el gradiente
    x, y = camino[-1]
    vec = [(x + dx, y + dy) for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]
           if 0 <= x + dx < 20 and 0 <= y + dy < 20]
    camino.append(min(vec, key=lambda p: dist[p[1], p[0]]))
camino = np.array(camino)

plt.imshow(np.where(grid, np.nan, dist), origin="lower", cmap="viridis")
plt.colorbar(label="distancia a la meta [celdas]")
plt.plot(camino[:, 0], camino[:, 1], "w-", linewidth=2)
plt.title("Transformada de distancia"); plt.show()
  ```)

  + ¿Por qué el descenso nunca se queda atrapado si existe un camino?
  + ¿Cuál es el costo computacional de construir el mapa? ¿Cuándo conviene sobre A\*?
  + Compara con Bug2 en el obstáculo en «U».
]

#tip[Este mismo principio, con costos que crecen cerca de los obstáculos, es lo que usa el _costmap_ de Nav2 para que las rutas no rocen las paredes.]

= Parte E — Navegación en ROS 2

== Nav2 en Gazebo

Nav2 integra todo lo anterior: un mapa, localización con AMCL (filtro de partículas), un planificador global sobre el _costmap_ y un controlador local que reacciona a lo que ve el LiDAR.

#flujo([Mapa + `/scan`], [AMCL], [Planificador global], [Controlador local], "/cmd_vel")

```bash
sudo apt install ros-jazzy-navigation2 ros-jazzy-nav2-bringup ros-jazzy-turtlebot3-simulations
source /opt/ros/jazzy/setup.bash
export TURTLEBOT3_MODEL=waffle
# Solo en máquinas virtuales (renderizado por software)
export LIBGL_ALWAYS_SOFTWARE=1
ros2 launch nav2_bringup tb3_simulation_launch.py headless:=False
```

En RViz2 usa *2D Pose Estimate* para indicar dónde está el robot y luego *Nav2 Goal* para la meta. Mientras navega, inspecciona el sistema:

```bash
ros2 lifecycle nodes
ros2 action list
ros2 topic echo /amcl_pose --once
ros2 run tf2_ros tf2_echo map base_link
```

#tabla(columnas: (auto, 1fr),
  [*Capa en RViz2*], [*Qué muestra*],
  [Map], [El mapa estático usado para localizarse.],
  [LaserScan], [Los puntos que detecta el LiDAR en este momento.],
  [Global / Local Costmap], [El costo de pasar por cada celda, en todo el mapa / alrededor del robot.],
  [Global Plan / Local Plan], [La ruta completa hasta la meta / la trayectoria inmediata del controlador.],
  [Particle Cloud], [Las hipótesis de AMCL sobre la pose del robot.],
)

#cuidado[Si aparecen dos robots en Gazebo, quedó una simulación anterior abierta. Cierra todo con `pkill -f "gz sim"; pkill -f rviz2; ros2 daemon stop` antes de relanzar.]

#actividad("E1", [Explorar Nav2])[
  + Envía tres metas en zonas distintas y observa cómo cambia el plan global.
  + Marca una pose inicial deliberadamente errada. ¿Cómo corrige AMCL la nube de partículas al moverse el robot?
  + Cancela una meta durante la navegación. ¿Qué hace el robot?
  + Relaciona los valores de `tf2_echo map base_link` con la posición del robot en el mapa.
]

== Un nodo reactivo con LiDAR

#actividad("E2", [Evitar obstáculos sin mapa])[
  Cierra Nav2 (para que nadie más publique en `/cmd_vel`) y lanza solo el mundo:

  ```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
ros2 topic info /cmd_vel
  ```

  El nodo mira un sector de ±30° al frente: si hay algo a menos de 0.5 m gira en el sitio; si no, avanza.

  #archivo("reactive_navigator.py", ```python
import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import LaserScan
from geometry_msgs.msg import TwistStamped

class ReactiveNavigator(Node):
    def __init__(self):
        super().__init__('reactive_navigator')
        self.create_subscription(LaserScan, '/scan', self.al_recibir_scan, 10)
        self.pub = self.create_publisher(TwistStamped, '/cmd_vel', 10)

    def al_recibir_scan(self, msg):
        r = np.asarray(msg.ranges, dtype=float)
        k = int(len(r) * 30 / 360)                    # ±30° alrededor del índice 0
        frente = np.concatenate((r[:k], r[-k:]))
        frente = frente[np.isfinite(frente)]
        if frente.size == 0:
            return
        cmd = TwistStamped()
        cmd.header.stamp = self.get_clock().now().to_msg()
        cmd.header.frame_id = 'base_link'
        if frente.min() < 0.5:
            cmd.twist.angular.z = 0.8                 # obstáculo: girar
        else:
            cmd.twist.linear.x = 0.2                  # libre: avanzar
        self.pub.publish(cmd)

def main():
    rclpy.init()
    rclpy.spin(ReactiveNavigator())
  ```)

  #idea[En el LiDAR del TurtleBot3 el índice 0 apunta *hacia adelante* y el arreglo recorre 360°. Por eso el frente está en los *dos extremos* del arreglo y no en el centro.]

  + Ejecuta el nodo y describe el comportamiento durante 2 minutos.
  + Haz que gire hacia el lado con más espacio libre en lugar de girar siempre a la izquierda.
]

#preguntas[
  + ¿Qué diferencia hay entre la navegación reactiva de la Parte E2 y Nav2?
  + ¿Qué hace el planificador dentro de Nav2 y qué hace el controlador?
  + ¿Por qué A\* con heurística euclidiana es óptimo en una grilla de 4 vecinos?
  + ¿Qué ventajas ofrece ROS 2 para construir un sistema de navegación como Nav2?
]

#entregables(
  [Gráficas y respuestas de las partes A a D.],
  [Capturas de Nav2 en RViz2 y de los comandos de inspección de la Parte E1.],
  [Código del nodo reactivo y un video corto de su funcionamiento.],
)
