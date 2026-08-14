
# Writing a Simple Publisher and Subscriber (C++) — Deep Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. The Red Underline on `#include "rclcpp/rclcpp.hpp"` — Why It Happens and All Fixes

### Why the Red Line Appears

When you write `#include "rclcpp/rclcpp.hpp"` in VS Code, a language server running in the background (either Microsoft's C/C++ IntelliSense engine or clangd) scans your system for header files to provide autocomplete and error checking. ROS 2 headers live at `/opt/ros/jazzy/include/`. The language server does not know this path exists until you tell it or give it a build artifact that maps it out. The build has not run yet, so nothing has told it.

This is purely a **language server configuration issue** — not a build error. The compiler itself (`g++`) finds the headers just fine once you source ROS 2 and run `colcon build`, because at that point the shell environment variable `CMAKE_PREFIX_PATH` contains `/opt/ros/jazzy`. The red line is the editor's linting layer being uninformed, not an actual broken include.

### Fix 1: Launch VS Code from a Sourced Terminal (Simplest)

When you start VS Code from a terminal that has ROS 2 sourced, VS Code inherits that shell's environment variables. The C/C++ extension then already knows about `/opt/ros/jazzy/include/` and the red line disappears without any other configuration.

```bash
# In your terminal, source ROS 2 first:
source /opt/ros/jazzy/setup.bash

# Then launch VS Code from the same terminal:
code ~/ros2_ws
```

This works because VS Code spawns its IntelliSense process as a child of the terminal process, inheriting the `PATH`, `CMAKE_PREFIX_PATH`, and other variables that include the ROS 2 install paths.

**Limitation:** if you open VS Code by clicking an icon on the desktop or from an application menu, it launches from the system default environment (no ROS 2 sourced) and the red line returns. You need to consistently open VS Code from a sourced terminal for this to work reliably.

### Fix 2: Build with `compile_commands.json` and Use clangd (Best Long-Term)

The cleanest approach is to generate a `compile_commands.json` file. This is a standardized JSON file that records the exact compiler invocation (compiler path, flags, include directories) for every source file in the project. Language servers like clangd can read it and know exactly where all headers are.

**Step 1** — Tell CMake to generate it at build time:

```bash
cd ~/ros2_ws
colcon build --packages-select cpp_pubsub \
  --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

This creates `~/ros2_ws/build/cpp_pubsub/compile_commands.json`. Inside it you will see entries like:

```json
{
  "command": "g++ -I/opt/ros/jazzy/include/rclcpp ... -c publisher_lambda_function.cpp",
  "file": ".../publisher_lambda_function.cpp"
}
```

The language server reads this and knows exactly where every include comes from.

**Step 2** — Install the clangd extension in VS Code and point it at the file. Create `.vscode/settings.json` in your workspace root:

```json
{
  "clangd.arguments": [
    "--compile-commands-dir=${workspaceFolder}/build/cpp_pubsub"
  ]
}
```

Now clangd reads the build database and resolves every include automatically. Autocomplete shows you the exact function signature, parameter names, and return types — all sourced from the real installed headers.

**Does `colcon` have a shortcut for this?** Yes — the `compile-commands` mixin from the default mixin repository does exactly this:

```bash
colcon build --packages-select cpp_pubsub --mixin compile-commands
```

This is equivalent to the `--cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` version but more convenient.

### Fix 3: Manually Edit `c_cpp_properties.json` (Quickest, Less Accurate)

If you want autocomplete without building at all, you can manually tell the Microsoft C/C++ extension where ROS 2 headers live by creating `.vscode/c_cpp_properties.json`:

```json
{
  "configurations": [
    {
      "name": "Linux",
      "includePath": [
        "${workspaceFolder}/**",
        "/opt/ros/jazzy/include/**"
      ],
      "defines": [],
      "compilerPath": "/usr/bin/g++",
      "cppStandard": "c++17",
      "intelliSenseMode": "linux-gcc-x64"
    }
  ],
  "version": 4
}
```

The `**` glob tells IntelliSense to scan all subdirectories recursively. You will immediately get include resolution and basic autocomplete for `rclcpp` types.

**Why this is less accurate than `compile_commands.json`:** This method tells IntelliSense which directories to scan but not which specific flags the compiler uses. This means it may miss preprocessor definitions or find headers in the wrong order. It works for basic navigation and autocomplete but may show false errors on advanced ROS 2 macro usage. The `compile_commands.json` approach is always more precise.

### Does Sourcing ROS 2 Alone Fix It?

Sourcing ROS 2 in a terminal modifies that terminal's environment variables. If VS Code was already open (not launched from that terminal), it does not receive those changes because VS Code's IntelliSense process is already running with the old environment. Sourcing only helps if you launch VS Code **after** sourcing, as described in Fix 1.

### Summary of All Three Options

| Method                      | Requires build first | Accuracy | Ease   |
| --------------------------- | -------------------- | -------- | ------ |
| Launch VS Code after source | No                   | Good     | Easy   |
| `compile_commands.json`     | Yes (one build)      | Exact    | Medium |
| `c_cpp_properties.json`     | No                   | Partial  | Easy   |

---

## 2. Build Before Writing to Enable Autocomplete

Yes. This is a legitimate and common workflow. The trick is to add just enough content to `CMakeLists.txt` first (the `find_package` calls and the `add_executable` registration), then run a first build with empty or stub source files. After that, `compile_commands.json` exists and IntelliSense works for everything you write next.

### Step-by-Step

**Step 1** — Create the package and an empty source file:

```bash
cd ~/ros2_ws/src
ros2 pkg create --build-type ament_cmake --license Apache-2.0 cpp_pubsub
touch cpp_pubsub/src/publisher_lambda_function.cpp
touch cpp_pubsub/src/subscriber_lambda_function.cpp
```

**Step 2** — Edit `CMakeLists.txt` to declare dependencies and register the executables (even though the source files are empty). Add after `find_package(ament_cmake REQUIRED)`:

```cmake
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

add_executable(talker src/publisher_lambda_function.cpp)
ament_target_dependencies(talker rclcpp std_msgs)

add_executable(listener src/subscriber_lambda_function.cpp)
ament_target_dependencies(listener rclcpp std_msgs)

install(TARGETS talker listener
  DESTINATION lib/${PROJECT_NAME})
```

**Step 3** — Run the build with compile_commands generation:

```bash
cd ~/ros2_ws
colcon build --packages-select cpp_pubsub \
  --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

The build will succeed because the empty `.cpp` files are valid C++ (they compile to empty translation units). The `compile_commands.json` is now generated.

**Step 4** — Open VS Code, configure it to use the compile_commands file, then start writing your actual node code. Every `rclcpp::` type you type will have full autocomplete, parameter hints, and go-to-definition support.

This first build takes the same amount of time as any real build. The advantage is you only need to do it once before starting to code, and from then on you write with full language support.

---

## 3. Code Patterns in the Publisher and Subscriber

Both files follow the same layered structure. Understanding the pattern makes every ROS 2 C++ node you ever read immediately familiar.

### Layer 1: Includes — What Libraries You Need

```cpp
#include <chrono>        // C++ standard: time durations (500ms, 1s, etc.)
#include <memory>        // C++ standard: smart pointers (shared_ptr, make_shared)
#include <string>        // C++ standard: std::string, std::to_string()

#include "rclcpp/rclcpp.hpp"         // The entire ROS 2 C++ client library
#include "std_msgs/msg/string.hpp"   // The String message type definition
```

The pattern is: **standard C++ headers first** (angle brackets `<>`), then **ROS and package headers** (double quotes `""`). This ordering is a convention that makes clear what is system-level and what is ROS-specific. Every ROS 2 message type has a header at `<package>/msg/<MessageType>.hpp` in lowercase with underscores.

### Layer 2: Namespace Convenience

```cpp
using namespace std::chrono_literals;
```

This single line makes `500ms`, `1s`, `2min` valid C++ duration literals instead of having to write `std::chrono::milliseconds(500)`. It is used only in the publisher because the publisher needs a timer; the subscriber reacts to incoming messages and has no timer.

### Layer 3: Class Definition — Your Node IS the Class

```cpp
class MinimalPublisher : public rclcpp::Node
```

Every ROS 2 C++ node is a **class that inherits from `rclcpp::Node`**. This inheritance gives your class all ROS node capabilities: the ability to create publishers, subscribers, timers, services, parameters, and a logger. The phrase `public rclcpp::Node` means MinimalPublisher is-a Node with full access to all its public methods.

### Layer 4: Constructor — Wire Everything Together

The constructor is where all the ROS communication primitives are created. The pattern for the publisher constructor has four distinct steps:

```cpp
MinimalPublisher()
: Node("minimal_publisher"), count_(0)   // Step A: name the node, init member vars
{
  publisher_ = this->create_publisher<std_msgs::msg::String>("topic", 10);
  // Step B: create publisher — type, topic name, queue size

  auto timer_callback =
    [this]() -> void {
      auto message = std_msgs::msg::String();
      message.data = "Hello, world! " + std::to_string(this->count_++);
      RCLCPP_INFO(this->get_logger(), "Publishing: '%s'", message.data.c_str());
      this->publisher_->publish(message);
    };
  // Step C: define callback as a lambda that uses this node's publisher

  timer_ = this->create_wall_timer(500ms, timer_callback);
  // Step D: create a wall timer that fires every 500ms and calls the callback
}
```

The subscriber constructor follows the same four steps but in a slightly different order because there is no timer:

```cpp
MinimalSubscriber()
: Node("minimal_subscriber")             // Step A: name the node (no counter needed)
{
  auto topic_callback =
    [this](std_msgs::msg::String::UniquePtr msg) -> void {
      RCLCPP_INFO(this->get_logger(), "I heard: '%s'", msg->data.c_str());
    };
  // Step B: define callback first — it receives a message as its parameter

  subscription_ =
    this->create_subscription<std_msgs::msg::String>("topic", 10, topic_callback);
  // Step C: create subscription — type, topic name, queue size, callback
  // Step D: no timer needed
}
```

### Layer 5: Private Member Declarations

```cpp
private:
  rclcpp::TimerBase::SharedPtr timer_;
  rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
  size_t count_;
```

```cpp
private:
  rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
```

All ROS communication objects are held as `SharedPtr` (shared pointer) members. This is a strict ROS 2 convention: you never store a raw pointer to a publisher, subscriber, timer, or service. SharedPtr ensures the object lives as long as the node lives and is automatically cleaned up when the node is destroyed. The pattern is always `rclcpp::<ObjectType><MessageType>::SharedPtr member_name_;`.

### Layer 6: The `main` Function — Identical in Both

```cpp
int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);                              // Initialize ROS 2
  rclcpp::spin(std::make_shared<MinimalPublisher>());    // Create node, run it
  rclcpp::shutdown();                                    // Clean up on Ctrl+C
  return 0;
}
```

This three-line pattern is the same in every single-node ROS 2 C++ executable:

`rclcpp::init(argc, argv)` sets up the ROS 2 middleware, reads command-line arguments for remapping or parameters, and connects to the DDS network.

`rclcpp::spin(node)` hands control to the ROS 2 executor. For the publisher, "spinning" means the executor fires the timer callback every 500ms. For the subscriber, "spinning" means the executor checks the DDS network for incoming messages and calls the topic_callback whenever one arrives. `spin` blocks — it does not return until the node is shut down.

`rclcpp::shutdown()` is called after `spin` returns (which only happens on Ctrl+C or another shutdown signal). It tears down all communication, closes network connections, and frees memory.

`std::make_shared<MinimalPublisher>()` creates the node instance on the heap and wraps it in a shared pointer. This is required because `rclcpp::spin` takes a `shared_ptr<Node>`, not a raw pointer or a stack-allocated object.

### Pattern Comparison Table

| Layer              | Publisher                                              | Subscriber                                        |
| ------------------ | ------------------------------------------------------ | ------------------------------------------------- |
| Includes           | `<chrono>`, `<memory>`, `<string>` + ROS headers       | `<memory>` only + ROS headers                     |
| Namespace          | `using namespace std::chrono_literals`                 | (none needed)                                     |
| Class              | `class MinimalPublisher : public rclcpp::Node`         | `class MinimalSubscriber : public rclcpp::Node`   |
| Constructor step 1 | Name node, init count_ to 0                            | Name node (no counter)                            |
| Constructor step 2 | `create_publisher<Type>("topic", queue)`               | Define lambda callback with msg parameter         |
| Constructor step 3 | Define lambda callback (no parameters)                 | `create_subscription<Type>("topic", q, cb)`       |
| Constructor step 4 | `create_wall_timer(500ms, callback)`                   | (no timer)                                        |
| Private members    | `timer_`, `publisher_`, `count_`                       | `subscription_` only                              |
| `main`             | `init`, `spin`, `shutdown`                             | `init`, `spin`, `shutdown` (identical)            |

### Lambda Pattern Explained

Both nodes use C++11 lambda functions as callbacks instead of named member functions. The lambda syntax `[this]() -> void { ... }` means:

- `[this]` — capture the current object by reference so the lambda body can call `this->publisher_->publish()` or `this->get_logger()`
- `()` — the lambda takes no parameters (publisher timer callback needs nothing; the message is built inside)
- `(std_msgs::msg::String::UniquePtr msg)` — the subscriber lambda takes the incoming message as its parameter (`UniquePtr` means the lambda owns this message exclusively)
- `-> void` — explicitly declare the return type is void (optional but clear)

---

## 4. The Three-Command Build Sequence Explained

```bash
rosdep install -i --from-path src --rosdistro jazzy -y
colcon build --packages-select cpp_pubsub
. install/setup.bash
```

### Command 1: `rosdep install -i --from-path src --rosdistro jazzy -y`

This reads the `<depend>` tags from every `package.xml` in `src/` and installs any system packages that are missing. For `cpp_pubsub`, the `package.xml` declares `<depend>rclcpp</depend>` and `<depend>std_msgs</depend>`. rosdep checks whether the corresponding system packages (the pre-compiled apt packages from `/opt/ros/jazzy/`) are already installed. Because you installed Jazzy's desktop package earlier, these are almost certainly present, and the command returns `#All required rosdeps installed successfully` immediately.

Running it anyway is **good practice** because:

- You might have added a new dependency to `package.xml` and forgotten to install it
- A new contributor to your project might not have your exact system setup
- The cost of running rosdep when everything is installed is near zero

Flag breakdown:

- `-i` / `--ignore-src`: if a dependency's source code is already in `src/`, don't try to install it from apt (avoid overriding your own workspace packages)
- `--from-path src`: scan the `src/` directory for `package.xml` files
- `--rosdistro jazzy`: use the Jazzy entry in rosdep's database (maps abstract names to concrete apt package names for Jazzy)
- `-y`: answer yes to all apt install prompts without asking

### Command 2: `colcon build --packages-select cpp_pubsub`

Builds only the `cpp_pubsub` package, skipping all other packages in the workspace. Without `--packages-select`, colcon would rebuild every package in `src/` — including `turtlesim` and anything else you cloned in earlier tutorials — which is unnecessary and slow.

`--packages-select` differs from `--packages-up-to`: `--packages-select` builds **only** the named package, assuming all its dependencies are already built in the underlay or install space. `--packages-up-to` would also rebuild any ROS package dependencies that are not yet built. For a package like `cpp_pubsub` that depends only on core Jazzy packages (already installed in `/opt/ros/jazzy/`), `--packages-select` is sufficient and faster.

The build process for this package is:

1. CMake configures: reads `CMakeLists.txt`, runs `find_package(rclcpp)` and `find_package(std_msgs)` against the sourced Jazzy install
2. CMake generates: produces `Makefile` in `build/cpp_pubsub/`
3. Make compiles: runs `g++` on `publisher_lambda_function.cpp` and `subscriber_lambda_function.cpp`, producing the `talker` and `listener` binaries
4. CMake installs: copies binaries to `install/cpp_pubsub/lib/cpp_pubsub/talker` and `listener`

### Command 3: `. install/setup.bash`

The `.` (dot) is the POSIX shorthand for `source`. These are exactly equivalent:

```bash
source install/setup.bash
. install/setup.bash
```

Both execute `install/setup.bash` inside the current shell process. The reason `.` (dot-space) is used in the tutorial is that it works in all POSIX-compatible shells (bash, zsh, dash, sh), while `source` is a bash built-in that may not exist in strictly POSIX shells. In practice, on Ubuntu with bash, they are identical.

`install/setup.bash` (with no `local_` prefix) activates both the Jazzy underlay and this workspace's overlay together. After running this, `ros2 run cpp_pubsub talker` resolves `cpp_pubsub` from your workspace's `install/` directory.

---

## 5. Full Commands — One `.sh` Script

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Writing a Simple Publisher and Subscriber (C++)
# Run from your home directory or any convenient location.
# ─────────────────────────────────────────────────────────────────────────────

# ─── SOURCE UNDERLAY ─────────────────────────────────────────────────────────
source /opt/ros/jazzy/setup.bash

# ─── NAVIGATE TO WORKSPACE src/ ──────────────────────────────────────────────
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
ros2 pkg create --build-type ament_cmake --license Apache-2.0 cpp_pubsub

# ─── DOWNLOAD THE SOURCE FILES ───────────────────────────────────────────────
cd ~/ros2_ws/src/cpp_pubsub/src

wget -O publisher_lambda_function.cpp \
  https://raw.githubusercontent.com/ros2/examples/jazzy/rclcpp/topics/minimal_publisher/lambda.cpp

wget -O subscriber_lambda_function.cpp \
  https://raw.githubusercontent.com/ros2/examples/jazzy/rclcpp/topics/minimal_subscriber/lambda.cpp

# ─── VERIFY BOTH FILES EXIST ─────────────────────────────────────────────────
ls
# Expected: publisher_lambda_function.cpp  subscriber_lambda_function.cpp

# ─── ADD DEPENDENCIES TO package.xml ─────────────────────────────────────────
# Navigate to the package root where package.xml lives:
cd ~/ros2_ws/src/cpp_pubsub

# Add <depend>rclcpp</depend> and <depend>std_msgs</depend> inside package.xml
# after the <buildtool_depend>ament_cmake</buildtool_depend> line.
# Do this manually in your editor.

# ─── WRITE CMakeLists.txt ─────────────────────────────────────────────────────
# Replace the contents of CMakeLists.txt with the following.
# Do this manually in your editor, or use the heredoc below:
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.5)
project(cpp_pubsub)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

