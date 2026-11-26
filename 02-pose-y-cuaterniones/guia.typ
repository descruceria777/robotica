#import "../plantilla/robotica.typ": *

#show: guia.with(
  numero: "02",
  titulo: [Pose y cuaterniones],
  subtitulo: [Representar posición y orientación, y llevarlas a TF2 en ROS 2],
  capitulo: "2",
  herramientas: ("Python", "SciPy", "ROS 2", "TF2", "RViz2"),
  duracion: "1 sesión",
  color: rgb("#9333ea"),
  objetivos: (
    [Describir una pose como posición más orientación y escribirla como transformación homogénea.],
    [Convertir una misma rotación entre Euler, matriz de rotación, eje-ángulo y cuaternión.],
    [Comprobar que el orden de las rotaciones importa.],
    [Publicar poses y transformaciones en ROS 2 y verlas en RViz2.],
    [Calcular errores de orientación e interpolar con SLERP.],
  ),
)

= ¿Qué es una pose?

La *pose* de un objeto responde dos preguntas: _¿dónde está?_ y _¿hacia dónde mira?_ Siempre se expresa *respecto a otro marco de referencia*. Decir que un robot está en $(2, 1)$ no significa nada si no se aclara respecto a qué.

#let marcos = box(width: 8.4cm, height: 4.6cm, {
  let c = rgb("#9333ea")
  let O = (0.8cm, 4.0cm)
  flecha(O, (2.4cm, 4.0cm), color: rgb("#dc2626"), grosor: 1.3pt)
  flecha(O, (0.8cm, 2.4cm), color: rgb("#16a34a"), grosor: 1.3pt)
  etiqueta((2.6cm, 4.25cm), $x_W$, color: rgb("#dc2626"))
  etiqueta((0.5cm, 2.3cm), $y_W$, color: rgb("#16a34a"))
  etiqueta((0.6cm, 4.35cm), [`world`], tam: 8pt)
  let P = (5.6cm, 1.9cm)
  let a = 35deg
  flecha(P, (P.at(0) + 1.5cm * calc.cos(a), P.at(1) - 1.5cm * calc.sin(a)), color: rgb("#dc2626"), grosor: 1.3pt)
  flecha(P, (P.at(0) - 1.5cm * calc.sin(a), P.at(1) - 1.5cm * calc.cos(a)), color: rgb("#16a34a"), grosor: 1.3pt)
  etiqueta((P.at(0) + 1.75cm * calc.cos(a), P.at(1) - 1.75cm * calc.sin(a)), $x_R$, color: rgb("#dc2626"))
  etiqueta((P.at(0) - 1.75cm * calc.sin(a), P.at(1) - 1.75cm * calc.cos(a)), $y_R$, color: rgb("#16a34a"))
  etiqueta((P.at(0) + 0.3cm, P.at(1) + 0.35cm), [`robot`], tam: 8pt)
  flecha(O, P, color: c, grosor: 1.4pt)
  etiqueta((3.0cm, 2.6cm), text(fill: c)[$bold(t)$], tam: 10pt)
  place(line(start: P, end: (P.at(0) + 1.6cm, P.at(1)), stroke: (paint: gris, thickness: 0.6pt, dash: "dashed")))
  etiqueta((P.at(0) + 1.75cm, P.at(1) - 0.45cm), $theta$, tam: 9pt)
})

#figure(marcos, kind: image, caption: [La pose del marco `robot` respecto a `world`: una traslación $bold(t)$ y una rotación $theta$.])

En 3D la pose se agrupa en una sola matriz de $4 times 4$, la *transformación homogénea*, que pertenece al grupo $"SE"(3)$:

$ bold(T) = mat(bold(R), bold(t); bold(0)^top, 1), quad bold(R) in "SO"(3), quad bold(t) in RR^3 $

Su gran ventaja es que encadenar marcos es multiplicar matrices: si conozco $attach(bold(T), tl: W, br: R)$ (robot respecto al mundo) y $attach(bold(T), tl: R, br: C)$ (cámara respecto al robot), entonces

$ attach(bold(T), tl: W, br: C) = attach(bold(T), tl: W, br: R) thin attach(bold(T), tl: R, br: C) $

TF2 hace exactamente esto por nosotros cada vez que pedimos la pose de un marco respecto a otro.

= Cuatro formas de escribir una rotación

