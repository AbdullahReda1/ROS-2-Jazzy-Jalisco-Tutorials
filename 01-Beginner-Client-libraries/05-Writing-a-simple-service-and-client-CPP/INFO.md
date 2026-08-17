
# Writing a Simple Service and Client (C++) — Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. `argc` and `argv` — Two Equivalent Declarations

### What They Are

`argc` (argument count) is an integer holding how many strings the OS passed to the program. `argv` (argument vector) is an array of those strings as null-terminated C-strings.

```cpp
int main(int argc, char **argv)      // service code style
int main(int argc, char * argv[])    // topic code style
```

These two declarations are **exactly equivalent**. In C and C++, a function parameter declared as an array (`T param[]`) is silently converted by the compiler to a pointer (`T *param`). So `char * argv[]` becomes `char **argv` — they compile to identical machine code. Both are equally common and acceptable; pick either style.

### How They Are Used

When you run `ros2 run cpp_srvcli client 2 3`, the operating system launches the `client` binary and delivers these values:

```text
argc   = 3
argv[0] = "/path/to/install/cpp_srvcli/lib/cpp_srvcli/client"  (the binary itself)
argv[1] = "2"
argv[2] = "3"
```

`argv[0]` is always the program's own path. User-supplied arguments start at index 1. All entries are C-strings — even numbers arrive as the text characters `"2"` and `"3"`, not as integers, which is why `atoll()` is needed later to convert them.

`rclcpp::init(argc, argv)` is always the first call. It lets rclcpp scan `argv` for ROS-specific flags (anything after `--ros-args`, like `--remap topic:=other`) and strip them out before your code processes the remaining arguments.

---

## 2. Class-Based (Topics) vs Function-Based (Services) — Why the Difference

### The Root Reason: Stateful vs Stateless

A topic publisher or subscriber has **persistent state**. The publisher holds a counter that increments across hundreds of timer callbacks. The subscriber holds an active subscription that must stay alive throughout the node's lifetime. State that lives across multiple callbacks naturally belongs in a class, where member variables survive between function calls. `this` is what lets the lambda callback reach `this->publisher_` or `this->count_` across those calls.

A service handler is **stateless**. The `add()` function receives a request, computes `request->a + request->b`, writes the result to `response->sum`, and returns. Every call is self-contained. Nothing needs to be remembered between one request and the next. A free function handles this cleanly without needing a class at all.

```cpp
// Topics — class holds state that persists across callbacks
class MinimalPublisher : public rclcpp::Node {
    void timer_callback() {
        this->publisher_->publish(msg);   // reaches member via 'this'
        this->count_++;
    }
    rclcpp::Publisher<...>::SharedPtr publisher_;
    size_t count_;
};

// Services — stateless free function, no class needed
void add(const std::shared_ptr<...::Request> request,
         std::shared_ptr<...::Response> response) {
    response->sum = request->a + request->b;
}
```

### `this` vs `make_shared` in `main()`

In topics, the node IS the class instance. You never hold a separate named pointer to it — `rclcpp::spin(std::make_shared<MinimalPublisher>())` creates it inline and hands it directly to spin.

In services, the node is a named local variable created with `make_shared` and then used explicitly in two separate steps:

```cpp
std::shared_ptr<rclcpp::Node> node = rclcpp::Node::make_shared("add_two_ints_server");
// node is created...
rclcpp::Service<...>::SharedPtr service = node->create_service<...>("add_two_ints", &add);
// ...then used here
rclcpp::spin(node);
// ...and here
```

The node variable must be named because it is referenced multiple times in `main()`. Naming it requires `make_shared` to produce a reusable `shared_ptr`.

### `const` Parameters Without `&` — Why No Reference

```cpp
void add(const std::shared_ptr<example_interfaces::srv::AddTwoInts::Request> request,
              std::shared_ptr<example_interfaces::srv::AddTwoInts::Response>  response)
```

`const` on `request` means: "you cannot reassign `request` to point to a different object." You can still read `request->a` and `request->b` through it. The `Response` has no `const` because the function must write `response->sum`.

