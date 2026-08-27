#include <chrono>
#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/address_book.hpp"

using namespace std::chrono_literals;


class AddressBookPublisher : public rclcpp::Node {
    private:
        rclcpp::Publisher<more_interfaces::msg::AddressBook>::SharedPtr address_book_publisher_;
        rclcpp::TimerBase::SharedPtr timer_;
    public:
        AddressBookPublisher() : Node("address_book_publisher") {
            address_book_publisher_ = this->create_publisher<more_interfaces::msg::AddressBook>("address_book", 10);
            auto publish_msg = [this] () -> void {
                auto msg = more_interfaces::msg::AddressBook();
                msg.first_name   = "AX";
                msg.last_name    = "BY";
                msg.phone_number = "1234567890";
                msg.phone_type   = msg.PHONE_TYPE_MOBILE;
                RCLCPP_INFO(this->get_logger(), "Publishing: %s %s", msg.first_name.c_str(), msg.last_name.c_str());
                this->address_book_publisher_->publish(msg);
            };
            timer_ = this->create_wall_timer(1s, publish_msg);
        }
};


int main(int argc, char* argv[]) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<AddressBookPublisher>());
    rclcpp::shutdown();
    return 0;
}