#tabla(columnas: (auto, auto, 1fr),
  [*Representación*], [*Números*], [*Ventajas y problemas*],
  [Ángulos de Euler], [3], [Intuitivos, pero dependen del orden de los ejes y tienen *bloqueo de cardán* (se pierde un grado de libertad en ciertas posturas).],
  [Matriz de rotación], [9], [Componer es multiplicar. Redundante: 9 números para 3 grados de libertad; se «desortogonaliza» con el redondeo.],
  [Eje-ángulo], [4 (3)], [Muy geométrica: un eje y cuánto girar. Útil para describir velocidades angulares.],
  [Cuaternión unitario], [4], [Compacto, sin singularidades, fácil de normalizar e interpolar. Es lo que usa ROS 2.],
)

Un cuaternión unitario que gira un ángulo $phi$ alrededor del eje unitario $hat(bold(n))$ es

$ q = (cos phi/2, thin hat(bold(n)) sin phi/2) $

#cuidado[El orden de las componentes cambia según la librería. SciPy y ROS 2 usan $[x, y, z, w]$; otras librerías (por ejemplo, la _Spatial Math Toolbox_ de Corke) usan $[w, x, y, z]$. Confundirlas es un error muy común y silencioso.]

= Rotaciones en Python

#actividad("1", [La misma rotación, cuatro representaciones])[
  #archivo("representaciones.py", ```python
import numpy as np
from scipy.spatial.transform import Rotation as R

r = R.from_euler('z', 90, degrees=True)

print("Cuaternión [x y z w]:", np.round(r.as_quat(), 4))
print("Matriz:\n", np.round(r.as_matrix(), 4))
print("Eje-ángulo (rotvec):", np.round(r.as_rotvec(), 4))
print("Euler xyz [°]:", r.as_euler('xyz', degrees=True))

# Comprobación: deshacer y rehacer debe dar la misma rotación
r2 = R.from_quat(r.as_quat())
print("¿Equivalentes?", np.allclose(r.as_matrix(), r2.as_matrix()))
  ```)

  + Verifica a mano que el cuaternión corresponde a $q = (cos 45°, 0, 0, sin 45°)$.
  + Comprueba que $bold(R)^top bold(R) = bold(I)$ y que $det bold(R) = 1$.
]

#actividad("2", [El orden importa])[
  Define $bold(R)_1$ como 90° en $Z$ y $bold(R)_2$ como 90° en $X$. Calcula $bold(R)_1 bold(R)_2$ y $bold(R)_2 bold(R)_1$.

  #archivo("no_conmutatividad.py", ```python
from scipy.spatial.transform import Rotation as R
import numpy as np

r1 = R.from_euler('z', 90, degrees=True)
r2 = R.from_euler('x', 90, degrees=True)

for nombre, r in [("R1·R2", r1 * r2), ("R2·R1", r2 * r1)]:
    print(nombre, "\n", np.round(r.as_matrix(), 3))
  ```)

  + ¿Son iguales los resultados? Haz el experimento con un objeto real (un celular): gíralo 90° en $Z$ y luego 90° en $X$, y después en el orden contrario.
  + Explica por qué la suma de números es conmutativa y la composición de rotaciones no.
]

= Poses y transformaciones en ROS 2

En ROS 2 hay dos formas de comunicar una pose:

- Como *mensaje* en un tópico (`geometry_msgs/PoseStamped`): un dato que otros nodos pueden leer.
- Como *transformada* en TF2 (`geometry_msgs/TransformStamped`): una relación entre dos marcos que TF2 encadena con el resto del árbol.

#actividad("3", [Publicar una pose])[
  #archivo("pose_publisher.py", ```python
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import PoseStamped
from scipy.spatial.transform import Rotation as R

class PosePublisher(Node):
    def __init__(self):
        super().__init__('pose_publisher')
        self.pub = self.create_publisher(PoseStamped, '/pose', 10)
        self.create_timer(0.5, self.publicar)

    def publicar(self):
        msg = PoseStamped()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'world'            # ¡respecto a qué!
        msg.pose.position.x, msg.pose.position.y = 1.0, 2.0
        q = R.from_euler('z', 90, degrees=True).as_quat()
        o = msg.pose.orientation
        o.x, o.y, o.z, o.w = map(float, q)
        self.pub.publish(msg)

def main():
    rclpy.init()
    rclpy.spin(PosePublisher())
  ```)

  Verifica con `ros2 topic echo /pose` y visualízala en RViz2 agregando un display *Pose* sobre `/pose` (Fixed Frame: `world`).
]

#actividad("4", [Un marco que orbita])[
  Este nodo publica la transformada `world → robot`: el robot da vueltas en un círculo de 2 m de radio y siempre mira en la dirección del movimiento.

  #archivo("tf_orbita.py", ```python
