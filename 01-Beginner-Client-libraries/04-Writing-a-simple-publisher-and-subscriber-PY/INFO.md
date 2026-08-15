
# Writing a Simple Publisher and Subscriber (Python) — Study Note

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. `<depend>` in C++ vs `<exec_depend>` in Python — Why the Tags Differ

The difference is not about which library you import. It is about **when** that library is needed during the package lifecycle.

### The Four Dependency Tag Types

| Tag                       | Needed at build time | Needed at run time | Needed when others build against you |
| ------------------------- | -------------------- | ------------------ | ------------------------------------ |
| `<build_depend>`          | Yes                  | No                 | No                                   |
| `<exec_depend>`           | No                   | Yes                | No                                   |
| `<depend>`                | Yes                  | Yes                | No                                   |
| `<build_export_depend>`   | No                   | No                 | Yes                                  |

### Why C++ Uses `<depend>rclcpp</depend>`

When colcon builds a C++ package, it invokes `g++`. The compiler physically reads header files from disk to process your `#include "rclcpp/rclcpp.hpp"` statement. Those headers live at `/opt/ros/jazzy/include/rclcpp/`. If they are not present, compilation fails immediately with "file not found."

After the binary is compiled, it links against `librclcpp.so`. When you later run the binary, the dynamic linker loads that shared library at startup. If it is missing, the program crashes before `main()` even begins.

So rclcpp is needed at **both** build time and run time. The `<depend>` tag is a shorthand that expands to both `<build_depend>` and `<exec_depend>` combined. Writing `<depend>rclcpp</depend>` is exactly equivalent to writing both of these:

```xml
<build_depend>rclcpp</build_depend>
<exec_depend>rclcpp</exec_depend>
```

### Why Python Uses `<exec_depend>rclpy</exec_depend>`

When colcon builds a Python package, there is **no compilation step**. colcon does not invoke the Python interpreter on your source files. It runs setuptools to register entry points and install data files, but your `.py` source files are not processed or compiled at this stage. No rclpy headers or libraries are read during `colcon build`.

rclpy is needed only at **run time**, when the Python interpreter actually executes `import rclpy`. This is a pure runtime dependency, so `<exec_depend>` is the correct and precise tag. Using the heavier `<depend>` would be technically wrong — it would declare a build-time dependency that does not exist, misleading tooling like rosdep and bloom.

The same reasoning applies to `std_msgs`: C++ needs `std_msgs` headers at compile time (`#include "std_msgs/msg/string.hpp"`), so it uses `<depend>`. Python only needs `std_msgs` at runtime (`from std_msgs.msg import String`), so it uses `<exec_depend>`.

---

## 2. `entry_points` in `setup.py` — Role, C++ Equivalent, and Syntax

### What entry_points Does

When you run `colcon build`, setuptools processes `setup.py` and reads the `entry_points` dictionary. For every entry under `'console_scripts'`, it generates a small executable wrapper script and installs it to a known location. That wrapper, when run, imports the named Python module and calls the named function.

For the entry `'talker = py_pubsub.publisher_member_function:main'`, the generated wrapper at `install/py_pubsub/lib/py_pubsub/talker` effectively does:

```python
#!/usr/bin/env python3
import sys
from py_pubsub.publisher_member_function import main
sys.exit(main())
```

When you type `ros2 run py_pubsub talker`, `ros2 run` reads `AMENT_PREFIX_PATH`, finds `install/py_pubsub/lib/py_pubsub/` in the list, locates the `talker` script there, and executes it.

### What It Matches in a C++ Package

The entry_points registration in Python exactly mirrors two lines in the C++ `CMakeLists.txt`:

```cmake
add_executable(talker src/publisher_lambda_function.cpp)
install(TARGETS talker DESTINATION lib/${PROJECT_NAME})
```

| Python (`setup.py`)                                        | C++ (`CMakeLists.txt`)                                     |
| -----------------------------------------------------------| ---------------------------------------------------------- |
| `'talker = py_pubsub.publisher_member_function:main'`      | `add_executable(talker src/publisher_lambda_function.cpp)` |
| (entry in`console_scripts` installs to `lib/py_pubsub/`)   | `install(TARGETS talker DESTINATION lib/${PROJECT_NAME})`  |

Both result in a file named `talker` at `install/<package_name>/lib/<package_name>/talker`. `ros2 run` finds both in exactly the same way — it just uses `AMENT_PREFIX_PATH` to locate the right `lib/<pkg>/` directory, and the file there is either a compiled ELF binary (C++) or a Python wrapper script (Python).

