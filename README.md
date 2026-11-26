# Robótica: laboratorios de simulación

Trabajos de la asignatura **Robótica**, Universidad Nacional de Colombia, sede Manizales.
Las guías siguen el texto de Peter Corke, *Robotics, Vision and Control* (Python), y se trabajan en ROS 2, Gazebo y Robotics Toolbox for Python.

**Integrantes:** Daniel Santiago Escruceria Rosero · Jailer Ramiro Chapid Romero

**Entorno:** Ubuntu 24.04 (VirtualBox) · ROS 2 Jazzy · Gazebo Sim · RViz2 · Python 3 + `roboticstoolbox-python` 1.5.0

## Contenido

| # | Tema | Guía | Informe | Código |
|---|------|------|---------|--------|
| 00 | [Introducción a ROS 2: mini INS con IMU](00-intro-ros2/) | ✅ | — | — |
| 02 | [Pose y cuaterniones en ROS 2](02-pose-y-cuaterniones/) | ✅ | — | — |
| 03 | [Movimiento, velocidad y trayectorias](03-movimiento-y-trayectorias/) | ✅ | — | — |
| 04 | [Modelado y control de robots móviles](04-control-robots-moviles/) | ✅ | ✅ Parte 5 (ROS 2 + Gazebo) | — |
| 05 | [Navegación: de lo reactivo a Nav2](05-navegacion-nav2/) | ✅ | ✅ Parte E | ✅ |
| 06 | [Localización y mapeo (EKF, SLAM)](06-localizacion-y-slam/) | ✅ | ✅ Partes 1–4 | ✅ |
| 07 | [Cinemática de manipuladores](07-cinematica-manipuladores/) | ✅ | — | — |
| — | [Proyecto: Quadrotor + TurtleBot 3 cooperativos](proyecto-quadrotor-turtlebot3/) | — | Avance | — |

Cada carpeta tiene un `README.md` con el resumen del laboratorio, la guía (`guia.pdf`, escrita en Typst en `guia.typ`), el informe entregado si existe, y en `src/` los scripts que se usaron.

## Guías

Las guías son una versión propia de cada práctica: explicaciones, diagramas y código reescritos y corregidos (por ejemplo, el sector frontal del LiDAR o el uso de `TwistStamped` en Jazzy). Todas comparten la plantilla [`plantilla/robotica.typ`](plantilla/robotica.typ).

Para regenerar un PDF después de editar el `.typ` (necesita [Typst](https://typst.app)):

```bash
typst compile --root . 04-control-robots-moviles/guia.typ
# o todas a la vez
for d in 0*/; do typst compile --root . "$d/guia.typ"; done
```

## Estructura

```
robotica/
├── plantilla/robotica.typ      ← estilo común de las guías
├── 00-intro-ros2/
├── 02-pose-y-cuaterniones/
├── 03-movimiento-y-trayectorias/
├── 04-control-robots-moviles/
├── 05-navegacion-nav2/
│   └── src/reactive_navigator.py
├── 06-localizacion-y-slam/
│   └── src/parte1..4_*.py
├── 07-cinematica-manipuladores/
└── proyecto-quadrotor-turtlebot3/
```

## Preparar el entorno

```bash
# ROS 2 Jazzy + simulación del TurtleBot3
sudo apt install -y ros-jazzy-desktop ros-jazzy-navigation2 ros-jazzy-nav2-bringup \
  ros-jazzy-turtlebot3 ros-jazzy-turtlebot3-simulations ros-jazzy-ros-gz ros-jazzy-tf2-tools
source /opt/ros/jazzy/setup.bash
export TURTLEBOT3_MODEL=waffle
export LIBGL_ALWAYS_SOFTWARE=1   # necesario para Gazebo/RViz dentro de VirtualBox

# Scripts de Python (capítulo 6)
python3 -m venv venv && source venv/bin/activate
pip install -r 06-localizacion-y-slam/src/requirements.txt
```
