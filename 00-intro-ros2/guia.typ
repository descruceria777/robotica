#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "00",
  titulo: [Primeros pasos en ROS 2],
  subtitulo: [Un sistema de navegación inercial mínimo con una IMU simulada],
  herramientas: ("ROS 2 Jazzy / Humble", "Python", "SciPy", "RViz2"),
  duracion: "1 sesión",
  color: rgb("#4f46e5"),
  objetivos: (
    [Crear un workspace y un paquete de Python en ROS 2.],
    [Escribir un nodo que publica y otro que se suscribe a un tópico.],
    [Integrar la velocidad angular de una IMU para estimar orientación con cuaterniones.],
    [Publicar esa orientación como una transformada TF y verla en RViz2.],
  ),
)

= Las piezas de ROS 2

ROS 2 no es un sistema operativo: es un conjunto de herramientas para que muchos programas pequeños, los *nodos*, se comuniquen entre sí. En esta práctica se usan cuatro conceptos:

#tabla(columnas: (auto, 1fr),
  [*Concepto*], [*Qué es en esta práctica*],
  [Nodo], [Un programa de Python con una tarea concreta: simular la IMU o integrar sus datos.],
  [Tópico], [Un canal con nombre, como `/imu`, por donde viajan mensajes de un tipo fijo.],
  [Mensaje], [La estructura de datos. `sensor_msgs/Imu` trae velocidad angular, aceleración y orientación.],
  [TF], [El sistema que lleva la cuenta de cómo se ubica cada marco de referencia respecto a los demás.],
)

El sistema completo es una cadena de dos nodos. El simulador finge ser una IMU que gira; el integrador acumula ese giro y lo anuncia a TF, de donde lo lee RViz2:

#flujo([`imu_simulator`], "/imu", [`imu_integrator`], "/tf", [RViz2])

#idea[Un INS (_Inertial Navigation System_) estima la orientación *sin mirar el mundo exterior*: solo suma pequeños giros medidos por el giróscopo. Por eso cualquier error se acumula. Esta idea reaparece en los laboratorios de odometría y localización.]

= Integrar la velocidad angular

El giróscopo mide la velocidad angular $bold(omega) = (omega_x, omega_y, omega_z)$ en rad/s. Durante un intervalo corto $Delta t$, el cuerpo gira un ángulo $norm(bold(omega)) Delta t$ alrededor del eje $bold(omega) \/ norm(bold(omega))$. Ese pequeño giro se expresa como un cuaternión incremental $Delta q$ y se compone con la orientación acumulada:

$ q_(k+1) = q_k times.o Delta q, quad Delta q = op("exp")(1/2 bold(omega) Delta t) $

En código esto es una línea con SciPy: `R.from_rotvec(w * dt)` construye $Delta q$ a partir del vector de rotación $bold(omega) Delta t$.

#cuidado[Por redondeo numérico, después de miles de multiplicaciones el cuaternión deja de tener norma 1 y ya no representa una rotación válida. Hay que *normalizarlo* en cada paso.]

= Workspace y paquete

```bash
source /opt/ros/jazzy/setup.bash
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src
ros2 pkg create imu_orientation --build-type ament_python --dependencies rclpy sensor_msgs geometry_msgs tf2_ros
```

El paquete queda con esta estructura; los dos nodos van en la carpeta interna `imu_orientation/`:

#archivo("~/ros2_ws/src/imu_orientation/", ```text
imu_orientation/
├── imu_orientation/
│   ├── __init__.py
│   ├── imu_simulator.py      ← nodo 1
│   └── imu_integrator.py     ← nodo 2
├── package.xml
├── setup.py
└── setup.cfg
```)

= Los dos nodos

#actividad("1", [Simulador de IMU])[
  Como no hay una IMU física, este nodo publica a 100 Hz una velocidad angular constante.

  #archivo("imu_orientation/imu_simulator.py", ```python
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Imu

class IMUSimulator(Node):
    def __init__(self):
        super().__init__('imu_simulator')
        # velocidad angular configurable desde la terminal
        self.w = [self.declare_parameter(e, v).value
                  for e, v in (('wx', 0.0), ('wy', 0.0), ('wz', 0.5))]
        self.pub = self.create_publisher(Imu, '/imu', 10)
        self.create_timer(0.01, self.publicar)        # 100 Hz

    def publicar(self):
        msg = Imu()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'imu_link'
        msg.angular_velocity.x, msg.angular_velocity.y, msg.angular_velocity.z = self.w
        self.pub.publish(msg)

def main():
    rclpy.init()
    rclpy.spin(IMUSimulator())
  ```)
]

#actividad("2", [Integrador de orientación])[
  #archivo("imu_orientation/imu_integrator.py", ```python
import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.time import Time
from sensor_msgs.msg import Imu
from geometry_msgs.msg import TransformStamped
from tf2_ros import TransformBroadcaster
from scipy.spatial.transform import Rotation as R

