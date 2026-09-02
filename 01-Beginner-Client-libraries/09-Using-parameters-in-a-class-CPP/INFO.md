
# Using Parameters in a Class (C++) — Deep Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. New Parameter Functions and Their Returns

### `declare_parameter`

```cpp
this->declare_parameter("my_parameter", "world");
```

Registers a parameter on the node with a name and default value. The type is inferred from the default — here `"world"` is a string literal so the parameter type becomes `string`. Returns an `rclcpp::Parameter` object but is almost never captured since you just want the side effect of registration.

```cpp
this->declare_parameter("my_parameter", "world", param_desc);
```

Same but adds a `ParameterDescriptor` for metadata (description, read-only flag, range constraints). Same return type.

### `get_parameter`

```cpp
this->get_parameter("my_parameter")
```

Returns an `rclcpp::Parameter` object holding the current value of the named parameter. From that object you call a type-specific extractor:

| Method                 | Returns                      |
| ---------------------- | ---------------------------- |
| `.as_string()`         | `std::string`                |
| `.as_int()`            | `int64_t`                    |
| `.as_double()`         | `double`                     |
| `.as_bool()`           | `bool`                       |
| `.as_string_array()`   | `std::vector<std::string>`   |

### `set_parameters`

```cpp
std::vector<rclcpp::Parameter> all_new_parameters{
    rclcpp::Parameter("my_parameter", "world")};
this->set_parameters(all_new_parameters);
```

Takes a `std::vector<rclcpp::Parameter>` and sets all of them. Returns `std::vector<rcl_interfaces::msg::SetParametersResult>` — one result per parameter, each holding a `bool successful` and a `std::string reason` if it failed. In the tutorial the return is ignored because the value is always valid.

### `rclcpp::Parameter`

```cpp
rclcpp::Parameter("my_parameter", "world")
```

A constructor that packages a name and value together into a parameter object. Used when passing parameters to `set_parameters`. The type is inferred from the value argument.

---

## 2. The Launch File

```python
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package="cpp_parameters",
            executable="minimal_param_node",
            name="custom_minimal_param_node",
            output="screen",
            emulate_tty=True,
            parameters=[
                {"my_parameter": "earth"}
            ]
        )
    ])
```

### Structure

`generate_launch_description()` is the mandatory entry point function — `ros2 launch` calls this function and expects a `LaunchDescription` object back. Without this exact function name, the launch system cannot find the entry point.

`LaunchDescription([...])` takes a list of **actions** — things to do when the launch file runs. The most common action is `Node`.

### The `Node` Action Arguments

| Argument                                   | Meaning                                                                                                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `package`                                  | The ROS 2 package containing the executable                                                                                                             |
| `executable`                               | The name registered in`install(TARGETS ... DESTINATION lib/${PROJECT_NAME})`                                                                            |
| `name`                                     | Overrides the node name declared in code — here renames it to`custom_minimal_param_node`                                                                |
| `output="screen"`                          | Prints the node's stdout/stderr to the terminal running the launch file instead of only to log files                                                    |
| `emulate_tty=True`                         | Forces color-coded log output (`[INFO]`, `[WARN]`) to appear even though the output is being redirected                                                 |
| `parameters=[{"my_parameter": "earth"}]`   | A list of dicts — each key-value pair sets a parameter before the node starts. This is what overrides the default`"world"` to `"earth"` at startup      |

### Why the First Output is `earth` But Then Switches to `world`

The launch file sets `my_parameter` to `"earth"` before the node starts. The first `timer_callback` fires, reads `"earth"`, logs `Hello earth!`, then immediately calls `set_parameters` to reset it back to `"world"`. Every callback after that reads `"world"` and resets it to `"world"` again. The tutorial's `set_parameters` call inside the callback is specifically designed to demonstrate parameter resetting.

### CMakeLists.txt Addition for Launch

```cmake
install(
  DIRECTORY launch
  DESTINATION share/${PROJECT_NAME}
)
```

`ros2 launch` looks for launch files under `share/<package>/launch/`. This installs the entire `launch/` directory there so `ros2 launch cpp_parameters cpp_parameters_launch.py` can find the file.

---

## 3. `{}` vs `()` — Brace vs Parenthesis Initialization

```cpp
auto param_desc = rcl_interfaces::msg::ParameterDescriptor{};
```

Both `{}` and `()` create an object, but they follow different rules.

`()` is the **traditional constructor call** syntax — it calls the constructor with the arguments inside. `ClassName()` calls the default constructor. `ClassName(a, b)` calls a constructor taking two arguments.

