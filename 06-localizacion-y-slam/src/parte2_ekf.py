"""Parte 2: EKF usando solo odometría (sin sensores externos)."""
from roboticstoolbox import Bicycle, EKF, RandomPath
import numpy as np
import matplotlib.pyplot as plt

# Experimento V alta: np.diag([0.1, np.deg2rad(2.0)])**2
V = np.diag([0.02, np.deg2rad(0.5)])**2

robot = Bicycle(covar=V, animation=None)
robot.control = RandomPath(workspace=10)

P0 = np.diag([0.05, 0.05, np.deg2rad(0.5)])**2
ekf = EKF(robot=(robot, V), P0=P0)
ekf.run(T=20)

plt.figure(figsize=(8, 6))
robot.plot_xy(color='blue')
ekf.plot_xy(color='red')
plt.title('Trayectoria real vs estimada')
plt.grid(True)

plt.figure(figsize=(8, 6))
plt.plot(ekf.get_t(), ekf.get_Pnorm(), linewidth=2)
plt.xlabel('Tiempo [s]')
plt.ylabel('Incertidumbre')
plt.title('Crecimiento de incertidumbre')
plt.grid(True)
plt.show()
