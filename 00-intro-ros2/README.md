# 00 · Introducción a ROS 2: mini INS

📄 [Guía (PDF)](guia.pdf) · [fuente Typst](guia.typ)

Primer contacto con ROS 2 (Jazzy/Humble) y RViz: se crea un nodo en Python que funciona como un sistema de navegación inercial mínimo.

**Objetivos**
- Probar ROS 2 y RViz en Ubuntu.
- Recibir datos de una IMU en el tópico `/imu`.
- Integrar la velocidad angular para obtener la orientación.
- Publicar la orientación como una transformada TF (cuaternión).

**Pasos principales**
1. Crear el workspace `~/ros2_ws` y compilarlo con `colcon build`.
2. Crear el paquete `imu_orientation` (`ament_python`, dependencias `rclpy sensor_msgs geometry_msgs tf2_ros`).
3. Escribir el nodo `imu_integrator.py`, registrarlo en `setup.py` y visualizar el frame en RViz.