add_executable(talker src/publisher_lambda_function.cpp)
ament_target_dependencies(talker rclcpp std_msgs)

add_executable(listener src/subscriber_lambda_function.cpp)
ament_target_dependencies(listener rclcpp std_msgs)

install(TARGETS
  talker
  listener
  DESTINATION lib/${PROJECT_NAME})

ament_package()
EOF

# ─── RESOLVE DEPENDENCIES ────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y

# ─── BUILD ───────────────────────────────────────────────────────────────────
# Build only this package:
colcon build --packages-select cpp_pubsub

# Build with compile_commands.json for VS Code IntelliSense (recommended):
# colcon build --packages-select cpp_pubsub \
#   --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# ─── SOURCE THE OVERLAY ──────────────────────────────────────────────────────
# Open a NEW terminal, then:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
. install/setup.bash

# ─── RUN THE TALKER (Terminal 2) ─────────────────────────────────────────────
ros2 run cpp_pubsub talker
# Expected output every 0.5s:
# [INFO] [minimal_publisher]: Publishing: "Hello World: 0"
# [INFO] [minimal_publisher]: Publishing: "Hello World: 1"
# ...

# ─── RUN THE LISTENER (Terminal 3) ───────────────────────────────────────────
# Open yet another new terminal:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
. install/setup.bash
ros2 run cpp_pubsub listener
# Expected output:
# [INFO] [minimal_subscriber]: I heard: "Hello World: 10"
# [INFO] [minimal_subscriber]: I heard: "Hello World: 11"
# ...

