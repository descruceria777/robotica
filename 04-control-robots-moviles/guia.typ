#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "04",
  titulo: [Control de robots móviles],
  subtitulo: [Del modelo cinemático al TurtleBot3 en ROS 2],
  capitulo: "4",
  herramientas: ("Python", "NumPy", "Matplotlib", "ROS 2 Jazzy", "Gazebo Sim"),
  duracion: "2 sesiones",
  color: rgb("#0f766e"),
  objetivos: (
    [Escribir y simular el modelo cinemático de un robot tipo bicicleta y de uno diferencial.],
    [Diseñar controladores proporcionales para ir a un punto, seguir una recta y seguir un camino.],
    [Explicar por qué un robot no holonómico no puede corregir cualquier error de forma directa.],
    [Llevar el controlador de «ir a un punto» a un nodo de ROS 2 que mueve un TurtleBot3 en Gazebo.],
  ),
)

= ¿Por qué un robot móvil es difícil de controlar?

Un carro puede estar en cualquier posición $(x, y)$ y con cualquier orientación $theta$: su configuración tiene tres grados de libertad. Sin embargo, solo tenemos *dos* entradas (acelerar y girar) y, además, el carro *no puede moverse de lado*. Esa restricción sobre la velocidad —no sobre la posición— es lo que se llama una restricción *no holonómica*.

La consecuencia práctica es que el robot sí puede llegar a cualquier pose, pero no en línea recta: para corregir un error lateral tiene que avanzar y girar al mismo tiempo, como cuando se estaciona un carro en paralelo. Todo el laboratorio gira alrededor de esta idea.

== Dos modelos cinemáticos

#let modelo-bici = box(width: 7.6cm, height: 5.2cm, {
  let c = rgb("#0f766e")
  // ejes
  flecha((0.3cm, 4.9cm), (7.2cm, 4.9cm), color: gris, grosor: 0.7pt)
  flecha((0.3cm, 4.9cm), (0.3cm, 0.3cm), color: gris, grosor: 0.7pt)
  etiqueta((7.3cm, 4.6cm), $x$, color: gris)
  etiqueta((0.6cm, 0.3cm), $y$, color: gris)
  let R = (1.8cm, 3.9cm)
  let F = (1.8cm + 3.2cm * calc.cos(25deg), 3.9cm - 3.2cm * calc.sin(25deg))
  // referencia horizontal y prolongación del chasis
  place(line(start: R, end: (4.3cm, 3.9cm), stroke: (paint: gris, thickness: 0.6pt, dash: "dashed")))
  place(line(start: F, end: (F.at(0) + 1.4cm * calc.cos(25deg), F.at(1) - 1.4cm * calc.sin(25deg)), stroke: (paint: gris, thickness: 0.6pt, dash: "dashed")))
  // chasis
  place(line(start: R, end: F, stroke: 2.2pt + tinta))
  // ruedas
  let rueda(p, ang) = place(line(
    start: (p.at(0) - 0.45cm * calc.cos(ang), p.at(1) + 0.45cm * calc.sin(ang)),
    end: (p.at(0) + 0.45cm * calc.cos(ang), p.at(1) - 0.45cm * calc.sin(ang)),
    stroke: (paint: c, thickness: 5pt, cap: "round")))
  rueda(R, 25deg)
  rueda(F, 55deg)
  // velocidad
  flecha(F, (F.at(0) + 1.5cm * calc.cos(55deg), F.at(1) - 1.5cm * calc.sin(55deg)), color: rgb("#dc2626"))
  etiqueta((F.at(0) + 1.1cm, F.at(1) - 1.55cm), $v$, color: rgb("#dc2626"))
  // etiquetas
  etiqueta((3.75cm, 3.65cm), $theta$)
  etiqueta((F.at(0) + 0.95cm, F.at(1) - 0.2cm), $delta$)
  etiqueta((3.0cm, 2.75cm), $L$)
  place(dx: R.at(0) - 2.5pt, dy: R.at(1) - 2.5pt, circle(radius: 2.5pt, fill: tinta))
  etiqueta((R.at(0) - 0.35cm, R.at(1) + 0.35cm), $(x, y)$, tam: 8pt)
})