As for no `&` (no reference): `shared_ptr` is already a lightweight handle — it's just a raw pointer plus a small reference count. Passing a `shared_ptr` by value copies those two things (typically 16 bytes) and increments the reference count. This is intentional: the middleware calling convention uses pass-by-value `shared_ptr` to ensure the handler always holds a valid owning reference to the request and response objects for the entire duration of the call. Passing by `const &` would also work technically, but the ROS 2 API convention is pass-by-value here.

---

## 3. Client Code — In Tutorial Order

### Argument Check

```cpp
if (argc != 3) {
    RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "usage: add_two_ints_client X Y");
    return 1;
}
```

`argc` equals 3 when you pass exactly two numbers: `argv[0]` is the binary, `argv[1]` is the first number, `argv[2]` is the second. So `argc != 3` is true in all other cases:

| Command                              | `argc` | Result                          |
| ------------------------------------ | ------ | ------------------------------- |
| `ros2 run cpp_srvcli client`         | 1      | Fails check — no numbers given  |
| `ros2 run cpp_srvcli client 5`       | 2      | Fails check — only one number   |
| `ros2 run cpp_srvcli client 2 3`     | 3      | Passes check — correct          |
| `ros2 run cpp_srvcli client 1 2 3`   | 4      | Fails check — too many          |

The message `"usage: add_two_ints_client X Y"` is a standard Unix help text pattern. It tells the user the correct syntax: run the program with two integer arguments named X and Y. `return 1` exits with a non-zero exit code, which on Unix signals an error to the caller (shell scripts and CI systems check exit codes).

### `wait_for_service(1s)` and `!rclcpp::ok()`

```cpp
while (!client->wait_for_service(1s)) {
    if (!rclcpp::ok()) {
        RCLCPP_ERROR(rclcpp::get_logger("rclcpp"), "Interrupted while waiting for the service. Exiting.");
        return 0;
    }
    RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "service not available, waiting again...");
}
```

`client->wait_for_service(1s)` blocks for up to 1 second watching the DDS network for a service named `"add_two_ints"`. It returns `true` if the service is found and `false` if the 1-second timeout expires without finding it.

The `while (!...)` loop means: keep looping as long as the service is NOT found within 1 second. On each failed attempt, it checks `!rclcpp::ok()` — this flag becomes false if ROS 2 is shutting down (Ctrl+C was pressed while waiting). If ROS is shutting down, the function exits cleanly. If ROS is still running, it prints "service not available, waiting again..." and loops back to wait another 1 second.

This handles the common scenario where you start the client before the server. The client politely waits and retries rather than crashing immediately.

### `request->a = atoll(argv[1])` and `argv[2]`

```cpp
auto request = std::make_shared<example_interfaces::srv::AddTwoInts::Request>();
request->a = atoll(argv[1]);
request->b = atoll(argv[2]);
```

`Request` is a struct generated by the ROS 2 interface toolchain from the `.srv` file:

```text
int64 a
int64 b
---
int64 sum
```

The generated C++ struct has `int64_t a` and `int64_t b` fields. `argv[1]` and `argv[2]` are C-strings like `"2"` and `"3"`. `atoll()` (from `<cstdlib>`) converts a C-string to `long long`, which matches `int64_t`. So `atoll("2")` returns `2LL` and is assigned to `request->a`.

`request->a` uses the arrow operator because `request` is a `shared_ptr<Request>` (a pointer-like object). `->` dereferences the pointer and accesses the member — equivalent to `(*request).a`.

### `result` and `async_send_request`

```cpp
auto result = client->async_send_request(request);
```

`async_send_request` transmits the request over the DDS network to the server and **returns immediately** without waiting for the response. It returns a `std::shared_future<Response::SharedPtr>` — a future object that will eventually hold the server's response when it arrives. This is stored in `result`.

A `std::shared_future` is a standard C++ object representing a value that will exist in the future. Right after this line, `result` does not yet contain the response — it is a pending promise. The next step actually waits for it.

### `spin_until_future_complete` and `FutureReturnCode::SUCCESS`

```cpp
if (rclcpp::spin_until_future_complete(node, result) ==
    rclcpp::FutureReturnCode::SUCCESS)
```

