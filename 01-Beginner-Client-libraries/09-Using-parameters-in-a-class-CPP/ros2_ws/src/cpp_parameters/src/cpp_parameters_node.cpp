#include <chrono>
#include <functional>
#include <string>

#include "rclcpp/rclcpp.hpp"

using namespace std::chrono_literals;


class MinimalParam : public rclcpp::Node {
    private:
        rclcpp::TimerBase::SharedPtr timer_;
    public:
        MinimalParam() : Node("minimal_param_node") {
            auto param_desc = rcl_interfaces::msg::ParameterDescriptor{};
            param_desc.description = "This parameter is mine!";
            
            this->declare_parameter("my_parameter", "world", param_desc);

            auto timer_callback = [this] () -> void {
                std::string my_param = this->get_parameter("my_parameter").as_string();

                RCLCPP_INFO(this->get_logger(), "Hello %s!", my_param.c_str());
                std::vector<rclcpp::Parameter> all_new_parameters{rclcpp::Parameter("my_parameter", "world")};

                this->set_parameters(all_new_parameters);
            };
            timer_ = this->create_wall_timer(1000ms, timer_callback);
        }
};


int main(int argc, char ** argv) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<MinimalParam>());
    rclcpp::shutdown();
    return 0;
}