#let modelo-dif = box(width: 6.4cm, height: 5.2cm, {
  let c = rgb("#0f766e")
  let C = (3.0cm, 3.0cm)
  let u = (calc.cos(30deg), -calc.sin(30deg))
  let n = (-calc.sin(30deg), -calc.cos(30deg))
  let r = 1.2cm
  place(dx: C.at(0) - r, dy: C.at(1) - r, circle(radius: r, fill: c.lighten(90%), stroke: 1.2pt + tinta))
  let pL = (C.at(0) + r * n.at(0), C.at(1) + r * n.at(1))
  let pR = (C.at(0) - r * n.at(0), C.at(1) - r * n.at(1))
  for p in (pL, pR) {
    place(line(start: (p.at(0) - 0.4cm * u.at(0), p.at(1) - 0.4cm * u.at(1)), end: (p.at(0) + 0.4cm * u.at(0), p.at(1) + 0.4cm * u.at(1)), stroke: (paint: c, thickness: 5pt, cap: "round")))
  }
  flecha(pL, (pL.at(0) + 1.1cm * u.at(0), pL.at(1) + 1.1cm * u.at(1)), color: rgb("#dc2626"))
  flecha(pR, (pR.at(0) + 1.8cm * u.at(0), pR.at(1) + 1.8cm * u.at(1)), color: rgb("#dc2626"))
  etiqueta((pL.at(0) + 1.3cm * u.at(0) - 0.2cm, pL.at(1) + 1.3cm * u.at(1) - 0.2cm), $v_L$, color: rgb("#dc2626"))
  etiqueta((pR.at(0) + 2.0cm * u.at(0) + 0.15cm, pR.at(1) + 2.0cm * u.at(1) + 0.15cm), $v_R$, color: rgb("#dc2626"))
  flecha(C, (C.at(0) + 1.0cm * u.at(0), C.at(1) + 1.0cm * u.at(1)), color: tinta)
  place(dx: C.at(0) - 2.5pt, dy: C.at(1) - 2.5pt, circle(radius: 2.5pt, fill: tinta))
  place(line(start: pL, end: pR, stroke: (paint: gris, thickness: 0.6pt, dash: "dashed")))
  etiqueta((C.at(0) - 0.55cm, C.at(1) + 0.15cm), $W$, tam: 9pt)
  etiqueta((C.at(0) + 1.3cm, C.at(1) - 0.3cm), $theta$, tam: 9pt)
})

#figure(
  grid(columns: 2, column-gutter: 0.6cm, align: bottom, modelo-bici, modelo-dif),
  caption: [Izquierda: modelo bicicleta, con distancia entre ejes $L$ y ángulo de dirección $delta$. Derecha: robot diferencial, con separación entre ruedas $W$ y velocidades $v_L$, $v_R$.],
)

Ambos modelos comparten las dos primeras ecuaciones (el robot avanza en la dirección hacia la que apunta) y se diferencian en *cómo cambia la orientación*:

#grid(columns: (1fr, 1fr), column-gutter: 14pt,
  block(fill: gris-claro.lighten(40%), inset: 10pt, radius: 5pt, width: 100%)[
    *Bicicleta (tipo carro)* \
    Entradas: $v$ y $delta$
    $ dot(x) = v cos theta, quad dot(y) = v sin theta, quad dot(theta) = v / L tan delta $
  ],
  block(fill: gris-claro.lighten(40%), inset: 10pt, radius: 5pt, width: 100%)[
    *Diferencial (TurtleBot3)* \
    Entradas: $v$ y $omega$
    $ v = (v_R + v_L) / 2, quad omega = (v_R - v_L) / W, quad dot(theta) = omega $
  ],
)

#idea[El robot bicicleta *no puede girar en el sitio*: si $v = 0$, entonces $dot(theta) = 0$ sin importar $delta$. El diferencial sí puede ($v = 0$, $omega != 0$). Esto cambia qué tan cerrados pueden ser los giros de cada controlador.]

== Simular es integrar

Para simular basta con avanzar el estado en pasos pequeños de tiempo $Delta t$ (integración de Euler):

$ x_(k+1) = x_k + v cos theta_k Delta t, quad y_(k+1) = y_k + v sin theta_k Delta t, quad theta_(k+1) = theta_k + dot(theta)_k Delta t $

Con $Delta t$ pequeño el error es despreciable para este laboratorio. Es exactamente lo que hace el nodo de odometría del TurtleBot3, solo que con las velocidades medidas por los encoders.

= Simulación del modelo bicicleta

#actividad("1", [Trayectoria en lazo abierto])[
  Escribe una función que avance un paso el modelo y úsala para simular 10 s con entradas constantes.

  #archivo("modelo_bicicleta.py", ```python
import numpy as np
import matplotlib.pyplot as plt

