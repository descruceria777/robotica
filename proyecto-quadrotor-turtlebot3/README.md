# Proyecto: control cooperativo Quadrotor + TurtleBot 3 en ROS 2

*Informe de avance, 12 de noviembre de 2026*

El objetivo es reproducir en ROS 2 Jazzy el sistema de una tesis de la EPN: un quadrotor mapea un entorno en 2D y un TurtleBot 3 navega con ese mapa. Ya funcionan el entorno de simulación y la navegación del TurtleBot 3 con Nav2. Faltan el quadrotor, el SLAM y la integración de las dos tareas.

## Avance (5 de 10 tareas)

| Tarea | Estado | Evidencia o entregable |
|-------|--------|------------------------|
| Análisis de la tesis y del flujo SLAM → mapa → navegación | ✅ Hecho | Informe de avance |
| Entorno ROS 2 Jazzy, Gazebo Sim y RViz2 en Ubuntu 24.04 | ✅ Hecho | [Laboratorio 05](../05-navegacion-nav2/) |
| TurtleBot 3 Waffle en Gazebo Sim con LiDAR publicando `/scan` | ✅ Hecho | [Laboratorio 05](../05-navegacion-nav2/) |
| Navegación autónoma con Nav2 sobre mapa estático | ✅ Hecho | Meta alcanzada con 0,02 m de error y 0 recuperaciones |
| Base de localización y SLAM (odometría, EKF, landmarks, SLAM) | ✅ Hecho | [Laboratorio 06](../06-localizacion-y-slam/) |
| Quadrotor en Gazebo Sim con control de vuelo y LiDAR 2D | ⏳ Pendiente | Dron que despega, se mueve y publica `/scan` |
| SLAM 2D desde el quadrotor con `slam_toolbox`, visto en RViz2 | ⏳ Pendiente | Mapa que se forma mientras el dron vuela |
| Guardado del mapa y carga en Nav2 | ⏳ Pendiente | Archivos `.yaml` y `.pgm` |
| Dos archivos de lanzamiento: SLAM y navegación | ⏳ Pendiente | `MAIN_SLAM` y `MAIN_NAV` |
| Dos escenarios, tres metas por escenario, tiempos de mapeo y trayecto | ⏳ Pendiente | Tabla comparable con la de la tesis |

**Siguiente paso:** el quadrotor (tarea 6), porque el SLAM, el mapa y la integración dependen de él.
