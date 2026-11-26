# 06 · Localización y mapeo

📄 [Guía](guia.pdf) · 📝 [Informe Partes 1–4](informe-localizacion-slam.pdf) · Corke, capítulo 6

Simulaciones en Python con Robotics Toolbox (no requieren ROS 2). Cada parte agrega una pieza al problema de saber dónde está el robot.

| Parte | Script | Qué hace | Incertidumbre |
|-------|--------|----------|---------------|
| 1 | [`parte1_odometria.py`](src/parte1_odometria.py) | Odometría con y sin ruido | El error se acumula |
| 2 | [`parte2_ekf.py`](src/parte2_ekf.py) | EKF solo con odometría | Crece todo el tiempo |
| 3 | [`parte3_ekf_landmarks.py`](src/parte3_ekf_landmarks.py) | EKF con landmarks conocidos | Sube y baja, acotada |
| 4 | [`parte4_slam.py`](src/parte4_slam.py) | SLAM con EKF (mapa desconocido) | Se reduce parcialmente |

## Ejecutar

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r src/requirements.txt
python3 src/parte1_odometria.py
```

Los experimentos del informe (más ruido de odometría `V` o de sensor `W`) se hacen cambiando el valor indicado en el comentario de cada script.

## Conclusiones

- La odometría sola acumula error sin límite, y más rápido cuanto mayor es `V`.
- El EKF sin observaciones externas solo mide su incertidumbre; no puede reducirla.
- Con landmarks conocidos, el filtro corrige la pose y mantiene la incertidumbre acotada.
- SLAM permite operar sin mapa previo, a cambio de una estimación menos precisa.
- `W` define cuánto baja la incertidumbre en cada corrección; `V`, qué tan rápido sube entre observaciones.
- Para comparar experimentos conviene fijar la semilla (`np.random.seed(42)`).
