#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "06",
  titulo: [Localización y mapeo],
  subtitulo: [Odometría, filtro de Kalman extendido y SLAM],
  capitulo: "6",
  herramientas: ("Python", "Robotics Toolbox", "ROS 2 Jazzy", "slam_toolbox", "RViz2"),
  duracion: "2 sesiones",
  color: rgb("#be123c"),
  objetivos: (
    [Mostrar por qué la odometría sola acumula error sin límite.],
    [Explicar las fases de predicción y corrección de un EKF y el papel de las covarianzas $bold(V)$ y $bold(W)$.],
    [Corregir la pose con landmarks de posición conocida.],
    [Resolver SLAM con EKF cuando el mapa también es desconocido.],
    [Construir y guardar un mapa con `slam_toolbox` en ROS 2.],
  ),
)

= El problema: ¿dónde estoy?

Un robot puede estimar su pose de dos maneras complementarias:

- *Hacia adentro*: sumando su propio movimiento (odometría, IMU). Es suave y siempre está disponible, pero el error se *acumula*.
- *Hacia afuera*: observando referencias del entorno (landmarks, paredes). Corrige el error, pero las observaciones son ruidosas y no siempre están disponibles.

El filtro de Kalman combina ambas fuentes y, además, lleva la cuenta de *cuánta confianza* merece la estimación. Este laboratorio construye esa idea en cuatro pasos y termina con un mapa real en ROS 2.

#let odo(t) = 0.9 * t * t
#let lm(t) = { let f = calc.fract(t * 4); 0.05 + 0.22 * f * f }
#let slam(t) = 0.08 + 0.55 * calc.exp(-6 * t)

#figure(
  grafica(((odo, rgb("#be123c"), "solo odometría"), (lm, rgb("#2563eb"), "con landmarks"), (slam, rgb("#059669"), "SLAM")),
    ancho: 9cm, alto: 3.8cm, ymax: 1.0, xlabel: [tiempo], ylabel: [incertidumbre], leyenda-pos: top + center),
  kind: image,
  caption: [Comportamiento cualitativo de la incertidumbre de la pose en cada parte del laboratorio. Tus gráficas deberían mostrar formas parecidas.],
)

= Preparar el entorno

Las partes 1 a 4 solo necesitan Python. En Ubuntu 24.04 hay que usar un entorno virtual porque `pip` no permite instalar paquetes de forma global:

```bash
sudo apt install -y python3-venv python3-tk
mkdir -p ~/cap6_lab && cd ~/cap6_lab
python3 -m venv venv && source venv/bin/activate
pip install roboticstoolbox-python matplotlib numpy scipy
python3 -c "import roboticstoolbox as rtb; print(rtb.__version__)"
```

#tip[Si `pip` muestra avisos sobre paquetes de ROS 2 (por ejemplo, `launch-ros`), puedes ignorarlos: el entorno virtual está aislado de la instalación de ROS.]

= Parte 1 — Odometría (_dead reckoning_)

El modelo del robot (bicicleta, Laboratorio 04) recibe en cada paso una medición de odometría $(delta_d, delta_theta)$ con ruido gaussiano de covarianza

$ bold(V) = mat(sigma_d^2, 0; 0, sigma_theta^2) $

#actividad("1", [Ver crecer el error])[
  #archivo("parte1_odometria.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from roboticstoolbox import Bicycle

V = np.diag([0.2, np.deg2rad(0.5)]) ** 2
con_ruido = Bicycle(covar=V)
ideal = Bicycle(covar=np.zeros((2, 2)))

q_r, q_i, tr_r, tr_i = np.zeros(3), np.zeros(3), [], []
for _ in range(200):
    q_r = con_ruido.f(q_r, con_ruido.step((1.0, 0.2)))
    q_i = ideal.f(q_i, ideal.step((1.0, 0.2)))
    tr_r.append(q_r); tr_i.append(q_i)

