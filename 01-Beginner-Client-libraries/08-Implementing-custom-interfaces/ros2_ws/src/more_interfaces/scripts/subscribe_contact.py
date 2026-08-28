#!/usr/bin/env python3

import rclpy
from rclpy.node import Node
from more_interfaces.msg import Contact


class ContactSubscriber(Node):

    def __init__(self):
        super().__init__('address_book_subscriber_py')
        self.subscription_ = self.create_subscription(
            Contact,
            'address_book',
            self.listener_callback,
            10)
        self.subscription_

    def listener_callback(self, msg):
        self.get_logger().info(
            f'Received: {msg.first_name} {msg.last_name} | '
            f'phone: {msg.phone_number} | type: {msg.phone_type}')


def main():
    rclpy.init()
    node = ContactSubscriber()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()