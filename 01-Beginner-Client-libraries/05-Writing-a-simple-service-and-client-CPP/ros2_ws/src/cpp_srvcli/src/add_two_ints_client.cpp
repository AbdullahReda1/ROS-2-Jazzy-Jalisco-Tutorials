#include <rclcpp/rclcpp.hpp>
#include <example_interfaces/srv/add_two_ints.hpp>

#include <memory>
#include <chrono>
#include <cstdlib>

using namespace std::chrono_literals;


int main(int argc, char **argv) {
    rclcpp::init(argc, argv);
    if (argc != 3) {
        RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "Use 2 input cmd parameters for adding X Y");
        return 1;
    }
    std::shared_ptr<rclcpp::Node> node = rclcpp::Node::make_shared("add_two_ints_client");
    rclcpp::Client<example_interfaces::srv::AddTwoInts>::SharedPtr cleint = node->create_client<example_interfaces::srv::AddTwoInts>("add_two_ints");
    auto request = std::make_shared<example_interfaces::srv::AddTwoInts::Request>();
    request->a = atoll(argv[1]);
    request->b = atoll(argv[2]);
    while (!cleint->wait_for_service(1s)) {
        if (!rclcpp::ok()) {
            RCLCPP_ERROR(rclcpp::get_logger("rclcpp"), "The client was interrupted while waiting the service. Exit");
            return 0;
        }
        RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "The cleint will wait again for service");
    }
    auto result = cleint->async_send_request(request);
    if (rclcpp::spin_until_future_complete(node, result) == rclcpp::FutureReturnCode::SUCCESS)
        RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "sum: %ld", result.get()->sum);
    else
        RCLCPP_ERROR(rclcpp::get_logger("rclcpp"), "Failed to call service");
    rclcpp::shutdown();
    return 0;
}