`{}` is **uniform initialization** introduced in C++11. It also calls the constructor but with two important differences:

**Difference 1 — Prevents narrowing conversions:**

```cpp
int x(3.7);   // compiles — silently truncates to 3
int x{3.7};   // compile ERROR — narrowing double→int is forbidden
```

`{}` is safer because accidental type truncation becomes a compile error instead of silent data loss.

**Difference 2 — Aggregate and value initialization:**
For structs with no user-defined constructor (like most ROS 2 message types), `{}` performs **value initialization** — all members are zero-initialized before any constructor runs. `()` on a struct with no constructor also value-initializes, so for simple structs they behave identically.

```cpp
// These are equivalent for a plain struct like ParameterDescriptor:
auto param_desc = rcl_interfaces::msg::ParameterDescriptor{};
auto param_desc = rcl_interfaces::msg::ParameterDescriptor();
```

The `{}` style is preferred in modern C++ because it is consistent (works for primitives, arrays, structs, and class objects alike) and safe (no narrowing). You will see both in ROS 2 code — `{}` in newer code, `()` in older code. Both are correct.

---

## 4. All Commands — One Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Using Parameters in a Class (C++)
# ─────────────────────────────────────────────────────────────────────────────

source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws/src

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
ros2 pkg create --build-type ament_cmake --license Apache-2.0 cpp_parameters \
  --dependencies rclcpp

# ─── CREATE THE NODE ─────────────────────────────────────────────────────────
cat > ~/ros2_ws/src/cpp_parameters/src/cpp_parameters_node.cpp << 'EOF'
#include <chrono>
#include <functional>
#include <string>

#include <rclcpp/rclcpp.hpp>

using namespace std::chrono_literals;

class MinimalParam : public rclcpp::Node
{
public:
  MinimalParam()
  : Node("minimal_param_node")
  {
    this->declare_parameter("my_parameter", "world");

    auto timer_callback = [this](){
      std::string my_param = this->get_parameter("my_parameter").as_string();
      RCLCPP_INFO(this->get_logger(), "Hello %s!", my_param.c_str());

      std::vector<rclcpp::Parameter> all_new_parameters{
          rclcpp::Parameter("my_parameter", "world")};
      this->set_parameters(all_new_parameters);
    };
    timer_ = this->create_wall_timer(1000ms, timer_callback);
  }

private:
  rclcpp::TimerBase::SharedPtr timer_;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<MinimalParam>());
  rclcpp::shutdown();
  return 0;
}
EOF

# ─── CREATE THE LAUNCH FILE ───────────────────────────────────────────────────
mkdir -p ~/ros2_ws/src/cpp_parameters/launch
cat > ~/ros2_ws/src/cpp_parameters/launch/cpp_parameters_launch.py << 'EOF'
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package="cpp_parameters",
            executable="minimal_param_node",
            name="custom_minimal_param_node",
            output="screen",
            emulate_tty=True,
            parameters=[
                {"my_parameter": "earth"}
            ]
        )
    ])
EOF

# ─── UPDATE CMakeLists.txt ────────────────────────────────────────────────────
# Add after find_package(rclcpp REQUIRED):
# add_executable(minimal_param_node src/cpp_parameters_node.cpp)
# ament_target_dependencies(minimal_param_node rclcpp)
# install(TARGETS minimal_param_node DESTINATION lib/${PROJECT_NAME})
# install(DIRECTORY launch DESTINATION share/${PROJECT_NAME})

# ─── BUILD ───────────────────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y
colcon build --packages-select cpp_parameters

# ─── SOURCE AND RUN ──────────────────────────────────────────────────────────
source install/setup.bash

# Run directly:
ros2 run cpp_parameters minimal_param_node
# Output every second: [INFO] [minimal_param_node]: Hello world!

# ─── CHANGE PARAMETER VIA CONSOLE (Terminal 2) ───────────────────────────────
ros2 param list
ros2 param set /minimal_param_node my_parameter earth
# Output: Set parameter successful
# Node terminal briefly shows: Hello earth! then resets to Hello world!

# ─── DESCRIBE PARAMETER (optional descriptor) ────────────────────────────────
ros2 param describe /minimal_param_node my_parameter

# ─── RUN VIA LAUNCH FILE ─────────────────────────────────────────────────────
ros2 launch cpp_parameters cpp_parameters_launch.py
# First output: [INFO] [custom_minimal_param_node]: Hello earth!
# Subsequent:   [INFO] [minimal_param_node]: Hello world!
```