import math
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import TransformStamped
from tf2_ros import TransformBroadcaster
from scipy.spatial.transform import Rotation as R

class Orbita(Node):
    def __init__(self):
        super().__init__('tf_orbita')
        self.br = TransformBroadcaster(self)
        self.t0 = self.get_clock().now()
        self.create_timer(0.05, self.publicar)    # 20 Hz

    def publicar(self):
        t = (self.get_clock().now() - self.t0).nanoseconds * 1e-9
        ang = 0.5 * t                                # 0.5 rad/s
        tf = TransformStamped()
        tf.header.stamp = self.get_clock().now().to_msg()
        tf.header.frame_id, tf.child_frame_id = 'world', 'robot'
        tf.transform.translation.x = 2.0 * math.cos(ang)
        tf.transform.translation.y = 2.0 * math.sin(ang)
        q = R.from_euler('z', ang + math.pi / 2).as_quat()   # tangente al círculo
        r = tf.transform.rotation
        r.x, r.y, r.z, r.w = map(float, q)
        self.br.sendTransform(tf)

def main():
    rclpy.init()
    rclpy.spin(Orbita())
  ```)

  + Visualiza en RViz2 con *TF* y *Axes* (`robot`). Genera también el diagrama del árbol con `ros2 run tf2_tools view_frames`.
  + Cambia la orientación a `ang` (sin $+pi\/2$). ¿Hacia dónde mira ahora el robot?
]

#tip[Con `ros2 run tf2_ros tf2_echo world robot` ves en la terminal la traslación y la rotación que TF2 calcula en cada instante.]

= Error e interpolación de orientación

== Error de orientación

Si la orientación deseada es $q_d$ y la actual es $q_a$, la rotación que falta para llegar es

$ q_e = q_d times.o q_a^(-1) $

Su ángulo indica *cuánto* falta girar y su eje, *alrededor de qué*. Un controlador de orientación intenta llevar ese ángulo a cero.

#actividad("5", [Calcular el error])[
  #archivo("error_orientacion.py", ```python
from scipy.spatial.transform import Rotation as R
import numpy as np

q_d = R.from_euler('z', 90, degrees=True)
q_a = R.from_euler('z', 45, degrees=True)
q_e = q_d * q_a.inv()

print("Error (Euler xyz) [°]:", q_e.as_euler('xyz', degrees=True))
print("Ángulo de error [°]:", np.degrees(q_e.magnitude()))
  ```)

  Repite con $q_d$ = 10° en $X$ y 80° en $Z$. ¿Por qué ahora el error no se puede leer como una simple resta de ángulos?
]

== Interpolar con SLERP

Para pasar suavemente de una orientación a otra no sirve interpolar cada componente por separado: el cuaternión intermedio deja de ser unitario y la velocidad de giro no es constante. SLERP (_spherical linear interpolation_) recorre el arco más corto entre $q_0$ y $q_1$ a velocidad angular constante:

$ op("slerp")(q_0, q_1, s) = q_0 times.o (q_0^(-1) times.o q_1)^s, quad s in [0, 1] $

#actividad("6", [Interpolación SLERP])[
  #archivo("slerp.py", ```python
import numpy as np
from scipy.spatial.transform import Rotation as R, Slerp

extremos = R.from_euler('z', [0, 90], degrees=True)
slerp = Slerp([0, 1], extremos)

s = np.linspace(0, 1, 7)
for si, r in zip(s, slerp(s)):
    print(f"s = {si:.2f}  ->  yaw = {r.as_euler('xyz', degrees=True)[2]:6.2f}°")
  ```)

  + ¿Los ángulos intermedios quedan igualmente espaciados?
  + Repite entre 0° y 270° en $Z$. ¿Por dónde gira SLERP y por qué?
]

#preguntas[
  + ¿Por qué ROS 2 usa cuaterniones y no ángulos de Euler para la orientación?
  + ¿Qué es el bloqueo de cardán y por qué los cuaterniones no lo sufren?
  + ¿Qué relación hay entre el árbol de TF2 y la composición de transformaciones homogéneas?
  + ¿Qué representa físicamente el cuaternión de error de la Actividad 5?
]

#entregables(
  [Salidas de las actividades 1, 2, 5 y 6 con una explicación breve de cada una.],
  [Capturas de RViz2 (pose publicada y marco en órbita) y del árbol de `view_frames`.],
  [Código de los nodos `pose_publisher` y `tf_orbita`.],
)