# Press Ctrl+C in both terminals to stop the nodes.

# ─── INTELLISENSE SETUP (VS Code) ────────────────────────────────────────────

# Option A — launch VS Code from a sourced terminal:
# source /opt/ros/jazzy/setup.bash && code ~/ros2_ws

# Option B — generate compile_commands.json then configure clangd:
# cd ~/ros2_ws
# colcon build --packages-select cpp_pubsub \
#   --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
# mkdir -p ~/ros2_ws/.vscode
# cat > ~/ros2_ws/.vscode/settings.json << 'VSCODE'
# {
#   "clangd.arguments": [
#     "--compile-commands-dir=${workspaceFolder}/build/cpp_pubsub"
#   ]
# }
# VSCODE

# Option C — manually set includePath in c_cpp_properties.json:
# mkdir -p ~/ros2_ws/.vscode
# cat > ~/ros2_ws/.vscode/c_cpp_properties.json << 'PROPS'
# {
#   "configurations": [
#     {
#       "name": "Linux",
#       "includePath": [
#         "${workspaceFolder}/**",
#         "/opt/ros/jazzy/include/**"
#       ],
#       "compilerPath": "/usr/bin/g++",
#       "cppStandard": "c++17",
#       "intelliSenseMode": "linux-gcc-x64"
#     }
#   ],
#   "version": 4
# }
# PROPS

# ─── COLCON QUICK REFERENCE ──────────────────────────────────────────────────
# Build only one package:
# colcon build --packages-select cpp_pubsub

# Build one package and all its dependencies:
# colcon build --packages-up-to cpp_pubsub

# Build with live console output:
# colcon build --packages-select cpp_pubsub --event-handlers console_direct+

# Build sequentially (one at a time):
# colcon build --packages-select cpp_pubsub --executor sequential

# Build with symlink install (useful for Python; less relevant for C++):
# colcon build --packages-select cpp_pubsub --symlink-install
```
