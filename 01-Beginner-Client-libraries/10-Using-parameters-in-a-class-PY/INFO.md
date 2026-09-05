
# Using Parameters in a Class (Python) — Deep Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. New Parameter Functions and Their Returns

### `declare_parameter`

```python
self.declare_parameter('my_parameter', 'world')
```

Same concept as C++. Registers the parameter on the node, type inferred from the default value. Returns an `rclpy.parameter.Parameter` object, almost never captured.

```python
self.declare_parameter('my_parameter', 'world', my_parameter_descriptor)
```

With descriptor for metadata. Same return.

### `get_parameter` → `get_parameter_value()` → `.string_value`

```python
self.get_parameter('my_parameter').get_parameter_value().string_value
```

Three chained steps:

| Call                                   | Returns                                              |
| -------------------------------------- | ---------------------------------------------------- |
| `self.get_parameter('my_parameter')`   | `rclpy.parameter.Parameter` object                   |
| `.get_parameter_value()`               | `rcl_interfaces.msg.ParameterValue` message object   |
| `.string_value`                        | `str` — the actual Python string                     |

Other value attributes on `ParameterValue`:

| Attribute               | Python type   |
| ----------------------- | ------------- |
| `.string_value`         | `str`         |
| `.integer_value`        | `int`         |
| `.double_value`         | `float`       |
| `.bool_value`           | `bool`        |
| `.string_array_value`   | `list[str]`   |

### `rclpy.parameter.Parameter`

```python
rclpy.parameter.Parameter(
    'my_parameter',
    rclpy.Parameter.Type.STRING,
    'world'
)
```

Constructs a parameter object. Unlike C++ where the type is inferred, Python requires the type to be stated explicitly via the `rclpy.Parameter.Type` enum. Common enum values:

| Enum                             | Meaning |
| -------------------------------- | ------- |
| `rclpy.Parameter.Type.STRING`    | string  |
| `rclpy.Parameter.Type.INTEGER`   | int     |
| `rclpy.Parameter.Type.DOUBLE`    | float   |
| `rclpy.Parameter.Type.BOOL`      | bool    |

### `set_parameters`

```python
self.set_parameters([my_new_param])
```

Takes a list of `rclpy.parameter.Parameter` objects. Returns a list of `rcl_interfaces.msg.SetParametersResult`, each with a `bool successful` field. Identical concept to C++.

### `ParameterDescriptor` (optional)

```python
from rcl_interfaces.msg import ParameterDescriptor
my_parameter_descriptor = ParameterDescriptor(description='This parameter is mine!')
```

A message object from `rcl_interfaces`. Created with keyword arguments matching its fields. Passed as the third argument to `declare_parameter`.

---

## 2. Why `.string_value` Has No Parentheses

```python
self.get_parameter('my_parameter').get_parameter_value().string_value
```

`get_parameter_value()` has parentheses — it is a **method** (a function you call). `string_value` has no parentheses — it is an **attribute** (a data field you read).

`get_parameter_value()` returns a `ParameterValue` message object. A message object in ROS 2 is essentially a struct with fields. `string_value` is one of those fields — you access it the same way you access any struct field: `obj.field_name`, with no call syntax.

If you accidentally wrote `string_value()` Python would try to call the string itself as a function and raise:

```text
TypeError: 'str' object is not callable
```

The rule is simple: if the thing you are accessing IS a function → use `()`. If it IS a data field → no `()`. `get_parameter_value` is a function that does work and returns something. `string_value` is the thing it returned, sitting there as a value.

This is the same reason you write `msg.data` not `msg.data()` when reading a topic message field.

---

## 3. What `(os.path.join('share', package_name, 'launch'), glob('launch/*'))` Means

This is one entry in the `data_files` list inside `setup.py`. `data_files` tells setuptools which non-Python files to install and where to put them.

Each entry is a **tuple** of two things:

```python
(destination_directory, list_of_source_files)
```

Breaking down the specific line:

```python
(os.path.join('share', package_name, 'launch'),   glob('launch/*'))
#  ──────────────────────────────────────────────   ──────────────
#  WHERE to install                                 WHAT to install
```

`os.path.join('share', package_name, 'launch')` builds the install path string `share/python_parameters/launch/` — the location where `ros2 launch` will look for launch files.

