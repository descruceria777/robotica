# 05 · Navegación de robots móviles: de lo reactivo a Nav2

📄 [Guía (PDF)](guia.pdf) · [fuente Typst](guia.typ) · 📝 [Informe Parte E](informe-nav2-ros2.docx) · Corke, capítulo 5

La guía recorre navegación reactiva, Bug2, planificación con A* sobre mapas de ocupación y navegación autónoma con Nav2. El informe documenta la **Parte E**, en ROS 2 Jazzy con Gazebo y TurtleBot3 Waffle.

## E1 · Navegación con Nav2

```bash
ros2 launch nav2_bringup tb3_simulation_launch.py headless:=False
```

En RViz se fija la pose inicial con *2D Pose Estimate* (AMCL) y la meta con *Nav2 Goal*. En la prueba registrada el robot llegó a la meta con un error de 0,02 m, en 13 s y sin recuperaciones.

Comandos útiles para inspeccionar Nav2:

```bash
ros2 node list
ros2 lifecycle nodes
ros2 topic echo /amcl_pose --once
ros2 run tf2_ros tf2_echo map base_link
```

Si quedan simulaciones anteriores abiertas (por ejemplo, aparecen dos robots):

```bash
pkill -9 -f "gz sim"; pkill -9 -f rviz2; pkill -9 -f nav2; ros2 daemon stop
```

## E2 · Nodo reactivo — [`src/reactive_navigator.py`](src/reactive_navigator.py)

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py   # solo Gazebo, sin Nav2
python3 src/reactive_navigator.py
```

El nodo avanza a 0,2 m/s y, si detecta un obstáculo a menos de 0,5 m al frente, se detiene y gira a 0,8 rad/s.

**Correcciones respecto al código de la guía**
- En Jazzy, `/cmd_vel` es `TwistStamped`, no `Twist`.
- El frente del LiDAR del TurtleBot3 está en el índice 0: el sector frontal son los extremos del arreglo (±30°), no el tramo central.
- Se filtran `inf`/`nan` en el mismo sector que se usa para decidir.

## Reactivo vs Nav2

| Aspecto | Reactivo | Nav2 |
|---------|----------|------|
| Mapa | No | Sí |
| Localización | No | AMCL |
| Meta | No | Sí |
| Planificación | No | Global + local |
| Riesgo | Atascos, sin rumbo | Depende del mapa y de la pose inicial |
