#include <chrono>
#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/contact.hpp"

using namespace std::chrono_literals;


class ContactPublisher : public rclcpp::Node {
    private:
        rclcpp::Publisher<more_interfaces::msg::Contact>::SharedPtr contact_publisher_;
        rclcpp::TimerBase::SharedPtr timer_;
    public:
        ContactPublisher() : Node("contact_publisher") {
            contact_publisher_ = this->create_publisher<more_interfaces::msg::Contact>("contact", 10);
            auto publish_msg = [this] () -> void {
                auto msg = more_interfaces::msg::Contact();
                msg.first_name   = "AX";
                msg.last_name    = "BY";
                msg.phone_number = "1234567890";
                msg.phone_type   = msg.PHONE_TYPE_MOBILE;
                RCLCPP_INFO(this->get_logger(), "Publishing: %s %s", msg.first_name.c_str(), msg.last_name.c_str());
                this->contact_publisher_->publish(msg);
            };
            timer_ = this->create_wall_timer(1s, publish_msg);
        }
};


int main(int argc, char* argv[]) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<ContactPublisher>());
    rclcpp::shutdown();
    return 0;
}