`rclcpp::spin_until_future_complete(node, result)` is a specialized spin that runs the node's event loop — processing incoming network messages — until one of two things happens: the future `result` receives its value (the server responded), or the node is shut down. It then stops, unlike regular `rclcpp::spin(node)` which would run forever.

It returns a `rclcpp::FutureReturnCode`, which is a scoped enum with three values:

| Value           | Meaning                                                |
| --------------- | ------------------------------------------------------ |
| `SUCCESS`       | The future completed; the response is ready            |
| `INTERRUPTED`   | A shutdown signal (Ctrl+C) arrived before the response |
| `TIMEOUT`       | A timeout was set and expired before the response      |

Comparing against `rclcpp::FutureReturnCode::SUCCESS` confirms that the response actually arrived and is safe to read.

### `result.get()->sum`

```cpp
RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "Sum: %ld", result.get()->sum);
```

This unpacks in three steps:

`result` is a `std::shared_future<Response::SharedPtr>`. Calling `.get()` on a completed future returns its stored value — here a `Response::SharedPtr`, which is a `shared_ptr<AddTwoInts::Response>`. The `->sum` then dereferences that shared pointer and reads the `sum` field of the Response struct. The complete chain:

```text
result            →  std::shared_future<Response::SharedPtr>
result.get()      →  Response::SharedPtr  (i.e., shared_ptr<AddTwoInts::Response>)
result.get()->sum →  int64_t              (the actual integer answer)
```

You can only safely call `.get()` after `spin_until_future_complete` returned `SUCCESS`. Calling it before the future is ready would block indefinitely; calling it after `INTERRUPTED` would throw an exception.

### `rclcpp::Node::make_shared`

```cpp
std::shared_ptr<rclcpp::Node> node = rclcpp::Node::make_shared("add_two_ints_server");
```

`make_shared` is **not a C++ language keyword**. It is a function — specifically `rclcpp::Node::make_shared` is a static member function of the `rclcpp::Node` class. It is essentially a convenience wrapper around the standard library function `std::make_shared<rclcpp::Node>("add_two_ints_server")`.

`std::make_shared<T>(args...)` is the standard C++ way to create an object of type `T` on the heap and immediately wrap it in a `std::shared_ptr<T>` in one allocation. The rclcpp version does the same thing but for Node objects specifically. It exists so you can write `rclcpp::Node::make_shared(name)` instead of the longer `std::make_shared<rclcpp::Node>(name)`.

---

## 4. Server and Client — Flow Idea

### Server Flow (Always Running)

```text
1. rclcpp::init(argc, argv)
      │
      ▼
2. Create node "add_two_ints_server"
      │
      ▼
3. Create service "add_two_ints" on the node
   → registers the callback function &add
   → advertises the service over DDS network
      │
      ▼
4. Log: "Ready to add two ints."
      │
      ▼
5. rclcpp::spin(node)  ────────────────────────────────────────┐
      │                                                        │
      │  (waits forever for incoming requests)                 │
      │  A request arrives from a client →                     │
      │  middleware deserializes it →                          │
      │  calls add(request, response)                          │
      │      response->sum = request->a + request->b           │
      │      log the incoming values                           │
      │      log the outgoing sum                              │
      │  middleware serializes and sends response back ────────┘
      │
      ▼  (only when Ctrl+C is pressed)
6. rclcpp::shutdown()
```

### Client Flow (One Shot, Then Exits)

```text
1. rclcpp::init(argc, argv)
      │
      ▼
2. Check argc == 3 (must have exactly 2 number arguments)
      │  (exits with error if not)
      ▼
3. Create node "add_two_ints_client"
4. Create client for service "add_two_ints"
      │
      ▼
5. Fill request: a = argv[1], b = argv[2]
      │
      ▼
6. while (!wait_for_service(1s))
      │  poll the network every 1s
      │  exit if Ctrl+C pressed
      │  until server is found
      ▼
7. async_send_request(request) → returns future "result"
      │  (request is sent, returns immediately)
      ▼
8. spin_until_future_complete(node, result)
      │  (processes network events until response arrives)
      ▼
9. if SUCCESS → log "Sum: <value>"
   else       → log error
      │
      ▼
10. rclcpp::shutdown(), return 0
```