tr_r, tr_i = np.array(tr_r), np.array(tr_i)
plt.plot(tr_i[:, 0], tr_i[:, 1], label="sin ruido")
plt.plot(tr_r[:, 0], tr_r[:, 1], label="con ruido")
plt.axis("equal"); plt.grid(True); plt.legend(); plt.show()
  ```)

  + Ejecuta varias veces. ¿Por qué cambia el resultado?
  + Interpreta cada elemento de $bold(V)$. ¿Por qué los términos fuera de la diagonal son cero?
  + Triplica $sigma_d$ y cuadruplica $sigma_theta$. ¿Qué cambia en la trayectoria?
]

= Parte 2 — EKF solo con odometría

El EKF mantiene una estimación $hat(bold(x))$ de la pose y su covarianza $bold(P)$. Sin sensores externos solo puede hacer la *predicción*:

$ hat(bold(x))^+ = f(hat(bold(x)), bold(u)), quad bold(P)^+ = bold(F)_x bold(P) bold(F)_x^top + bold(F)_v bold(V) bold(F)_v^top $

El segundo término siempre suma: la incertidumbre solo puede crecer.

#actividad("2", [Predicción pura])[
  #archivo("parte2_ekf.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from roboticstoolbox import Bicycle, EKF, RandomPath

V = np.diag([0.02, np.deg2rad(0.5)]) ** 2
robot = Bicycle(covar=V, animation=None)
robot.control = RandomPath(workspace=10)

P0 = np.diag([0.05, 0.05, np.deg2rad(0.5)]) ** 2
ekf = EKF(robot=(robot, V), P0=P0)
ekf.run(T=20)

plt.figure(); robot.plot_xy(color="b"); ekf.plot_xy(color="r"); plt.grid(True)
plt.figure(); plt.plot(ekf.get_t(), ekf.get_Pnorm()); plt.xlabel("t [s]")
plt.ylabel("‖P‖"); plt.grid(True); plt.show()
  ```)

  + ¿Por qué la curva de $norm(bold(P))$ crece cada vez más rápido?
  + El filtro «sabe» que está perdido. ¿Por qué no puede hacer nada al respecto?
  + Aumenta $bold(V)$ y compara la escala de la curva.
]

= Parte 3 — EKF con landmarks conocidos

Ahora el robot tiene un sensor de rango y ángulo, tipo LiDAR, que ve landmarks cuya posición está en un mapa. Cada observación $bold(z)$ se compara con la que el filtro *esperaba* ver desde su pose estimada. La diferencia es la *innovación* $bold(nu)$ y se usa para corregir:

$ bold(nu) = bold(z) - h(hat(bold(x))), quad bold(K) = bold(P) bold(H)^top (bold(H) bold(P) bold(H)^top + bold(W))^(-1), quad hat(bold(x)) <- hat(bold(x)) + bold(K) bold(nu) $

La ganancia $bold(K)$ pesa qué tanto confiar en el sensor ($bold(W)$) frente a la predicción ($bold(P)$).

#actividad("3", [Corrección con landmarks])[
  #archivo("parte3_ekf_landmarks.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from math import pi
from roboticstoolbox import Bicycle, EKF, RandomPath, LandmarkMap, RangeBearingSensor

V = np.diag([0.02, np.deg2rad(0.5)]) ** 2
robot = Bicycle(covar=V, animation=None)
robot.control = RandomPath(workspace=10)

mapa = LandmarkMap(20, workspace=10)
W = np.diag([0.1, np.deg2rad(1)]) ** 2
sensor = RangeBearingSensor(robot=robot, map=mapa, covar=W,
                            angle=[-pi / 2, pi / 2], range=4)

P0 = np.diag([0.05, 0.05, np.deg2rad(0.5)]) ** 2
ekf = EKF(robot=(robot, V), P0=P0, map=mapa, sensor=(sensor, W))
ekf.run(T=40)

plt.figure(); mapa.plot(); robot.plot_xy(color="b"); ekf.plot_xy(color="r")
ekf.plot_ellipse(); plt.grid(True)
plt.figure(); plt.plot(ekf.get_t(), ekf.get_Pnorm()); plt.grid(True); plt.show()
  ```)

  + Explica la forma de «sierra» de la curva de incertidumbre.
  + Identifica en la trayectoria los tramos donde el robot no veía ningún landmark.
  + Reduce el alcance del sensor a 2 m. ¿Qué cambia?
]

= Parte 4 — SLAM con EKF

En SLAM el mapa *no se conoce*: el estado del filtro crece con la posición de cada landmark que se descubre,

$ bold(x) = (x, y, theta, thin x_1, y_1, thin x_2, y_2, thin dots) $

y los errores de la pose y del mapa quedan correlacionados. Basta con no pasar el mapa al filtro:

#actividad("4", [Localizar y mapear a la vez])[
  #archivo("parte4_slam.py (diferencias con la parte 3)", ```python
