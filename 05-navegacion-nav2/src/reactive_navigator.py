"""Nodo reactivo para TurtleBot3 (ROS 2 Jazzy).

Avanza mientras el frente está libre y gira sobre su eje cuando detecta un
obstáculo a menos de 0,5 m en el sector frontal del LiDAR (±30°).

Ejecución (con Gazebo corriendo y sin Nav2 publicando en /cmd_vel):
    ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
    python3 reactive_navigator.py
"""
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import LaserScan
from geometry_msgs.msg import TwistStamped
import numpy as np


class ReactiveNavigator(Node):
    def __init__(self):
        super().__init__('reactive_navigator')

        self.sub = self.create_subscription(
            LaserScan, '/scan', self.scan_callback, 10)

        # En Jazzy /cmd_vel del TurtleBot3 usa TwistStamped (no Twist)
        self.pub = self.create_publisher(TwistStamped, '/cmd_vel', 10)

    def scan_callback(self, msg):
        ranges = np.array(msg.ranges, dtype=float)
        n = len(ranges)
        if n == 0:
            return

        # Sector frontal: ±30° alrededor del índice 0 (frente del robot)
        k = int(n * 30 / 360)
        front_sector = np.concatenate((ranges[:k], ranges[-k:]))

        # Limpiar inf / nan
        front_sector = front_sector[np.isfinite(front_sector)]
        if len(front_sector) == 0:
            return

        front = np.min(front_sector)

        cmd = TwistStamped()
        cmd.header.stamp = self.get_clock().now().to_msg()
        cmd.header.frame_id = 'base_link'

        if front < 0.5:
            cmd.twist.linear.x = 0.0
            cmd.twist.angular.z = 0.8
        else:
            cmd.twist.linear.x = 0.2
            cmd.twist.angular.z = 0.0

        self.pub.publish(cmd)


def main():
    rclpy.init()
    node = ReactiveNavigator()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