### Why the Entry Syntax Looks the Way It Does

```python
entry_points={
    'console_scripts': [
        'talker = py_pubsub.publisher_member_function:main',
        'listener = py_pubsub.subscriber_member_function:main',
    ],
},
```

The overall structure is a Python dictionary where the key `'console_scripts'` is a setuptools convention — it means "these entries become runnable shell commands." The value is a list of strings, each following the format:

```text
'<command_name> = <python.module.dotted.path>:<function_name>'
```

Breaking down `'talker = py_pubsub.publisher_member_function:main'`:

- `talker` is the name of the shell command and the name `ros2 run` uses as the executable argument
- `py_pubsub` is the inner Python package directory (the one containing `__init__.py`)
- `publisher_member_function` is the filename without `.py`
- `main` is the function name inside that file to call

The `=` separates the command name from the module reference. The `:` separates the module path from the function name. Spaces around `=` are optional but conventional.

---

## 3. `setup.cfg` — What It Is, How It Differs from `setup.py`, and What Its Content Means

### What `setup.cfg` Is

`setup.cfg` is a static INI-format configuration file that provides default values for setuptools commands. It is read by setuptools before running any command, and the values inside it override setuptools' built-in defaults without requiring Python code.

The file uses the standard INI format: sections in `[brackets]`, followed by `key=value` pairs on each line.

```ini
[develop]
script_dir=$base/lib/py_pubsub
[install]
install_scripts=$base/lib/py_pubsub
```

### How It Differs from `setup.py`

`setup.py` is **Python code** that calls the `setup()` function with your package's metadata (name, version, description, license, entry_points, data_files, etc.). It is flexible and programmable.

`setup.cfg` is **not code** — it is a static configuration file that modifies the behavior of the commands that `setup.py` triggers. It answers the question: "when setuptools runs, where should it put things?"

They work together: `setup.py` defines what the package is, and `setup.cfg` defines where the generated artifacts go when commands run.

### What the Content Means

`[develop]` configures the `python setup.py develop` command, which is what colcon uses internally when you pass `--symlink-install`. In this mode, entry point scripts are installed as symlinks or stubs pointing back to your source.

`script_dir=$base/lib/py_pubsub` tells setuptools to place the entry point scripts under `lib/py_pubsub/` relative to `$base`, which is the install prefix for this package (resolved at build time to something like `install/py_pubsub`). The full path becomes `install/py_pubsub/lib/py_pubsub/`.

`[install]` configures the `python setup.py install` command, which is what colcon uses during a regular build (without `--symlink-install`).

`install_scripts=$base/lib/py_pubsub` tells setuptools to copy the generated entry point scripts to `install/py_pubsub/lib/py_pubsub/`.

### Why This Path Matters

By default, setuptools installs scripts to a `bin/` directory (e.g., `install/py_pubsub/bin/talker`). But `ros2 run` does not look in `bin/`. It looks in `lib/<package_name>/` within each prefix in `AMENT_PREFIX_PATH`. Without `setup.cfg` redirecting scripts to the right location, `ros2 run py_pubsub talker` would fail with "executable not found," even though the script physically exists on disk.

`setup.cfg` bridges the gap between Python packaging conventions (`bin/`) and ROS 2 conventions (`lib/<pkg>/`).

---

## 4. Why `__init__.py` Is Auto-Generated and Empty

### What `__init__.py` Does

`__init__.py` is the file that tells Python's import system that a directory is a **Python package** (an importable module namespace). Without it, `import py_pubsub` and `from py_pubsub.publisher_member_function import main` both raise `ModuleNotFoundError`.

When the Python interpreter processes `from py_pubsub.publisher_member_function import main`, it:

1. Looks for a `py_pubsub` directory containing `__init__.py` on the Python path
2. Enters that directory and looks for `publisher_member_function.py`
3. Imports `main` from that file

If step 1 fails (no `__init__.py`), the import chain breaks immediately regardless of whether `publisher_member_function.py` exists.

### Why It Is Empty

The file is empty because the package requires no initialization code when imported. There is no shared state to set up, no version variable to define, no sub-modules to import automatically. The file exists purely as a marker.

You could add code to `__init__.py` if needed — for example, `from py_pubsub.publisher_member_function import MinimalPublisher` would make `MinimalPublisher` importable directly as `from py_pubsub import MinimalPublisher`. But for a simple pub/sub package, nothing in `__init__.py` is needed.