class IMUIntegrator(Node):
    def __init__(self):
        super().__init__('imu_integrator')
        self.create_subscription(Imu, '/imu', self.al_recibir, 10)
        self.tf = TransformBroadcaster(self)
        self.q = R.identity()          # orientación acumulada
        self.t_anterior = None
        self.get_logger().info('Integrador listo')

    def al_recibir(self, msg):
        t = Time.from_msg(msg.header.stamp)       # tiempo de la medición
        if self.t_anterior is None:                # primera muestra: solo guardar
            self.t_anterior = t
            return
        dt = (t - self.t_anterior).nanoseconds * 1e-9
        self.t_anterior = t
        if dt <= 0.0:
            return

        w = msg.angular_velocity
        dq = R.from_rotvec(np.array([w.x, w.y, w.z]) * dt)
        self.q = R.from_quat((self.q * dq).as_quat())   # normaliza
        self.publicar_tf(msg.header.stamp)

    def publicar_tf(self, stamp):
        tf = TransformStamped()
        tf.header.stamp = stamp
        tf.header.frame_id = 'world'
        tf.child_frame_id = 'imu_link'
        qx, qy, qz, qw = self.q.as_quat()                # SciPy usa [x, y, z, w]
        tf.transform.rotation.x, tf.transform.rotation.y = float(qx), float(qy)
        tf.transform.rotation.z, tf.transform.rotation.w = float(qz), float(qw)
        self.tf.sendTransform(tf)

def main():
    rclpy.init()
    rclpy.spin(IMUIntegrator())
  ```)

  Fíjate en dos decisiones: $Delta t$ se calcula con la *marca de tiempo del mensaje* (no con la hora a la que llega), y la primera muestra solo inicializa el tiempo.
]

= Compilar y ejecutar

Registra ambos ejecutables en `setup.py`:

#archivo("setup.py (fragmento)", ```python
entry_points={
    'console_scripts': [
        'imu_simulator = imu_orientation.imu_simulator:main',
        'imu_integrator = imu_orientation.imu_integrator:main',
    ],
},
```)

```bash
cd ~/ros2_ws && colcon build --packages-select imu_orientation
source install/setup.bash
# Terminal 1
ros2 run imu_orientation imu_simulator
# Terminal 2 (también con source install/setup.bash)
ros2 run imu_orientation imu_integrator
```

Antes de abrir RViz, comprueba desde otra terminal que los datos fluyen:

```bash
ros2 node list
ros2 topic hz /imu
ros2 topic echo /tf --once
```

= Visualización en RViz2

+ Ejecuta `rviz2`.
+ En *Global Options → Fixed Frame* escribe `world`. Debe coincidir exactamente con el `frame_id` que publica el integrador.
+ Pulsa *Add* y agrega *TF*. Activa _Show Names_ y _Show Axes_.
+ Agrega *Axes* y en _Reference Frame_ elige `imu_link`.

Deberías ver el marco `world` fijo y el marco `imu_link` girando sobre el eje $Z$ (azul): rojo es $X$ y verde es $Y$.

#tabla(columnas: (1fr, 1.3fr),
  [*Si no ves nada…*], [*Revisa*],
  [RViz muestra «Frame [world] does not exist»], [Que el integrador esté corriendo: `ros2 node list`.],
  [Los nodos corren pero no hay TF], [`ros2 topic echo /tf`; si está vacío, el simulador no publica en `/imu`.],
  [`ros2 run` no encuentra el paquete], [Faltó `source install/setup.bash` en esa terminal.],
  [El marco aparece con otro nombre], [Errores de escritura: `imu_link` ≠ `imu-link`. Verifica con `ros2 run tf2_tools view_frames`.],
)

= Experimentos

#actividad("3", [Comprobar que el modelo tiene sentido])[
  Cambia la velocidad angular sin recompilar, usando parámetros:

  ```bash
ros2 run imu_orientation imu_simulator --ros-args -p wz:=1.0
ros2 run imu_orientation imu_simulator --ros-args -p wx:=0.5 -p wz:=0.0
ros2 run imu_orientation imu_simulator --ros-args -p wx:=0.2 -p wy:=0.3 -p wz:=0.5
  ```

  + Con `wz:=1.0`, ¿cuánto tarda en dar una vuelta? Calcula el valor esperado ($2 pi \/ omega$) y mídelo.
  + Con `wx:=0.5`, ¿alrededor de qué eje gira ahora el marco?
  + Con los tres ejes a la vez, describe el movimiento. ¿Es una rotación alrededor de un único eje fijo?
]

#reto[Quita la normalización del integrador, deja el sistema corriendo varios minutos y registra la norma del cuaternión. ¿Cuánto se aleja de 1? Luego intenta integrar *ángulos de Euler* sumando $omega_x Delta t$, $omega_y Delta t$, $omega_z Delta t$ por separado y compara con el caso de tres ejes. ¿Por qué el resultado es distinto?]

#preguntas[
  + ¿Por qué el integrador necesita $Delta t$ y qué pasa si se calcula mal?
  + ¿Qué representa físicamente el marco `imu_link` y por qué su traslación es cero?
  + En un INS real, ¿qué fuentes de error harían que la orientación estimada se desvíe con el tiempo?
  + ¿Qué sensor añadirías para corregir la deriva en el ángulo de guiñada (_yaw_)?
]

#entregables(
  [Capturas de `ros2 node list`, `ros2 topic hz /imu` y de RViz2 con el marco girando.],
  [Resultados y respuestas de la Actividad 3.],
  [Código de los dos nodos.],
)