np.random.seed(42)          # misma trayectoria en cada ejecución
# ...
slam = EKF(robot=(robot, V), P0=P0, sensor=(sensor, W), map=None)
slam.run(T=40)

plt.figure(); mapa.plot(); robot.plot_xy(color="b"); slam.plot_xy(color="r")
slam.plot_ellipse(); plt.axis("equal"); plt.grid(True)
plt.figure(); plt.plot(slam.get_t(), slam.get_Pnorm()); plt.grid(True); plt.show()
  ```)

  + Compara la trayectoria estimada con la de la Parte 3. ¿Cuál se ajusta mejor y por qué?
  + Aumenta mucho $bold(W)$, por ejemplo $sigma_r = 2$ m y $sigma_beta = 15°$. Usa la misma semilla para comparar de forma justa.
  + ¿Por qué la incertidumbre baja pero nunca llega a cero?
]

#cuidado[Como el recorrido es aleatorio, dos ejecuciones no son comparables a menos que fijes la semilla (`np.random.seed`) al comienzo del script.]

= Parte 5 — SLAM en ROS 2 con TurtleBot3

En ROS 2 Jazzy, `slam_toolbox` construye un mapa de ocupación a partir del LiDAR y la odometría, y publica la transformada `map → odom` que corrige la deriva.

#flujo("/scan", [`slam_toolbox`], "/map", [RViz2])
#flujo("/odom", [`slam_toolbox`], [TF `map → odom`])

```bash
sudo apt install -y ros-jazzy-slam-toolbox ros-jazzy-nav2-map-server ros-jazzy-turtlebot3*
export TURTLEBOT3_MODEL=burger
# Terminal 1 — mundo con obstáculos
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
# Terminal 2 — SLAM
ros2 launch slam_toolbox online_async_launch.py use_sim_time:=True
# Terminal 3 — mover el robot (o usar el nodo reactivo del Laboratorio 05)
ros2 run turtlebot3_teleop teleop_keyboard
# Terminal 4 — visualizar
rviz2
```

En RViz2 fija *Fixed Frame* en `map` y agrega los displays *Map* (`/map`), *LaserScan* (`/scan`) y *TF*. Recorre el mundo despacio hasta cerrar el mapa y guárdalo:

```bash
ros2 run nav2_map_server map_saver_cli -f ~/mapa_tb3_world
```

Se generan dos archivos: `mapa_tb3_world.pgm` (la imagen) y `mapa_tb3_world.yaml` (resolución y origen). Ese mapa es el que Nav2 usa para navegar.

#tabla(columnas: (1fr, 1.3fr),
  [*Problema*], [*Solución*],
  [RViz2: «Frame [map] does not exist»], [`slam_toolbox` aún no publica; usa `odom` como Fixed Frame mientras arranca.],
  [El mapa no crece y el reloj no avanza], [Gazebo está en pausa: pulsa _Play_.],
  [El mapa sale torcido o duplicado], [El robot giró muy rápido; muévelo más despacio y vuelve a zonas ya vistas para cerrar el lazo.],
  [Cartographer se cierra al iniciar], [En Jazzy es más estable `slam_toolbox`; usa el procedimiento de esta guía.],
)

#reto[
  Usa el mapa guardado con Nav2 (Laboratorio 05) y navega a tres metas:
  ```bash
  ros2 launch nav2_bringup tb3_simulation_launch.py map:=$HOME/mapa_tb3_world.yaml
  ```
]

#preguntas[
  + ¿Por qué el error de la odometría crece sin límite?
  + ¿Qué representan $bold(V)$ y $bold(W)$ y cómo afecta cada una a la curva de incertidumbre?
  + ¿Qué es la innovación y qué indica que sea grande?
  + ¿Por qué SLAM es más difícil que localizarse con un mapa conocido?
  + ¿Qué hace la transformada `map → odom` que publica `slam_toolbox`?
  + Menciona tres aplicaciones industriales de SLAM.
]

#entregables(
  [Gráficas de trayectoria e incertidumbre de las partes 1 a 4, con los experimentos de $bold(V)$ y $bold(W)$.],
  [Tabla comparativa de las cuatro partes (corrección externa e incertidumbre).],
  [Captura del mapa en RViz2 y los archivos `.pgm` y `.yaml` del mapa guardado.],
)
