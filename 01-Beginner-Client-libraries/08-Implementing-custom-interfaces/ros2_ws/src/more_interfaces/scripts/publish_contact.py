#!/usr/bin/env python3

import rclpy
from rclpy.node import Node
from more_interfaces.msg import Contact

class ContactPublisher(Node):

    def __init__(self):
        super().__init__('address_book_publisher_py')
        self.publisher_ = self.create_publisher(Contact, 'address_book', 10)
        self.timer_     = self.create_timer(1.0, self.timer_callback)

    def timer_callback(self):
        msg              = Contact()
        msg.first_name   = 'John'
        msg.last_name    = 'Doe'
        msg.phone_number = '1234567890'
        msg.phone_type   = Contact.PHONE_TYPE_MOBILE
        self.get_logger().info(f'Publishing: {msg.first_name} {msg.last_name}')
        self.publisher_.publish(msg)


def main():
    rclpy.init()
    node = ContactPublisher()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()