def paso_bicicleta(estado, v, delta, L=2.0, dt=0.1):
    """Avanza un paso de Euler del modelo bicicleta."""
    x, y, th = estado
    return np.array([
        x + v * np.cos(th) * dt,
        y + v * np.sin(th) * dt,
        th + v / L * np.tan(delta) * dt,
    ])

for delta in [0.0, 0.15, 0.3, 0.5]:
    estado = np.zeros(3)
    tray = [estado]
    for _ in range(100):                      # 100 pasos × 0.1 s = 10 s
        estado = paso_bicicleta(estado, v=1.0, delta=delta)
        tray.append(estado)
    tray = np.array(tray)
    plt.plot(tray[:, 0], tray[:, 1], label=f"δ = {delta} rad")

plt.axis("equal"); plt.grid(True); plt.legend()
plt.xlabel("x [m]"); plt.ylabel("y [m]")
plt.title("Modelo bicicleta en lazo abierto")
plt.show()
  ```)

  + Ejecuta el script y describe la forma de cada trayectoria.
  + Calcula a mano el radio de giro $R = L \/ tan delta$ para $delta = 0.3$ rad y compáralo con la gráfica.
  + Repite con $L = 1$ m y $L = 4$ m. ¿Qué robot gira más cerrado?
]

= Ir a un punto

El objetivo es llegar a $(x^*, y^*)$ sin importar con qué orientación termine el robot. Se usan dos errores: la *distancia* al objetivo y el *error de rumbo*, es decir, cuánto debe girar para mirar hacia él.

$ d = sqrt((x^* - x)^2 + (y^* - y)^2), quad theta^* = op("atan2")(y^* - y, x^* - x), quad alpha = op("wrap")(theta^* - theta) $

La ley de control es proporcional en ambos canales:

$ v = K_v d, quad delta = K_h alpha quad ("bicicleta") quad quad omega = K_h alpha quad ("diferencial") $

#cuidado[Sin la función `wrap`, que lleva el ángulo al intervalo $[-pi, pi]$, el robot puede dar una vuelta completa innecesaria. Por ejemplo, si $theta^* = 179°$ y $theta = -179°$, la resta da $358°$ cuando el error real es de solo $-2°$.]

#actividad("2", [Controlador de posición])[
  #archivo("ir_a_punto.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from modelo_bicicleta import paso_bicicleta

def wrap(a):
    return (a + np.pi) % (2 * np.pi) - np.pi

def ir_a_punto(inicio, meta, Kv=0.5, Kh=1.5, delta_max=np.deg2rad(35)):
    estado, tray = np.array(inicio, float), []
    for _ in range(2000):
        dx, dy = meta[0] - estado[0], meta[1] - estado[1]
        d = np.hypot(dx, dy)
        if d < 0.1:
            break
        alpha = wrap(np.arctan2(dy, dx) - estado[2])
        v = Kv * d
        delta = np.clip(Kh * alpha, -delta_max, delta_max)   # límite físico
        estado = paso_bicicleta(estado, v, delta)
        tray.append(estado)
    return np.array(tray)

meta = (5, 5)
for ang in np.linspace(0, 2 * np.pi, 8, endpoint=False):     # 8 arranques
    inicio = (5 + 6 * np.cos(ang), 5 + 6 * np.sin(ang), 0.0)
    t = ir_a_punto(inicio, meta)
    plt.plot(t[:, 0], t[:, 1])
plt.plot(*meta, "r*", markersize=14)
plt.axis("equal"); plt.grid(True); plt.title("Ir a un punto")
plt.show()
  ```)

  + Observa las 8 trayectorias. ¿Cuáles hacen maniobras más largas y por qué?
  + Duplica $K_v$ y luego $K_h$. Describe el efecto de cada ganancia.
  + Quita el `np.clip`. ¿Es realista lo que ocurre?
]

= Seguir una recta

Ahora no hay un punto final: el robot debe *alinearse y mantenerse* sobre la recta $a x + b y + c = 0$. Se combinan dos correcciones:

- *Distancia con signo* a la recta, que indica de qué lado está el robot y qué tan lejos:
  $ d = (a x + b y + c) / sqrt(a^2 + b^2) $
- *Error de rumbo* respecto a la dirección de la recta, $theta_ell = op("atan2")(a, -b)$.

$ delta = K_d d + K_h op("wrap")(theta_ell - theta) $

El primer término acerca el robot a la recta y el segundo lo pone paralelo a ella. Con solo uno de los dos, el robot oscila o termina paralelo pero desplazado.