`ros2 pkg create --build-type ament_python` generates this file automatically because an ament_python package's inner directory is **always** a Python package by design. Without `__init__.py`, the package structure would be broken from the start.

---

## 5. `def main(args=None)` and `rclpy.init(args=args)` — Why `None` and What It Flows Into

### Why the Default Value Is `None`

```python
def main(args=None):
    rclpy.init(args=args)
```

`args=None` makes `args` an **optional parameter** with a default value of `None`. This means the function can be called in three ways:

```python
main()                              # args is None — normal execution
main(args=sys.argv)                 # explicitly pass command-line args
main(args=['--ros-args', '--remap', 'topic:=my_topic'])  # pass args programmatically
```

Why `None` and not `sys.argv` directly as the default? Python evaluates default argument values **once at function definition time**, not each time the function is called. If you wrote `def main(args=sys.argv)`, `sys.argv` would be captured the instant the module was first imported — before any command-line arguments might be in place, and the same frozen list would be used on every call. `None` is the idiomatic Python pattern for "I have no specific value, determine it at runtime."

### What `rclpy.init(args=args)` Does With It

Inside `rclpy.init()`, when `args=None`, rclpy internally reads `sys.argv` at that moment to get command-line arguments. It specifically looks for `--ros-args` and everything that follows it, which is how you pass ROS-specific parameters like node remapping, parameter overrides, and log levels from the command line.

When `args` is explicitly provided (not `None`), rclpy uses that list instead of `sys.argv`. This is essential for testing: a test can call `main(args=['--ros-args', '--remap', 'topic:=test_topic'])` to redirect the node to a test topic without needing actual command-line arguments.

The full flow:

```python
def main(args=None):          # 1. Declared optional; default is None
    rclpy.init(args=args)     # 2. Pass None → rclpy reads sys.argv internally
                              #    Pass a list → rclpy uses that list directly
    minimal_publisher = MinimalPublisher()
    rclpy.spin(minimal_publisher)
    minimal_publisher.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()                    # 3. Called with no arguments → args=None → normal path
```

---

## 6. The Lone `self.subscription` Line and the Format String Difference

### `self.subscription  # prevent unused variable warning`

This line is a **no-op expression statement**. In Python, writing a variable name as a statement by itself is perfectly valid syntax. It evaluates the expression (reads the variable) and discards the result. It does not call a function, it does not modify any state, it does not send any message.

It is **not a function call** — there are no parentheses. Compare:

```python
self.subscription       # expression statement: evaluates and discards — no side effects
self.subscription()     # function call: would try to call the object as a function
```

Why is it there? The `self.subscription` member is assigned in `create_subscription()` and then never read again in the class body. The subscription works by **callback** — rclpy calls `listener_callback` automatically whenever a message arrives. `self.subscription` just needs to exist as a member to keep the subscription object alive; if it went out of scope, rclpy would clean it up and stop receiving messages.

Because the variable is assigned but never accessed again, tools like pylint and static analysis pass produce a warning: "self.subscription is assigned but its value is never used." The bare expression `self.subscription` on its own line silences that warning by "using" the variable, with the comment explaining the intent.

Compare to the publisher: `self.publisher_` IS used — `timer_callback` calls `self.publisher_.publish(msg)` every 0.5 seconds. So the publisher needs no such workaround.

### `'Hello World: %d' % self.i` vs `'Publishing: "%s"' % msg.data`

Both use Python's old-style `%` string formatting operator. The format string on the left contains `%d` or `%s` as placeholders, and the value on the right is substituted in.

**`'Hello World: %d' % self.i`**

- `%d` is the **integer decimal** format specifier
- `self.i` is an `int` (a counter that increments each callback)
- Result for `self.i = 3`: `'Hello World: 3'`
- No quotation marks in the output — just the number

**`'Publishing: "%s"' % msg.data`**

- `%s` is the **string** format specifier
- `msg.data` is a `str` (already the string `'Hello World: 3'`)
- The `"` characters around `%s` are **literal characters inside the format string**, not Python string delimiters
- Result for `msg.data = 'Hello World: 3'`: `'Publishing: "Hello World: 3"'`
- The output contains literal double-quote characters around the value

The outer `'` (single quotes) are Python's string delimiters for the format string. The inner `"` (double quotes) are content characters that appear literally in the output. Python allows mixing both quote styles within a string because one is the delimiter and the other is ordinary content.

You can verify this with the actual log output:

