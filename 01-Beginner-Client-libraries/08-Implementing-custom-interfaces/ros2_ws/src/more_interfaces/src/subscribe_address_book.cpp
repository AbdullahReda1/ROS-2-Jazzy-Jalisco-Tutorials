#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/address_book.hpp"


class AddressBookSubscriber : public rclcpp::Node {
    private:
        rclcpp::Subscription<more_interfaces::msg::AddressBook>::SharedPtr address_book_subscription_;
    public:
        AddressBookSubscriber() : Node("address_book_subscriber") {
            address_book_subscription_ = this->create_subscription<more_interfaces::msg::AddressBook>("address_book", 10, 
            [this] (const more_interfaces::msg::AddressBook::SharedPtr msg) -> void {
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
    rclcpp::spin(std::make_shared<AddressBookSubscriber>());
    rclcpp::shutdown();
    return 0;
}