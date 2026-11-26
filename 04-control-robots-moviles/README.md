# 04 · Modelado y control de robots móviles

📄 [Guía](guia.pdf) · 📝 [Informe Parte 5: ROS 2 Jazzy + Gazebo](informe-parte5-ros2-gazebo.pdf) · Corke, capítulo 4

Modelos cinemáticos de robots móviles (tipo bicicleta y diferencial) y controladores para **ir a un punto**, **seguir una línea** y **seguir una trayectoria (Pure Pursuit)**, primero en Python y luego en ROS 2.

## Parte 5: implementación en ROS 2 con TurtleBot3

- Paquete `lab_robotica` (`ament_python`; `rclpy`, `geometry_msgs`, `nav_msgs`, `std_msgs`).
- Nodo `go_to_goal.py`: lee `/odom`, convierte el cuaternión en el rumbo θ con `atan2`, calcula los errores de distancia y de ángulo (normalizado a [−π, π]) y publica `TwistStamped` en `/cmd_vel` a 10 Hz.
- Prueba en Gazebo Sim (`turtlebot3_world`) con los modelos Burger y Waffle, y teleoperación con `turtlebot3_teleop_key`.

## Problemas encontrados y soluciones

| Problema | Causa | Solución |
|----------|-------|----------|
| `cartographer_node` se cierra al iniciar | Incompatibilidad con el reloj de Gazebo Sim en Jazzy | Usar `slam_toolbox` (`online_async_launch.py use_sim_time:=True`) |
| Mapa en cero y robot sin respuesta | Gazebo Sim arranca en pausa | Pulsar *Play* en Gazebo |
| `Frame [map] does not exist` en RViz | El SLAM aún no publica `map → odom` | Usar `odom` como Fixed Frame mientras arranca `slam_toolbox` |
| El robot gira sin parar | Último `/cmd_vel` sigue activo o hay varios publicadores | Cerrar los otros nodos y enviar velocidad cero |
