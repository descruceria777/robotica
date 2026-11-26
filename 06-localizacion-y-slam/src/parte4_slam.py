"""Parte 4: SLAM con EKF (el filtro no conoce el mapa de landmarks)."""
from roboticstoolbox import Bicycle, EKF, RandomPath, LandmarkMap, RangeBearingSensor
import numpy as np
import matplotlib.pyplot as plt
from math import pi

np.random.seed(42)  # misma trayectoria en cada ejecución, para comparar experimentos

V = np.diag([0.02, np.deg2rad(0.5)])**2
robot = Bicycle(covar=V, animation=None)
robot.control = RandomPath(workspace=10)

mapa = LandmarkMap(20, workspace=10)  # mapa real (solo para simular el sensor)

# Experimento de sensor ruidoso: np.diag([2.0, np.deg2rad(15)])**2
W = np.diag([0.1, np.deg2rad(1)])**2
sensor = RangeBearingSensor(
    robot=robot, map=mapa, covar=W,
    angle=[-pi/2, pi/2], range=4,
)

P0 = np.diag([0.05, 0.05, np.deg2rad(0.5)])**2
slam = EKF(
    robot=(robot, V),
    P0=P0,
    sensor=(sensor, W),
    map=None,            # no conoce el mapa: lo estima junto con la pose
)
slam.run(T=40)

plt.figure(figsize=(10, 8))
mapa.plot()
robot.plot_xy(color='blue', label='Trayectoria real')
slam.plot_xy(color='red', label='Trayectoria estimada')
slam.plot_ellipse()
plt.title('SLAM usando EKF')
plt.grid(True)
plt.axis('equal')

plt.figure(figsize=(8, 6))
plt.plot(slam.get_t(), slam.get_Pnorm(), linewidth=2)
plt.xlabel('Tiempo [s]')
plt.ylabel('Incertidumbre')
plt.title('Evolución de incertidumbre en SLAM')
plt.grid(True)
plt.show()
