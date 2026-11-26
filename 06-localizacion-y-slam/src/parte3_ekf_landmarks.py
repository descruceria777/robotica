"""Parte 3: EKF con landmarks de posición conocida (sensor rango-ángulo)."""
from roboticstoolbox import Bicycle, EKF, RandomPath, LandmarkMap, RangeBearingSensor
import numpy as np
import matplotlib.pyplot as plt
from math import pi

V = np.diag([0.02, np.deg2rad(0.5)])**2
robot = Bicycle(covar=V, animation=None)
robot.control = RandomPath(workspace=10)

mapa = LandmarkMap(20, workspace=10)

W = np.diag([0.1, np.deg2rad(1)])**2
sensor = RangeBearingSensor(
    robot=robot, map=mapa, covar=W,
    angle=[-pi/2, pi/2], range=4,
)

P0 = np.diag([0.05, 0.05, np.deg2rad(0.5)])**2
ekf = EKF(
    robot=(robot, V),
    P0=P0,
    map=mapa,            # el filtro conoce el mapa de landmarks
    sensor=(sensor, W),
)
ekf.run(T=40)

plt.figure(figsize=(8, 6))
mapa.plot()
robot.plot_xy(color='blue')
ekf.plot_xy(color='red')
ekf.plot_ellipse()
plt.title('EKF con landmarks')
plt.grid(True)

plt.figure(figsize=(8, 6))
plt.plot(ekf.get_t(), ekf.get_Pnorm(), linewidth=2)
plt.xlabel('Tiempo [s]')
plt.ylabel('Incertidumbre')
plt.title('Incertidumbre con correcciones')
plt.grid(True)
plt.show()
