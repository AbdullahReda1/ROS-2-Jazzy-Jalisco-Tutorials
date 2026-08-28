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
                auto msg = std::make_shared<more_interfaces::msg::AddressBook>();
                {
                    auto contact = more_interfaces::msg::Contact();
                    contact.first_name   = "AX";
                    contact.last_name    = "BY";
                    contact.phone_number = "1234567890";
                    contact.phone_type   = contact.PHONE_TYPE_MOBILE;
                    msg->address_book.push_back(contact);
                }
                {
                    auto contact = more_interfaces::msg::Contact();
                    contact.first_name   = "CX";
                    contact.last_name    = "DY";
                    contact.phone_number = "1234567891";
                    contact.phone_type   = contact.PHONE_TYPE_HOME;
                    msg->address_book.push_back(contact);
                }
                {
                    auto contact = more_interfaces::msg::Contact();
                    contact.first_name   = "EX";
                    contact.last_name    = "FY";
                    contact.phone_number = "1234567892";
                    contact.phone_type   = contact.PHONE_TYPE_WORK;
                    msg->address_book.push_back(contact);
                }
                for (auto & contact : msg->address_book)
                    RCLCPP_INFO(this->get_logger(), "Publishing: %s %s", contact.first_name.c_str(), contact.last_name.c_str());
                this->address_book_publisher_->publish(*msg);
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