#actividad("3", [Seguimiento de línea])[
  Escribe `seguir_linea.py` reutilizando `paso_bicicleta` y `wrap`. Usa la recta $x - 2y + 4 = 0$, pose inicial $(8, 5, pi\/2)$, $v = 1$ m/s, $K_d = 0.5$, $K_h = 1$ y 200 pasos. Dibuja la recta y la trayectoria en la misma figura.

  + Grafica también $d$ contra el tiempo. ¿Cuánto tarda en ser menor que 0.1 m?
  + Prueba $K_d = 0$ y luego $K_h = 0$. Explica lo que ves con los dos términos de la ley de control.
]

= Seguir un camino: _pure pursuit_

Un camino es una secuencia de puntos. La idea de _pure pursuit_ es perseguir una «zanahoria»: un punto del camino que está siempre una distancia $ell_d$ (_lookahead_) por delante del robot. Si ese punto está a un ángulo $alpha$ del rumbo actual, el arco circular que lo alcanza exige el ángulo de dirección

$ delta = arctan((2 L sin alpha) / ell_d) $

#actividad("4", [Pure pursuit sobre un camino de waypoints])[
  #archivo("pure_pursuit.py", ```python
import numpy as np
import matplotlib.pyplot as plt
from modelo_bicicleta import paso_bicicleta

def densificar(waypoints, paso=0.05):
    """Interpola los waypoints para tener un camino continuo."""
    puntos = [waypoints[0]]
    for a, b in zip(waypoints[:-1], waypoints[1:]):
        n = int(np.hypot(*(b - a)) / paso)
        puntos += [a + (b - a) * s for s in np.linspace(0, 1, n)[1:]]
    return np.array(puntos)

camino = densificar(np.array([[0, 0], [2, 4], [6, 5], [8, 10]], float))
L, ld, v = 2.0, 1.0, 0.5
estado, tray, i = np.array([0.0, 0.0, 0.0]), [], 0

while i < len(camino) - 1:
    # avanza el índice hasta el primer punto a más de ld del robot
    while i < len(camino) - 1 and np.hypot(*(camino[i] - estado[:2])) < ld:
        i += 1
    dx, dy = camino[i] - estado[:2]
    alpha = np.arctan2(dy, dx) - estado[2]
    delta = np.arctan2(2 * L * np.sin(alpha), ld)
    estado = paso_bicicleta(estado, v, delta, L=L)
    tray.append(estado)

tray = np.array(tray)
plt.plot(camino[:, 0], camino[:, 1], "r--", label="camino")
plt.plot(tray[:, 0], tray[:, 1], label=f"robot (ld = {ld} m)")
plt.axis("equal"); plt.grid(True); plt.legend(); plt.show()
  ```)

  + Compara $ell_d = 0.3$, $1.0$ y $3.0$ m en una sola figura.
  + ¿Por qué el robot «corta» las esquinas? ¿Puede evitarse del todo?
  + ¿Qué pasa con $ell_d$ muy pequeño cuando la velocidad es alta?
]

#tip[Un buen punto de partida es $ell_d approx 2$ a $3$ veces la distancia que el robot recorre en un segundo. En los vehículos reales $ell_d$ suele crecer con la velocidad.]

= Implementación en ROS 2 con el TurtleBot3

En la simulación anterior el estado lo calculábamos nosotros. En ROS 2 el estado llega por el tópico `/odom`, que publica el simulador o el robot real, y la orden se envía por `/cmd_vel`. El controlador queda en medio, cerrando el lazo:

#flujo([Gazebo · TurtleBot3], "/odom", [nodo `go_to_goal`], "/cmd_vel", [Gazebo · TurtleBot3])

La orientación llega como cuaternión $(q_x, q_y, q_z, q_w)$. Para un robot plano basta con el ángulo de guiñada (_yaw_):

$ theta = op("atan2")(2(q_w q_z + q_x q_y), 1 - 2(q_y^2 + q_z^2)) $

== Paquete y nodo

```bash
cd ~/ros2_ws/src
ros2 pkg create lab_robotica --build-type ament_python --dependencies rclpy geometry_msgs nav_msgs
```

#archivo("lab_robotica/go_to_goal.py", ```python
import math
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import TwistStamped
from nav_msgs.msg import Odometry

V_MAX, W_MAX = 0.22, 2.0        # límites del TurtleBot3 Burger [m/s], [rad/s]

def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi

class GoToGoal(Node):
    def __init__(self):
        super().__init__('go_to_goal')
        self.meta = (self.declare_parameter('x', 2.0).value,
                     self.declare_parameter('y', 2.0).value)
        self.Kv, self.Kh = 0.5, 2.0
        self.pose = None
        self.create_subscription(Odometry, '/odom', self.al_recibir_odom, 10)
        self.pub = self.create_publisher(TwistStamped, '/cmd_vel', 10)
        self.create_timer(0.1, self.controlar)            # 10 Hz

    def al_recibir_odom(self, msg):
        p, q = msg.pose.pose.position, msg.pose.pose.orientation
        yaw = math.atan2(2 * (q.w * q.z + q.x * q.y), 1 - 2 * (q.y**2 + q.z**2))
        self.pose = (p.x, p.y, yaw)

    def controlar(self):
        if self.pose is None:                              # aún no hay odometría
            return
        x, y, th = self.pose
        d = math.hypot(self.meta[0] - x, self.meta[1] - y)
        alpha = wrap(math.atan2(self.meta[1] - y, self.meta[0] - x) - th)

        cmd = TwistStamped()
        cmd.header.stamp = self.get_clock().now().to_msg()
        cmd.header.frame_id = 'base_link'
        if d > 0.05:
            # primero orientarse, luego avanzar
            avance = max(0.0, math.cos(alpha))
            cmd.twist.linear.x = min(self.Kv * d * avance, V_MAX)
            cmd.twist.angular.z = max(-W_MAX, min(self.Kh * alpha, W_MAX))
        self.pub.publish(cmd)                              # en la meta publica ceros

def main():
    rclpy.init()
    nodo = GoToGoal()
    try:
        rclpy.spin(nodo)
    except KeyboardInterrupt:
        pass
    nodo.destroy_node()
    rclpy.shutdown()
```)

Registra el ejecutable en `setup.py`, dentro de `entry_points`:

#archivo("setup.py (fragmento)", ```python
'console_scripts': [
    'go_to_goal = lab_robotica.go_to_goal:main',
],
```)

== Ejecución

```bash
# Terminal 1 — simulador
export TURTLEBOT3_MODEL=burger
ros2 launch turtlebot3_gazebo empty_world.launch.py
# Terminal 2 — compilar y correr el controlador
cd ~/ros2_ws && colcon build --packages-select lab_robotica
source install/setup.bash
ros2 run lab_robotica go_to_goal --ros-args -p x:=1.5 -p y:=-1.0
```

#tabla(columnas: (1.2fr, 1.5fr, 1.6fr),
  [*Síntoma*], [*Causa probable*], [*Qué hacer*],
  [El robot no se mueve y el mapa en RViz aparece en cero], [Gazebo Sim arrancó en pausa], [Pulsar _Play_ en Gazebo],
  [El robot ignora los comandos], [Se publicó `Twist` y Jazzy espera `TwistStamped`], [Revisar con `ros2 topic info /cmd_vel`],
  [Gira sin parar al terminar], [Otro nodo (teleop) sigue publicando en `/cmd_vel`], [Cerrar los demás publicadores; enviar un comando nulo],
  [La meta parece desplazada], [La odometría arranca en $(0, 0)$ donde nace el robot], [Medir las metas respecto a la pose inicial],
)

#reto[Modifica el nodo para recorrer una lista de metas, una tras otra (por ejemplo, los vértices de un cuadrado de 1 m). Grafica la trayectoria registrando `/odom` con `ros2 bag record /odom`.]

= Cierre

#preguntas[
  + ¿Qué información viaja en `/cmd_vel`? ¿Por qué solo se usan `linear.x` y `angular.z`?
  + ¿Qué datos de `/odom` cierran el lazo de control y cómo se obtienen en el robot?
  + La odometría *estima* la pose integrando el modelo. ¿Qué la hace derivar con el tiempo en un robot real?
  + ¿Qué sensores adicionales usarías para corregir esa deriva?
  + Compara el comportamiento de «ir a un punto» en la bicicleta (Actividad 2) y en el TurtleBot3. ¿Qué cambia gracias a que el diferencial puede girar en el sitio?
]

#entregables(
  [Informe técnico en PDF con las gráficas de las actividades 1 a 4 y sus análisis.],
  [Scripts de Python de las actividades 1 a 4.],
  [Paquete `lab_robotica` con el nodo `go_to_goal` funcionando.],
  [_(Opcional)_ Video corto del TurtleBot3 llegando a la meta en Gazebo.],
)