```text
[INFO] [minimal_publisher]: Publishing: "Hello World: 3"
```

The `"` around `Hello World: 3` come directly from the `"` characters in the format string. They are a visual convention — they make it immediately clear in the log where the message data begins and ends, which is helpful when messages might contain spaces or special characters.

Why `%d` vs `%s`? Use the specifier that matches the type. `self.i` is an `int`, so `%d` is correct and efficient. `msg.data` is already a `str`, so `%s` is used. Using `%s` for an integer would also work (it calls `str()` implicitly), but `%d` is more explicit and raises a `TypeError` if you accidentally pass a non-integer, which is a useful safety check.

---

## 7. Full Commands — One Code Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Writing a Simple Publisher and Subscriber (Python)
# ─────────────────────────────────────────────────────────────────────────────

# ─── SOURCE UNDERLAY ─────────────────────────────────────────────────────────
source /opt/ros/jazzy/setup.bash

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
cd ~/ros2_ws/src
ros2 pkg create --build-type ament_python --license Apache-2.0 py_pubsub

# ─── DOWNLOAD SOURCE FILES ───────────────────────────────────────────────────
cd ~/ros2_ws/src/py_pubsub/py_pubsub

wget https://raw.githubusercontent.com/ros2/examples/jazzy/rclpy/topics/minimal_publisher/examples_rclpy_minimal_publisher/publisher_member_function.py

wget https://raw.githubusercontent.com/ros2/examples/jazzy/rclpy/topics/minimal_subscriber/examples_rclpy_minimal_subscriber/subscriber_member_function.py

# Verify both files exist alongside __init__.py:
ls
# Expected: __init__.py  publisher_member_function.py  subscriber_member_function.py

# ─── EDIT package.xml ────────────────────────────────────────────────────────
# Navigate to the package root:
cd ~/ros2_ws/src/py_pubsub

# Add these two lines to package.xml after the <license> tag:
#   <exec_depend>rclpy</exec_depend>
#   <exec_depend>std_msgs</exec_depend>
# (Do this manually in your editor.)

# ─── EDIT setup.py ───────────────────────────────────────────────────────────
# Fill in maintainer, maintainer_email, description, license to match package.xml.
# Set entry_points to register both executables:
cat > setup.py << 'EOF'
from setuptools import find_packages, setup

package_name = 'py_pubsub'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Your Name',
    maintainer_email='you@email.com',
    description='Examples of minimal publisher/subscriber using rclpy',
    license='Apache-2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'talker = py_pubsub.publisher_member_function:main',
            'listener = py_pubsub.subscriber_member_function:main',
        ],
    },
)
EOF

# ─── VERIFY setup.cfg (auto-generated, should already be correct) ────────────
cat setup.cfg
# Expected contents:
# [develop]
# script_dir=$base/lib/py_pubsub
# [install]
# install_scripts=$base/lib/py_pubsub

# ─── RESOLVE DEPENDENCIES ────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y

# ─── BUILD ───────────────────────────────────────────────────────────────────
# Build only this package:
colcon build --packages-select py_pubsub

# Build with symlink install (edit .py files and run immediately without rebuild):
# colcon build --packages-select py_pubsub --symlink-install

# ─── SOURCE THE OVERLAY ──────────────────────────────────────────────────────
# Open a NEW terminal for running nodes:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
source install/setup.bash

# ─── RUN THE TALKER (Terminal 2) ─────────────────────────────────────────────
ros2 run py_pubsub talker
# Expected output every 0.5s:
# [INFO] [minimal_publisher]: Publishing: "Hello World: 0"
# [INFO] [minimal_publisher]: Publishing: "Hello World: 1"
# ...

# ─── RUN THE LISTENER (Terminal 3) ───────────────────────────────────────────
# Open yet another new terminal:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
source install/setup.bash
ros2 run py_pubsub listener
# Expected output:
# [INFO] [minimal_subscriber]: I heard: "Hello World: 10"
# [INFO] [minimal_subscriber]: I heard: "Hello World: 11"
# ...

# Press Ctrl+C in both terminals to stop the nodes.

# ─── USEFUL COLCON VARIANTS ──────────────────────────────────────────────────
# Build with live output in terminal:
# colcon build --packages-select py_pubsub --event-handlers console_direct+

# Build one package and all its upstream dependencies:
# colcon build --packages-up-to py_pubsub

# Run tests for this package:
# colcon test --packages-select py_pubsub
# colcon test-result --verbose
```