`glob('launch/*')` returns a Python list of every file found in the `launch/` directory of your package source at build time — e.g., `['launch/python_parameters_launch.py']`. `glob` is a standard library function that expands filesystem wildcard patterns.

So the full line says: **"take all files in my source `launch/` folder and install them to `share/python_parameters/launch/` in the install space."**

This is the Python package equivalent of the CMakeLists.txt line in C++ packages:

```cmake
install(DIRECTORY launch DESTINATION share/${PROJECT_NAME})
```

Python packages cannot use CMake, so any non-Python file installation must be declared in `setup.py` via `data_files`.

---

## 4. Python vs C++ Parameters — Key Differences

| Aspect               | C++                                                 | Python                                                 |
| -------------------- | --------------------------------------------------- | ------------------------------------------------------ |
| Get value            | `.as_string()` directly on Parameter                | `.get_parameter_value().string_value` — two steps      |
| Explicit type in set | No — inferred from value                            | Yes —`rclpy.Parameter.Type.STRING` required            |
| Install launch files | `install(DIRECTORY launch ...)` in CMakeLists.txt   | `data_files` entry with `glob` in setup.py             |
| Descriptor import    | `rcl_interfaces::msg::ParameterDescriptor`          | `from rcl_interfaces.msg import ParameterDescriptor`   |

---

## 5. All Commands — One Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Using Parameters in a Class (Python)
# ─────────────────────────────────────────────────────────────────────────────

source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws/src

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
ros2 pkg create --build-type ament_python --license Apache-2.0 python_parameters \
  --dependencies rclpy

# ─── CREATE THE NODE ─────────────────────────────────────────────────────────
cat > ~/ros2_ws/src/python_parameters/python_parameters/python_parameters_node.py << 'EOF'
import rclpy
from rclpy.node import Node


class MinimalParam(Node):

    def __init__(self):
        super().__init__('minimal_param_node')
        self.declare_parameter('my_parameter', 'world')
        self.timer = self.create_timer(1, self.timer_callback)

    def timer_callback(self):
        my_param = self.get_parameter('my_parameter').get_parameter_value().string_value
        self.get_logger().info('Hello %s!' % my_param)

        my_new_param = rclpy.parameter.Parameter(
            'my_parameter',
            rclpy.Parameter.Type.STRING,
            'world'
        )
        self.set_parameters([my_new_param])


def main():
    rclpy.init()
    node = MinimalParam()
    rclpy.spin(node)


if __name__ == '__main__':
    main()
EOF

# ─── CREATE THE LAUNCH FILE ───────────────────────────────────────────────────
mkdir -p ~/ros2_ws/src/python_parameters/launch
cat > ~/ros2_ws/src/python_parameters/launch/python_parameters_launch.py << 'EOF'
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package='python_parameters',
            executable='minimal_param_node',
            name='custom_minimal_param_node',
            output='screen',
            emulate_tty=True,
            parameters=[
                {'my_parameter': 'earth'}
            ]
        )
    ])
EOF

# ─── UPDATE setup.py ──────────────────────────────────────────────────────────
# Add at top of setup.py:
#   import os
#   from glob import glob
#
# Add to data_files list:
#   (os.path.join('share', package_name, 'launch'), glob('launch/*')),
#
# Add entry point:
#   'minimal_param_node = python_parameters.python_parameters_node:main',

# ─── BUILD ───────────────────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y
colcon build --packages-select python_parameters

# ─── SOURCE AND RUN ──────────────────────────────────────────────────────────
source install/setup.bash

# Run directly:
ros2 run python_parameters minimal_param_node
# Output every second: [INFO] [minimal_param_node]: Hello world!

# ─── CHANGE PARAMETER VIA CONSOLE (Terminal 2) ───────────────────────────────
ros2 param list
ros2 param set /minimal_param_node my_parameter earth
# Output: Set parameter successful
# Node briefly shows: Hello earth! then resets to Hello world!

# ─── DESCRIBE PARAMETER ──────────────────────────────────────────────────────
ros2 param describe /minimal_param_node my_parameter

# ─── RUN VIA LAUNCH FILE ─────────────────────────────────────────────────────
ros2 launch python_parameters python_parameters_launch.py
# First output: [INFO] [custom_minimal_param_node]: Hello earth!
# Subsequent:   [INFO] [minimal_param_node]: Hello world!
```
