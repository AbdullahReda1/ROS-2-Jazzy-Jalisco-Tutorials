#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/contact.hpp"


class ContactSubscriber : public rclcpp::Node {
    private:
        rclcpp::Subscription<more_interfaces::msg::Contact>::SharedPtr contact_subscription_;
    public:
        ContactSubscriber() : Node("contact_subscriber") {
            contact_subscription_ = this->create_subscription<more_interfaces::msg::Contact>("contact", 10, 
            [this] (const more_interfaces::msg::Contact::SharedPtr msg) -> void {
                RCLCPP_INFO(this->get_logger(),
                    "Received: %s %s | phone: %s | type: %d",
                    msg->first_name.c_str(),
                    msg->last_name.c_str(),
                    msg->phone_number.c_str(),
                    msg->phone_type);
            });
        }
};


int main(int argc, char* argv[]) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<ContactSubscriber>());
    rclcpp::shutdown();
    return 0;
}