### Key Difference from Topics

A topic publisher never stops — it runs forever publishing at a fixed rate. A service client has a definite lifetime: it sends exactly one request, receives one response, and exits. This is why the client uses `spin_until_future_complete` (runs until one task is done) instead of `spin` (runs forever).

The server, by contrast, does run forever — just like a subscriber — because it must remain available to handle any number of future requests from any number of clients.

---

## 5. CMakeLists.txt Autocomplete Missing for `ament_target_dependencies`

### Why It Is Missing

`ament_target_dependencies` is not a built-in CMake command. It is a CMake **macro** defined inside the `ament_cmake` package, loaded at build time when CMake processes `find_package(ament_cmake REQUIRED)`. CMake language servers (the extension that powers VS Code's CMakeLists.txt autocomplete) only know about built-in CMake commands by default. They cannot know about macros from external packages unless they have seen those packages configured.

The same issue applies to any ament-specific command: `ament_package()`, `ament_export_dependencies()`, and so on.

### Fix 1: Build Once and Point the CMake Extension at the Build Directory

After the first build, cmake has fully processed all `find_package` calls and generated a `CMakeCache.txt` and related files in `build/cpp_srvcli/`. The CMake Tools extension in VS Code can read this configured build to understand which macros are available.

Open VS Code settings and configure:

```json
{
  "cmake.buildDirectory": "${workspaceFolder}/build/cpp_srvcli"
}
```

Or press `Ctrl+Shift+P` → "CMake: Configure" inside VS Code, which triggers cmake to run and populate the build directory. The extension then reads the configured project, loads the ament_cmake macro definitions, and autocomplete for `ament_target_dependencies` starts working.

### Fix 2: Install `cmake-language-server`

A dedicated CMake language server understands package-provided macros better than the generic VS Code extension. Install it via pip:

```bash
pip install cmake-language-server --break-system-packages
```

Then install the "CMake Language Support" VS Code extension (not "CMake Tools") which uses this language server. After one build so cmake can configure the project, the language server reads the generated cmake files and gains knowledge of all ament macros.

### Fix 3: Accept Limited Autocomplete for ament Commands

For simple projects, the pragmatic approach is to use autocomplete for built-in cmake commands (`add_executable`, `find_package`, `target_link_libraries`) and type the ament-specific commands manually. The ament macro names are short and consistent — once you know `ament_target_dependencies`, `ament_package`, and `ament_export_dependencies`, you will not need autocomplete for them.

---

## 6. All Commands — One Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Writing a Simple Service and Client (C++)
# ─────────────────────────────────────────────────────────────────────────────

# ─── SOURCE UNDERLAY ─────────────────────────────────────────────────────────
source /opt/ros/jazzy/setup.bash

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
cd ~/ros2_ws/src
ros2 pkg create --build-type ament_cmake --license Apache-2.0 cpp_srvcli \
  --dependencies rclcpp example_interfaces
# --dependencies automatically adds <depend> tags to package.xml
# and find_package() calls to CMakeLists.txt

# ─── UPDATE package.xml METADATA ─────────────────────────────────────────────
# Edit ~/ros2_ws/src/cpp_srvcli/package.xml and fill in:
# <description>C++ client server tutorial</description>
# <maintainer email="you@email.com">Your Name</maintainer>
# <license>Apache-2.0</license>

# ─── CREATE THE SERVER SOURCE FILE ───────────────────────────────────────────
cat > ~/ros2_ws/src/cpp_srvcli/src/add_two_ints_server.cpp << 'EOF'
#include "rclcpp/rclcpp.hpp"
#include "example_interfaces/srv/add_two_ints.hpp"

#include <memory>

void add(const std::shared_ptr<example_interfaces::srv::AddTwoInts::Request> request,
              std::shared_ptr<example_interfaces::srv::AddTwoInts::Response>  response)
{
  response->sum = request->a + request->b;
  RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "Incoming request\na: %ld b: %ld",
      request->a, request->b);
  RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "sending back response: [%ld]",
      (long int)response->sum);
}

