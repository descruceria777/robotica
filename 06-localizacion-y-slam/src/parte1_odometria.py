"""Parte 1: odometría (dead reckoning) con y sin ruido."""
from roboticstoolbox import Bicycle
import numpy as np
import matplotlib.pyplot as plt

# Covarianza del ruido de odometría (velocidad, ángulo de dirección).
# Experimento de ruido alto: np.diag([0.6, np.deg2rad(2.0)])**2
V = np.diag([0.2, np.deg2rad(0.5)])**2
print(V)

robot = Bicycle(covar=V)                          # con ruido
robot_ideal = Bicycle(covar=np.zeros((2, 2)))     # sin ruido

x_real, y_real = [], []
x_ideal, y_ideal = [], []
qp_real = [0, 0, 0]
qp_ideal = [0, 0, 0]

for _ in range(200):
    odo_real = robot.step((1.0, 0.2))
    qp_real = robot.f(qp_real, odo_real)

    odo_ideal = robot_ideal.step((1.0, 0.2))
    qp_ideal = robot_ideal.f(qp_ideal, odo_ideal)

    x_real.append(qp_real[0])
    y_real.append(qp_real[1])
    x_ideal.append(qp_ideal[0])
    y_ideal.append(qp_ideal[1])

plt.figure(figsize=(8, 6))
plt.plot(x_ideal, y_ideal, label='Odometría sin ruido', linewidth=1)
plt.plot(x_real, y_real, label='Odometría con ruido', linewidth=1)
plt.xlabel('X [m]')
plt.ylabel('Y [m]')
plt.title('Comparación de trayectorias')
plt.grid(True)
plt.axis('equal')
plt.legend()
plt.show()