int main(int argc, char **argv)
{
  rclcpp::init(argc, argv);
  std::shared_ptr<rclcpp::Node> node = rclcpp::Node::make_shared("add_two_ints_server");
  rclcpp::Service<example_interfaces::srv::AddTwoInts>::SharedPtr service =
    node->create_service<example_interfaces::srv::AddTwoInts>("add_two_ints", &add);
  RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "Ready to add two ints.");
  rclcpp::spin(node);
  rclcpp::shutdown();
}
EOF

# ─── CREATE THE CLIENT SOURCE FILE ───────────────────────────────────────────
cat > ~/ros2_ws/src/cpp_srvcli/src/add_two_ints_client.cpp << 'EOF'
#include "rclcpp/rclcpp.hpp"
#include "example_interfaces/srv/add_two_ints.hpp"

#include <chrono>
#include <cstdlib>
#include <memory>

using namespace std::chrono_literals;

int main(int argc, char **argv)
{
  rclcpp::init(argc, argv);

  if (argc != 3) {
    RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "usage: add_two_ints_client X Y");
    return 1;
  }

  std::shared_ptr<rclcpp::Node> node = rclcpp::Node::make_shared("add_two_ints_client");
  rclcpp::Client<example_interfaces::srv::AddTwoInts>::SharedPtr client =
    node->create_client<example_interfaces::srv::AddTwoInts>("add_two_ints");

  auto request = std::make_shared<example_interfaces::srv::AddTwoInts::Request>();
  request->a = atoll(argv[1]);
  request->b = atoll(argv[2]);

  while (!client->wait_for_service(1s)) {
    if (!rclcpp::ok()) {
      RCLCPP_ERROR(rclcpp::get_logger("rclcpp"),
          "Interrupted while waiting for the service. Exiting.");
      return 0;
    }
    RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "service not available, waiting again...");
  }

  auto result = client->async_send_request(request);
  if (rclcpp::spin_until_future_complete(node, result) ==
      rclcpp::FutureReturnCode::SUCCESS)
  {
    RCLCPP_INFO(rclcpp::get_logger("rclcpp"), "Sum: %ld", result.get()->sum);
  } else {
    RCLCPP_ERROR(rclcpp::get_logger("rclcpp"), "Failed to call service add_two_ints");
  }

  rclcpp::shutdown();
  return 0;
}
EOF

# ─── WRITE CMakeLists.txt ─────────────────────────────────────────────────────
cat > ~/ros2_ws/src/cpp_srvcli/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.5)
project(cpp_srvcli)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(example_interfaces REQUIRED)

add_executable(server src/add_two_ints_server.cpp)
ament_target_dependencies(server rclcpp example_interfaces)

add_executable(client src/add_two_ints_client.cpp)
ament_target_dependencies(client rclcpp example_interfaces)

install(TARGETS
  server
  client
  DESTINATION lib/${PROJECT_NAME})

ament_package()
EOF

# ─── RESOLVE DEPENDENCIES ────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y

# ─── BUILD ───────────────────────────────────────────────────────────────────
colcon build --packages-select cpp_srvcli

# Build with compile_commands.json for VS Code IntelliSense (recommended):
# colcon build --packages-select cpp_srvcli \
#   --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# ─── SOURCE THE OVERLAY ──────────────────────────────────────────────────────
# Open a NEW terminal for running nodes:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
source install/setup.bash

# ─── RUN THE SERVER (Terminal 2) ─────────────────────────────────────────────
ros2 run cpp_srvcli server
# Expected output, then waits:
# [INFO] [rclcpp]: Ready to add two ints.

# ─── RUN THE CLIENT (Terminal 3) ─────────────────────────────────────────────
# Open another new terminal:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
source install/setup.bash
ros2 run cpp_srvcli client 2 3
# Expected client output:
# [INFO] [rclcpp]: Sum: 5
#
# Expected server output (in Terminal 2):
# [INFO] [rclcpp]: Incoming request
# a: 2 b: 3
# [INFO] [rclcpp]: sending back response: [5]

# Press Ctrl+C in the server terminal to stop it.
```
